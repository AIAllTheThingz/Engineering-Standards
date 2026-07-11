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
if ($workflows.ContainsKey($entry)) {
    $branches = @(Get-PushBranches -Workflow $workflows[$entry])
    if ($branches -notcontains $DefaultBranch) {
        $results.Add((New-ValidationResult -Status Failed -Message "Entry workflow push trigger does not include default branch '$DefaultBranch'." -Path $entry))
    }
    $entryJobUses = @((Get-WorkflowUses -Workflow $workflows[$entry] -RelativePath $entry) | Where-Object kind -eq 'job')
    $localCall = @($entryJobUses | Where-Object value -eq './.github/workflows/governance-ci-reusable.yml')
    $remoteCall = @($entryJobUses | Where-Object value -match '^AIAllTheThingz/Engineering-Standards/\.github/workflows/governance-ci-reusable\.yml@([a-fA-F0-9]{40})$')
    if ($entryJobUses.Count -ne 1 -or ($localCall.Count + $remoteCall.Count) -ne 1) {
        $results.Add((New-ValidationResult -Status Failed -Message 'Entry workflow must call the local reusable workflow or a full-SHA Engineering Standards reusable workflow exactly once.' -Path $entry))
    }
    elseif ($remoteCall.Count -eq 1 -and $ExpectedReusableWorkflowSha) {
        $actualSha = ([string]$remoteCall[0].value -split '@')[-1]
        if ($actualSha -ne $ExpectedReusableWorkflowSha) {
            $results.Add((New-ValidationResult -Status Failed -Message "Entry workflow reusable SHA '$actualSha' does not match expected trusted SHA '$ExpectedReusableWorkflowSha'." -Path $entry))
        }
    }
}
else {
    $results.Add((New-ValidationResult -Status Failed -Message 'Entry workflow is missing.' -Path $entry))
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

if (-not @($results | Where-Object status -eq 'Failed')) {
    $results.Add((New-ValidationResult -Status Passed -Message 'GitHub workflow architecture validation passed.' -Path $root -Severity info -Data @{ callGraph = $callGraph }))
}

$report = New-ValidationReport -Results @($results)
Write-ValidationReport -Report $report -OutputJson $OutputJson
if ($report.failed -gt 0) { exit 1 }
exit 0
