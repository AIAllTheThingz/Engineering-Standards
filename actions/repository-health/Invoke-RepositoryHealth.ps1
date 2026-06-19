<#
.SYNOPSIS
Checks repository governance health.
.DESCRIPTION
Checks required files, JSON parsing, documentation completeness, schema fixtures, tests, CODEOWNERS, Dependabot, and branch-protection documentation.
.PARAMETER Path
Repository path.
.PARAMETER OutputJson
Optional JSON report.
.PARAMETER Advisory
Return success while recording findings.
.EXAMPLE
pwsh -File Invoke-RepositoryHealth.ps1 -Path .
.OUTPUTS
Console and optional JSON.
.NOTES
Does not execute repository content beyond local validators.
#>
[CmdletBinding()]
param([string]$Path='.', [string]$OutputJson, [switch]$Advisory)
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
Import-Module (Join-Path $PSScriptRoot '../../scripts/GovernanceValidation.psm1') -Force
$root = (Resolve-Path -LiteralPath $Path).Path
$results = [System.Collections.Generic.List[object]]::new()
$required = @('README.md','LICENSE','SECURITY.md','CONTRIBUTING.md','CODEOWNERS','project-manifest.json','governance.config.json','AGENTS.md','.github/dependabot.yml','.github/workflows/governance-ci.yml','.github/pull_request_template.md','docs/BRANCH_PROTECTION.md','scripts/Test-DocumentationCompleteness.ps1')
foreach ($item in $required) {
    $full = Resolve-SafePath $root $item
    if (Test-Path $full) { $results.Add((New-ValidationResult Passed 'Required health file exists.' $item info)) } else { $results.Add((New-ValidationResult Failed 'Required health file missing.' $item)) }
}
foreach ($json in Get-ChildItem -LiteralPath $root -Filter '*.json' -Recurse -File | Where-Object { $_.FullName -notmatch '\\.git\\' }) {
    try { Read-JsonFile $json.FullName | Out-Null } catch { $results.Add((New-ValidationResult Failed "Invalid JSON: $($_.Exception.Message)" ([System.IO.Path]::GetRelativePath($root,$json.FullName)))) }
}
& pwsh -NoProfile -File (Join-Path $root 'scripts/Test-DocumentationCompleteness.ps1') -Path $root | Out-Null
if ($LASTEXITCODE -ne 0) { $results.Add((New-ValidationResult Failed 'Documentation completeness failed.' $root)) }
if (-not (Get-ChildItem -LiteralPath (Join-Path $root 'tests') -Recurse -Filter '*.Tests.ps1')) { $results.Add((New-ValidationResult Failed 'No Pester tests found.' 'tests')) }
$failed = @($results | Where-Object status -eq 'Failed').Count
if ($failed -eq 0) { $results.Add((New-ValidationResult Passed 'Repository health validation completed.' $root info)) }
$report = [ordered]@{ generatedAtUtc=(Get-Date).ToUniversalTime().ToString('o'); results=@($results); failed=$failed }
if ($OutputJson) { $report | ConvertTo-OrderedJson | Set-Content -LiteralPath $OutputJson -Encoding utf8 }
$report.results | ForEach-Object { "[$($_.status)] $($_.path) $($_.message)" }
if ($failed -gt 0 -and -not $Advisory) { exit 1 }
exit 0
