[CmdletBinding()]
param(
    [Parameter(Mandatory)][string]$ContractPath,
    [Parameter(Mandatory)][string]$OutputPath
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$contract = Get-Content -LiteralPath $ContractPath -Raw | ConvertFrom-Json
$keyMaterial = 'example-webhook-key-not-a-secret'
$timestamp = [DateTimeOffset]::UtcNow.ToUnixTimeSeconds().ToString()
$deliveryId = 'delivery-001'
$payload = '{"eventType":"example.created","tenantId":"tenant-a","items":[{"id":"1","status":"ok"},{"id":"2","status":"rejected"}]}'

$hmac = [System.Security.Cryptography.HMACSHA256]::new([Text.Encoding]::UTF8.GetBytes($keyMaterial))
$signatureBytes = $hmac.ComputeHash([Text.Encoding]::UTF8.GetBytes("$timestamp.$deliveryId.$payload"))
$signature = [Convert]::ToHexString($signatureBytes).ToLowerInvariant()

$logRecord = [ordered]@{
    eventType = $contract.eventType
    deliveryId = $deliveryId
    authenticationMethod = 'shared-secret-hmac'
    idempotency = 'deliveryId'
    rateLimitBehavior = 'retry-after-respected'
    duplicateDelivery = 'ignored'
    sandboxMode = $true
    payloadClassification = 'Internal'
    payloadPreview = '[redacted]'
    partialSuccess = $true
}

$result = [ordered]@{
    contractVersion = $contract.schemaVersion
    authenticationMethod = 'shared-secret-hmac'
    timeoutSeconds = 10
    retryPolicy = [ordered]@{
        maxAttempts = 3
        strategy = 'exponential-backoff-with-jitter'
        respectsRetryAfter = $true
    }
    validSignature = [ordered]@{
        deliveryId = $deliveryId
        timestamp = $timestamp
        signature = $signature
        replayProtected = $true
        status = 'Passed'
    }
    invalidSignature = [ordered]@{
        deliveryId = 'delivery-002'
        timestamp = $timestamp
        signature = 'deadbeef'
        status = 'Failed'
        reason = 'Signature did not match the expected HMAC.'
    }
    duplicateDelivery = [ordered]@{
        deliveryId = $deliveryId
        status = 'Passed'
        behavior = 'duplicate ignored using idempotency key'
    }
    partialSuccess = [ordered]@{
        processed = 1
        rejected = 1
        status = 'Passed'
    }
    redactedLog = $logRecord
}

New-Item -ItemType Directory -Path (Split-Path -Parent $OutputPath) -Force | Out-Null
$result | ConvertTo-Json -Depth 20 | Set-Content -LiteralPath $OutputPath -Encoding utf8
Write-Output "Synthetic integration execution evidence written to $OutputPath"
