<#
.SYNOPSIS
Runs the controlled nonproduction Codex skill behavior evaluator.
.DESCRIPTION
The evaluator consumes one sanitized JSON observation per case/sample from a
bounded provider command. It never grants write authority and does not retain raw
model transcripts. Replay mode validates mechanics but is always reported NotRun.
#>
[CmdletBinding()]
param(
    [string]$Path = '.',
    [Parameter(Mandatory)][string]$ObservationDirectory,
    [Parameter(Mandatory)][string]$OutputJson,
    [ValidateSet('Live', 'Replay')][string]$ExecutionMode = 'Replay',
    [string]$RunnerVersion,
    [string]$EvaluatedCommitSha,
    [ValidateSet('ModelUnavailable', 'TransportTimeout')][string]$UnavailableReason,
    [string]$UnavailableDetail
)
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
Import-Module (Join-Path $PSScriptRoot 'CodexSkillBehaviorEvaluation.psm1') -Force
$root = (Resolve-Path -LiteralPath $Path).Path
$observations = (Resolve-Path -LiteralPath $ObservationDirectory).Path
$declaredUnavailableReason = $UnavailableReason
$declaredUnavailableDetail = $UnavailableDetail
if ([IO.Path]::GetRelativePath($root, $observations).StartsWith('..')) { throw 'ObservationDirectory must be beneath the repository root.' }
$provider = {
    param($case, $index, $config)
    if ($declaredUnavailableReason) {
        $detail = if ($declaredUnavailableDetail) { $declaredUnavailableDetail } else { 'The approved model transport was unavailable.' }
        return [pscustomobject]@{ status = 'Blocked'; attemptCount = 2; failureReason = "$declaredUnavailableReason`: $detail" }
    }
    $file = Join-Path $observations ("{0}.{1}.json" -f $case.caseId, $index)
    if (-not (Test-Path -LiteralPath $file -PathType Leaf)) { return [pscustomobject]@{ status = 'Blocked'; failureReason = 'Required observation file is missing from this partial run.' } }
    $bytes = [IO.File]::ReadAllBytes($file)
    if ($bytes.Length -gt [int]$config.Limits.MaximumOutputBytes) { return [pscustomobject]@{ status = 'Blocked'; failureReason = 'Observation output exceeded the configured byte limit.' } }
    try { [Text.Encoding]::UTF8.GetString($bytes) | ConvertFrom-Json }
    catch { [pscustomobject]@{ status = 'Blocked'; failureReason = 'Observation output was malformed JSON and was not retried.' } }
}
$report = Invoke-CodexSkillBehaviorEvaluation -Path $root -ObservationProvider $provider -ExecutionMode $ExecutionMode -RunnerVersion $RunnerVersion -EvaluatedCommitSha $EvaluatedCommitSha
$output = if ([IO.Path]::IsPathRooted($OutputJson)) { [IO.Path]::GetFullPath($OutputJson) } else { [IO.Path]::GetFullPath((Join-Path $root $OutputJson)) }
if ([IO.Path]::GetRelativePath($root, $output).StartsWith('..')) { throw 'OutputJson must be beneath the repository root.' }
New-Item -ItemType Directory -Path (Split-Path -Parent $output) -Force | Out-Null
$report | ConvertTo-Json -Depth 32 | Set-Content -LiteralPath $output -Encoding utf8
"Codex skill behavior: status=$($report.status), cases=$($report.aggregates.casesCompleted)/$($report.aggregates.casesExpected), samples=$($report.aggregates.samplesCompleted)/$($report.aggregates.samplesExpected), variance=$($report.aggregates.materialVarianceCases)."
if ($report.status -eq 'Passed') { exit 0 }
if ($report.status -eq 'Failed') { exit 1 }
exit 2
