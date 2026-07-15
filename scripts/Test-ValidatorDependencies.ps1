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
                if ($workflowText -notmatch 'Install-ValidatorDependencies\.ps1') {
                    $results.Add([ordered]@{ ruleId='DEP018'; status='Failed'; message='Workflow does not use the shared hash-verifying dependency installer.'; path=$expectation.Path })
                }
            }
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
