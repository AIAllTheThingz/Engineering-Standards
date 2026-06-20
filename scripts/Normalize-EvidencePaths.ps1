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

foreach ($item in $EvidencePath) {
    $base = if ([System.IO.Path]::IsPathRooted($item)) { $item } else { Join-Path $root $item }
    if (-not (Test-Path -LiteralPath $base)) { continue }
    foreach ($file in Get-ChildItem -LiteralPath $base -Recurse -File -Filter *.json) {
        $content = Get-Content -LiteralPath $file.FullName -Raw
        $content = $content.Replace($root.Replace('\','\\'), '.').Replace($root, '.')
        $content = $content.Replace($rootSlash, '.')
        $content = $content.Replace('.\\', '')
        $content = $content -replace '"\./', '"'
        $content = $content -replace '"\\', '"'
        Set-Content -LiteralPath $file.FullName -Value $content -Encoding utf8
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
