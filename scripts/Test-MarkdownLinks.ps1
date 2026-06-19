<#
.SYNOPSIS
Validates internal Markdown links.
.DESCRIPTION
Checks relative Markdown links and skips external URLs because network availability is not guaranteed.
.PARAMETER Path
Repository root.
.PARAMETER OutputJson
Optional JSON report path.
.EXAMPLE
pwsh -NoProfile -File scripts/Test-MarkdownLinks.ps1 -Path .
.OUTPUTS
Console report and optional JSON.
.NOTES
External-link validation should be run separately when network access is available.
#>
[CmdletBinding()]
param([string]$Path='.', [string]$OutputJson)
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
Import-Module (Join-Path $PSScriptRoot 'GovernanceValidation.psm1') -Force
$root = (Resolve-Path -LiteralPath $Path).Path
$results = [System.Collections.Generic.List[object]]::new()
foreach ($file in Get-ChildItem -LiteralPath $root -Filter '*.md' -Recurse -File | Where-Object { $_.FullName -notmatch '\\.git\\' }) {
    $content = Get-Content -LiteralPath $file.FullName -Raw
    foreach ($match in [regex]::Matches($content, '(?<!!)\[[^\]]+\]\((?<target>[^)]+)\)')) {
        $target = $match.Groups['target'].Value.Trim()
        if ($target -match '^(https?:|mailto:|#)' -or $target -eq '') { continue }
        $target = $target.Split('#')[0].Trim('<','>')
        if ($target -eq '') { continue }
        try {
            if ([System.IO.Path]::IsPathRooted($target)) {
                $resolved = [System.IO.Path]::GetFullPath($target)
            }
            else {
                $resolved = [System.IO.Path]::GetFullPath((Join-Path $file.DirectoryName $target))
            }
            if (-not $resolved.StartsWith($root, [System.StringComparison]::OrdinalIgnoreCase)) {
                throw "Path '$target' resolves outside repository root '$root'."
            }
            if (-not (Test-Path -LiteralPath $resolved)) {
                $results.Add((New-ValidationResult -Status Failed -Message "Missing Markdown target '$target'." -Path $file.FullName))
            }
        }
        catch {
            $results.Add((New-ValidationResult -Status Failed -Message $_.Exception.Message -Path $file.FullName))
        }
    }
}
if ($results.Count -eq 0) { $results.Add((New-ValidationResult -Status Passed -Message 'Internal Markdown links validated.' -Path $root -Severity info)) }
$report = [ordered]@{ generatedAtUtc=(Get-Date).ToUniversalTime().ToString('o'); results=@($results); failed=@($results | Where-Object status -eq 'Failed').Count }
if ($OutputJson) { $report | ConvertTo-OrderedJson | Set-Content -LiteralPath $OutputJson -Encoding utf8 }
$report.results | ForEach-Object { "[$($_.status)] $($_.path) $($_.message)" }
if ($report.failed -gt 0) { exit 1 }
exit 0
