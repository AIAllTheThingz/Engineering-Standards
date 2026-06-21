[CmdletBinding()]
param([string]$Path = 'examples/combined-script-runner-project')

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$root = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot '../../..')).Path
$example = Resolve-Path -LiteralPath (Join-Path $root $Path)
$catalog = Get-Content -LiteralPath (Join-Path $example 'catalog/approved-scripts.json') -Raw | ConvertFrom-Json
$inputSchema = Get-Content -LiteralPath (Join-Path $example 'schemas/example-report-input.schema.json') -Raw | ConvertFrom-Json

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

Write-Output 'Combined script-runner example validation passed.'
