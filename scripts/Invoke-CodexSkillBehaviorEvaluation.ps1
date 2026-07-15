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
function Resolve-BehaviorRepositoryPath {
    param([Parameter(Mandatory)][string]$Candidate, [switch]$MustExist, [Parameter(Mandatory)][string]$Name)
    $full = if ([IO.Path]::IsPathRooted($Candidate)) { [IO.Path]::GetFullPath($Candidate) } else { [IO.Path]::GetFullPath((Join-Path $root $Candidate)) }
    $comparison = if ($IsWindows) { [StringComparison]::OrdinalIgnoreCase } else { [StringComparison]::Ordinal }
    $boundary = $root.TrimEnd([IO.Path]::DirectorySeparatorChar, [IO.Path]::AltDirectorySeparatorChar) + [IO.Path]::DirectorySeparatorChar
    if (-not $full.StartsWith($boundary, $comparison)) { throw "$Name must be beneath the repository root." }
    $current = $root
    foreach ($segment in @([IO.Path]::GetRelativePath($root, $full) -split '[\\/]' | Where-Object { $_ -and $_ -ne '.' })) {
        $current = Join-Path $current $segment
        if (-not (Test-Path -LiteralPath $current)) { break }
        $item = Get-Item -LiteralPath $current -Force
        if ($item.LinkType -or ($item.Attributes -band [IO.FileAttributes]::ReparsePoint)) { throw "$Name must not traverse a symbolic link, junction, or reparse point." }
    }
    if ($MustExist -and -not (Test-Path -LiteralPath $full)) { throw "$Name does not exist." }
    $full
}
$observations = Resolve-BehaviorRepositoryPath -Candidate $ObservationDirectory -MustExist -Name ObservationDirectory
$declaredUnavailableReason = $UnavailableReason
$declaredUnavailableDetail = $UnavailableDetail
$observationSchema = Join-Path $root 'schemas/codex-skill-behavior-observation.schema.json'
$observationItem = Get-Item -LiteralPath $observations -Force
if (-not $observationItem.PSIsContainer) { throw 'ObservationDirectory must identify a directory.' }
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
    $json = [Text.Encoding]::UTF8.GetString($bytes)
    try { $observation = $json | ConvertFrom-Json }
    catch { return [pscustomobject]@{ status = 'Blocked'; failureReason = 'Observation output was malformed JSON and was not retried.' } }
    try { $schemaValid = $json | Test-Json -SchemaFile $observationSchema -ErrorAction Stop }
    catch { $schemaValid = $false }
    if (-not $schemaValid) { return [pscustomobject]@{ status = 'Blocked'; failureReason = 'Observation output did not satisfy the observation schema and was not scored.' } }
    $observation
}
$report = Invoke-CodexSkillBehaviorEvaluation -Path $root -ObservationProvider $provider -ExecutionMode $ExecutionMode -RunnerVersion $RunnerVersion -EvaluatedCommitSha $EvaluatedCommitSha
$output = Resolve-BehaviorRepositoryPath -Candidate $OutputJson -Name OutputJson
New-Item -ItemType Directory -Path (Split-Path -Parent $output) -Force | Out-Null
$output = Resolve-BehaviorRepositoryPath -Candidate $output -Name OutputJson
$report | ConvertTo-Json -Depth 32 | Set-Content -LiteralPath $output -Encoding utf8
"Codex skill behavior: status=$($report.status), cases=$($report.aggregates.casesCompleted)/$($report.aggregates.casesExpected), samples=$($report.aggregates.samplesCompleted)/$($report.aggregates.samplesExpected), variance=$($report.aggregates.materialVarianceCases)."
if ($report.status -eq 'Passed') { exit 0 }
if ($report.status -eq 'Failed') { exit 1 }
exit 2
