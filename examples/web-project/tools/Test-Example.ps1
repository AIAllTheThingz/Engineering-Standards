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
        workingDirectory = 'examples/web-project'
        startedAtUtc = $started.ToString('o')
        completedAtUtc = $now.ToString('o')
        durationSeconds = [math]::Round(($now - $started).TotalSeconds, 3)
        runtime = 'Node.js local tooling'
        toolVersion = 'local'
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

$node = Get-Command node -ErrorAction SilentlyContinue
if (-not $node) {
    Add-TestResult -Name 'Node.js availability' -Category 'build' -Status NotRun -Command 'node --version' -Summary 'Node.js is not installed in the local environment.' -ExitCode 3 -FailureReason 'Node.js is unavailable.'
    New-Item -ItemType Directory -Path (Split-Path -Parent $evidenceFile) -Force | Out-Null
    $results | ConvertTo-Json -Depth 20 | Set-Content -LiteralPath $evidenceFile -Encoding utf8
    Write-Output "Web example evidence written to $evidenceFile"
    exit 0
}

Push-Location $projectRoot
try {
    foreach ($step in @(
        @{ Name = 'Web lint validation'; Command = 'node scripts/lint.js'; Category = 'lint'; Script = 'scripts/lint.js'; Summary = 'Web example lint script completed successfully.' },
        @{ Name = 'Web unit validation'; Command = 'node scripts/test.js'; Category = 'unit'; Script = 'scripts/test.js'; Summary = 'Web example test script completed successfully.' },
        @{ Name = 'Web build validation'; Command = 'node scripts/build.js'; Category = 'build'; Script = 'scripts/build.js'; Summary = 'Web example build script completed successfully.' }
    )) {
        & node $step.Script
        if ($LASTEXITCODE -ne 0) {
            Add-TestResult -Name $step.Name -Category $step.Category -Status Failed -Command $step.Command -Summary "$($step.Name) failed." -ExitCode $LASTEXITCODE -FailureReason "Command '$($step.Command)' returned a nonzero exit code."
            New-Item -ItemType Directory -Path (Split-Path -Parent $evidenceFile) -Force | Out-Null
            $results | ConvertTo-Json -Depth 20 | Set-Content -LiteralPath $evidenceFile -Encoding utf8
            exit $LASTEXITCODE
        }
        Add-TestResult -Name $step.Name -Category $step.Category -Status Passed -Command $step.Command -Summary $step.Summary -ExitCode 0
    }
}
finally {
    Pop-Location
}

& pwsh -NoProfile -File (Join-Path $standardsRootPath 'actions/validate-contract/Invoke-ContractValidation.ps1') -Path $projectRoot
if ($LASTEXITCODE -ne 0) {
    Add-TestResult -Name 'Governance contract validation' -Category 'workflow' -Status Failed -Command 'Invoke-ContractValidation.ps1 -Path examples/web-project' -Summary 'Web example governance contract validation failed.' -ExitCode $LASTEXITCODE -FailureReason 'Contract validator returned a nonzero exit code.'
    New-Item -ItemType Directory -Path (Split-Path -Parent $evidenceFile) -Force | Out-Null
    $results | ConvertTo-Json -Depth 20 | Set-Content -LiteralPath $evidenceFile -Encoding utf8
    exit $LASTEXITCODE
}
Add-TestResult -Name 'Governance contract validation' -Category 'workflow' -Status Passed -Command 'Invoke-ContractValidation.ps1 -Path examples/web-project' -Summary 'Web example manifest and governance configuration validated.' -ExitCode 0

New-Item -ItemType Directory -Path (Split-Path -Parent $evidenceFile) -Force | Out-Null
$results | ConvertTo-Json -Depth 20 | Set-Content -LiteralPath $evidenceFile -Encoding utf8
Write-Output "Web example evidence written to $evidenceFile"
