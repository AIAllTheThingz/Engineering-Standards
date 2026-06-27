[CmdletBinding()]
param([string]$Path='.')
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
$root = (Resolve-Path -LiteralPath $Path).Path
$evidencePath = Join-Path $root 'evidence/test-evidence.json'
$migrations = Get-ChildItem -LiteralPath (Join-Path $root 'migrations') -Filter '*.sql'
if (-not $migrations) { throw 'No migrations found.' }
foreach ($migration in $migrations) {
    $content = Get-Content -LiteralPath $migration.FullName -Raw
    if ($content -match '(?i)\bDROP\s+TABLE\b') { throw "Destructive statement found in $($migration.Name)." }
}
New-Item -ItemType Directory -Path (Split-Path -Parent $evidencePath) -Force | Out-Null
$record = [ordered]@{
    schemaVersion = '1.1.0'
    name = 'Database migration validation'
    category = 'schema'
    status = 'Passed'
    requiredValidation = $true
    evidenceSource = 'local-execution'
    environment = 'developer-workstation'
    command = 'pwsh -NoProfile -File examples/database-project/tools/Test-Migrations.ps1 -Path examples/database-project'
    workingDirectory = 'examples/database-project'
    startedAtUtc = (Get-Date).ToUniversalTime().ToString('o')
    completedAtUtc = (Get-Date).ToUniversalTime().ToString('o')
    durationSeconds = 0
    runtime = "PowerShell $($PSVersionTable.PSVersion)"
    toolVersion = "$($PSVersionTable.PSVersion)"
    exitCode = 0
    summary = 'Database example migrations passed non-mutating safety validation.'
    warnings = @()
    failureReason = $null
    blockedReason = $null
    notApplicableRationale = $null
    manualProcedure = $null
    executionMode = [ordered]@{
        dryRun = $false
        whatIf = $false
        planOnly = $true
        applied = $false
    }
    details = [ordered]@{
        migrationCount = @($migrations).Count
        destructiveStatementsDetected = $false
    }
}
@($record) | ConvertTo-Json -Depth 20 | Set-Content -LiteralPath $evidencePath -Encoding utf8
Write-Output 'Migration validation passed.'
