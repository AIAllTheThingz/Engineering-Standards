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
        [Parameter(Mandatory)][ValidateSet('Passed','Failed','Blocked','NotRun','NotApplicable')][string]$Status,
        [Parameter(Mandatory)][string]$Command,
        [Parameter(Mandatory)][string]$Summary,
        [AllowNull()][int]$ExitCode = 0,
        [AllowNull()][string]$FailureReason = $null
    )

    $now = (Get-Date).ToUniversalTime()
    $results.Add([ordered]@{
        schemaVersion = '1.1.0'
        name = $Name
        category = $Category
        status = $Status
        requiredValidation = $true
        evidenceSource = 'local-execution'
        environment = 'developer-workstation'
        command = $Command
        workingDirectory = 'examples/worker-service-project'
        startedAtUtc = $started.ToString('o')
        completedAtUtc = $now.ToString('o')
        durationSeconds = [math]::Round(($now - $started).TotalSeconds, 3)
        runtime = "PowerShell $($PSVersionTable.PSVersion)"
        toolVersion = "$($PSVersionTable.PSVersion)"
        exitCode = $ExitCode
        summary = $Summary
        warnings = @()
        failureReason = $FailureReason
        blockedReason = $null
        notApplicableRationale = $null
        manualProcedure = $null
        executionMode = [ordered]@{
            dryRun = $false
            whatIf = $false
            planOnly = $false
            applied = $true
        }
        details = $null
    })
}

$workerScript = Join-Path $projectRoot 'src/Worker.ps1'
$tokens = $null
$errors = $null
[System.Management.Automation.Language.Parser]::ParseFile($workerScript, [ref]$tokens, [ref]$errors) | Out-Null
if ($errors.Count -gt 0) {
    Add-TestResult -Name 'PowerShell parser validation' -Category 'lint' -Status Failed -Command 'Parser.ParseFile src/Worker.ps1' -Summary 'PowerShell parser reported errors in the worker example.' -ExitCode 1 -FailureReason 'Worker script did not parse successfully.'
    $results | ConvertTo-Json -Depth 20 | Set-Content -LiteralPath $evidenceFile -Encoding utf8
    exit 1
}
Add-TestResult -Name 'PowerShell parser validation' -Category 'lint' -Status Passed -Command 'Parser.ParseFile src/Worker.ps1' -Summary 'Worker example PowerShell source parsed successfully.' -ExitCode 0

. $workerScript
$job = Invoke-ExampleJob -JobId 'example'
if ($job.State -ne 'Completed' -or $job.IdempotencyKey -ne 'job:example') {
    Add-TestResult -Name 'Worker smoke test' -Category 'integration' -Status Failed -Command '. src/Worker.ps1; Invoke-ExampleJob -JobId example' -Summary 'Worker smoke test returned an unexpected job state.' -ExitCode 1 -FailureReason 'Worker did not return the expected completed job payload.'
    $results | ConvertTo-Json -Depth 20 | Set-Content -LiteralPath $evidenceFile -Encoding utf8
    exit 1
}
Add-TestResult -Name 'Worker smoke test' -Category 'integration' -Status Passed -Command '. src/Worker.ps1; Invoke-ExampleJob -JobId example' -Summary 'Worker returned a completed job with the expected idempotency key.' -ExitCode 0

$pester = Invoke-Pester -Path (Join-Path $projectRoot 'tests') -Output Detailed -PassThru
if ($pester.FailedCount -gt 0) {
    Add-TestResult -Name 'Pester test suite' -Category 'unit' -Status Failed -Command 'Invoke-Pester -Path tests -Output Detailed' -Summary 'Worker-service example Pester tests failed.' -ExitCode 1 -FailureReason "$($pester.FailedCount) worker-service tests failed."
    $results | ConvertTo-Json -Depth 20 | Set-Content -LiteralPath $evidenceFile -Encoding utf8
    exit 1
}
Add-TestResult -Name 'Pester test suite' -Category 'unit' -Status Passed -Command 'Invoke-Pester -Path tests -Output Detailed' -Summary "$($pester.PassedCount) worker-service Pester tests passed." -ExitCode 0

& pwsh -NoProfile -File (Join-Path $standardsRootPath 'actions/validate-contract/Invoke-ContractValidation.ps1') -Path $projectRoot
if ($LASTEXITCODE -ne 0) {
    Add-TestResult -Name 'Governance contract validation' -Category 'workflow' -Status Failed -Command 'Invoke-ContractValidation.ps1 -Path examples/worker-service-project' -Summary 'Worker-service example governance contract validation failed.' -ExitCode $LASTEXITCODE -FailureReason 'Contract validator returned a nonzero exit code.'
    $results | ConvertTo-Json -Depth 20 | Set-Content -LiteralPath $evidenceFile -Encoding utf8
    exit $LASTEXITCODE
}
Add-TestResult -Name 'Governance contract validation' -Category 'workflow' -Status Passed -Command 'Invoke-ContractValidation.ps1 -Path examples/worker-service-project' -Summary 'Worker-service manifest and governance configuration validated.' -ExitCode 0

New-Item -ItemType Directory -Path (Split-Path -Parent $evidenceFile) -Force | Out-Null
$results | ConvertTo-Json -Depth 20 | Set-Content -LiteralPath $evidenceFile -Encoding utf8
Write-Output "Worker-service example evidence written to $evidenceFile"
