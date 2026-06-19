<#
.SYNOPSIS
Runs defensive forbidden-pattern scanning.
.DESCRIPTION
Applies configurable regex patterns, supports reviewed allowlists, redacts findings, skips binary or large files, and emits JSON reports.
.PARAMETER Path
Repository path.
.PARAMETER PatternFile
Pattern JSON path.
.PARAMETER AllowlistFile
Optional allowlist JSON path.
.PARAMETER OutputJson
Optional JSON report.
.PARAMETER Advisory
Return success while recording findings.
.EXAMPLE
pwsh -File Invoke-ForbiddenPatternScan.ps1 -Path .
.OUTPUTS
Console and optional JSON.
.NOTES
This is not a complete secret scanner or SAST product.
#>
[CmdletBinding()]
param([string]$Path='.', [string]$PatternFile, [string]$AllowlistFile, [string]$OutputJson, [switch]$Advisory)
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
Import-Module (Join-Path $PSScriptRoot '../../scripts/GovernanceValidation.psm1') -Force
$root = (Resolve-Path -LiteralPath $Path).Path
if (-not $PatternFile) { $PatternFile = Join-Path $PSScriptRoot 'forbidden-patterns.json' }
$patterns = (Read-JsonFile $PatternFile).patterns
$allowlist = @()
if ($AllowlistFile -and (Test-Path $AllowlistFile)) { $allowlist = @((Read-JsonFile $AllowlistFile).entries) }
$findings = [System.Collections.Generic.List[object]]::new()
$files = Get-ChildItem -LiteralPath $root -Recurse -File | Where-Object { $_.FullName -notmatch '\\.git\\|node_modules|bin\\|obj\\|TestResults' -and $_.Name -ne 'forbidden-patterns.json' }
foreach ($file in $files) {
    if ($file.Length -gt 1048576) { continue }
    try { $content = Get-Content -LiteralPath $file.FullName -Raw -ErrorAction Stop } catch { continue }
    if ($content -match "`0") { continue }
    $relative = [System.IO.Path]::GetRelativePath($root, $file.FullName).Replace('\','/')
    foreach ($pattern in $patterns) {
        $allowed = $false
        foreach ($entry in $allowlist) {
            if ($entry.patternId -eq $pattern.id -and $relative -like $entry.path -and $entry.reason -and $entry.reason.Length -ge 10) { $allowed = $true }
        }
        foreach ($match in [regex]::Matches($content, $pattern.regex)) {
            if ($allowed) { continue }
            $snippet = $match.Value
            if ($snippet.Length -gt 12) { $snippet = $snippet.Substring(0,4) + '...[redacted]...' + $snippet.Substring($snippet.Length-4) } else { $snippet = '[redacted]' }
            $findings.Add([ordered]@{ patternId=$pattern.id; severity=$pattern.severity; path=$relative; description=$pattern.description; redactedMatch=$snippet })
        }
    }
}
$failed = @($findings | Where-Object severity -eq 'error').Count
$report = [ordered]@{ generatedAtUtc=(Get-Date).ToUniversalTime().ToString('o'); completeSecretScanner=$false; findings=@($findings); failed=$failed }
if ($OutputJson) { $report | ConvertTo-OrderedJson | Set-Content -LiteralPath $OutputJson -Encoding utf8 }
if ($findings.Count) { $findings | ForEach-Object { "[$($_.severity)] $($_.path) $($_.patternId): $($_.redactedMatch)" } } else { Write-Output '[Passed] No forbidden-pattern findings.' }
if ($failed -gt 0 -and -not $Advisory) { exit 1 }
exit 0
