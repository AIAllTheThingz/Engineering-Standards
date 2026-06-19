<#
.SYNOPSIS
Generates completion evidence.
.DESCRIPTION
Creates a completion-result JSON document from supplied test records, commands, artifacts, warnings, and repository metadata.
.PARAMETER RepositoryPath
Repository root.
.PARAMETER OutputPath
Output evidence path relative to repository.
.PARAMETER GovernanceVersion
Governance version used for validation.
.PARAMETER RiskClassification
Risk classification.
.PARAMETER Status
Overall status.
.PARAMETER Summary
Summary of work.
.PARAMETER TestResultPath
Optional JSON array of test evidence records.
.PARAMETER ArtifactPath
Artifacts to hash and include.
.PARAMETER CommandsExecuted
Exact commands that ran.
.PARAMETER CommandsNotExecuted
Commands not run and reasons.
.EXAMPLE
pwsh -File scripts/New-CompletionEvidence.ps1 -OutputPath evidence/completion-result.json -Summary 'Validation completed'
.OUTPUTS
Writes JSON evidence.
.NOTES
The script refuses `Passed` when supplied tests contain Failed, NotRun, or Blocked.
#>
[CmdletBinding()]
param(
    [string]$RepositoryPath='.',
    [Parameter(Mandatory)][string]$OutputPath,
    [string]$GovernanceVersion='1.0.0',
    [ValidateSet('Low','Moderate','High','Critical')][string]$RiskClassification='High',
    [ValidateSet('Passed','Failed','NotRun','NotApplicable','Blocked')][string]$Status='NotRun',
    [Parameter(Mandatory)][string]$Summary,
    [string]$TestResultPath,
    [string[]]$ArtifactPath=@(),
    [string[]]$CommandsExecuted=@(),
    [string[]]$CommandsNotExecuted=@(),
    [string[]]$Warnings=@(),
    [string[]]$KnownLimitations=@(),
    [string[]]$RemainingRisks=@(),
    [string[]]$Exceptions=@()
)
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
Import-Module (Join-Path $PSScriptRoot 'GovernanceValidation.psm1') -Force
$root = (Resolve-Path -LiteralPath $RepositoryPath).Path
$tests = @()
if ($TestResultPath) { $tests = @(Read-JsonFile -Path (Resolve-SafePath -Root $root -ChildPath $TestResultPath)) }
if ($Status -eq 'Passed') {
    foreach ($test in $tests) {
        if ($test.status -in @('Failed','NotRun','Blocked')) { throw "Cannot emit Passed because test '$($test.name)' is '$($test.status)'." }
    }
}
$artifacts = @()
foreach ($artifact in $ArtifactPath) {
    $resolved = Resolve-SafePath -Root $root -ChildPath $artifact
    if (Test-Path -LiteralPath $resolved -PathType Leaf) {
        $item = Get-Item -LiteralPath $resolved
        $artifacts += [ordered]@{
            schemaVersion = '1.0.0'
            name = $item.Name
            artifactType = 'report'
            path = $artifact
            mediaType = 'application/octet-stream'
            sizeBytes = $item.Length
            sha256 = (Get-FileHash -LiteralPath $resolved -Algorithm SHA256).Hash.ToLowerInvariant()
            createdAtUtc = (Get-Date).ToUniversalTime().ToString('o')
            producer = 'New-CompletionEvidence.ps1'
            retention = 'audit'
            sensitivity = 'Internal'
            relatedTest = $null
        }
    }
}
$commit = (& git -C $root rev-parse HEAD 2>$null)
if ($LASTEXITCODE -ne 0 -or -not $commit) { $commit = 'unknown' }
$branch = (& git -C $root rev-parse --abbrev-ref HEAD 2>$null)
if ($LASTEXITCODE -ne 0 -or -not $branch) { $branch = 'unknown' }
$changedFiles = @(& git -C $root status --short 2>$null | ForEach-Object { $_.Substring(3) })
if ($changedFiles.Count -eq 0 -and $commit -ne 'unknown') {
    $changedFiles = @(& git -C $root diff-tree --no-commit-id --name-only -r $commit 2>$null)
}
if ($changedFiles.Count -eq 0) { $changedFiles = @('unknown') }
$evidence = [ordered]@{
    schemaVersion = '1.0.0'
    repository = 'AIAllTheThingz/Engineering-Standards'
    commitSha = $commit.Trim()
    branch = $branch.Trim()
    pullRequest = $null
    governanceVersion = $GovernanceVersion
    riskClassification = $RiskClassification
    status = $Status
    startedAtUtc = (Get-Date).ToUniversalTime().ToString('o')
    completedAtUtc = (Get-Date).ToUniversalTime().ToString('o')
    summary = $Summary
    changedFiles = @($changedFiles)
    commandsExecuted = @($CommandsExecuted)
    commandsNotExecuted = @($CommandsNotExecuted)
    tests = @($tests)
    artifacts = @($artifacts)
    warnings = @($Warnings)
    knownLimitations = @($KnownLimitations)
    remainingRisks = @($RemainingRisks)
    exceptions = @($Exceptions)
    approvals = @()
}
$out = Resolve-SafePath -Root $root -ChildPath $OutputPath
New-Item -ItemType Directory -Path (Split-Path -Parent $out) -Force | Out-Null
$evidence | ConvertTo-OrderedJson | Set-Content -LiteralPath $out -Encoding utf8
Write-Output "Completion evidence written to $out"
