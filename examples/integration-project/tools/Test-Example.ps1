[CmdletBinding()]
param([string]$Path = 'examples/integration-project')

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$root = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot '../../..')).Path
$example = Resolve-Path -LiteralPath (Join-Path $root $Path)
$contractPath = Join-Path $example 'contracts/synthetic-webhook.schema.json'
$contract = Get-Content -LiteralPath $contractPath -Raw | ConvertFrom-Json
$evidencePath = Join-Path $example 'evidence/integration-execution.json'

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

& pwsh -NoProfile -File (Join-Path $example 'tools/Invoke-SyntheticWebhook.ps1') -ContractPath $contractPath -OutputPath $evidencePath
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }

$evidence = Get-Content -LiteralPath $evidencePath -Raw | ConvertFrom-Json -Depth 20
if ($evidence.validSignature.status -ne 'Passed') {
    throw 'Synthetic integration example must pass valid signature verification.'
}
if ($evidence.invalidSignature.status -ne 'Failed') {
    throw 'Synthetic integration example must prove invalid signature failure.'
}
if ($evidence.duplicateDelivery.behavior -notmatch 'duplicate ignored') {
    throw 'Synthetic integration example must document duplicate delivery handling.'
}
if ($evidence.redactedLog.payloadPreview -ne '[redacted]') {
    throw 'Synthetic integration example must redact payload previews.'
}

Write-Output 'Integration example validation passed.'
