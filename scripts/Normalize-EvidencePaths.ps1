<#
.SYNOPSIS
Normalizes committed evidence paths.
.DESCRIPTION
Rewrites JSON evidence files so paths under the repository root are repository-relative.
Fails if Windows drive-qualified, UNC, or Unix absolute paths remain.
#>
[CmdletBinding()]
param(
    [string]$Path = '.',
    [string[]]$EvidencePath = @('evidence', 'examples/powershell-project/evidence')
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$root = (Resolve-Path -LiteralPath $Path).Path
$rootSlash = $root.Replace('\','/')

function ConvertTo-NormalizedEvidenceText {
    param([Parameter(Mandatory)][string]$Value)

    $normalized = $Value.Replace($root, '.').Replace($rootSlash, '.')
    if ($normalized.StartsWith('.\') -or $normalized.StartsWith('./')) {
        return $normalized.Substring(2)
    }
    if ($normalized.StartsWith('\') -and -not $normalized.StartsWith('\\')) {
        return $normalized.Substring(1)
    }
    $normalized
}

function Update-NormalizedEvidenceNode {
    param([AllowNull()]$Node)

    if ($Node -is [System.Collections.IDictionary]) {
        foreach ($key in @($Node.Keys)) {
            if ($Node[$key] -is [string]) {
                $Node[$key] = ConvertTo-NormalizedEvidenceText -Value $Node[$key]
            }
            elseif ($null -ne $Node[$key]) {
                Update-NormalizedEvidenceNode -Node $Node[$key]
            }
        }
    }
    elseif ($Node -is [System.Collections.IList]) {
        for ($index = 0; $index -lt $Node.Count; $index++) {
            if ($Node[$index] -is [string]) {
                $Node[$index] = ConvertTo-NormalizedEvidenceText -Value $Node[$index]
            }
            elseif ($null -ne $Node[$index]) {
                Update-NormalizedEvidenceNode -Node $Node[$index]
            }
        }
    }
}

foreach ($item in $EvidencePath) {
    $base = if ([System.IO.Path]::IsPathRooted($item)) { $item } else { Join-Path $root $item }
    if (-not (Test-Path -LiteralPath $base)) { continue }
    foreach ($file in Get-ChildItem -LiteralPath $base -Recurse -File -Filter *.json) {
        try {
            $document = Get-Content -LiteralPath $file.FullName -Raw | ConvertFrom-Json -AsHashtable
        }
        catch {
            throw "Evidence JSON '$($file.FullName)' is malformed: $($_.Exception.Message)"
        }
        Update-NormalizedEvidenceNode -Node $document
        $document | ConvertTo-Json -Depth 100 | Set-Content -LiteralPath $file.FullName -Encoding utf8
    }
}

$remaining = @()
foreach ($item in $EvidencePath) {
    $base = if ([System.IO.Path]::IsPathRooted($item)) { $item } else { Join-Path $root $item }
    if (-not (Test-Path -LiteralPath $base)) { continue }
    $jsonFiles = @(Get-ChildItem -LiteralPath $base -Recurse -File -Filter *.json)
    if ($jsonFiles.Count -gt 0) {
        $remaining += @(Select-String -LiteralPath $jsonFiles.FullName -Pattern '([A-Za-z]:\\|^\\\\[^\\]|/home/runner|/tmp/)' -ErrorAction SilentlyContinue)
    }
}
if ($remaining.Count -gt 0) {
    $remaining | ForEach-Object { Write-Error "Absolute path remains in $($_.Path):$($_.LineNumber)" }
    exit 1
}

Write-Output 'Evidence paths normalized.'
