<#
.SYNOPSIS
Validates governance contract adoption.
.DESCRIPTION
Validates manifest, governance config, required documentation, standards, exceptions, and documentation completeness without executing repository content.
.PARAMETER Path
Repository path.
.PARAMETER ManifestPath
Manifest path.
.PARAMETER ConfigPath
Governance config path.
.PARAMETER OutputJson
Optional JSON report.
.PARAMETER Advisory
Return success while preserving findings.
.EXAMPLE
pwsh -File Invoke-ContractValidation.ps1 -Path .
.OUTPUTS
Console and optional JSON.
.NOTES
Paths are resolved beneath the workspace.
#>
[CmdletBinding()]
param([string]$Path='.', [string]$ManifestPath='project-manifest.json', [string]$ConfigPath='governance.config.json', [string]$OutputJson, [switch]$Advisory)
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
Import-Module (Join-Path $PSScriptRoot '../../scripts/GovernanceValidation.psm1') -Force
$root = (Resolve-Path -LiteralPath $Path).Path
$standardsRoot = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot '../..')).Path
$results = [System.Collections.Generic.List[object]]::new()
try { $manifestFull = Resolve-SafePath $root $ManifestPath; $configFull = Resolve-SafePath $root $ConfigPath } catch { $results.Add((New-ValidationResult Failed $_.Exception.Message)) }
if ($results.Count -eq 0) {
    if (Test-Path $manifestFull) { foreach ($item in @(Test-GovernanceJsonDocument $manifestFull 'project-manifest')) { $results.Add($item) } } else { $results.Add((New-ValidationResult Failed 'Project manifest missing.' $ManifestPath)) }
    if (Test-Path $configFull) {
        foreach ($item in @(Test-GovernanceJsonDocument $configFull 'governance-config')) { $results.Add($item) }
        $cfg = Read-JsonFile $configFull
        foreach ($doc in @($cfg.requiredDocumentationPaths)) {
            $resolved = Resolve-SafePath $root $doc
            if (-not (Test-Path $resolved)) { $results.Add((New-ValidationResult Failed 'Required documentation missing.' $doc)) }
        }
    } else { $results.Add((New-ValidationResult Failed 'Governance config missing.' $ConfigPath)) }
    if ([string]::Equals($root, $standardsRoot, [System.StringComparison]::OrdinalIgnoreCase)) {
        & pwsh -NoProfile -File (Join-Path $standardsRoot 'scripts/Test-DocumentationCompleteness.ps1') -Path $root | Out-Null
        if ($LASTEXITCODE -ne 0) { $results.Add((New-ValidationResult Failed 'Documentation completeness validation failed.' $root)) }
    }
    else {
        $results.Add((New-ValidationResult Passed 'Required downstream documentation paths validated from governance config.' $root info))
    }
}
if (-not @($results | Where-Object status -eq 'Failed')) { $results.Add((New-ValidationResult Passed 'Contract validation completed.' $root info)) }
$report = [ordered]@{ generatedAtUtc=(Get-Date).ToUniversalTime().ToString('o'); results=@($results); failed=@($results | Where-Object status -eq 'Failed').Count }
if ($OutputJson) { $report | ConvertTo-OrderedJson | Set-Content -LiteralPath $OutputJson -Encoding utf8 }
$report.results | ForEach-Object { "[$($_.status)] $($_.path) $($_.message)" }
if ($report.failed -gt 0 -and -not $Advisory) { exit 1 }
exit 0
