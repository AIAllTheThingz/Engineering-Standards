<#
.SYNOPSIS
Runs the functional validation set for the PowerShell example project.
.DESCRIPTION
Validates the module manifest, parses PowerShell files, imports the module,
runs Pester tests, optionally runs PSScriptAnalyzer when installed, validates
the governance contract from the central repository, and writes test evidence.
#>
[CmdletBinding()]
param(
    [string]$ProjectPath = (Join-Path $PSScriptRoot '..'),
    [string]$StandardsRoot = (Join-Path $PSScriptRoot '..\..\..'),
    [string]$EvidencePath = 'evidence/test-evidence.json'
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$projectRoot = (Resolve-Path -LiteralPath $ProjectPath).Path
$standardsRootPath = (Resolve-Path -LiteralPath $StandardsRoot).Path
$evidenceFile = Join-Path $projectRoot $EvidencePath
$results = [System.Collections.Generic.List[object]]::new()
$started = (Get-Date).ToUniversalTime()

function Add-TestResult {
    param(
        [Parameter(Mandatory)][string]$Name,
        [Parameter(Mandatory)][ValidateSet('unit','integration','security','build','lint','schema','workflow','documentation','manual','other')][string]$Category,
        [Parameter(Mandatory)][ValidateSet('Passed','Failed','Blocked','Skipped','NotRun')][string]$Status,
        [Parameter(Mandatory)][string]$Command,
        [Parameter(Mandatory)][string]$Summary,
        [int]$ExitCode = 0,
        [string[]]$Warnings = @(),
        [AllowNull()][object]$FailureReason = $null
    )

    $now = (Get-Date).ToUniversalTime().ToString('o')
    $results.Add([ordered]@{
        schemaVersion = '1.0.0'
        name = $Name
        category = $Category
        status = $Status
        command = $Command
        workingDirectory = 'examples/powershell-project'
        startedAtUtc = $started.ToString('o')
        completedAtUtc = $now
        durationSeconds = [math]::Max(0, [int]((Get-Date).ToUniversalTime() - $started).TotalSeconds)
        runtime = "PowerShell $($PSVersionTable.PSVersion)"
        toolVersion = 'local'
        exitCode = if ($Status -in @('NotRun','Skipped','Blocked')) { $null } else { $ExitCode }
        summary = $Summary
        warnings = @($Warnings)
        failureReason = $FailureReason
    })
}

$moduleManifest = Join-Path $projectRoot 'ExampleModule.psd1'
Test-ModuleManifest -Path $moduleManifest | Out-Null
Add-TestResult -Name 'Module manifest validation' -Category 'lint' -Status Passed -Command 'Test-ModuleManifest -Path ExampleModule.psd1' -Summary 'Module manifest parsed and required metadata is valid.'

$parseFailed = $false
foreach ($file in Get-ChildItem -LiteralPath $projectRoot -Recurse -File -Include *.ps1,*.psm1,*.psd1) {
    $tokens = $null
    $errors = $null
    [System.Management.Automation.Language.Parser]::ParseFile($file.FullName, [ref]$tokens, [ref]$errors) | Out-Null
    if ($errors.Count -gt 0) {
        $parseFailed = $true
        Write-Error "PowerShell parser errors found in $($file.FullName)."
    }
}
Add-TestResult -Name 'PowerShell parser validation' -Category 'lint' -Status Passed -Command 'Parser.ParseFile for *.ps1, *.psm1, and *.psd1' -Summary 'PowerShell parser accepted all example project PowerShell files.'
if ($parseFailed) { exit 1 }

Import-Module $moduleManifest -Force
Invoke-ExampleGreeting -Name 'Example' | Out-Null
Add-TestResult -Name 'Module import smoke test' -Category 'integration' -Status Passed -Command 'Import-Module ExampleModule.psd1; Invoke-ExampleGreeting -Name Example' -Summary 'Module imported and exported command executed successfully.'

$pesterResult = Invoke-Pester -Path (Join-Path $projectRoot 'tests') -Output Detailed -PassThru
if ($pesterResult.FailedCount -gt 0) {
    Add-TestResult -Name 'Pester test suite' -Category 'unit' -Status Failed -Command 'Invoke-Pester -Path tests -Output Detailed' -Summary 'One or more Pester tests failed.' -ExitCode 1 -FailureReason "$($pesterResult.FailedCount) Pester tests failed."
    exit 1
}
Add-TestResult -Name 'Pester test suite' -Category 'unit' -Status Passed -Command 'Invoke-Pester -Path tests -Output Detailed' -Summary "$($pesterResult.PassedCount) Pester tests passed."

$analyzer = Get-Module -ListAvailable PSScriptAnalyzer | Select-Object -First 1
if ($analyzer) {
    $settings = Join-Path $projectRoot 'PSScriptAnalyzerSettings.psd1'
    $findings = Invoke-ScriptAnalyzer -Path $projectRoot -Settings $settings -Recurse -Severity Error
    if ($findings) {
        $findings | Format-Table -AutoSize | Out-String | Write-Warning
        Add-TestResult -Name 'PSScriptAnalyzer' -Category 'lint' -Status Failed -Command 'Invoke-ScriptAnalyzer -Path . -Recurse' -Summary 'PSScriptAnalyzer returned findings.' -ExitCode 1 -FailureReason 'Static analysis findings were returned.'
        exit 1
    }
    Add-TestResult -Name 'PSScriptAnalyzer' -Category 'lint' -Status Passed -Command 'Invoke-ScriptAnalyzer -Path . -Recurse' -Summary 'PSScriptAnalyzer completed without findings.'
} else {
    Add-TestResult -Name 'PSScriptAnalyzer' -Category 'lint' -Status NotRun -Command 'Invoke-ScriptAnalyzer -Path . -Recurse' -Summary 'PSScriptAnalyzer is not installed in the local environment.' -Warnings @('Install PSScriptAnalyzer to enable local static analysis.') -FailureReason 'PSScriptAnalyzer module not installed.'
}

$contractScript = Join-Path $standardsRootPath 'actions/validate-contract/Invoke-ContractValidation.ps1'
& pwsh -NoProfile -File $contractScript -Path $projectRoot
if ($LASTEXITCODE -ne 0) {
    Add-TestResult -Name 'Governance contract validation' -Category 'integration' -Status Failed -Command 'Invoke-ContractValidation.ps1 -Path examples/powershell-project' -Summary 'Governance contract validation failed.' -ExitCode $LASTEXITCODE -FailureReason 'Contract validator returned a nonzero exit code.'
    exit $LASTEXITCODE
}
Add-TestResult -Name 'Governance contract validation' -Category 'integration' -Status Passed -Command 'Invoke-ContractValidation.ps1 -Path examples/powershell-project' -Summary 'Governance manifest, config, documentation paths, and agent standards validated.'

New-Item -ItemType Directory -Path (Split-Path -Parent $evidenceFile) -Force | Out-Null
$results | ConvertTo-Json -Depth 20 | Set-Content -LiteralPath $evidenceFile -Encoding utf8

$validationModule = Join-Path $standardsRootPath 'scripts/GovernanceValidation.psm1'
Import-Module $validationModule -Force
$evidenceRecords = @(Read-JsonFile -Path $evidenceFile)
for ($i = 0; $i -lt $evidenceRecords.Count; $i++) {
    $recordPath = Join-Path (Split-Path -Parent $evidenceFile) "test-evidence-record-$i.json"
    $evidenceRecords[$i] | ConvertTo-OrderedJson | Set-Content -LiteralPath $recordPath -Encoding utf8
    $recordResults = @(Test-GovernanceJsonDocument -Path $recordPath -Kind 'test-evidence')
    Remove-Item -LiteralPath $recordPath -Force
    if ($recordResults | Where-Object { $_.status -eq 'Failed' }) {
        $recordResults | ForEach-Object { Write-Error $_.message }
        exit 1
    }
}
Write-Output "PowerShell example evidence written to $evidenceFile"
