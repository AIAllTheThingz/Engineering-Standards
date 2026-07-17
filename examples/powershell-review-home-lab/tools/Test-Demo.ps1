<#
.SYNOPSIS
Runs deterministic validation for the PowerShell review home-lab demo.
.DESCRIPTION
Parses PowerShell without executing the intentionally unsafe sample, validates
the isolated skill package and synthetic prompt corpus, runs Pester, and checks
the downstream governance contract. No model, secret, network, or production
access is used by this script.
#>
[CmdletBinding()]
param(
    [string]$ProjectPath = (Join-Path $PSScriptRoot '..'),
    [string]$StandardsRoot = (Join-Path $PSScriptRoot '..\..\..')
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$projectRoot = (Resolve-Path -LiteralPath $ProjectPath).Path
$standardsRootPath = (Resolve-Path -LiteralPath $StandardsRoot).Path

foreach ($file in Get-ChildItem -LiteralPath $projectRoot -Recurse -File -Include *.ps1,*.psd1) {
    $tokens = $null
    $errors = $null
    [System.Management.Automation.Language.Parser]::ParseFile($file.FullName, [ref]$tokens, [ref]$errors) | Out-Null
    if ($errors.Count -gt 0) {
        throw "PowerShell parser errors found in '$([IO.Path]::GetRelativePath($projectRoot, $file.FullName))'."
    }
}

$skillModule = Join-Path $standardsRootPath 'scripts/CodexSkillsValidation.psm1'
Import-Module $skillModule -Force
$skillReport = Invoke-CodexSkillValidation -Path $projectRoot -SkipPromptBehavior
if ($skillReport.deterministicStatus -ne 'Passed' -or @($skillReport.skillsDiscovered) -notcontains 'powershell-review') {
    throw 'The isolated demo skill failed deterministic validation.'
}
$promptResults = @(Test-PromptBehaviorCorpus -RepositoryRoot $projectRoot -SkillNames @('powershell-review'))
if (@($promptResults | Where-Object status -eq 'Failed').Count -gt 0) {
    throw 'The synthetic prompt-behavior corpus failed deterministic validation.'
}
$modelResults = @($promptResults | Where-Object ruleId -eq 'SKL018')
if ($modelResults.Count -ne 9 -or @($modelResults | Where-Object status -ne 'NotRun').Count -gt 0) {
    throw 'The demo must report all live model behavior as NotRun.'
}

$pesterResult = Invoke-Pester -Path (Join-Path $projectRoot 'tests') -Output Detailed -PassThru
if ($pesterResult.FailedCount -gt 0 -or $pesterResult.NotRunCount -gt 0) {
    throw "Demo Pester result was '$($pesterResult.Result)' with $($pesterResult.FailedCount) failed and $($pesterResult.NotRunCount) NotRun tests."
}

$contractScript = Join-Path $standardsRootPath 'actions/validate-contract/Invoke-ContractValidation.ps1'
& pwsh -NoProfile -File $contractScript -Path $projectRoot
if ($LASTEXITCODE -ne 0) {
    throw "Demo governance contract validation failed with exit code $LASTEXITCODE."
}

Write-Output "PowerShell review home-lab demo validation passed: $($pesterResult.PassedCount) Pester tests; live model behavior NotRun by design."
