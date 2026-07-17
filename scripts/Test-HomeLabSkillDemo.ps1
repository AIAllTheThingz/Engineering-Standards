<#
.SYNOPSIS
Runs deterministic validation for an isolated home-lab skill example.
.DESCRIPTION
Parses PowerShell without executing copied scenario content, validates one
isolated skill and its synthetic prompt corpus, runs the example Pester tests,
and checks the downstream governance contract. The runner makes no model call,
uses no secret, and performs no production or external write operation.
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory)]
    [string]$ProjectPath,

    [Parameter(Mandatory)]
    [ValidatePattern('^[a-z0-9]+(?:-[a-z0-9]+)*$')]
    [string]$SkillName
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$standardsRoot = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot '..')).Path
$projectRoot = (Resolve-Path -LiteralPath $ProjectPath).Path
$examplesRoot = (Resolve-Path -LiteralPath (Join-Path $standardsRoot 'examples')).Path
$projectBoundary = $examplesRoot.TrimEnd([IO.Path]::DirectorySeparatorChar, [IO.Path]::AltDirectorySeparatorChar) + [IO.Path]::DirectorySeparatorChar
if (-not $projectRoot.StartsWith($projectBoundary, [StringComparison]::Ordinal)) {
    throw 'Home-lab project path must remain beneath the repository examples directory.'
}

foreach ($file in Get-ChildItem -LiteralPath $projectRoot -Recurse -File -Include *.ps1,*.psd1) {
    $tokens = $null
    $errors = $null
    [System.Management.Automation.Language.Parser]::ParseFile($file.FullName, [ref]$tokens, [ref]$errors) | Out-Null
    if ($errors.Count -gt 0) {
        throw "PowerShell parser errors found in '$([IO.Path]::GetRelativePath($projectRoot, $file.FullName))'."
    }
}

Import-Module (Join-Path $standardsRoot 'scripts/CodexSkillsValidation.psm1') -Force
$skillReport = Invoke-CodexSkillValidation -Path $projectRoot -SkipPromptBehavior
if ($skillReport.deterministicStatus -ne 'Passed' -or @($skillReport.skillsDiscovered) -notcontains $SkillName) {
    throw "The isolated '$SkillName' demo skill failed deterministic validation."
}

$promptResults = @(Test-PromptBehaviorCorpus -RepositoryRoot $projectRoot -SkillNames @($SkillName))
if (@($promptResults | Where-Object status -eq 'Failed').Count -gt 0) {
    throw "The '$SkillName' synthetic prompt-behavior corpus failed deterministic validation."
}
$modelResults = @($promptResults | Where-Object ruleId -eq 'SKL018')
if ($modelResults.Count -ne 9 -or @($modelResults | Where-Object status -ne 'NotRun').Count -gt 0) {
    throw "The '$SkillName' demo must report all live model behavior as NotRun."
}

$pesterResult = Invoke-Pester -Path (Join-Path $projectRoot 'tests') -Output Detailed -PassThru
if ($pesterResult.FailedCount -gt 0 -or $pesterResult.NotRunCount -gt 0) {
    throw "Home-lab Pester result was '$($pesterResult.Result)' with $($pesterResult.FailedCount) failed and $($pesterResult.NotRunCount) NotRun tests."
}

& pwsh -NoProfile -File (Join-Path $standardsRoot 'actions/validate-contract/Invoke-ContractValidation.ps1') -Path $projectRoot
if ($LASTEXITCODE -ne 0) {
    throw "Home-lab governance contract validation failed with exit code $LASTEXITCODE."
}

Write-Output "$SkillName home-lab validation passed: $($pesterResult.PassedCount) Pester tests; live model behavior NotRun by design."
