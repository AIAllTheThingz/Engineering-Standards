<#
.SYNOPSIS
Validates completion evidence.
.DESCRIPTION
Checks evidence structure, status consistency, timestamp ordering, optional commit consistency, and artifact hashes.
.PARAMETER Path
Repository path.
.PARAMETER EvidencePath
Evidence path.
.PARAMETER ExpectedCommitSha
Optional expected commit SHA.
.PARAMETER OutputJson
Optional JSON report.
.EXAMPLE
pwsh -File Invoke-EvidenceValidation.ps1 -Path . -EvidencePath evidence/completion-result.json
.OUTPUTS
Console and optional JSON.
.NOTES
Evidence is untrusted input.
#>
[CmdletBinding()]
param([string]$Path='.', [string]$EvidencePath='evidence/completion-result.json', [string]$ExpectedCommitSha, [string]$OutputJson)
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
Import-Module (Join-Path $PSScriptRoot '../../scripts/GovernanceValidation.psm1') -Force
$root = (Resolve-Path -LiteralPath $Path).Path
$results = [System.Collections.Generic.List[object]]::new()
try { $full = Resolve-SafePath $root $EvidencePath } catch { $results.Add((New-ValidationResult Failed $_.Exception.Message $EvidencePath)) }
if ($results.Count -eq 0 -and -not (Test-Path $full)) { $results.Add((New-ValidationResult Failed 'Completion evidence missing.' $EvidencePath)) }
if ($results.Count -eq 0) {
    foreach ($item in @(Test-GovernanceJsonDocument $full 'completion-result')) { $results.Add($item) }
    $evidence = Read-JsonFile $full
    if ($ExpectedCommitSha -and $evidence.commitSha -ne $ExpectedCommitSha) { $results.Add((New-ValidationResult Failed 'Commit SHA mismatch.' $EvidencePath)) }
    if ([datetime]$evidence.completedAtUtc -lt [datetime]$evidence.startedAtUtc) { $results.Add((New-ValidationResult Failed 'Completion timestamp precedes start timestamp.' $EvidencePath)) }
    if ($evidence.status -eq 'Passed') {
        foreach ($test in @($evidence.tests)) {
            if ($test.status -in @('Failed','NotRun','Blocked')) { $results.Add((New-ValidationResult Failed "Overall Passed conflicts with test '$($test.name)'." $EvidencePath)) }
        }
    }
    foreach ($artifact in @($evidence.artifacts)) {
        $artifactPath = Resolve-SafePath $root $artifact.path
        if (Test-Path $artifactPath -PathType Leaf) {
            $actual = (Get-FileHash $artifactPath -Algorithm SHA256).Hash.ToLowerInvariant()
            if ($actual -ne $artifact.sha256.ToLowerInvariant()) { $results.Add((New-ValidationResult Failed 'Artifact hash mismatch.' $artifact.path)) }
        } else { $results.Add((New-ValidationResult Warning 'Artifact listed but not present for hash verification.' $artifact.path warning)) }
    }
}
if (-not @($results | Where-Object status -eq 'Failed')) { $results.Add((New-ValidationResult Passed 'Evidence validation completed.' $EvidencePath info)) }
$report = [ordered]@{ generatedAtUtc=(Get-Date).ToUniversalTime().ToString('o'); results=@($results); failed=@($results | Where-Object status -eq 'Failed').Count }
if ($OutputJson) { $report | ConvertTo-OrderedJson | Set-Content -LiteralPath $OutputJson -Encoding utf8 }
$report.results | ForEach-Object { "[$($_.status)] $($_.path) $($_.message)" }
if ($report.failed -gt 0) { exit 1 }
exit 0
