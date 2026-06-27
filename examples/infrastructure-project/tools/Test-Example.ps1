[CmdletBinding()]
param([string]$Path = 'examples/infrastructure-project')

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$root = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot '../../..')).Path
$example = Resolve-Path -LiteralPath (Join-Path $root $Path)
$planPath = Join-Path $example 'plans/example-plan.json'
$plan = Get-Content -LiteralPath $planPath -Raw | ConvertFrom-Json
$evidencePath = Join-Path $example 'evidence/plan-evidence.json'

if ($plan.mutation -ne $false) {
    throw 'Infrastructure example plan must remain non-mutating.'
}
if ($plan.environment -ne 'local') {
    throw 'Infrastructure example must target only the local synthetic environment.'
}
if (@($plan.destructiveChanges).Count -ne 0) {
    throw 'Infrastructure example must not include destructive changes.'
}
if (-not $plan.toolVersion -or -not $plan.planHash) {
    throw 'Infrastructure example plan must declare toolVersion and planHash.'
}

& pwsh -NoProfile -File (Join-Path $root 'actions/validate-contract/Invoke-ContractValidation.ps1') -Path $example
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }

New-Item -ItemType Directory -Path (Split-Path -Parent $evidencePath) -Force | Out-Null
[ordered]@{
    planId = $plan.planId
    planHash = $plan.planHash
    tool = $plan.tool
    toolVersion = $plan.toolVersion
    policyResult = 'Passed'
    applyStatus = 'NotRun'
    applyReason = 'Synthetic infrastructure example does not mutate any target environment.'
    rollback = $plan.rollback
} | ConvertTo-Json -Depth 20 | Set-Content -LiteralPath $evidencePath -Encoding utf8

Write-Output 'Infrastructure example validation passed.'
