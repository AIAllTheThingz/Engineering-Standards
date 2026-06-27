[CmdletBinding()]
param([string]$Path = 'examples/combined-script-runner-project')

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$root = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot '../../..')).Path
$example = Resolve-Path -LiteralPath (Join-Path $root $Path)
$catalog = Get-Content -LiteralPath (Join-Path $example 'catalog/approved-scripts.json') -Raw | ConvertFrom-Json
$inputSchema = Get-Content -LiteralPath (Join-Path $example 'schemas/example-report-input.schema.json') -Raw | ConvertFrom-Json
$evidencePath = Join-Path $example 'evidence/script-runner-execution.json'

foreach ($script in @($catalog.scripts)) {
    if ($script.sha256 -notmatch '^[A-Fa-f0-9]{64}$') {
        throw "Script '$($script.id)' must have a 64-character SHA-256 identity."
    }
    if ($script.entryPoint -match '(^|[\\/])\.\.([\\/]|$)') {
        throw "Script '$($script.id)' entryPoint must not use traversal."
    }
    if (-not $script.inputSchema) {
        throw "Script '$($script.id)' must declare an input schema."
    }
}
if ($inputSchema.immutableAfterSubmission -ne $true) {
    throw 'Combined script-runner input must be immutable after submission.'
}
if ($inputSchema.allowsArbitraryCommandText -ne $false) {
    throw 'Combined script-runner input must not allow arbitrary command text.'
}

& pwsh -NoProfile -File (Join-Path $root 'actions/validate-contract/Invoke-ContractValidation.ps1') -Path $example
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }

Import-Module (Join-Path $example 'src/ScriptRunner.psm1') -Force
$catalogObject = Get-RunnerCatalog -CatalogPath (Join-Path $example 'catalog/approved-scripts.json')
$job = New-RunnerJob -Catalog $catalogObject -Request @{
    requestId = 'req-001'
    tenantId = 'tenant-a'
    scriptId = 'example-report'
}
$job = Claim-RunnerJob -Job $job -WorkerId 'worker-a'
$job = Complete-RunnerJob -Job $job -ReportDirectory (Join-Path $example 'evidence/reports')

Invoke-Pester -Path (Join-Path $example 'tests') -Output Detailed | Out-Null
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }

New-Item -ItemType Directory -Path (Split-Path -Parent $evidencePath) -Force | Out-Null
[ordered]@{
    apiSurface = 'synthetic-powershell-command-surface'
    jobId = $job.jobId
    state = $job.state
    idempotencyKey = $job.idempotencyKey
    duplicateHandling = $job.duplicateHandling
    retryBehavior = 'manual-retry-with-idempotent-job-record'
    deadLetterBehavior = 'not-triggered-in-happy-path-smoke'
    reportPath = [System.IO.Path]::GetRelativePath($example, $job.reportPath).Replace('\','/')
    artifactState = $job.artifactState
} | ConvertTo-Json -Depth 20 | Set-Content -LiteralPath $evidencePath -Encoding utf8

Write-Output 'Combined script-runner example validation passed.'
