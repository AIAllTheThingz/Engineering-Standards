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
                $runText = [string]$validationStep.run
                $candidateTokens = $null
                $candidateParseErrors = $null
                $candidateAst = [System.Management.Automation.Language.Parser]::ParseInput($runText, [ref]$candidateTokens, [ref]$candidateParseErrors)
                if (@($candidateParseErrors).Count -gt 0) {
                    $results.Add((New-ValidationResult -Status Failed -Message 'Candidate implementation validation PowerShell does not parse.' -Path $candidateWorkflowPath))
                }
                $candidateCommands = @($candidateAst.FindAll({ param($node) $node -is [System.Management.Automation.Language.CommandAst] }, $true))
                $candidateScriptPaths = @(
                    $candidateCommands |
                        Where-Object { $_.GetCommandName() -eq 'Invoke-CandidateScript' -and $_.CommandElements.Count -gt 1 } |
                        ForEach-Object { [string]$_.CommandElements[1].Value }
                )
                foreach ($requiredScript in @(
                    'scripts/Test-AgentStandards.ps1','scripts/Test-YamlSyntax.ps1','scripts/Test-GitHubWorkflowArchitecture.ps1',
                    'scripts/Test-JsonSchemas.ps1','scripts/Test-MarkdownLinks.ps1','scripts/Test-DocumentationCompleteness.ps1',
                    'actions/validate-contract/Invoke-ContractValidation.ps1','actions/repository-health/Invoke-RepositoryHealth.ps1',
                    'actions/forbidden-pattern-scan/Invoke-ForbiddenPatternScan.ps1','scripts/Test-CodexSkills.ps1','scripts/Invoke-PesterSuite.ps1','scripts/Test-Examples.ps1'
                )) {
                    if ($candidateScriptPaths -notcontains $requiredScript) {
                        $results.Add((New-ValidationResult -Status Failed -Message "Candidate harness is missing required candidate script invocation '$requiredScript'." -Path $candidateWorkflowPath))
                    }
                }
                $codexSkillCommands = @(
                    $candidateCommands |
                        Where-Object {
                            $_.GetCommandName() -eq 'Invoke-CandidateScript' -and
                            $_.CommandElements.Count -gt 1 -and
                            [string]$_.CommandElements[1].Value -eq 'scripts/Test-CodexSkills.ps1'
                        }
                )
                if ($codexSkillCommands.Count -ne 1 -or $codexSkillCommands[0].Extent.Text -notmatch "Join-Path\s+\`$reportRoot\s+'codex-skills\.json'") {
                    $results.Add((New-ValidationResult -Status Failed -Message 'Candidate Codex skill validation must write beneath .tmp/candidate-validation through reportRoot.' -Path $candidateWorkflowPath))
                }
                $gitDiffCommand = @($candidateCommands | Where-Object { $_.GetCommandName() -eq 'git' -and ($_.CommandElements.Extent.Text -join ' ') -match '\bdiff\b.*--check' })
                if ($gitDiffCommand.Count -eq 0) { $results.Add((New-ValidationResult -Status Failed -Message 'Candidate harness is missing an executable git diff --check command.' -Path $candidateWorkflowPath)) }
                if (@($candidateCommands | Where-Object { $_.GetCommandName() -eq 'Invoke-ScriptAnalyzer' }).Count -eq 0) { $results.Add((New-ValidationResult -Status Failed -Message 'Candidate harness is missing an executable Invoke-ScriptAnalyzer command.' -Path $candidateWorkflowPath)) }
                $parseFileCalls = @($candidateAst.FindAll({ param($node) $node -is [System.Management.Automation.Language.InvokeMemberExpressionAst] -and [string]$node.Member.Value -eq 'ParseFile' }, $true))
                if ($parseFileCalls.Count -eq 0) { $results.Add((New-ValidationResult -Status Failed -Message 'Candidate harness is missing executable PowerShell parser validation.' -Path $candidateWorkflowPath)) }
                $architectureCommands = @(
                    $candidateCommands |
                        Where-Object {
                            $_.GetCommandName() -eq 'Invoke-CandidateScript' -and
                            $_.CommandElements.Count -gt 1 -and
                            [string]$_.CommandElements[1].Value -eq 'scripts/Test-GitHubWorkflowArchitecture.ps1'
                        }
                )
                $candidatePolicyArguments = @(
                    $architectureCommands |
                        ForEach-Object {
                            $_.FindAll({
                                param($node)
                                $node -is [System.Management.Automation.Language.StringConstantExpressionAst]
                            }, $true)
                        } |
                        ForEach-Object { [string]$_.Value }
                )
                if ($candidatePolicyArguments -notcontains '-RequireCandidateValidation') {
                    $results.Add((New-ValidationResult -Status Failed -Message 'Candidate workflow architecture validation must fail closed with RequireCandidateValidation.' -Path $candidateWorkflowPath))
                }
                $repositoryHealthCommands = @(
                    $candidateCommands |
                        Where-Object {
                            $_.GetCommandName() -eq 'Invoke-CandidateScript' -and
                            $_.CommandElements.Count -gt 1 -and
                            [string]$_.CommandElements[1].Value -eq 'actions/repository-health/Invoke-RepositoryHealth.ps1'
                        }
                )
                $repositoryHealthArguments = @(
                    $repositoryHealthCommands |
                        ForEach-Object {
                            $_.FindAll({
                                param($node)
                                $node -is [System.Management.Automation.Language.StringConstantExpressionAst]
                            }, $true)
                        } |
                        ForEach-Object { [string]$_.Value }
                )
                $ownerTypeArgumentIndex = [array]::IndexOf($repositoryHealthArguments, '-RepositoryOwnerType')
                if ($ownerTypeArgumentIndex -lt 0 -or $ownerTypeArgumentIndex + 1 -ge $repositoryHealthArguments.Count -or $repositoryHealthArguments[$ownerTypeArgumentIndex + 1] -cne 'User') {
                    $results.Add((New-ValidationResult -Status Failed -Message 'Candidate repository-health validation must explicitly use RepositoryOwnerType User.' -Path $candidateWorkflowPath))
                }
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

