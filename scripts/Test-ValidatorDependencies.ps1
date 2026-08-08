<#
.SYNOPSIS
Validates the governance validator dependency model.
.DESCRIPTION
Validates the reviewed dependency lock, hash-locked Python requirements, pinned
runtime declarations, immutable setup-action references, package provenance,
and workflow use of the supported Ubuntu runner and declared runtime versions.
This command is validation-only and never downloads or installs dependencies.
.PARAMETER Path
Repository root to validate.
.PARAMETER LockFile
Repository-relative dependency lock path.
.PARAMETER RequirementsFile
Repository-relative hash-locked Python requirements path.
.PARAMETER OutputJson
Optional JSON report path.
.EXAMPLE
pwsh -NoProfile -File scripts/Test-ValidatorDependencies.ps1 -Path . -OutputJson evidence/dependency-lock-validation.json
.NOTES
Exit code 0 means Passed. Exit code 1 means the lock, hashes, provenance, runner,
or workflow runtime declarations failed validation.
#>
[CmdletBinding()]
param(
    [string]$Path = '.',
    [string]$LockFile = '.github/dependencies/validator-dependencies.psd1',
    [string]$RequirementsFile = '.github/dependencies/workflow-validation-requirements.txt',
    [string]$OutputJson
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
Import-Module (Join-Path $PSScriptRoot 'ValidatorDependencyTools.psm1') -Force

$root = (Resolve-Path -LiteralPath $Path).Path
$lockPath = Join-Path $root $LockFile
$requirementsPath = Join-Path $root $RequirementsFile
$results = [System.Collections.Generic.List[object]]::new()

try {
    $lock = Import-ValidatorDependencyLock -Path $lockPath
    foreach ($result in @(Test-ValidatorDependencyLock -Lock $lock -LockPath $LockFile -RequirementsPath $requirementsPath)) {
        $results.Add($result)
    }

    $globalJsonPath = Join-Path $root 'global.json'
    if (-not (Test-Path -LiteralPath $globalJsonPath -PathType Leaf)) {
        $results.Add([ordered]@{ ruleId='DEP019'; status='Failed'; message='global.json is required to select the locked .NET SDK.'; path='global.json' })
    }
    else {
        try {
            $globalJson = Get-Content -LiteralPath $globalJsonPath -Raw | ConvertFrom-Json
            if ([string]$globalJson.sdk.version -ne [string]$lock.Runtimes.DotNet.Version -or
                [string]$globalJson.sdk.rollForward -ne 'disable' -or
                [bool]$globalJson.sdk.allowPrerelease) {
                $results.Add([ordered]@{ ruleId='DEP019'; status='Failed'; message='global.json must select the exact locked .NET SDK with roll-forward and prerelease disabled.'; path='global.json' })
            }
        }
        catch {
            $results.Add([ordered]@{ ruleId='DEP019'; status='Failed'; message='global.json is malformed or does not declare the locked .NET SDK.'; path='global.json' })
        }
    }

    if (-not @($results | Where-Object status -eq 'Failed')) {
        $workflowExpectations = @(
            @{ Path='.github/workflows/governance-ci-reusable.yml'; FullRuntime=$true },
            @{ Path='.github/workflows/governance-ci-candidate.yml'; FullRuntime=$true },
            @{ Path='.github/workflows/pr-governance-reusable.yml'; FullRuntime=$false }
        )
        foreach ($expectation in $workflowExpectations) {
            $workflowPath = Join-Path $root $expectation.Path
            if (-not (Test-Path -LiteralPath $workflowPath -PathType Leaf)) {
                $results.Add([ordered]@{ ruleId='DEP014'; status='Failed'; message='Release-critical workflow is missing.'; path=$expectation.Path })
                continue
            }
            $workflowText = Get-Content -LiteralPath $workflowPath -Raw
            if ($workflowText -match 'runs-on:\s*ubuntu-latest' -or $workflowText -notmatch "runs-on:\s*$([regex]::Escape([string]$lock.Runner.Label))") {
                $results.Add([ordered]@{ ruleId='DEP015'; status='Failed'; message="Release-critical jobs must use runner '$($lock.Runner.Label)' and must not use ubuntu-latest."; path=$expectation.Path })
            }
            if ($workflowText -notmatch 'Install-ValidatorRuntime\.ps1') {
                $results.Add([ordered]@{ ruleId='DEP016'; status='Failed'; message='Release-critical workflow does not install the hash-verified PowerShell runtime.'; path=$expectation.Path })
            }
            if ($expectation.FullRuntime) {
                foreach ($runtimeName in @('Python','Node','DotNet')) {
                    $runtime = $lock.Runtimes[$runtimeName]
                    $actionReference = [regex]::Escape("$($runtime.SetupAction)@$($runtime.ActionSha)")
                    if ($workflowText -notmatch $actionReference -or $workflowText -notmatch [regex]::Escape([string]$runtime.Version)) {
                        $results.Add([ordered]@{ ruleId='DEP017'; status='Failed'; message="Workflow does not match the locked $runtimeName setup action SHA and version."; path=$expectation.Path })
                    }
                }
                if ($workflowText -notmatch 'Install-ValidatorDependencies\.ps1' -or $workflowText -notmatch '-ToolRoot') {
                    $results.Add([ordered]@{ ruleId='DEP018'; status='Failed'; message='Workflow does not use the shared hash-verifying dependency installer.'; path=$expectation.Path })
                }
            }
        }
    }

    $codexDependencyRoot = Join-Path $root '.github/dependencies/codex-evaluator'
    $codexPackagePath = Join-Path $codexDependencyRoot 'package.json'
    $codexLockPath = Join-Path $codexDependencyRoot 'package-lock.json'
    $codexWorkflowPath = Join-Path $root '.github/workflows/codex-skill-behavior.yml'
    if (-not (Test-Path -LiteralPath $codexPackagePath -PathType Leaf) -or -not (Test-Path -LiteralPath $codexLockPath -PathType Leaf)) {
        $results.Add([ordered]@{ ruleId='DEP020'; status='Failed'; message='Trusted Codex evaluator package.json and package-lock.json are required.'; path='.github/dependencies/codex-evaluator' })
    }
    else {
        try {
            $codexPackage = Get-Content -LiteralPath $codexPackagePath -Raw | ConvertFrom-Json -AsHashtable
            $codexLock = Get-Content -LiteralPath $codexLockPath -Raw | ConvertFrom-Json -AsHashtable
            $rootLockPackage = $codexLock.packages['']
            $codexLockPackage = $codexLock.packages['node_modules/@openai/codex']
            if ([string]$codexPackage.dependencies['@openai/codex'] -cne '0.144.0-alpha.4' -or
                [string]$rootLockPackage.dependencies['@openai/codex'] -cne '0.144.0-alpha.4' -or
                [string]$codexLockPackage.version -cne '0.144.0-alpha.4' -or
                [string]$codexLockPackage.resolved -cne 'https://registry.npmjs.org/@openai/codex/-/codex-0.144.0-alpha.4.tgz' -or
                [string]$codexLockPackage.integrity -cne 'sha512-Uf915avv7ETTv5PFLPf+Bw2KICFXgW8M+5vMzoUlrJkcRlCOTs5FgzjLZPvawWOJqZEgFsrQuJeLMRog0XSxxQ==' -or
                [int]$codexLock.lockfileVersion -ne 3 -or $codexPackage.ContainsKey('scripts')) {
                $results.Add([ordered]@{ ruleId='DEP021'; status='Failed'; message='Trusted Codex evaluator dependency must use the exact reviewed package, registry artifact, integrity hash, lockfile version, and no package scripts.'; path='.github/dependencies/codex-evaluator/package-lock.json' })
            }
        }
        catch {
            $results.Add([ordered]@{ ruleId='DEP021'; status='Failed'; message="Trusted Codex evaluator dependency metadata is malformed: $($_.Exception.Message)"; path='.github/dependencies/codex-evaluator/package-lock.json' })
        }
    }
    if (-not (Test-Path -LiteralPath $codexWorkflowPath -PathType Leaf)) {
        $results.Add([ordered]@{ ruleId='DEP022'; status='Failed'; message='Trusted Codex evaluator workflow is missing.'; path='.github/workflows/codex-skill-behavior.yml' })
    }
    else {
        $codexWorkflowText = Get-Content -LiteralPath $codexWorkflowPath -Raw
        if ($codexWorkflowText -notmatch 'actions/setup-node@820762786026740c76f36085b0efc47a31fe5020' -or
            $codexWorkflowText -notmatch 'node-version:\s*22\.17\.0' -or
            $codexWorkflowText -notmatch 'Install-ValidatorRuntime\.ps1' -or
            $codexWorkflowText -notmatch 'npm ci --ignore-scripts --no-audit --no-fund' -or
            $codexWorkflowText -notmatch "codexVersion\s+-cne\s+'codex-cli 0\.144\.0-alpha\.4'" -or
            $codexWorkflowText -notmatch 'codex-evaluator-provenance\.json' -or
            $codexWorkflowText -notmatch 'codex-evaluator-sbom\.cdx\.json' -or
            $codexWorkflowText -notmatch "bomFormat\s*=\s*'CycloneDX'") {
            $results.Add([ordered]@{ ruleId='DEP022'; status='Failed'; message='Trusted Codex evaluator workflow must use locked runtimes, lifecycle-disabled npm install, exact CLI verification, file-hash provenance, and CycloneDX inventory.'; path='.github/workflows/codex-skill-behavior.yml' })
        }
    }
    $codexPolicyRelativePath = '.github/dependencies/codex-evaluator/behavior-trust-policy.psd1'
    $codexPolicyPath = Join-Path $root $codexPolicyRelativePath
    if (-not (Test-Path -LiteralPath $codexPolicyPath -PathType Leaf)) {
        $results.Add([ordered]@{ ruleId='DEP023'; status='Failed'; message='Trusted Codex evaluator trust policy is missing.'; path=$codexPolicyRelativePath })
    }
    else {
        try {
            $policy = Import-PowerShellDataFile -LiteralPath $codexPolicyPath
            $approvedHashes = @($policy.ApprovedConfigurations | ForEach-Object { [string]$_.Sha256 })
            $requiredEvaluatorPaths = @(
                $codexPolicyRelativePath,
                'scripts/CodexSkillBehaviorActionsEvaluation.psm1',
                'scripts/Invoke-CodexSkillBehaviorActionsEvaluation.ps1',
                'scripts/Invoke-CodexSkillBehaviorActionsModel.ps1',
                'scripts/Test-CodexSkillBehaviorActionsEvidence.ps1',
                'schemas/codex-skill-behavior-evaluation.schema.json',
                'schemas/codex-skill-behavior-observation.schema.json'
            )
            $requiredLimits = @(
                'MaximumConfigurationBytes','MaximumPromptFileCount','MaximumPromptBytesPerFile','MaximumPromptCharacters',
                'MaximumSkillFileCount','MaximumSkillBytesPerFile','MaximumAggregateSkillBytes','MaximumAuthorityFileBytes',
                'MaximumAggregateAuthorityBytes','MaximumCaseIdLength','MaximumSkillNameLength','MaximumCategoryLength',
                'MaximumRationaleCharacters','MaximumDeterministicAssertions','MaximumDeterministicAssertionLength'
            )
            if ([string]$policy.SchemaVersion -cne '1.0.0' -or
                [string]$policy.ConfigurationPath -cne 'governance/codex-skill-behavior-evaluation.psd1' -or
                @($requiredEvaluatorPaths | Where-Object { $_ -notin @($policy.EvaluatorPaths) }).Count -gt 0 -or
                @($policy.EvaluatorPaths).Count -ne $requiredEvaluatorPaths.Count -or
                [string]$policy.ConfigurationPath -in @($policy.EvaluatorPaths) -or
                @($policy.ApprovedConfigurations).Count -ne 2 -or
                '26edd6a335bfcc359e32f35959cf1a5bd514125f0fd94d88b688083c782f1515' -notin $approvedHashes -or
                '9a24ce3d74448b2787e3470dbb9cace027aa5ae9fddbeff507a0019ccd700de6' -notin $approvedHashes -or
                @($approvedHashes | Where-Object { $_ -cnotmatch '^[0-9a-f]{64}$' }).Count -gt 0 -or
                @($requiredLimits | Where-Object { -not $policy.InputLimits.ContainsKey($_) -or [long]$policy.InputLimits[$_] -lt 1 }).Count -gt 0 -or
                @($policy.InputLimits.ApprovedCategories).Count -lt 1 -or
                @($policy.InputLimits.ApprovedDeterministicAssertions).Count -lt 1) {
                $results.Add([ordered]@{ ruleId='DEP023'; status='Failed'; message='Trusted Codex evaluator policy must separate approved configuration hashes from immutable evaluator paths and declare all positive input bounds.'; path=$codexPolicyRelativePath })
            }
        }
        catch {
            $results.Add([ordered]@{ ruleId='DEP023'; status='Failed'; message="Trusted Codex evaluator policy is malformed: $($_.Exception.Message)"; path=$codexPolicyRelativePath })
        }
    }
}
catch {
    $results.Add([ordered]@{ ruleId='DEP001'; status='Failed'; message=$_.Exception.Message; path=$LockFile })
}

$failed = @($results | Where-Object status -eq 'Failed').Count
$blocked = @($results | Where-Object status -eq 'Blocked').Count
$status = if ($failed -gt 0) { 'Failed' } elseif ($blocked -gt 0) { 'Blocked' } else { 'Passed' }
$report = [ordered]@{
    schemaVersion = '1.0.0'
    generatedAtUtc = (Get-Date).ToUniversalTime().ToString('o')
    status = $status
    lockFile = $LockFile
    lockSha256 = if (Test-Path -LiteralPath $lockPath -PathType Leaf) { Get-ValidatorFileSha256 -Path $lockPath } else { $null }
    requirementsFile = $RequirementsFile
    requirementsSha256 = if (Test-Path -LiteralPath $requirementsPath -PathType Leaf) { Get-ValidatorFileSha256 -Path $requirementsPath } else { $null }
    results = @($results)
    failed = $failed
    blocked = $blocked
    passed = @($results | Where-Object status -eq 'Passed').Count
}

if ($OutputJson) {
    $outputFull = [System.IO.Path]::GetFullPath((Join-Path $root $OutputJson))
    $rootPrefix = $root.TrimEnd([System.IO.Path]::DirectorySeparatorChar) + [System.IO.Path]::DirectorySeparatorChar
    if (-not $outputFull.StartsWith($rootPrefix, [System.StringComparison]::Ordinal) -and $outputFull -ne $root) {
        throw 'OutputJson must remain beneath the repository root.'
    }
    New-Item -ItemType Directory -Path (Split-Path -Parent $outputFull) -Force | Out-Null
    $report | ConvertTo-Json -Depth 20 | Set-Content -LiteralPath $outputFull -Encoding utf8
}

$results | ForEach-Object { "[$($_.status)] $($_.ruleId): $($_.message)" }
if ($status -ne 'Passed') { exit 1 }
exit 0
