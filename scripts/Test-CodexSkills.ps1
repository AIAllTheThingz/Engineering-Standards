<#
.SYNOPSIS
Validates repository-scoped Codex skills as untrusted code-adjacent inputs.
.DESCRIPTION
Runs bounded deterministic structural validation without executing skill scripts,
declared tools, dependencies, or model evaluations. Optional JSON output uses the
canonical governance statuses Passed, Failed, Blocked, NotRun, and NotApplicable.
.PARAMETER Path
Repository root. Defaults to the current directory.
.PARAMETER OutputJson
Optional report path. Relative output paths resolve beneath the repository root.
.PARAMETER AllowedOutputRoot
Optional trusted evidence root used by aggregate validation. When set, OutputJson
must resolve beneath this root; ordinary callers should omit it.
.EXAMPLE
pwsh -NoProfile -File scripts/Test-CodexSkills.ps1 -Path . -OutputJson .tmp/codex-skills-validation.json
#>
[CmdletBinding()]
param([string]$Path = '.', [string]$OutputJson, [string]$AllowedOutputRoot)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
Import-Module (Join-Path $PSScriptRoot 'CodexSkillsValidation.psm1') -Force

$root = (Resolve-Path -LiteralPath $Path).Path
try {
    $reports = [Collections.Generic.List[object]]::new()
    foreach ($skillRoot in @('.agents/skills','.agents/suspended-skills')) {
        if (Test-Path -LiteralPath (Join-Path $root $skillRoot) -PathType Container) {
            $reports.Add((Invoke-CodexSkillValidation -Path $root -SkillsRootRelative $skillRoot -SkipPromptBehavior))
        }
    }
    if ($reports.Count -eq 0) { $reports.Add((Invoke-CodexSkillValidation -Path $root)) }
    $allResults = @($reports | ForEach-Object { $_.results })
    $allSkills = @($reports | ForEach-Object { $_.skillsDiscovered } | Sort-Object -Unique)
    [object[]]$allPromptResults = @()
    if ($allSkills.Count -gt 0) { $allPromptResults = @(Test-PromptBehaviorCorpus -RepositoryRoot $root -SkillNames $allSkills) }
    $allValidationResults = @($allResults) + @($allPromptResults) | Where-Object { $null -ne $_ }
    $requiredFailures = @($allValidationResults | Where-Object { $_.requiredValidation -and $_.status -in @('Failed','Blocked') })
    $report = [ordered]@{
        schemaVersion='1.0.0'; generatedAtUtc=[DateTime]::UtcNow.ToString('o'); repositoryRoot=$root
        skillsRoot=@($reports | ForEach-Object { $_.skillsRoot }); skillsDiscovered=$allSkills
        deterministicStatus=if($requiredFailures.Count -gt 0){if(@($requiredFailures | Where-Object status -eq 'Blocked').Count -gt 0){'Blocked'}else{'Failed'}}else{'Passed'}
        modelEvaluationStatus=if($allSkills.Count -eq 0){'NotApplicable'}else{'NotRun'}
        results=$allResults; promptBehaviorResults=$allPromptResults
        failed=@($allValidationResults | Where-Object status -eq 'Failed').Count
        blocked=@($allValidationResults | Where-Object status -eq 'Blocked').Count
        notRun=@($allValidationResults | Where-Object status -eq 'NotRun').Count
        warnings=@($allValidationResults | Where-Object severity -eq 'warning').Count
    }
    if ($OutputJson) {
        if ($AllowedOutputRoot) {
            $outputRoot = (Resolve-Path -LiteralPath $AllowedOutputRoot).Path
            $candidate = if ([System.IO.Path]::IsPathRooted($OutputJson)) { [System.IO.Path]::GetFullPath($OutputJson) } else { [System.IO.Path]::GetFullPath((Join-Path $outputRoot $OutputJson)) }
            $relativeOutput = [System.IO.Path]::GetRelativePath($outputRoot, $candidate)
            $resolvedOutput = Resolve-BoundedChildPath -Root $outputRoot -ChildPath $relativeOutput -AllowMissingLeaf
        }
        else {
            $relativeOutput = if ([System.IO.Path]::IsPathRooted($OutputJson)) { [System.IO.Path]::GetRelativePath($root, [System.IO.Path]::GetFullPath($OutputJson)) } else { $OutputJson }
            $resolvedOutput = Resolve-BoundedChildPath -Root $root -ChildPath $relativeOutput -AllowMissingLeaf
        }
        $parent = Split-Path -Parent $resolvedOutput
        if ($parent) { New-Item -ItemType Directory -Path $parent -Force | Out-Null }
        $report.repositoryRoot = '.'
        $report.skillsRoot = @($reports | ForEach-Object { [IO.Path]::GetRelativePath($root, $_.skillsRoot).Replace('\','/') })
        $report | ConvertTo-Json -Depth 32 | Set-Content -LiteralPath $resolvedOutput -Encoding utf8
    }
    "Codex skills: deterministic=$($report.deterministicStatus), modelEvaluation=$($report.modelEvaluationStatus), skills=$(@($report.skillsDiscovered).Count), failed=$($report.failed), blocked=$($report.blocked), notRun=$($report.notRun)."
    if ($report.deterministicStatus -in @('Failed','Blocked')) { exit 1 }
    $behaviorEvidence = Join-Path $root 'evidence/codex-skill-behavior.json'
    $behaviorConfiguration = Join-Path $root 'governance/codex-skill-behavior-evaluation.psd1'
    if ((Test-Path -LiteralPath $behaviorEvidence -PathType Leaf) -or (Test-Path -LiteralPath $behaviorConfiguration -PathType Leaf)) {
        if (-not (Test-Path -LiteralPath $behaviorEvidence -PathType Leaf) -or -not (Test-Path -LiteralPath $behaviorConfiguration -PathType Leaf)) {
            Write-Error 'Controlled behavior evidence and its approved configuration must be present together.'
            exit 1
        }
        & (Join-Path $PSHOME 'pwsh') -NoProfile -File (Join-Path $PSScriptRoot 'Test-CodexSkillBehaviorEvidence.ps1') -Path $root
        if ($LASTEXITCODE -ne 0) { exit 1 }
        $behavior = Get-Content -LiteralPath $behaviorEvidence -Raw | ConvertFrom-Json
        $approvedBehavior = Import-PowerShellDataFile -LiteralPath $behaviorConfiguration
        if ($behavior.status -in @('Failed','Blocked','NotRun')) {
            if ($behavior.decision.skillStatus -eq 'Active') {
                if ($behavior.decision.action -ne 'Suspend') { Write-Error 'Nonpassing Active-skill evidence must require suspension.'; exit 1 }
                $activeInstruction = Join-Path $root $approvedBehavior.Skill.ActiveInstructionPath
                $suspendedInstruction = Join-Path $root $approvedBehavior.Skill.SuspendedInstructionPath
                if ((Test-Path -LiteralPath $activeInstruction -PathType Leaf) -or -not (Test-Path -LiteralPath $suspendedInstruction -PathType Leaf)) { Write-Error "Active skill '$($approvedBehavior.Skill.Name)' has nonpassing behavior evidence but its discoverable SKILL.md is not physically suspended."; exit 1 }
            }
            elseif ($behavior.decision.action -ne 'BlockPromotion') { Write-Error 'Nonpassing Candidate evidence must block promotion.'; exit 1 }
        }
        elseif ($behavior.status -eq 'Passed') {
            if ($behavior.humanAdjudication.status -ne 'Passed' -or $behavior.humanAdjudication.decision -ne 'Approved' -or [string]::IsNullOrWhiteSpace([string]$behavior.humanAdjudication.reviewer) -or $null -eq $behavior.humanAdjudication.reviewedAtUtc) { Write-Error 'Passed behavior evidence requires an attributable Approved human adjudication before aggregate success.'; exit 1 }
        }
    }
    exit 0
}
catch {
    Write-Error ("Codex skill validation blocked: {0}" -f $_.Exception.Message)
    exit 2
}