$reusable = '.github/workflows/governance-ci-reusable.yml'
if ($workflows.ContainsKey($reusable)) {
    if (-not (Test-HasWorkflowCall -Workflow $workflows[$reusable])) {
        $results.Add((New-ValidationResult -Status Failed -Message 'Reusable governance workflow is missing workflow_call.' -Path $reusable))
    }
    if (@($callGraph[$reusable]).Count -gt 0) {
        $results.Add((New-ValidationResult -Status Failed -Message 'Reusable governance workflow must not call another reusable workflow.' -Path $reusable))
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
        if ($standardsCheckout.Count -ne 1 -or $standardsCheckout[0].uses -notmatch '^actions/checkout@[a-fA-F0-9]{40}$') {
            $results.Add((New-ValidationResult -Status Failed -Message 'Reusable workflow must contain one SHA-pinned trusted standards checkout.' -Path $reusable))
        }
        elseif ($standardsCheckout[0].with.repository -ne '${{ job.workflow_repository }}' -or $standardsCheckout[0].with.ref -ne '${{ job.workflow_sha }}' -or $standardsCheckout[0].with.path -ne 'standards') {
            $results.Add((New-ValidationResult -Status Failed -Message 'Standards checkout must use immutable job.workflow_repository and job.workflow_sha identity in the standards workspace.' -Path $reusable))
        }
        if ($workflowInputs[$reusable].ContainsKey('standards-repository') -or $workflowInputs[$reusable].ContainsKey('standards-sha') -or $workflowInputs[$reusable].ContainsKey('standards-ref')) {
            $results.Add((New-ValidationResult -Status Failed -Message 'Callers must not be able to override the standards repository or workflow SHA.' -Path $reusable))
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

if (-not @($results | Where-Object status -eq 'Failed')) {
    $results.Add((New-ValidationResult -Status Passed -Message 'GitHub workflow architecture validation passed.' -Path $root -Severity info -Data @{ callGraph = $callGraph }))
}

$report = New-ValidationReport -Results @($results)
Write-ValidationReport -Report $report -OutputJson $OutputJson
if ($report.failed -gt 0) { exit 1 }
exit 0
