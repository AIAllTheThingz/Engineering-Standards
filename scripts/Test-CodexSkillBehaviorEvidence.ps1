<#
.SYNOPSIS
Validates controlled Codex skill behavior evidence without running a model.
.DESCRIPTION
Fails closed when evidence is missing, stale, malformed, contradictory, or
fabricated. A valid Blocked or NotRun report is accepted as honest evidence but
does not become a passing behavior result or promotion approval.
#>
[CmdletBinding()]
param([string]$Path = '.', [string]$EvidencePath = 'evidence/codex-skill-behavior.json', [string]$OutputJson)
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
Import-Module (Join-Path $PSScriptRoot 'CodexSkillBehaviorEvaluation.psm1') -Force
$root = (Resolve-Path -LiteralPath $Path).Path
$evidenceFile = if ([IO.Path]::IsPathRooted($EvidencePath)) { [IO.Path]::GetFullPath($EvidencePath) } else { [IO.Path]::GetFullPath((Join-Path $root $EvidencePath)) }
$results = [Collections.Generic.List[object]]::new()
$evidence = $null
function Add-Result([string]$Status, [string]$Message) { $results.Add([pscustomobject]@{ status=$Status; message=$Message; path=[IO.Path]::GetRelativePath($root,$evidenceFile).Replace('\','/') }) }
try {
    if ([IO.Path]::GetRelativePath($root, $evidenceFile).StartsWith('..')) { throw 'Evidence path escapes the repository root.' }
    $raw = Get-Content -LiteralPath $evidenceFile -Raw
    $schemaPath = Join-Path $root 'schemas/codex-skill-behavior-evaluation.schema.json'
    if (-not ($raw | Test-Json -SchemaFile $schemaPath -ErrorAction Stop)) { throw 'Evidence does not satisfy the behavior evidence JSON schema.' }
    $evidence = $raw | ConvertFrom-Json
    $inputs = Get-CodexBehaviorInput -Path $root
    $config = Import-PowerShellDataFile -LiteralPath (Join-Path $root $inputs.ConfigurationPath)
    foreach ($property in @('schemaVersion','evidenceKind','evaluatorVersion','scoringContractVersion','configurationId','configurationHash','evaluatorHash','corpusHash','skillInputHash','authorityHash','evaluatedCommitSha','executionMode','probabilistic','deterministicStructureStatus','status','caseOutcomes','aggregates','humanAdjudication','decision','notRunReason','blockedReason','limitations')) {
        if ($evidence.PSObject.Properties.Name -notcontains $property) { throw "Evidence is missing required property '$property'." }
    }
    if ($evidence.status -notin @('Passed','Failed','NotRun','Blocked','NotApplicable')) { throw 'Evidence uses a noncanonical status.' }
    if (-not $evidence.probabilistic -or ($evidence.limitations -join ' ') -notmatch 'not deterministic proof') { throw 'Evidence must explicitly identify probabilistic limitations.' }
    if ($evidence.configurationId -ne $config.ConfigurationId -or $evidence.evaluatorVersion -ne $config.EvaluatorVersion -or $evidence.scoringContractVersion -ne $config.ScoringContractVersion) { throw 'Evidence version or approved configuration identity is stale.' }
    if ($evidence.configurationHash -ne (Get-BoundedInputHash -Root $root -RelativePaths @($inputs.ConfigurationPath))) { throw 'Evidence configuration hash is stale or fabricated.' }
    if ($evidence.evaluatorHash -ne (Get-BoundedInputHash -Root $root -RelativePaths $inputs.EvaluatorPaths)) { throw 'Evidence evaluator hash is stale or fabricated.' }
    if ($evidence.corpusHash -ne (Get-BoundedInputHash -Root $root -RelativePaths $inputs.CorpusPaths)) { throw 'Evidence corpus hash is stale or fabricated.' }
    if ($evidence.skillInputHash -ne (Get-BoundedInputHash -Root $root -RelativePaths $inputs.SkillPaths)) { throw 'Evidence skill input hash is stale or fabricated.' }
    if ($evidence.authorityHash -ne (Get-BoundedInputHash -Root $root -RelativePaths $inputs.AuthorityPaths)) { throw 'Evidence authority input hash is stale or fabricated.' }
    if ($evidence.evaluatedCommitSha -notmatch '^[0-9a-f]{40}$') { throw 'Evidence commit SHA is malformed.' }
    & git -C $root merge-base --is-ancestor $evidence.evaluatedCommitSha HEAD 2>$null
    if ($LASTEXITCODE -ne 0) { throw 'Evidence commit is not an ancestor of the validated revision.' }
    # Compare dynamic input roots so files present only in the evaluated commit
    # (for example, a subsequently deleted case or skill file) remain visible.
    # Static inputs stay individually bounded; changing the module that declares
    # those sets is itself an evaluator change.
    $boundInputPaths = @($inputs.ConfigurationPath) + @($inputs.EvaluatorPaths) + @($inputs.AuthorityPaths) + @(
        'tests/fixtures/codex-skills/prompt-behavior',
        '.agents/skills',
        '.agents/suspended-skills'
    ) | Sort-Object -Unique
    & git -C $root diff --quiet $evidence.evaluatedCommitSha -- @boundInputPaths 2>$null
    if ($LASTEXITCODE -ne 0) { throw 'Hash-bound evaluator inputs differ from the evaluated commit.' }
    if (@($evidence.caseOutcomes).Count -ne @($inputs.Cases).Count) { throw 'Evidence is a partial run with a mismatched case count.' }
    $expectedSamples = @($inputs.Cases).Count * [int]$config.Sampling.SamplesPerCase
    if ([int]$evidence.aggregates.samplesExpected -ne $expectedSamples) { throw 'Evidence sample count contradicts the approved sampling contract.' }
    foreach ($caseOutcome in $evidence.caseOutcomes) {
        if (@($caseOutcome.samples).Count -ne [int]$config.Sampling.SamplesPerCase) { throw "Case '$($caseOutcome.caseId)' is incomplete." }
        foreach ($sample in $caseOutcome.samples) {
            if ($sample.status -notin @('Passed','Failed','NotRun','Blocked','NotApplicable')) { throw 'A sample uses a noncanonical status.' }
            if ($sample.status -ne 'Passed' -and [string]::IsNullOrWhiteSpace([string]$sample.failureReason)) { throw 'Every nonpassing sample requires a reason.' }
            if ($null -ne $sample.responseSummary -and $sample.responseSha256 -ne (Get-Sha256String -Value ([string]$sample.responseSummary))) { throw 'A sanitized response hash is fabricated or contradictory.' }
            if ($sample.unsafeToolAccess -and $sample.status -eq 'Passed') { throw 'Unsafe tool access cannot be reported Passed.' }
        }
    }
    $evidenceForScoring = $evidence
    $scoringProvider = {
        param($case, $index)
        $storedCase = @($evidenceForScoring.caseOutcomes | Where-Object caseId -eq $case.caseId)
        if ($storedCase.Count -ne 1) { return [pscustomobject]@{ status='Blocked'; failureReason='The stored case identity is missing or duplicated.' } }
        $storedSample = @($storedCase[0].samples | Where-Object sampleIndex -eq $index)
        if ($storedSample.Count -ne 1) { return [pscustomobject]@{ status='Blocked'; failureReason='The stored sample identity is missing or duplicated.' } }
        $storedSample[0]
    }.GetNewClosure()
    $recomputed = Invoke-CodexSkillBehaviorEvaluation -Path $root -ObservationProvider $scoringProvider -ExecutionMode $evidence.executionMode -RunnerVersion $evidence.model.runnerVersion -EvaluatedCommitSha $evidence.evaluatedCommitSha
    foreach ($section in @('model','sampling','retryPolicy','isolation','thresholds','caseOutcomes','aggregates','varianceObservations','decision')) {
        $actualValue = $evidence.$section | ConvertTo-Json -Depth 32 | ConvertFrom-Json
        $expectedValue = $recomputed.$section | ConvertTo-Json -Depth 32 | ConvertFrom-Json
        if ($section -eq 'caseOutcomes') {
            foreach ($caseValue in @($actualValue) + @($expectedValue)) {
                foreach ($sampleValue in $caseValue.samples) { $sampleValue.startedAtUtc = $null; $sampleValue.completedAtUtc = $null }
            }
        }
        $actualSection = $actualValue | ConvertTo-Json -Depth 32 -Compress
        $expectedSection = $expectedValue | ConvertTo-Json -Depth 32 -Compress
        if ($actualSection -cne $expectedSection) { throw "Evidence section '$section' contradicts evaluator-recomputed results." }
    }
    if ($evidence.status -cne $recomputed.status) { throw 'Evidence status contradicts evaluator-recomputed status.' }
    if ($evidence.status -eq 'Passed' -and (-not $evidence.aggregates.thresholdsPassed -or $evidence.executionMode -ne 'Live')) { throw 'Passing evidence contradicts its mode or thresholds.' }
    if ($evidence.status -eq 'Blocked' -and [string]::IsNullOrWhiteSpace([string]$evidence.blockedReason)) { throw 'Blocked evidence requires an explicit reason.' }
    if ($evidence.status -eq 'NotRun' -and [string]::IsNullOrWhiteSpace([string]$evidence.notRunReason)) { throw 'NotRun evidence requires an explicit reason.' }
    if ($evidence.humanAdjudication.status -eq 'Passed' -and ([string]::IsNullOrWhiteSpace([string]$evidence.humanAdjudication.reviewer) -or $null -eq $evidence.humanAdjudication.reviewedAtUtc)) { throw 'Human adjudication must be attributable.' }
    Add-Result Passed "Behavior evidence contract is valid; underlying probabilistic result is '$($evidence.status)'."
}
catch { Add-Result Failed $_.Exception.Message }
$report = [pscustomobject]@{ generatedAtUtc=[DateTime]::UtcNow.ToString('o'); evidenceStatus=if($evidence){$evidence.status}else{'Blocked'}; results=@($results); failed=@($results | Where-Object status -eq 'Failed').Count }
if ($OutputJson) { $report | ConvertTo-Json -Depth 16 | Set-Content -LiteralPath $OutputJson -Encoding utf8 }
$results | ForEach-Object { "[$($_.status)] $($_.message)" }
if ($report.failed -gt 0) { exit 1 }
exit 0
