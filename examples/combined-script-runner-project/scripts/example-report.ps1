[CmdletBinding()]
param(
    [Parameter(Mandatory)][string]$InputPath,
    [Parameter(Mandatory)][string]$OutputPath
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$payload = Get-Content -LiteralPath $InputPath -Raw | ConvertFrom-Json -Depth 10
$report = [ordered]@{
    requestId = $payload.requestId
    tenantId = $payload.tenantId
    requestedBy = $payload.requestedBy
    generatedAtUtc = (Get-Date).ToUniversalTime().ToString('o')
    rows = @(
        [ordered]@{ item = 'synthetic-row'; value = 1 }
    )
}

New-Item -ItemType Directory -Path (Split-Path -Parent $OutputPath) -Force | Out-Null
$report | ConvertTo-Json -Depth 20 | Set-Content -LiteralPath $OutputPath -Encoding utf8
