[CmdletBinding()]
param([string]$Path = 'examples/infrastructure-project')

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$root = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot '../../..')).Path
$example = Resolve-Path -LiteralPath (Join-Path $root $Path)
$planPath = Join-Path $example 'plans/example-plan.json'
$plan = Get-Content -LiteralPath $planPath -Raw | ConvertFrom-Json

if ($plan.mutation -ne $false) {
    throw 'Infrastructure example plan must remain non-mutating.'
}
if ($plan.environment -ne 'local') {
    throw 'Infrastructure example must target only the local synthetic environment.'
}
if (@($plan.destructiveChanges).Count -ne 0) {
    throw 'Infrastructure example must not include destructive changes.'
}

& pwsh -NoProfile -File (Join-Path $root 'actions/validate-contract/Invoke-ContractValidation.ps1') -Path $example
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }

Write-Output 'Infrastructure example validation passed.'
