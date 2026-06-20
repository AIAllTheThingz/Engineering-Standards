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
Optional caller status. The script computes the effective overall status from test records and rejects contradictions.
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

function Get-OverallStatus {
    param([object[]]$TestRecords)
    if (@($TestRecords | Where-Object status -eq 'Failed').Count -gt 0) { return 'Failed' }
    if (@($TestRecords | Where-Object status -eq 'Blocked').Count -gt 0) { return 'Blocked' }
    if (@($TestRecords | Where-Object status -eq 'NotRun').Count -gt 0) { return 'NotRun' }
    if (@($TestRecords).Count -gt 0) { return 'Passed' }
    return 'NotRun'
}

$computedStatus = Get-OverallStatus -TestRecords $tests
if ($Status -ne $computedStatus) {
    if ($Status -eq 'NotRun' -and $computedStatus -ne 'NotRun') {
        $Status = $computedStatus
    }
    else {
        throw "Caller status '$Status' contradicts computed test-record status '$computedStatus'."
    }
}
$artifacts = @()
foreach ($artifact in $ArtifactPath) {
    if ($artifact -eq $OutputPath) { continue }
    $resolved = Resolve-SafePath -Root $root -ChildPath $artifact
    if (Test-Path -LiteralPath $resolved -PathType Leaf) {
        $item = Get-Item -LiteralPath $resolved
        $mediaType = if ($item.Extension -eq '.json') { 'application/json' } elseif ($item.Extension -eq '.xml') { 'application/xml' } else { 'application/octet-stream' }
        $related = switch -Regex ($artifact) {
            'yaml-syntax' { 'YAML syntax validation'; break }
            'workflow-architecture' { 'Workflow architecture validation'; break }
            'json-schemas' { 'JSON schema validation'; break }
            'markdown-links' { 'Markdown link validation'; break }
            'documentation-completeness' { 'Documentation completeness'; break }
            'contract' { 'Governance contract validation'; break }
            'forbidden-patterns' { 'Forbidden-pattern scanning'; break }
            'repository-health' { 'Repository-health validation'; break }
            'powershell-parser' { 'PowerShell parser validation'; break }
            'pester' { 'Pester repository tests'; break }
            'psscriptanalyzer' { 'PSScriptAnalyzer'; break }
            'examples' { 'Example-project validation'; break }
            'evidence-validation' { 'Completion-evidence validation'; break }
            'environment' { 'GitHub-hosted workflow execution'; break }
            'ci-test-results' { $null; break }
            default { $null }
        }
        $artifacts += [ordered]@{
            schemaVersion = '1.0.0'
            name = $item.Name
            artifactType = 'report'
            path = $artifact
            mediaType = $mediaType
            sizeBytes = $item.Length
            sha256 = (Get-FileHash -LiteralPath $resolved -Algorithm SHA256).Hash.ToLowerInvariant()
            createdAtUtc = (Get-Date).ToUniversalTime().ToString('o')
            producer = 'New-CompletionEvidence.ps1'
            retention = 'audit'
            sensitivity = 'Internal'
            relatedTest = $related
        }
    }
}
$commit = $env:GITHUB_SHA
if (-not $commit) {
    $commit = (& git -C $root rev-parse HEAD 2>$null)
    if ($LASTEXITCODE -ne 0 -or -not $commit) { $commit = 'unknown' }
}
$branch = $env:GITHUB_REF_NAME
if (-not $branch) {
    $branch = (& git -C $root rev-parse --abbrev-ref HEAD 2>$null)
    if ($LASTEXITCODE -ne 0 -or -not $branch) { $branch = 'unknown' }
}
$changedFiles = @(& git -C $root status --short 2>$null | ForEach-Object { $_.Substring(3) })
if ($changedFiles.Count -eq 0 -and $commit -ne 'unknown') {
    $changedFiles = @(& git -C $root diff-tree --no-commit-id --name-only -r $commit 2>$null)
}
if ($changedFiles.Count -eq 0) { $changedFiles = @('unknown') }
$evidence = [ordered]@{
    schemaVersion = '1.0.0'
    repository = $(if ($env:GITHUB_REPOSITORY) { $env:GITHUB_REPOSITORY } else { 'AIAllTheThingz/Engineering-Standards' })
    commitSha = $commit.Trim()
    branch = $branch.Trim()
    pullRequest = $null
    governanceVersion = $GovernanceVersion
    riskClassification = $RiskClassification
    status = $computedStatus
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
$out = Resolve-SafePath -Root $root -ChildPath $OutputPath -AllowMissingLeaf
New-Item -ItemType Directory -Path (Split-Path -Parent $out) -Force | Out-Null
$evidence | ConvertTo-OrderedJson | Set-Content -LiteralPath $out -Encoding utf8
Write-Output "Completion evidence written to $out"
