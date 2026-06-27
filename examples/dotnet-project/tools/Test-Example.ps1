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
        workingDirectory = 'examples/dotnet-project'
        startedAtUtc = $started.ToString('o')
        completedAtUtc = $now.ToString('o')
        durationSeconds = [math]::Round(($now - $started).TotalSeconds, 3)
        runtime = '.NET local tooling'
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

$dotnet = Get-Command dotnet -ErrorAction SilentlyContinue
if (-not $dotnet) {
    Add-TestResult -Name '.NET SDK availability' -Category 'build' -Status NotRun -Command 'dotnet --version' -Summary '.NET SDK is not installed in the local environment.' -ExitCode 3 -FailureReason '.NET SDK is unavailable.'
    New-Item -ItemType Directory -Path (Split-Path -Parent $evidenceFile) -Force | Out-Null
    $results | ConvertTo-Json -Depth 20 | Set-Content -LiteralPath $evidenceFile -Encoding utf8
    Write-Output "Dotnet example evidence written to $evidenceFile"
    exit 0
}

Push-Location $projectRoot
try {
    & dotnet test tests/Example.Service.Tests.csproj -c Release --nologo
    if ($LASTEXITCODE -ne 0) {
        Add-TestResult -Name '.NET test suite' -Category 'unit' -Status Failed -Command 'dotnet test tests/Example.Service.Tests.csproj -c Release --nologo' -Summary '.NET example tests failed.' -ExitCode $LASTEXITCODE -FailureReason 'dotnet test returned a nonzero exit code.'
        New-Item -ItemType Directory -Path (Split-Path -Parent $evidenceFile) -Force | Out-Null
        $results | ConvertTo-Json -Depth 20 | Set-Content -LiteralPath $evidenceFile -Encoding utf8
        exit $LASTEXITCODE
    }
    Add-TestResult -Name '.NET test suite' -Category 'unit' -Status Passed -Command 'dotnet test tests/Example.Service.Tests.csproj -c Release --nologo' -Summary '.NET example tests passed.' -ExitCode 0

    & dotnet build src/Example.csproj -c Release --nologo --no-restore
    if ($LASTEXITCODE -ne 0) {
        Add-TestResult -Name '.NET build validation' -Category 'build' -Status Failed -Command 'dotnet build src/Example.csproj -c Release --nologo --no-restore' -Summary '.NET example build failed.' -ExitCode $LASTEXITCODE -FailureReason 'dotnet build returned a nonzero exit code.'
        New-Item -ItemType Directory -Path (Split-Path -Parent $evidenceFile) -Force | Out-Null
        $results | ConvertTo-Json -Depth 20 | Set-Content -LiteralPath $evidenceFile -Encoding utf8
        exit $LASTEXITCODE
    }
    Add-TestResult -Name '.NET build validation' -Category 'build' -Status Passed -Command 'dotnet build src/Example.csproj -c Release --nologo --no-restore' -Summary '.NET example build completed successfully.' -ExitCode 0
}
finally {
    Pop-Location
}

& pwsh -NoProfile -File (Join-Path $standardsRootPath 'actions/validate-contract/Invoke-ContractValidation.ps1') -Path $projectRoot
if ($LASTEXITCODE -ne 0) {
    Add-TestResult -Name 'Governance contract validation' -Category 'workflow' -Status Failed -Command 'Invoke-ContractValidation.ps1 -Path examples/dotnet-project' -Summary '.NET example governance contract validation failed.' -ExitCode $LASTEXITCODE -FailureReason 'Contract validator returned a nonzero exit code.'
    New-Item -ItemType Directory -Path (Split-Path -Parent $evidenceFile) -Force | Out-Null
    $results | ConvertTo-Json -Depth 20 | Set-Content -LiteralPath $evidenceFile -Encoding utf8
    exit $LASTEXITCODE
}
Add-TestResult -Name 'Governance contract validation' -Category 'workflow' -Status Passed -Command 'Invoke-ContractValidation.ps1 -Path examples/dotnet-project' -Summary '.NET example manifest and governance configuration validated.' -ExitCode 0

New-Item -ItemType Directory -Path (Split-Path -Parent $evidenceFile) -Force | Out-Null
$results | ConvertTo-Json -Depth 20 | Set-Content -LiteralPath $evidenceFile -Encoding utf8
Write-Output "Dotnet example evidence written to $evidenceFile"
