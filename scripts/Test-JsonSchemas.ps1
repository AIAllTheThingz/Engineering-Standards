<#
.SYNOPSIS
Validates JSON schemas and fixtures.
.DESCRIPTION
Parses schema files and validates valid and invalid fixtures with repository-local structural validation.
.PARAMETER Path
Repository root.
.PARAMETER OutputJson
Optional JSON report path.
.EXAMPLE
pwsh -NoProfile -File scripts/Test-JsonSchemas.ps1 -Path .
.OUTPUTS
Console report and optional JSON.
.NOTES
This script does not install external validators. If a full JSON Schema validator is unavailable, the result is structural validation.
#>
[CmdletBinding()]
param([string]$Path='.', [string]$OutputJson)
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
Import-Module (Join-Path $PSScriptRoot 'GovernanceValidation.psm1') -Force
$root = (Resolve-Path -LiteralPath $Path).Path
$results = [System.Collections.Generic.List[object]]::new()
foreach ($schema in Get-ChildItem -LiteralPath (Join-Path $root 'schemas') -Filter '*.schema.json' -File) {
    try {
        $doc = Read-JsonFile -Path $schema.FullName
        foreach ($required in @('$schema','$id','type','properties','additionalProperties','required')) {
            if (-not $doc.ContainsKey($required)) {
                $results.Add((New-ValidationResult -Status Failed -Message "Schema missing '$required'." -Path $schema.FullName))
            }
        }
        $results.Add((New-ValidationResult -Status Passed -Message 'Schema parsed and declares required metadata.' -Path $schema.FullName -Severity info))
    }
    catch {
        $results.Add((New-ValidationResult -Status Failed -Message "Schema parse failed: $($_.Exception.Message)" -Path $schema.FullName))
    }
}
$map = @{
    'completion-result' = 'completion-result'
    'test-evidence' = 'test-evidence'
    'artifact-record' = 'artifact-record'
    'project-manifest' = 'project-manifest'
    'governance-config' = 'governance-config'
    'verified-run' = 'verified-run'
}
foreach ($mode in @('valid','invalid')) {
    $fixtureRoot = Join-Path $root "tests/fixtures/$mode"
    foreach ($fixture in Get-ChildItem -LiteralPath $fixtureRoot -Filter '*.json' -File) {
        $kind = $null
        foreach ($key in $map.Keys) {
            if ($fixture.BaseName -like "$key*") { $kind = $map[$key] }
        }
        if (-not $kind) { continue }
        $fixtureResults = @(Test-GovernanceJsonDocument -Path $fixture.FullName -Kind $kind)
        $hasFailure = @($fixtureResults | Where-Object status -eq 'Failed').Count -gt 0
        if ($mode -eq 'valid' -and -not $hasFailure) {
            $results.Add((New-ValidationResult -Status Passed -Message 'Valid fixture accepted.' -Path $fixture.FullName -Severity info))
        }
        elseif ($mode -eq 'invalid' -and $hasFailure) {
            $results.Add((New-ValidationResult -Status Passed -Message 'Invalid fixture rejected as expected.' -Path $fixture.FullName -Severity info -Data $fixtureResults))
        }
        else {
            $results.Add((New-ValidationResult -Status Failed -Message 'Fixture expectation failed.' -Path $fixture.FullName -Data $fixtureResults))
        }
    }
}
$report = [ordered]@{ generatedAtUtc=(Get-Date).ToUniversalTime().ToString('o'); results=@($results); failed=@($results | Where-Object status -eq 'Failed').Count }
if ($OutputJson) { $report | ConvertTo-OrderedJson | Set-Content -LiteralPath $OutputJson -Encoding utf8 }
$report.results | ForEach-Object { "[$($_.status)] $($_.path) $($_.message)" }
if ($report.failed -gt 0) { exit 1 }
exit 0
