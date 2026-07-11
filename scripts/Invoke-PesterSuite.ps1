<#
.SYNOPSIS
Runs the Engineering Standards Pester suite with structured evidence.
.DESCRIPTION
Runs only tests co-located with this trusted standards checkout, writes summary
counts and sanitized individual results beneath a dedicated evidence root, and
fails on failed tests, NotRun tests, a non-Passed suite result, or zero discovery.
.PARAMETER EvidenceRoot
Dedicated output directory for pester-summary.json and pester-details.json.
.EXAMPLE
pwsh -NoProfile -File scripts/Invoke-PesterSuite.ps1 -EvidenceRoot evidence
.OUTPUTS
Pester output and structured JSON evidence.
.NOTES
This is a maintainer-profile validator, not a downstream project test runner.
#>
[CmdletBinding()]
param([Parameter(Mandatory)][string]$EvidenceRoot)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
$standardsRoot = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot '..')).Path
$evidenceFull = [System.IO.Path]::GetFullPath($EvidenceRoot)
New-Item -ItemType Directory -Path $evidenceFull -Force | Out-Null
$xmlPath = Join-Path $evidenceFull '.pester-results.xml'
$workspaceRoot = Split-Path -Parent $standardsRoot

try {
    $config = New-PesterConfiguration
    $config.Run.Path = Join-Path $standardsRoot 'tests'
    $config.Run.PassThru = $true
    $config.Output.Verbosity = 'Detailed'
    $config.TestResult.Enabled = $true
    $config.TestResult.OutputPath = $xmlPath
    $config.TestResult.OutputFormat = 'NUnitXml'
    $priorErrorActionPreference = $ErrorActionPreference
    $priorNativeErrorPreference = $PSNativeCommandUseErrorActionPreference
    try {
        # Some negative-path tests intentionally emit non-terminating errors.
        # They also invoke child processes that intentionally return nonzero.
        # Let Pester classify those results instead of aborting evidence creation.
        $ErrorActionPreference = 'Continue'
        $PSNativeCommandUseErrorActionPreference = $false
        $result = Invoke-Pester -Configuration $config
    }
    finally {
        $ErrorActionPreference = $priorErrorActionPreference
        $PSNativeCommandUseErrorActionPreference = $priorNativeErrorPreference
    }
    $discovered = [int]$result.PassedCount + [int]$result.FailedCount + [int]$result.SkippedCount + [int]$result.NotRunCount
    [ordered]@{
        result = [string]$result.Result
        discoveredCount = $discovered
        passedCount = [int]$result.PassedCount
        failedCount = [int]$result.FailedCount
        skippedCount = [int]$result.SkippedCount
        notRunCount = [int]$result.NotRunCount
        durationSeconds = [math]::Round($result.Duration.TotalSeconds, 3)
        generatedAtUtc = (Get-Date).ToUniversalTime().ToString('o')
    } | ConvertTo-Json -Depth 10 | Set-Content -LiteralPath (Join-Path $evidenceFull 'pester-summary.json') -Encoding utf8

    if (-not (Test-Path -LiteralPath $xmlPath -PathType Leaf)) { throw 'Pester did not produce the required NUnit XML result.' }
    & (Join-Path $standardsRoot 'scripts/Convert-PesterResultToSanitizedJson.ps1') -InputPath $xmlPath -OutputPath (Join-Path $evidenceFull 'pester-details.json') -RepositoryPath $workspaceRoot
    if ($discovered -eq 0) { throw 'Pester discovered zero tests.' }
    if ($result.Result -ne 'Passed' -or $result.FailedCount -gt 0 -or $result.NotRunCount -gt 0) {
        throw "Pester result was '$($result.Result)' with $($result.FailedCount) failed and $($result.NotRunCount) NotRun tests."
    }
}
finally {
    if (Test-Path -LiteralPath $xmlPath) { Remove-Item -LiteralPath $xmlPath -Force }
}
exit 0
