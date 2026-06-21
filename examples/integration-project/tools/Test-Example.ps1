[CmdletBinding()]
param([string]$Path = 'examples/integration-project')

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$root = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot '../../..')).Path
$example = Resolve-Path -LiteralPath (Join-Path $root $Path)
$contractPath = Join-Path $example 'contracts/synthetic-webhook.schema.json'
$contract = Get-Content -LiteralPath $contractPath -Raw | ConvertFrom-Json

foreach ($header in @('X-Example-Signature','X-Example-Timestamp','X-Example-Delivery-Id')) {
    if (@($contract.requiredHeaders) -notcontains $header) {
        throw "Synthetic webhook contract is missing required header '$header'."
    }
}
if ($contract.replayWindowSeconds -gt 300) {
    throw 'Synthetic webhook replay window exceeds the example policy.'
}
if ($contract.piiAllowed -ne $false) {
    throw 'Synthetic integration example must not allow PII.'
}

& pwsh -NoProfile -File (Join-Path $root 'actions/validate-contract/Invoke-ContractValidation.ps1') -Path $example
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }

Write-Output 'Integration example validation passed.'
