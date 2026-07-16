<#
.SYNOPSIS
Validates GitHub Actions workflow architecture.
.DESCRIPTION
Parses workflow YAML with Python and PyYAML, validates reusable workflow call
graphs, local workflow references, declared inputs, permissions, event triggers,
third-party action pinning, and default-branch trigger expectations.
.PARAMETER Path
Repository root path.
.PARAMETER DefaultBranch
Expected repository default branch. Defaults to master for this repository.
.PARAMETER OutputJson
Optional JSON report path.
.PARAMETER ExpectedReusableWorkflowSha
Optional immutable Engineering Standards SHA required for a remote self-CI call.
.EXAMPLE
pwsh -NoProfile -File scripts/Test-GitHubWorkflowArchitecture.ps1 -Path .
#>
[CmdletBinding()]
param(
    [string]$Path = '.',
    [string]$DefaultBranch = 'master',
    [string]$ExpectedReusableWorkflowSha,
    [switch]$RequireCandidateValidation,
    [string]$OutputJson
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
Import-Module (Join-Path $PSScriptRoot 'GovernanceValidation.psm1') -Force

$root = (Resolve-Path -LiteralPath $Path).Path
$results = [System.Collections.Generic.List[object]]::new()

function ConvertTo-RelativePath {
    param([Parameter(Mandatory)][string]$FullPath)
    [System.IO.Path]::GetRelativePath($root, $FullPath).Replace('\','/')
}

function Read-YamlDocument {
    param([Parameter(Mandatory)][string]$YamlPath)

    $python = @'
import json
import sys

try:
    import yaml
except Exception as exc:
    print(json.dumps({"ok": False, "error": "PyYAML unavailable: " + str(exc)}))
    sys.exit(2)

class GithubActionsLoader(yaml.SafeLoader):
    pass

for ch, resolvers in list(GithubActionsLoader.yaml_implicit_resolvers.items()):
    GithubActionsLoader.yaml_implicit_resolvers[ch] = [
        (tag, regexp) for tag, regexp in resolvers
        if tag != "tag:yaml.org,2002:bool"
    ]

try:
    with open(sys.argv[1], "r", encoding="utf-8") as handle:
        data = yaml.load(handle, Loader=GithubActionsLoader)
    print(json.dumps({"ok": True, "data": data}))
except Exception as exc:
    print(json.dumps({"ok": False, "error": str(exc)}))
    sys.exit(1)
'@
    $pythonFile = Join-Path ([System.IO.Path]::GetTempPath()) ("workflow-yaml-" + [guid]::NewGuid() + ".py")
    try {
        Set-Content -LiteralPath $pythonFile -Value $python -Encoding utf8
        $output = & python $pythonFile $YamlPath 2>&1
        $code = $LASTEXITCODE
    }
    finally {
        if (Test-Path -LiteralPath $pythonFile) { Remove-Item -LiteralPath $pythonFile -Force }
    }
    if ($code -ne 0) {
        throw "YAML parse failed for '$YamlPath': $output"
    }
    $payload = ($output | Out-String).Trim() | ConvertFrom-Json -AsHashtable
    if (-not $payload.ok) { throw $payload.error }
    $payload.data
}

function Get-WorkflowCallInputs {
    param([hashtable]$Workflow)
    $inputs = @{}
    if ($Workflow.ContainsKey('on')) {
        $on = $Workflow['on']
        if ($on -is [hashtable] -and $on.ContainsKey('workflow_call')) {
            $workflowCall = $on['workflow_call']
            if ($workflowCall -is [hashtable] -and $workflowCall.ContainsKey('inputs') -and $workflowCall['inputs'] -is [hashtable]) {
                foreach ($key in $workflowCall['inputs'].Keys) { $inputs[$key] = $true }
            }
        }
    }
    $inputs
}

function Test-HasWorkflowCall {
    param([hashtable]$Workflow)
    if (-not $Workflow.ContainsKey('on')) { return $false }
    $on = $Workflow['on']
    if ($on -is [string]) { return $on -eq 'workflow_call' }
    if ($on -is [array]) { return @($on) -contains 'workflow_call' }
    if ($on -is [hashtable]) { return $on.ContainsKey('workflow_call') }
    $false
}

function Get-PushBranches {
    param([hashtable]$Workflow)
    if (-not $Workflow.ContainsKey('on')) { return @() }
    $on = $Workflow['on']
    if ($on -isnot [hashtable] -or -not $on.ContainsKey('push')) { return @() }
    $push = $on['push']
    if ($push -is [hashtable] -and $push.ContainsKey('branches')) { return @($push['branches']) }
    @()
}

function Get-WorkflowUses {
    param(
        [hashtable]$Workflow,
        [string]$RelativePath
    )
    $uses = [System.Collections.Generic.List[object]]::new()
    if (-not ($Workflow.ContainsKey('jobs')) -or $Workflow['jobs'] -isnot [hashtable]) { return @($uses) }
    foreach ($jobName in $Workflow['jobs'].Keys) {
        $job = $Workflow['jobs'][$jobName]
        if ($job -isnot [hashtable]) { continue }
        if ($job.ContainsKey('uses')) {
            $uses.Add([ordered]@{ source = $RelativePath; job = $jobName; kind = 'job'; value = [string]$job['uses']; with = $(if ($job.ContainsKey('with') -and $job['with'] -is [hashtable]) { $job['with'] } else { @{} }) })
        }
        if ($job.ContainsKey('steps') -and $job['steps'] -is [array]) {
            foreach ($step in $job['steps']) {
                if ($step -is [hashtable] -and $step.ContainsKey('uses')) {
                    $uses.Add([ordered]@{ source = $RelativePath; job = $jobName; kind = 'step'; value = [string]$step['uses']; with = @{} })
                }
            }
        }
    }
    @($uses)
}

function Get-JobStepRecords {
    param([hashtable]$Workflow)
    $records = [System.Collections.Generic.List[object]]::new()
    if (-not ($Workflow.ContainsKey('jobs')) -or $Workflow['jobs'] -isnot [hashtable]) { return @($records) }
    foreach ($jobName in $Workflow['jobs'].Keys) {
        $job = $Workflow['jobs'][$jobName]
        if ($job -isnot [hashtable]) { continue }
        if (-not $job.ContainsKey('steps') -or $job.steps -isnot [array]) { continue }
        foreach ($step in @($job.steps)) {
            if ($step -isnot [hashtable]) { continue }
            $records.Add([ordered]@{
                job = $jobName
                step = $step
            })
        }
    }
    @($records)
}

$workflowFiles = @(
    Get-ChildItem -LiteralPath (Join-Path $root '.github/workflows') -File -Include *.yml,*.yaml -ErrorAction SilentlyContinue
    Get-ChildItem -LiteralPath (Join-Path $root 'workflows') -File -Include *.yml,*.yaml -ErrorAction SilentlyContinue
) | Where-Object { $_ } | Sort-Object -Property FullName -Unique

$workflows = @{}
foreach ($file in $workflowFiles) {
    $rel = ConvertTo-RelativePath -FullPath $file.FullName
    try {
        $doc = Read-YamlDocument -YamlPath $file.FullName
        if ($doc -isnot [hashtable]) {
            $results.Add((New-ValidationResult -Status Failed -Message 'Workflow YAML root is not a mapping.' -Path $rel))
            continue
        }
        $workflows[$rel] = $doc
    }
    catch {
        $results.Add((New-ValidationResult -Status Failed -Message $_.Exception.Message -Path $rel))
    }
}

$callGraph = @{}
$workflowInputs = @{}
foreach ($rel in $workflows.Keys) {
    $callGraph[$rel] = [System.Collections.Generic.List[string]]::new()
    $workflowInputs[$rel] = Get-WorkflowCallInputs -Workflow $workflows[$rel]
}

foreach ($rel in $workflows.Keys) {
    $workflow = $workflows[$rel]
    $workflowText = Get-Content -LiteralPath (Join-Path $root $rel) -Raw
    foreach ($declaredInput in $workflowInputs[$rel].Keys) {
        if ($workflowText -notmatch [regex]::Escape("inputs.$declaredInput")) {
            $results.Add((New-ValidationResult -Status Failed -Message "Declared workflow input '$declaredInput' is never consumed." -Path $rel))
        }
    }
    if (-not $workflow.ContainsKey('jobs') -or $workflow['jobs'] -isnot [hashtable] -or $workflow['jobs'].Count -eq 0) {
        $results.Add((New-ValidationResult -Status Failed -Message 'Workflow has no executable jobs.' -Path $rel))
        continue
    }

    if (-not $workflow.ContainsKey('permissions')) {
        $results.Add((New-ValidationResult -Status Failed -Message 'Workflow must declare explicit permissions.' -Path $rel))
    }

    if ($rel -eq '.github/workflows/governance-ci.yml' -and -not $workflow.ContainsKey('concurrency')) {
        $results.Add((New-ValidationResult -Status Failed -Message 'Entry workflow must declare concurrency.' -Path $rel))
    }

    $uses = @(Get-WorkflowUses -Workflow $workflow -RelativePath $rel)
    foreach ($use in $uses) {
        $value = $use.value
        if ($value -match '^\.\/(.+\.ya?ml)$') {
            $targetRel = $Matches[1].Replace('\','/')
            if ($targetRel -notmatch '^\.github/workflows/') {
                $results.Add((New-ValidationResult -Status Failed -Message "Local reusable workflow reference '$value' is outside .github/workflows." -Path $rel))
                continue
            }
            if (-not $workflows.ContainsKey($targetRel)) {
                $results.Add((New-ValidationResult -Status Failed -Message "Local reusable workflow target '$targetRel' does not exist." -Path $rel))
                continue
            }
            $callGraph[$rel].Add($targetRel)
            if (-not (Test-HasWorkflowCall -Workflow $workflows[$targetRel])) {
                $results.Add((New-ValidationResult -Status Failed -Message "Reusable workflow target '$targetRel' is missing workflow_call." -Path $targetRel))
            }
            foreach ($inputName in @($use.with.Keys)) {
                if (-not $workflowInputs[$targetRel].ContainsKey($inputName)) {
                    $results.Add((New-ValidationResult -Status Failed -Message "Call passes unsupported input '$inputName' to '$targetRel'." -Path $rel))
                }
            }
        }
        elseif ($value -match '^AIAllTheThingz/Engineering-Standards/(workflows/.+\.ya?ml)@') {
            $results.Add((New-ValidationResult -Status Failed -Message "Cross-repository workflow reference points to root workflows directory: '$value'." -Path $rel))
        }
        elseif ($value -match '^actions/[^@]+@(.+)$') {
            $ref = $Matches[1]
            if ($ref -notmatch '^[a-fA-F0-9]{40}$') {
                $results.Add((New-ValidationResult -Status Failed -Message "Third-party action reference is not pinned to a full commit SHA: '$value'." -Path $rel))
            }
        }
        elseif ($value -match '^[^/]+/[^/@]+@(.+)$' -and $value -notmatch '^AIAllTheThingz/Engineering-Standards/\.github/workflows/') {
            $ref = $Matches[1]
            if ($ref -notmatch '^[a-fA-F0-9]{40}$') {
                $results.Add((New-ValidationResult -Status Failed -Message "Third-party workflow reference is not pinned to a full commit SHA: '$value'." -Path $rel))
            }
        }
    }

    if ($workflow.ContainsKey('permissions') -and [string]$workflow['permissions'] -match 'write-all') {
        $results.Add((New-ValidationResult -Status Failed -Message 'Workflow uses permissions: write-all.' -Path $rel))
    }
    if ($workflow.ContainsKey('on')) {
        $onText = ($workflow['on'] | ConvertTo-Json -Depth 20)
        if ($onText -match 'pull_request_target') {
            $results.Add((New-ValidationResult -Status Failed -Message 'Workflow uses pull_request_target.' -Path $rel))
        }
    }

    foreach ($jobName in $workflow.jobs.Keys) {
        $job = $workflow.jobs[$jobName]
        if ($job -isnot [hashtable]) { continue }
        if ($job.ContainsKey('uses')) { continue }
        if (-not $job.ContainsKey('timeout-minutes')) {
            $results.Add((New-ValidationResult -Status Failed -Message "Job '$jobName' is missing timeout-minutes." -Path $rel))
        }
    }

    foreach ($record in @(Get-JobStepRecords -Workflow $workflow)) {
        $step = $record.step
        $jobName = $record.job
        if ($step.ContainsKey('uses') -and [string]$step.uses -match '^actions/checkout@') {
            if (-not $step.ContainsKey('with') -or $step.with -isnot [hashtable] -or -not $step.with.ContainsKey('persist-credentials') -or [string]$step.with['persist-credentials'] -ne 'false') {
                $results.Add((New-ValidationResult -Status Failed -Message "Checkout step in job '$jobName' must set persist-credentials: false." -Path $rel))
            }
        }
        if ($step.ContainsKey('uses') -and [string]$step.uses -match '^actions/upload-artifact@') {
            if (-not $step.ContainsKey('with') -or $step.with -isnot [hashtable]) {
                $results.Add((New-ValidationResult -Status Failed -Message "Artifact upload step in job '$jobName' must declare with settings." -Path $rel))
            }
            else {
                if (-not $step.with.ContainsKey('if-no-files-found') -or [string]$step.with['if-no-files-found'] -ne 'error') {
                    $results.Add((New-ValidationResult -Status Failed -Message "Artifact upload step in job '$jobName' must use if-no-files-found: error." -Path $rel))
                }
                if (-not $step.with.ContainsKey('name') -or [string]$step.with.name -notmatch 'run_id') {
                    $results.Add((New-ValidationResult -Status Failed -Message "Artifact upload step in job '$jobName' must include run-qualified artifact naming." -Path $rel))
                }
            }
        }
    }
}

foreach ($rel in $workflows.Keys) {
    if ((Test-HasWorkflowCall -Workflow $workflows[$rel]) -and $rel -notmatch '^\.github/workflows/') {
        $text = Get-Content -LiteralPath (Join-Path $root $rel) -Raw
        if ($rel -match '^workflows/' -and $text -match 'distribution template' -and $text -notmatch 'directly executable from this location') {
            $results.Add((New-ValidationResult -Status Passed -Message 'Root workflows directory file is an informational distribution template.' -Path $rel -Severity info))
        }
        else {
            $results.Add((New-ValidationResult -Status Failed -Message 'Root workflow template is missing clear distribution-template labeling or claims direct executability.' -Path $rel))
        }
    }
}

foreach ($source in $callGraph.Keys) {
    foreach ($target in @($callGraph[$source])) {
        if ($target -eq $source) {
            $results.Add((New-ValidationResult -Status Failed -Message 'Workflow calls itself.' -Path $source))
        }
        if ($callGraph.ContainsKey($target) -and @($callGraph[$target]) -contains $source) {
            $results.Add((New-ValidationResult -Status Failed -Message "Workflow recursion detected between '$source' and '$target'." -Path $source))
        }
    }
}

$entry = '.github/workflows/governance-ci.yml'
$manifestFile = Join-Path $root 'project-manifest.json'
$isStandardsRepository = [bool]$RequireCandidateValidation
if (Test-Path -LiteralPath $manifestFile -PathType Leaf) {
    try {
        $repositoryManifest = Get-Content -LiteralPath $manifestFile -Raw | ConvertFrom-Json
        $isStandardsRepository = $isStandardsRepository -or $repositoryManifest.repository -eq 'AIAllTheThingz/Engineering-Standards'
    }
    catch {
        $results.Add((New-ValidationResult -Status Failed -Message 'project-manifest.json could not be parsed while validating workflow architecture.' -Path 'project-manifest.json'))
    }
}
if ($workflows.ContainsKey($entry)) {
    $branches = @(Get-PushBranches -Workflow $workflows[$entry])
    if ($branches -notcontains $DefaultBranch) {
        $results.Add((New-ValidationResult -Status Failed -Message "Entry workflow push trigger does not include default branch '$DefaultBranch'." -Path $entry))
    }
    $entryJobUses = @((Get-WorkflowUses -Workflow $workflows[$entry] -RelativePath $entry) | Where-Object kind -eq 'job')
    $localCall = @($entryJobUses | Where-Object value -eq './.github/workflows/governance-ci-reusable.yml')
    $remoteCall = @($entryJobUses | Where-Object value -match '^AIAllTheThingz/Engineering-Standards/\.github/workflows/governance-ci-reusable\.yml@([a-fA-F0-9]{40})$')
    if (($localCall.Count + $remoteCall.Count) -ne 1) {
        $results.Add((New-ValidationResult -Status Failed -Message 'Entry workflow must call the local reusable workflow or a full-SHA Engineering Standards reusable workflow exactly once.' -Path $entry))
    }
    elseif ($remoteCall.Count -eq 1 -and $ExpectedReusableWorkflowSha) {
        $actualSha = ([string]$remoteCall[0].value -split '@')[-1]
        if ($actualSha -ne $ExpectedReusableWorkflowSha) {
            $results.Add((New-ValidationResult -Status Failed -Message "Entry workflow reusable SHA '$actualSha' does not match expected trusted SHA '$ExpectedReusableWorkflowSha'." -Path $entry))
        }
    }

    if ($isStandardsRepository) {
        $entryWorkflow = $workflows[$entry]
        $on = $entryWorkflow['on']
        foreach ($requiredTrigger in @('pull_request','push','workflow_dispatch')) {
            if ($on -isnot [hashtable] -or -not $on.ContainsKey($requiredTrigger)) {
                $results.Add((New-ValidationResult -Status Failed -Message "Engineering Standards entry workflow is missing '$requiredTrigger' for candidate validation." -Path $entry))
            }
        }
        if ($on -is [hashtable] -and $on.ContainsKey('pull_request_target')) {
            $results.Add((New-ValidationResult -Status Failed -Message 'Engineering Standards entry workflow must not use pull_request_target.' -Path $entry))
        }
        if ($remoteCall.Count -ne 1) {
            $results.Add((New-ValidationResult -Status Failed -Message 'Engineering Standards trusted baseline must use a full-SHA remote reusable workflow call.' -Path $entry))
        }

        $candidateCalls = @($entryJobUses | Where-Object value -match '^AIAllTheThingz/Engineering-Standards/\.github/workflows/governance-ci-candidate\.yml@([a-fA-F0-9]{40})$')
        if ($candidateCalls.Count -ne 1) {
            $results.Add((New-ValidationResult -Status Failed -Message 'Engineering Standards entry workflow must call the candidate-validation harness at a full immutable SHA exactly once.' -Path $entry))
        }
        else {
            $candidateSha = ([string]$candidateCalls[0].value -split '@')[-1]
            $baselineSha = if ($remoteCall.Count -eq 1) { ([string]$remoteCall[0].value -split '@')[-1] } else { $null }
            if ($baselineSha -and $candidateSha -ne $baselineSha) {
                $results.Add((New-ValidationResult -Status Failed -Message 'Trusted baseline and candidate-validation harness must use the same reviewed immutable SHA.' -Path $entry))
            }
            if ($ExpectedReusableWorkflowSha -and $candidateSha -ne $ExpectedReusableWorkflowSha) {
                $results.Add((New-ValidationResult -Status Failed -Message "Candidate-validation harness SHA '$candidateSha' does not match expected trusted SHA '$ExpectedReusableWorkflowSha'." -Path $entry))
            }
            $candidateEntryJob = $entryWorkflow.jobs[$candidateCalls[0].job]
            if ([string]$candidateEntryJob.name -ne 'Candidate implementation validation') {
                $results.Add((New-ValidationResult -Status Failed -Message 'Candidate validation entry job must be named Candidate implementation validation.' -Path $entry))
            }
            if ($candidateEntryJob.ContainsKey('secrets')) {
                $results.Add((New-ValidationResult -Status Failed -Message 'Candidate validation entry job must not receive secrets.' -Path $entry))
            }
            if ($candidateEntryJob.ContainsKey('if')) {
                $results.Add((New-ValidationResult -Status Failed -Message 'Candidate validation entry job must not use a condition that can skip execution.' -Path $entry))
            }
        }
    }
}
else {
    $results.Add((New-ValidationResult -Status Failed -Message 'Entry workflow is missing.' -Path $entry))
}

$candidateWorkflowPath = '.github/workflows/governance-ci-candidate.yml'
if ($isStandardsRepository) {
    if (-not $workflows.ContainsKey($candidateWorkflowPath)) {
        $results.Add((New-ValidationResult -Status Failed -Message 'Candidate-validation reusable workflow is missing.' -Path $candidateWorkflowPath))
    }
    else {
        $candidateWorkflow = $workflows[$candidateWorkflowPath]
        if (-not (Test-HasWorkflowCall -Workflow $candidateWorkflow)) {
            $results.Add((New-ValidationResult -Status Failed -Message 'Candidate-validation workflow must declare workflow_call.' -Path $candidateWorkflowPath))
        }
        if ($candidateWorkflow.permissions -isnot [hashtable] -or $candidateWorkflow.permissions.Count -ne 1 -or [string]$candidateWorkflow.permissions.contents -ne 'read') {
            $results.Add((New-ValidationResult -Status Failed -Message 'Candidate workflow permissions must be exactly contents: read.' -Path $candidateWorkflowPath))
        }
        $candidateJob = $candidateWorkflow.jobs.candidate
        if ($candidateJob -isnot [hashtable]) {
            $results.Add((New-ValidationResult -Status Failed -Message 'Candidate-validation workflow must define the candidate job.' -Path $candidateWorkflowPath))
        }
        else {
            if ([string]$candidateJob.name -ne 'Candidate implementation validation') {
                $results.Add((New-ValidationResult -Status Failed -Message 'Candidate harness job must be named Candidate implementation validation.' -Path $candidateWorkflowPath))
            }
            if ($candidateJob.permissions -isnot [hashtable] -or $candidateJob.permissions.Count -ne 1 -or [string]$candidateJob.permissions.contents -ne 'read') {
                $results.Add((New-ValidationResult -Status Failed -Message 'Candidate harness job permissions must be exactly contents: read.' -Path $candidateWorkflowPath))
            }
            if ($candidateJob.ContainsKey('environment') -or $candidateJob.ContainsKey('secrets')) {
                $results.Add((New-ValidationResult -Status Failed -Message 'Candidate harness job must not use environments or secrets.' -Path $candidateWorkflowPath))
            }
            if ($candidateJob.ContainsKey('continue-on-error')) {
                $results.Add((New-ValidationResult -Status Failed -Message 'Candidate harness job must fail when candidate validation fails.' -Path $candidateWorkflowPath))
            }
            if ($candidateJob.ContainsKey('if')) {
                $results.Add((New-ValidationResult -Status Failed -Message 'Candidate harness job must not use a condition that can skip execution.' -Path $candidateWorkflowPath))
            }
            $candidateSteps = @($candidateJob.steps)
            $checkout = @($candidateSteps | Where-Object { $_ -is [hashtable] -and $_.name -eq 'Checkout candidate implementation' })
            if ($checkout.Count -ne 1 -or $checkout[0].uses -notmatch '^actions/checkout@[a-fA-F0-9]{40}$') {
                $results.Add((New-ValidationResult -Status Failed -Message 'Candidate harness must contain one full-SHA-pinned candidate checkout.' -Path $candidateWorkflowPath))
            }
            elseif ($checkout[0].with -isnot [hashtable] -or [string]$checkout[0].with.repository -ne '${{ github.repository }}' -or [string]$checkout[0].with.ref -ne '${{ github.sha }}' -or [string]$checkout[0].with.path -ne 'candidate' -or [string]$checkout[0].with['persist-credentials'] -ne 'false') {
                $results.Add((New-ValidationResult -Status Failed -Message 'Candidate checkout must use github.repository/github.sha, path candidate, and persist-credentials false.' -Path $candidateWorkflowPath))
            }
            $validationSteps = @($candidateSteps | Where-Object { $_ -is [hashtable] -and $_.name -eq 'Run candidate implementation validation' })
            if ($validationSteps.Count -ne 1) {
                $results.Add((New-ValidationResult -Status Failed -Message 'Candidate harness must contain one candidate implementation validation step.' -Path $candidateWorkflowPath))
            }
            else {
                $validationStep = $validationSteps[0]
                if ($validationStep.ContainsKey('continue-on-error')) {
                    $results.Add((New-ValidationResult -Status Failed -Message 'Candidate implementation validation step must propagate failures.' -Path $candidateWorkflowPath))
                }
                if ($validationStep.ContainsKey('if')) {
                    $results.Add((New-ValidationResult -Status Failed -Message 'Candidate implementation validation step must not use a condition that can skip execution.' -Path $candidateWorkflowPath))
                }
                if ([string]$validationStep['working-directory'] -ne 'candidate') {
                    $results.Add((New-ValidationResult -Status Failed -Message 'Candidate implementation validation must execute from the candidate checkout.' -Path $candidateWorkflowPath))
                }
                $validationEnvironment = $validationStep.env
                if ($validationEnvironment -isnot [hashtable] -or
                    [string]$validationEnvironment.CALLER_REPOSITORY -ne '${{ github.repository }}' -or
                    [string]$validationEnvironment.CANDIDATE_SHA -ne '${{ github.sha }}' -or
                    [string]$validationEnvironment.HARNESS_SHA -ne '${{ job.workflow_sha }}') {
                    $results.Add((New-ValidationResult -Status Failed -Message 'Candidate authoritative validation must bind caller, candidate, and harness identities to trusted GitHub context.' -Path $candidateWorkflowPath))
                }
                $runText = [string]$validationStep.run
                $candidateTokens = $null
                $candidateParseErrors = $null
                $candidateAst = [System.Management.Automation.Language.Parser]::ParseInput($runText, [ref]$candidateTokens, [ref]$candidateParseErrors)
                if (@($candidateParseErrors).Count -gt 0) {
                    $results.Add((New-ValidationResult -Status Failed -Message 'Candidate implementation validation PowerShell does not parse.' -Path $candidateWorkflowPath))
                }
                $candidateCommands = @($candidateAst.FindAll({ param($node) $node -is [System.Management.Automation.Language.CommandAst] }, $true))
                $aggregateCommands = @(
                    $candidateCommands |
                        Where-Object {
                            $_.GetCommandName() -eq 'Invoke-CandidateScript' -and
                            $_.CommandElements.Count -gt 1 -and
                            [string]$_.CommandElements[1].Value -eq 'scripts/Invoke-GovernanceValidation.ps1'
                        }
                )
                $candidateScriptInvocations = @($candidateCommands | Where-Object { $_.GetCommandName() -eq 'Invoke-CandidateScript' })
                if ($aggregateCommands.Count -ne 1) {
                    $results.Add((New-ValidationResult -Status Failed -Message "Candidate harness must invoke the authoritative 'scripts/Invoke-GovernanceValidation.ps1' exactly once." -Path $candidateWorkflowPath))
                }
                elseif ($candidateScriptInvocations.Count -ne 1) {
                    $results.Add((New-ValidationResult -Status Failed -Message 'Candidate harness must not orchestrate additional candidate scripts outside the authoritative aggregate validator.' -Path $candidateWorkflowPath))
                }
                else {
                    $aggregateText = $aggregateCommands[0].Extent.Text
                    $aggregateArguments = @(
                        $aggregateCommands[0].FindAll({
                            param($node)
                            $node -is [System.Management.Automation.Language.StringConstantExpressionAst]
                        }, $true) | ForEach-Object { [string]$_.Value }
                    )
                    foreach ($requiredArgument in @('-Path','-EvidenceRoot','-CallerRepository','-CallerCommitSha','-RepositoryOwnerType','-ExpectedReusableWorkflowSha','-CandidateMaintainerValidation')) {
                        if ($aggregateArguments -cnotcontains $requiredArgument) {
                            $results.Add((New-ValidationResult -Status Failed -Message "Candidate authoritative validation is missing required argument '$requiredArgument'." -Path $candidateWorkflowPath))
                        }
                    }
                    $ownerTypeIndex = [array]::IndexOf($aggregateArguments, '-RepositoryOwnerType')
                    if ($ownerTypeIndex -lt 0 -or $ownerTypeIndex + 1 -ge $aggregateArguments.Count -or $aggregateArguments[$ownerTypeIndex + 1] -cne 'User') {
                        $results.Add((New-ValidationResult -Status Failed -Message 'Candidate authoritative validation must explicitly use RepositoryOwnerType User.' -Path $candidateWorkflowPath))
                    }
                    if ($aggregateText -notmatch "'-EvidenceRoot'\s*,\s*\`$reportRoot") {
                        $results.Add((New-ValidationResult -Status Failed -Message 'Candidate authoritative validation must write to the external runner report root.' -Path $candidateWorkflowPath))
                    }
                }
                $gitDiffCommand = @($candidateCommands | Where-Object { $_.GetCommandName() -eq 'git' -and ($_.CommandElements.Extent.Text -join ' ') -match '\bdiff\b.*--check' })
                if ($gitDiffCommand.Count -eq 0) { $results.Add((New-ValidationResult -Status Failed -Message 'Candidate harness is missing an executable git diff --check command.' -Path $candidateWorkflowPath)) }
                $stopCommandCalls = @(
                    $candidateCommands |
                        Where-Object { $_.GetCommandName() -eq 'Write-Output' -and $_.Extent.Text -match '::stop-commands::' }
                )
                $restoringTryStatements = @(
                    $candidateAst.FindAll({
                        param($node)
                        if ($node -isnot [System.Management.Automation.Language.TryStatementAst] -or $null -eq $node.Finally) { return $false }
                        $resumeCommands = @($node.Finally.FindAll({
                            param($child)
                            $child -is [System.Management.Automation.Language.CommandAst] -and
                            $child.GetCommandName() -eq 'Write-Output' -and
                            $child.Extent.Text -match 'commandMarker'
                        }, $true))
                        return $resumeCommands.Count -gt 0
                    }, $true)
                )
                if ($stopCommandCalls.Count -eq 0 -or $restoringTryStatements.Count -eq 0) {
                    $results.Add((New-ValidationResult -Status Failed -Message 'Candidate harness must suspend workflow-command processing while candidate code runs and restore it in finally.' -Path $candidateWorkflowPath))
                }
            }
        }
        $candidateText = Get-Content -LiteralPath (Join-Path $root $candidateWorkflowPath) -Raw
        $prohibitedCandidatePattern = 'pull_request_target|secrets\.|secrets:\s*inherit|id-' + ('tok' + 'en') + ':\s*write|contents:\s*write'
        if ($candidateText -match $prohibitedCandidatePattern) {
            $results.Add((New-ValidationResult -Status Failed -Message 'Candidate-validation workflow requests a prohibited trigger, secret, or elevated permission.' -Path $candidateWorkflowPath))
        }
    }
}

$behaviorWorkflowPath = '.github/workflows/codex-skill-behavior.yml'
$requiresBehaviorWorkflow = Test-Path -LiteralPath (Join-Path $root 'governance/codex-skill-behavior-evaluation.psd1') -PathType Leaf
if ($workflows.ContainsKey($behaviorWorkflowPath)) {
    $behaviorWorkflow = $workflows[$behaviorWorkflowPath]
    $behaviorText = Get-Content -LiteralPath (Join-Path $root $behaviorWorkflowPath) -Raw
    $behaviorOn = if ($behaviorWorkflow.ContainsKey('on')) { $behaviorWorkflow['on'] } else { $null }
    if ($behaviorOn -isnot [hashtable] -or $behaviorOn.Count -ne 1 -or -not $behaviorOn.ContainsKey('workflow_dispatch')) {
        $results.Add((New-ValidationResult -Status Failed -Message 'Codex behavior workflow must be triggered only by workflow_dispatch.' -Path $behaviorWorkflowPath))
    }
    else {
        $candidateInput = $behaviorOn.workflow_dispatch.inputs.candidate_sha
        if ($candidateInput -isnot [hashtable] -or $candidateInput.required -ne $true -or [string]$candidateInput.type -ne 'string') {
            $results.Add((New-ValidationResult -Status Failed -Message 'Codex behavior workflow must require the string input candidate_sha.' -Path $behaviorWorkflowPath))
        }
    }
    if ($behaviorWorkflow.permissions -isnot [hashtable] -or $behaviorWorkflow.permissions.Count -ne 1 -or [string]$behaviorWorkflow.permissions.contents -ne 'read') {
        $results.Add((New-ValidationResult -Status Failed -Message 'Codex behavior workflow permissions must be exactly contents: read.' -Path $behaviorWorkflowPath))
    }
    if ($behaviorWorkflow.ContainsKey('env')) {
        $results.Add((New-ValidationResult -Status Failed -Message 'Codex behavior workflow must not expose secrets or environment values at workflow scope.' -Path $behaviorWorkflowPath))
    }
    if ($behaviorWorkflow.concurrency -isnot [hashtable] -or [string]$behaviorWorkflow.concurrency.group -ne 'codex-skill-behavior-${{ inputs.candidate_sha }}' -or [string]$behaviorWorkflow.concurrency['cancel-in-progress'] -ne 'false') {
        $results.Add((New-ValidationResult -Status Failed -Message 'Codex behavior workflow concurrency must bind the exact candidate SHA without cancellation.' -Path $behaviorWorkflowPath))
    }
    if ($behaviorWorkflow.jobs -isnot [hashtable] -or $behaviorWorkflow.jobs.Count -ne 2 -or
        -not $behaviorWorkflow.jobs.ContainsKey('guard') -or -not $behaviorWorkflow.jobs.ContainsKey('evaluate')) {
        $results.Add((New-ValidationResult -Status Failed -Message 'Codex behavior workflow must define exactly the non-secret guard and protected evaluate jobs.' -Path $behaviorWorkflowPath))
    }
    else {
        $guardJob = $behaviorWorkflow.jobs.guard
        $behaviorJob = $behaviorWorkflow.jobs.evaluate
        if ($guardJob.ContainsKey('environment') -or $guardJob.ContainsKey('env') -or $guardJob.ContainsKey('secrets') -or $guardJob.ContainsKey('if') -or
            $guardJob.permissions -isnot [hashtable] -or $guardJob.permissions.Count -ne 1 -or [string]$guardJob.permissions.contents -ne 'read') {
            $results.Add((New-ValidationResult -Status Failed -Message 'Codex behavior guard must be unskippable, non-secret, unprotected, and limited to contents: read.' -Path $behaviorWorkflowPath))
        }
        $guardSteps = @($guardJob.steps)
        $dispatchGuard = @($guardSteps | Where-Object { $_ -is [hashtable] -and $_.name -eq 'Reject invalid dispatch context' })
        $guardRun = if ($dispatchGuard.Count -eq 1) { [string]$dispatchGuard[0].run } else { '' }
        $expectedGuardEnvironment = [ordered]@{
            CANDIDATE_SHA = '${{ inputs.candidate_sha }}'
            DEFAULT_BRANCH = '${{ github.event.repository.default_branch }}'
            EVENT_NAME = '${{ github.event_name }}'
            REPOSITORY = '${{ github.repository }}'
            WORKFLOW_REF = '${{ github.ref }}'
        }
        $guardEnvironment = if ($dispatchGuard.Count -eq 1) { $dispatchGuard[0].env } else { $null }
        if ($guardEnvironment -isnot [hashtable] -or $guardEnvironment.Count -ne $expectedGuardEnvironment.Count -or
            @($expectedGuardEnvironment.Keys | Where-Object { -not $guardEnvironment.ContainsKey($_) -or [string]$guardEnvironment[$_] -cne [string]$expectedGuardEnvironment[$_] }).Count -gt 0) {
            $results.Add((New-ValidationResult -Status Failed -Message 'Codex behavior guard variables must bind exactly to trusted GitHub event contexts.' -Path $behaviorWorkflowPath))
        }
        foreach ($guardPattern in @(
            "REPOSITORY\s+-cne\s+'AIAllTheThingz/Engineering-Standards'",
            "EVENT_NAME\s+-cne\s+'workflow_dispatch'",
            "DEFAULT_BRANCH\s+-cne\s+'master'",
            "WORKFLOW_REF\s+-cne\s+'refs/heads/master'",
            "CANDIDATE_SHA\s+-cnotmatch\s+'\^\[0-9a-f\]\{40\}\$'"
        )) {
            if ($guardRun -notmatch $guardPattern) {
                $results.Add((New-ValidationResult -Status Failed -Message 'Codex behavior guard must fail explicitly for every invalid repository, event, branch, ref, or candidate SHA.' -Path $behaviorWorkflowPath))
                break
            }
        }
        if (-not $behaviorJob.ContainsKey('needs') -or [string]$behaviorJob.needs -ne 'guard' -or $behaviorJob.ContainsKey('if')) {
            $results.Add((New-ValidationResult -Status Failed -Message 'Codex behavior evaluation must depend on the successful guard without a skippable job condition.' -Path $behaviorWorkflowPath))
        }
        if ([string]$behaviorJob.environment -ne 'codex-skill-evaluation') {
            $results.Add((New-ValidationResult -Status Failed -Message 'Codex behavior job must use the codex-skill-evaluation environment.' -Path $behaviorWorkflowPath))
        }
        if ($behaviorJob.permissions -isnot [hashtable] -or $behaviorJob.permissions.Count -ne 1 -or [string]$behaviorJob.permissions.contents -ne 'read') {
            $results.Add((New-ValidationResult -Status Failed -Message 'Codex behavior job permissions must be exactly contents: read.' -Path $behaviorWorkflowPath))
        }
        if ($behaviorJob.ContainsKey('env') -or $behaviorJob.ContainsKey('secrets')) {
            $results.Add((New-ValidationResult -Status Failed -Message 'Codex behavior job must not expose secrets or environment values at job scope.' -Path $behaviorWorkflowPath))
        }
        $behaviorSteps = @($behaviorJob.steps)
        $trustedCheckout = @($behaviorSteps | Where-Object { $_ -is [hashtable] -and $_.name -eq 'Checkout trusted evaluator code' })
        $candidateCheckout = @($behaviorSteps | Where-Object { $_ -is [hashtable] -and $_.name -eq 'Checkout candidate as untrusted data' })
        if ($trustedCheckout.Count -ne 1 -or $trustedCheckout[0].uses -notmatch '^actions/checkout@[0-9a-f]{40}$' -or
            [string]$trustedCheckout[0].with.repository -ne '${{ github.repository }}' -or [string]$trustedCheckout[0].with.ref -ne '${{ github.sha }}' -or
            [string]$trustedCheckout[0].with.path -ne 'trusted' -or [string]$trustedCheckout[0].with['persist-credentials'] -ne 'false') {
            $results.Add((New-ValidationResult -Status Failed -Message 'Codex behavior trusted checkout must use github.sha in a separate credential-free trusted path.' -Path $behaviorWorkflowPath))
        }
        if ($candidateCheckout.Count -ne 1 -or $candidateCheckout[0].uses -notmatch '^actions/checkout@[0-9a-f]{40}$' -or
            [string]$candidateCheckout[0].with.repository -ne '${{ github.repository }}' -or [string]$candidateCheckout[0].with.ref -ne '${{ inputs.candidate_sha }}' -or
            [string]$candidateCheckout[0].with.path -ne 'candidate' -or [string]$candidateCheckout[0].with['persist-credentials'] -ne 'false') {
            $results.Add((New-ValidationResult -Status Failed -Message 'Codex behavior candidate checkout must use candidate_sha as untrusted data in a separate credential-free path.' -Path $behaviorWorkflowPath))
        }
        $initializeStep = @($behaviorSteps | Where-Object { $_ -is [hashtable] -and $_.name -eq 'Initialize fail-closed trusted output boundary' })
        $stepNames = @($behaviorSteps | ForEach-Object { if ($_ -is [hashtable] -and $_.ContainsKey('name')) { [string]$_.name } })
        $trustedIndex = [array]::IndexOf($stepNames, 'Checkout trusted evaluator code')
        $initializeIndex = [array]::IndexOf($stepNames, 'Initialize fail-closed trusted output boundary')
        $candidateIndex = [array]::IndexOf($stepNames, 'Checkout candidate as untrusted data')
        if ($initializeStep.Count -ne 1 -or $trustedIndex -lt 0 -or $initializeIndex -le $trustedIndex -or $candidateIndex -le $initializeIndex -or
            [string]$initializeStep[0].run -notmatch 'New-CodexBehaviorOutputRoot' -or
            [string]$initializeStep[0].run -notmatch 'CODEX_BEHAVIOR_ARTIFACT_ROOT' -or
            [string]$initializeStep[0].run -notmatch 'CODEX_BEHAVIOR_OBSERVATION_ROOT') {
            $results.Add((New-ValidationResult -Status Failed -Message 'Codex behavior workflow must create a new run-specific trusted output root after trusted checkout and before candidate checkout.' -Path $behaviorWorkflowPath))
        }
        $readonlyStep = @($behaviorSteps | Where-Object { $_ -is [hashtable] -and $_.name -eq 'Make candidate checkout read-only' })
        if ($readonlyStep.Count -ne 1 -or [string]$readonlyStep[0].run -notmatch 'chmod\s+-R\s+a-w\s+\./candidate') {
            $results.Add((New-ValidationResult -Status Failed -Message 'Codex behavior workflow must make the candidate checkout read-only before evaluation.' -Path $behaviorWorkflowPath))
        }
        $trustStep = @($behaviorSteps | Where-Object { $_ -is [hashtable] -and $_.name -eq 'Validate candidate identity, file modes, configuration, and evaluator hashes' })
        if ($trustStep.Count -ne 1 -or [string]$trustStep[0].run -notmatch 'Test-CodexBehaviorCandidateTrust' -or
            [string]$trustStep[0].run -notmatch '-TrustedPath\s+\./trusted' -or [string]$trustStep[0].run -notmatch '-CandidatePath\s+\./candidate') {
            $results.Add((New-ValidationResult -Status Failed -Message 'Codex behavior workflow must reject prohibited modes, approve configuration, and compare evaluator hashes with trusted code.' -Path $behaviorWorkflowPath))
        }
        $dependencyStep = @($behaviorSteps | Where-Object { $_ -is [hashtable] -and $_.name -eq 'Install pinned trusted evaluator dependency' })
        if ($dependencyStep.Count -ne 1 -or [string]$dependencyStep[0]['working-directory'] -ne 'trusted/.github/dependencies/codex-evaluator' -or
            [string]$dependencyStep[0].run -notmatch '^npm ci --ignore-scripts --no-audit --no-fund\s*$') {
            $results.Add((New-ValidationResult -Status Failed -Message 'Codex behavior dependency install must use npm ci with lifecycle scripts, audit, and funding calls disabled in the trusted dependency directory.' -Path $behaviorWorkflowPath))
        }
        $provenanceStep = @($behaviorSteps | Where-Object { $_ -is [hashtable] -and $_.name -eq 'Verify pinned evaluator provenance' })
        if ($provenanceStep.Count -ne 1 -or [string]$provenanceStep[0].run -notmatch "nodeVersion\s+-cne\s+'v22\.17\.0'" -or
            [string]$provenanceStep[0].run -notmatch "codexVersion\s+-cne\s+'codex-cli 0\.144\.0-alpha\.4'" -or
            [string]$provenanceStep[0].run -notmatch 'Get-FileHash' -or [string]$provenanceStep[0].run -notmatch "bomFormat\s*=\s*'CycloneDX'" -or
            [string]$provenanceStep[0].run -notmatch 'codex-evaluator-provenance\.json' -or [string]$provenanceStep[0].run -notmatch 'codex-evaluator-sbom\.cdx\.json') {
            $results.Add((New-ValidationResult -Status Failed -Message 'Codex behavior workflow must verify exact Node and Codex versions and emit hashed dependency provenance plus a CycloneDX inventory.' -Path $behaviorWorkflowPath))
        }
        $collector = @($behaviorSteps | Where-Object { $_ -is [hashtable] -and $_.name -eq 'Collect trusted model observations' })
        $secretReferences = [regex]::Matches($behaviorText, '\$\{\{\s*secrets\.OPENAI_API_KEY\s*\}\}')
        if ($collector.Count -ne 1 -or $collector[0].env -isnot [hashtable] -or $collector[0].env.Count -ne 1 -or
            [string]$collector[0].env.OPENAI_API_KEY -ne '${{ secrets.OPENAI_API_KEY }}' -or $secretReferences.Count -ne 1 -or
            [string]$collector[0].run -notmatch 'trusted/scripts/Invoke-CodexSkillBehaviorModel\.ps1' -or
            [string]$collector[0].run -notmatch '-TrustedOutputRoot\s+\$env:CODEX_BEHAVIOR_OUTPUT_ROOT' -or
            [string]$collector[0].run -notmatch '-OutputDirectory\s+\$env:CODEX_BEHAVIOR_OBSERVATION_ROOT') {
            $results.Add((New-ValidationResult -Status Failed -Message 'Only the trusted model collector step may receive OPENAI_API_KEY.' -Path $behaviorWorkflowPath))
        }
        foreach ($step in $behaviorSteps) {
            if ($step -isnot [hashtable]) { continue }
            if (($step.ContainsKey('uses') -and [string]$step.uses -match '^\.?[/\\]candidate([/\\]|$)') -or
                ($step.ContainsKey('working-directory') -and [string]$step['working-directory'] -match '^\.?[/\\]candidate([/\\]|$)')) {
                $results.Add((New-ValidationResult -Status Failed -Message 'Codex behavior workflow must not execute candidate actions, packages, or commands.' -Path $behaviorWorkflowPath))
            }
            if ($step.ContainsKey('run')) {
                $runText = [string]$step.run
                $candidateExecutionPatterns = @(
                    '(?im)^\s*(?:&|\.)\s+["'']?\.?[/\\]candidate(?:[/\\]|["'']|\s|$)',
                    '(?im)^\s*\.?[/\\]candidate[/\\][^\r\n\s]+(?:\s|$)',
                    '(?im)^\s*(?:Import-Module|Start-Process|Invoke-Command)\b[^\r\n]*\.?[/\\]candidate(?:[/\\]|["'']|\s|$)',
                    '(?im)^\s*(?:iex|Invoke-Expression)\b[^\r\n]*candidate',
                    '(?im)^[^\r\n]*candidate[^\r\n]*\|\s*(?:iex|Invoke-Expression)\b',
                    '(?im)^\s*(?:npm|npx|pwsh|powershell|python|bash|sh|node|dotnet)\b[^\r\n]*\.?[/\\]candidate(?:[/\\]|\s|$)'
                )
                if (@($candidateExecutionPatterns | Where-Object { $runText -match $_ }).Count -gt 0) {
                    $results.Add((New-ValidationResult -Status Failed -Message 'Codex behavior workflow must treat candidate content only as untrusted data.' -Path $behaviorWorkflowPath))
                }
            }
            if ($step.ContainsKey('continue-on-error')) {
                $results.Add((New-ValidationResult -Status Failed -Message 'Codex behavior workflow must not suppress step failures with continue-on-error.' -Path $behaviorWorkflowPath))
            }
        }
        $stageStep = @($behaviorSteps | Where-Object { $_ -is [hashtable] -and $_.name -eq 'Stage sanitized artifact only' })
        if ($stageStep.Count -ne 1 -or [string]$stageStep[0]['if'] -ne "always() && steps.initialize.outcome == 'success'" -or
            [string]$stageStep[0].run -match '(?i)candidate[/\\]\.tmp|Copy-Item[^\r\n]*candidate' -or
            [string]$stageStep[0].run -notmatch 'allowedNames' -or [string]$stageStep[0].run -notmatch 'Test-Json -SchemaFile') {
            $results.Add((New-ValidationResult -Status Failed -Message 'Codex behavior artifact staging must validate only trusted output files and must never copy candidate files.' -Path $behaviorWorkflowPath))
        }
        $uploadIndex = [array]::IndexOf($stepNames, 'Upload sanitized behavior evidence')
        $enforceIndex = [array]::IndexOf($stepNames, 'Enforce trusted evaluation result')
        $uploadStep = @($behaviorSteps | Where-Object { $_ -is [hashtable] -and $_.name -eq 'Upload sanitized behavior evidence' })
        $expectedUploadPaths = @(
            '${{ steps.initialize.outputs.artifact-root }}/workflow-result.json',
            '${{ steps.initialize.outputs.artifact-root }}/runtime-bootstrap.json',
            '${{ steps.initialize.outputs.artifact-root }}/codex-evaluator-provenance.json',
            '${{ steps.initialize.outputs.artifact-root }}/codex-evaluator-sbom.cdx.json',
            '${{ steps.initialize.outputs.artifact-root }}/evaluator-hashes.json',
            '${{ steps.initialize.outputs.artifact-root }}/codex-skill-behavior.json'
        )
        $actualUploadPaths = if ($uploadStep.Count -eq 1) { @(([string]$uploadStep[0].with.path -split "`r?`n") | ForEach-Object Trim | Where-Object { $_ }) } else { @() }
        if ($uploadIndex -lt 0 -or $enforceIndex -le $uploadIndex -or $uploadStep.Count -ne 1 -or
            [string]$uploadStep[0]['if'] -ne "always() && steps.initialize.outcome == 'success' && steps.stage.outcome == 'success'" -or
            [string]$uploadStep[0].with['if-no-files-found'] -ne 'error' -or
            $actualUploadPaths.Count -ne $expectedUploadPaths.Count -or
            @($expectedUploadPaths | Where-Object { $_ -notin $actualUploadPaths }).Count -gt 0 -or
            @($actualUploadPaths | Where-Object { $_ -match '(?i)candidate|(?:^|/)artifact(?:/)?$' }).Count -gt 0) {
            $results.Add((New-ValidationResult -Status Failed -Message 'Codex behavior workflow must upload only the explicit trusted sanitized files before final fail-closed enforcement.' -Path $behaviorWorkflowPath))
        }
    }
    if ($behaviorText -match 'pull_request_target|secrets:\s*inherit|contents:\s*write|id-' + ('tok' + 'en') + ':\s*write') {
        $results.Add((New-ValidationResult -Status Failed -Message 'Codex behavior workflow contains a prohibited trigger, inherited secret, or elevated permission.' -Path $behaviorWorkflowPath))
    }
}
elseif ($requiresBehaviorWorkflow) {
    $results.Add((New-ValidationResult -Status Failed -Message 'Trusted Codex skill behavior workflow is missing.' -Path $behaviorWorkflowPath))
}

$reusable = '.github/workflows/governance-ci-reusable.yml'
if ($workflows.ContainsKey($reusable)) {
    if (-not (Test-HasWorkflowCall -Workflow $workflows[$reusable])) {
        $results.Add((New-ValidationResult -Status Failed -Message 'Reusable governance workflow is missing workflow_call.' -Path $reusable))
    }
    if (@($callGraph[$reusable]).Count -gt 0) {
        $results.Add((New-ValidationResult -Status Failed -Message 'Reusable governance workflow must not call another reusable workflow.' -Path $reusable))
    }
    if (-not $workflows[$reusable].ContainsKey('permissions') -or $workflows[$reusable].permissions -isnot [hashtable] -or $workflows[$reusable].permissions.Count -ne 1 -or [string]$workflows[$reusable].permissions.contents -ne 'read') {
        $results.Add((New-ValidationResult -Status Failed -Message 'Reusable governance workflow permissions must be exactly contents: read.' -Path $reusable))
    }
    $requiredInputs = @('project-path','governance-version','artifact-retention-days')
    foreach ($inputName in $requiredInputs) {
        if (-not $workflowInputs[$reusable].ContainsKey($inputName)) {
            $results.Add((New-ValidationResult -Status Failed -Message "Reusable governance workflow is missing input '$inputName'." -Path $reusable))
        }
    }
    if (Test-Path -LiteralPath (Join-Path $root 'project-manifest.json') -PathType Leaf) {
        $governanceSteps = @($workflows[$reusable].jobs.governance.steps)
        $callerCheckout = @($governanceSteps | Where-Object { $_ -is [hashtable] -and $_.name -eq 'Checkout caller' })
        $standardsCheckout = @($governanceSteps | Where-Object { $_ -is [hashtable] -and $_.name -eq 'Checkout trusted standards' })
        if ($callerCheckout.Count -ne 1 -or $callerCheckout[0].uses -notmatch '^actions/checkout@[a-fA-F0-9]{40}$') {
            $results.Add((New-ValidationResult -Status Failed -Message 'Reusable workflow must contain one SHA-pinned caller checkout.' -Path $reusable))
        }
        elseif ($callerCheckout[0].with.repository -ne '${{ github.repository }}' -or $callerCheckout[0].with.ref -ne '${{ github.sha }}' -or $callerCheckout[0].with.path -ne 'caller') {
            $results.Add((New-ValidationResult -Status Failed -Message 'Caller checkout must explicitly use github.repository, github.sha, and the caller workspace.' -Path $reusable))
        }
        if ($callerCheckout.Count -eq 1 -and [string]$callerCheckout[0].with['fetch-depth'] -ne '0') {
            $results.Add((New-ValidationResult -Status Failed -Message 'Caller checkout must fetch full history so evidence validatedCommitSha objects can be verified.' -Path $reusable))
        }
        if ($standardsCheckout.Count -ne 1 -or $standardsCheckout[0].uses -notmatch '^actions/checkout@[a-fA-F0-9]{40}$') {
            $results.Add((New-ValidationResult -Status Failed -Message 'Reusable workflow must contain one SHA-pinned trusted standards checkout.' -Path $reusable))
        }
        elseif ($standardsCheckout[0].with.repository -ne '${{ job.workflow_repository }}' -or $standardsCheckout[0].with.ref -ne '${{ job.workflow_sha }}' -or $standardsCheckout[0].with.path -ne 'standards') {
            $results.Add((New-ValidationResult -Status Failed -Message 'Standards checkout must use immutable job.workflow_repository and job.workflow_sha identity in the standards workspace.' -Path $reusable))
        }
        if ($workflowInputs[$reusable].ContainsKey('standards-repository') -or $workflowInputs[$reusable].ContainsKey('standards-sha') -or $workflowInputs[$reusable].ContainsKey('standards-ref')) {
            $results.Add((New-ValidationResult -Status Failed -Message 'Callers must not be able to override the standards repository or workflow SHA.' -Path $reusable))
        }
        if ($workflowInputs[$reusable].ContainsKey('repository-owner-type')) {
            $results.Add((New-ValidationResult -Status Failed -Message 'Callers must not be able to supply or override the trusted repository owner type.' -Path $reusable))
        }
        $identitySteps = @($governanceSteps | Where-Object { $_ -is [hashtable] -and $_.name -eq 'Validate workflow identity and inputs' })
        if ($identitySteps.Count -ne 1 -or $identitySteps[0].env -isnot [hashtable] -or [string]$identitySteps[0].env.CALLER_REPOSITORY_OWNER_TYPE -ne '${{ github.event.repository.owner.type }}') {
            $results.Add((New-ValidationResult -Status Failed -Message 'Reusable workflow must read repository owner type from trusted github.event.repository.owner.type context.' -Path $reusable))
        }
        elseif ([string]$identitySteps[0].run -notmatch 'switch\s+-CaseSensitive\s+\(\$env:CALLER_REPOSITORY_OWNER_TYPE\)' -or
            [string]$identitySteps[0].run -notmatch "'User'\s*\{\s*'User'" -or
            [string]$identitySteps[0].run -notmatch "'Organization'\s*\{\s*'Organization'" -or
            [string]$identitySteps[0].run -notmatch "default\s*\{\s*'Unknown'" -or
            [string]$identitySteps[0].run -notmatch 'repository-owner-type=\$repositoryOwnerType') {
            $results.Add((New-ValidationResult -Status Failed -Message 'Reusable workflow must normalize only exact User or Organization owner types and map every other value to Unknown.' -Path $reusable))
        }
        $validationSteps = @($governanceSteps | Where-Object { $_ -is [hashtable] -and $_.name -eq 'Run trusted governance validation' })
        if ($validationSteps.Count -ne 1 -or $validationSteps[0].env -isnot [hashtable] -or [string]$validationSteps[0].env.CALLER_REPOSITORY_OWNER_TYPE -ne '${{ steps.inputs.outputs.repository-owner-type }}' -or
            [string]$validationSteps[0].run -notmatch '(?m)^\s*-RepositoryOwnerType\s+\$env:CALLER_REPOSITORY_OWNER_TYPE\s+`?\s*$') {
            $results.Add((New-ValidationResult -Status Failed -Message 'Reusable workflow must pass the normalized trusted repository owner type to Invoke-GovernanceValidation.ps1.' -Path $reusable))
        }
        if ($workflowInputs[$reusable].ContainsKey('run-examples') -or $workflowInputs[$reusable].ContainsKey('run-pester') -or $workflowInputs[$reusable].ContainsKey('run-documentation-validation')) {
            $results.Add((New-ValidationResult -Status Failed -Message 'Misleading mandatory-true compatibility inputs must not be exposed.' -Path $reusable))
        }
        foreach ($record in @(Get-JobStepRecords -Workflow $workflows[$reusable])) {
            $step = $record.step
            if ($step.ContainsKey('uses') -and [string]$step.uses -match '^\.?[/\\]caller([/\\]|$)') {
                $results.Add((New-ValidationResult -Status Failed -Message 'Reusable workflow must not load a caller-controlled local action.' -Path $reusable))
            }
            if ($step.ContainsKey('working-directory') -and [string]$step['working-directory'] -match '(^|[/\\])caller([/\\]|$)') {
                $results.Add((New-ValidationResult -Status Failed -Message 'Reusable workflow must not execute commands from the caller working directory.' -Path $reusable))
            }
            if ($step.ContainsKey('run')) {
                $runText = [string]$step.run
                $executesCallerFile = $runText -match '(?im)^\s*(?:&\s*)?(?:\./)?caller[/\\][^\r\n]*\.(?:ps1|psm1|sh|py|js|cmd|bat)\b'
                $passesCallerToInterpreter = $runText -match '(?im)^\s*(?:pwsh|powershell|python|bash|sh|node|dotnet|npm|npx)\b[^\r\n]*(?:\./)?caller[/\\]'
                $runsCallerTests = $runText -match '(?im)^\s*Invoke-Pester\b[^\r\n]*(?:\./)?caller[/\\]'
                if ($executesCallerFile -or $passesCallerToInterpreter -or $runsCallerTests) {
                    $results.Add((New-ValidationResult -Status Failed -Message 'Reusable workflow must not directly execute caller-controlled code, tests, or package commands.' -Path $reusable))
                }
            }
        }
        $steps = @()
        if ($workflows[$reusable].ContainsKey('jobs') -and $workflows[$reusable].jobs.ContainsKey('governance')) {
            $steps = @($workflows[$reusable].jobs.governance.steps | ForEach-Object { if ($_ -is [hashtable] -and $_.ContainsKey('name')) { [string]$_.name } })
        }
        $requiredOrder = @(
            'Generate workflow test evidence',
            'Generate completion evidence',
            'Validate completion evidence',
            'Finalize workflow test evidence',
            'Generate final completion evidence',
            'Validate final completion evidence',
            'Upload governance evidence',
            'Enforce mandatory governance result'
        )
        $lastIndex = -1
        foreach ($stepName in $requiredOrder) {
            $index = [array]::IndexOf($steps, $stepName)
            if ($index -lt 0) {
                $results.Add((New-ValidationResult -Status Failed -Message "Reusable governance workflow is missing ordered step '$stepName'." -Path $reusable))
            }
            elseif ($index -le $lastIndex) {
                $results.Add((New-ValidationResult -Status Failed -Message "Reusable governance workflow step '$stepName' is out of order." -Path $reusable))
            }
            $lastIndex = $index
        }
    }
}
else {
    $results.Add((New-ValidationResult -Status Failed -Message 'Reusable governance workflow is missing.' -Path $reusable))
}

$prReusable = '.github/workflows/pr-governance-reusable.yml'
$requiresPrGovernance = Test-Path -LiteralPath (Join-Path $root 'docs/PR_BODY_GOVERNANCE.md') -PathType Leaf
if ($workflows.ContainsKey($prReusable)) {
    $prWorkflow = $workflows[$prReusable]
    $prText = Get-Content -LiteralPath (Join-Path $root $prReusable) -Raw
    if (-not (Test-HasWorkflowCall -Workflow $prWorkflow)) { $results.Add((New-ValidationResult -Status Failed -Message 'PR governance reusable workflow must declare workflow_call.' -Path $prReusable)) }
    if ($prText -match 'pull_request_target|secrets\.|secrets:\s*inherit|contents:\s*write|pull-requests:\s*write|environment:') { $results.Add((New-ValidationResult -Status Failed -Message 'PR governance workflow requests a prohibited trigger, secret, environment, or write permission.' -Path $prReusable)) }
    if ($prText -notmatch 'contents:\s*read' -or $prText -notmatch 'pull-requests:\s*read') { $results.Add((New-ValidationResult -Status Failed -Message 'PR governance workflow must declare exact read-only permissions.' -Path $prReusable)) }
    if ($prText -notmatch 'job\.workflow_repository' -or $prText -notmatch 'job\.workflow_sha' -or $prText -notmatch 'persist-credentials:\s*false') { $results.Add((New-ValidationResult -Status Failed -Message 'PR governance workflow must check out only immutable trusted workflow content without credentials.' -Path $prReusable)) }
    if ($prText -match 'github\.event\.pull_request\.head|github\.head_ref' -or $prText -match 'checkout[^\r\n]*PR') { $results.Add((New-ValidationResult -Status Failed -Message 'PR governance workflow must not check out PR-head content.' -Path $prReusable)) }
    if ($prText -notmatch 'GITHUB_EVENT_PATH' -or $prText -notmatch 'Get-PullRequestChangedFiles\.ps1' -or $prText -notmatch 'if:\s*always\(\)' -or $prText -notmatch 'if-no-files-found:\s*error') { $results.Add((New-ValidationResult -Status Failed -Message 'PR governance workflow must use event-file input, paginated filename retrieval, and fail-closed artifact upload.' -Path $prReusable)) }
    $thirdPartyUses = [regex]::Matches($prText, '(?m)^\s*uses:\s*(?!\./)([^\s]+)$')
    foreach ($use in $thirdPartyUses) { if ($use.Groups[1].Value -notmatch '@[0-9a-fA-F]{40}$') { $results.Add((New-ValidationResult -Status Failed -Message 'PR governance workflow actions must use full immutable SHA pins.' -Path $prReusable)) } }
}
elseif ($requiresPrGovernance) { $results.Add((New-ValidationResult -Status Failed -Message 'PR governance reusable workflow is missing.' -Path $prReusable)) }

$prEntry = '.github/workflows/pr-governance.yml'
if ($workflows.ContainsKey($prEntry)) {
    $entry = $workflows[$prEntry]; $entryText = Get-Content -LiteralPath (Join-Path $root $prEntry) -Raw
    if ([string]$entry.name -ne 'Pull Request Governance') { $results.Add((New-ValidationResult -Status Failed -Message 'PR governance entry workflow name is not stable.' -Path $prEntry)) }
    $types = @($entry['on'].pull_request.types)
    foreach ($requiredType in @('opened','edited','reopened','synchronize','ready_for_review')) { if ($requiredType -notin $types) { $results.Add((New-ValidationResult -Status Failed -Message "PR governance entry workflow is missing trigger '$requiredType'." -Path $prEntry)) } }
    if ($entryText -match 'pull_request_target|secrets\.|environment:|contents:\s*write|pull-requests:\s*write') { $results.Add((New-ValidationResult -Status Failed -Message 'PR governance entry workflow requests a prohibited trigger, secret, environment, or permission.' -Path $prEntry)) }
    $job = $entry.jobs.validate
    if ([string]$job.name -ne 'Validate pull request governance record') { $results.Add((New-ValidationResult -Status Failed -Message 'PR governance job name is not stable.' -Path $prEntry)) }
    if ([string]$job.uses -notmatch '^AIAllTheThingz/Engineering-Standards/\.github/workflows/pr-governance-reusable\.yml@[0-9a-f]{40}$') { $results.Add((New-ValidationResult -Status Failed -Message 'PR governance reusable call must use the central path and a full immutable SHA.' -Path $prEntry)) }
}
elseif ($requiresPrGovernance) { $results.Add((New-ValidationResult -Status Failed -Message 'PR governance entry workflow is missing.' -Path $prEntry)) }

$dependencyLockPath = Join-Path $root '.github/dependencies/validator-dependencies.psd1'
if (Test-Path -LiteralPath $dependencyLockPath -PathType Leaf) {
    $dependencyReportRelative = ".tmp/validator-dependencies-$([guid]::NewGuid().ToString('N')).json"
    $dependencyReportPath = Join-Path $root $dependencyReportRelative
    try {
        $currentPowerShell = Join-Path $PSHOME $(if ($IsWindows) { 'pwsh.exe' } else { 'pwsh' })
        & $currentPowerShell -NoProfile -File (Join-Path $PSScriptRoot 'Test-ValidatorDependencies.ps1') -Path $root -OutputJson $dependencyReportRelative | Out-Null
        $dependencyExitCode = $LASTEXITCODE
        if (-not (Test-Path -LiteralPath $dependencyReportPath -PathType Leaf)) {
            $results.Add((New-ValidationResult -Status Failed -Message 'Validator dependency validation did not produce its required report.' -Path '.github/dependencies/validator-dependencies.psd1'))
        }
        else {
            $dependencyReport = Get-Content -LiteralPath $dependencyReportPath -Raw | ConvertFrom-Json
            foreach ($dependencyResult in @($dependencyReport.results | Where-Object status -in @('Failed','Blocked'))) {
                $results.Add((New-ValidationResult -Status Failed -Message "$($dependencyResult.ruleId): $($dependencyResult.message)" -Path ([string]$dependencyResult.path)))
            }
            if ($dependencyExitCode -ne 0 -and -not @($dependencyReport.results | Where-Object status -in @('Failed','Blocked'))) {
                $results.Add((New-ValidationResult -Status Failed -Message "Validator dependency validation exited $dependencyExitCode without a structured failure." -Path '.github/dependencies/validator-dependencies.psd1'))
            }
        }
    }
    finally {
        Remove-Item -LiteralPath $dependencyReportPath -Force -ErrorAction SilentlyContinue
    }
}

if (-not @($results | Where-Object status -eq 'Failed')) {
    $results.Add((New-ValidationResult -Status Passed -Message 'GitHub workflow architecture validation passed.' -Path $root -Severity info -Data @{ callGraph = $callGraph }))
}

$report = New-ValidationReport -Results @($results)
Write-ValidationReport -Report $report -OutputJson $OutputJson
if ($report.failed -gt 0) { exit 1 }
exit 0
