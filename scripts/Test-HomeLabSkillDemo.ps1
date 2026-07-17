<#
.SYNOPSIS
Runs deterministic validation for an isolated home-lab skill example.
.DESCRIPTION
Parses every committed PowerShell script and module before execution, validates
one isolated skill and its synthetic prompt corpus, runs the reviewed example
Pester tests, and checks the downstream governance contract. A demo test may
execute its committed synthetic module under test. The runner makes no model
call or secret request; repository policy and reviewed tests constrain writes
to the example or test-managed temporary storage.
.PARAMETER ProjectPath
Repository-relative or absolute path to one isolated project beneath examples.
.PARAMETER SkillName
Kebab-case name of the single skill expected in the isolated project.
.EXAMPLE
pwsh -NoProfile -File scripts/Test-HomeLabSkillDemo.ps1 -ProjectPath examples/build-pester-tests-home-lab -SkillName build-pester-tests
.INPUTS
None.
.OUTPUTS
System.String. Writes a concise deterministic-validation summary.
.NOTES
Requires PowerShell 7.2 or later, Pester 5.7.1 or later, Python 3, and PyYAML.
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
$pathComparison = if ($IsWindows) { [StringComparison]::OrdinalIgnoreCase } else { [StringComparison]::Ordinal }
if (-not $projectRoot.StartsWith($projectBoundary, $pathComparison)) {
    throw 'Home-lab project path must remain beneath the repository examples directory.'
}
$relativeProjectPath = [IO.Path]::GetRelativePath($examplesRoot, $projectRoot)
$currentPath = $examplesRoot
foreach ($segment in @($relativeProjectPath -split '[\\/]' | Where-Object { $_ -and $_ -ne '.' })) {
    $currentPath = Join-Path $currentPath $segment
    $pathItem = Get-Item -LiteralPath $currentPath -Force
    if ($pathItem.LinkType -or (($pathItem.Attributes -band [IO.FileAttributes]::ReparsePoint) -ne 0)) {
        throw "Home-lab project path must not traverse a symbolic link, junction, or other reparse point: '$currentPath'."
    }
}

$python = Get-Command python -CommandType Application -ErrorAction SilentlyContinue | Select-Object -First 1
if ($null -eq $python) {
    throw 'Python 3 is required to validate the isolated skill metadata.'
}
& $python.Source -c 'import yaml' 2>$null
if ($LASTEXITCODE -ne 0) {
    throw 'PyYAML is required to validate the isolated skill metadata.'
}

$projectItems = @(Get-ChildItem -LiteralPath $projectRoot -Recurse -Force)
foreach ($item in $projectItems) {
    if ($item.LinkType -or (($item.Attributes -band [IO.FileAttributes]::ReparsePoint) -ne 0)) {
        throw "Home-lab content must not contain links or reparse points: '$([IO.Path]::GetRelativePath($projectRoot, $item.FullName))'."
    }
}

foreach ($file in $projectItems | Where-Object { -not $_.PSIsContainer -and $_.Extension -in @('.ps1', '.psd1', '.psm1') }) {
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
