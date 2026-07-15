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
    $report = Invoke-CodexSkillValidation -Path $root
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
        $report.skillsRoot = '.agents/skills'
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
                $catalog = Get-Content -LiteralPath (Join-Path $root '.agents/skills/README.md') -Raw
                $escapedSkill = [regex]::Escape([string]$approvedBehavior.Skill.Name)
                if ($catalog -notmatch "(?m)^\|[^|]*$escapedSkill[^|]*\|[^|]*\|\s*Suspended\s*\|") { Write-Error "Active skill '$($approvedBehavior.Skill.Name)' has nonpassing behavior evidence but is not marked Suspended in the catalog."; exit 1 }
            }
            elseif ($behavior.decision.action -ne 'BlockPromotion') { Write-Error 'Nonpassing Candidate evidence must block promotion.'; exit 1 }
        }
    }
    exit 0
}
catch {
    Write-Error ("Codex skill validation blocked: {0}" -f $_.Exception.Message)
    exit 2
}
