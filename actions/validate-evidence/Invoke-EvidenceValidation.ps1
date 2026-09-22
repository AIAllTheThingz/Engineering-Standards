<#
.SYNOPSIS
Validates completion evidence.
.DESCRIPTION
Checks evidence structure, status consistency, timestamp ordering, commit consistency, artifact hashes, safe paths, and test-evidence semantics.
#>
[CmdletBinding()]
param(
    [string]$Path = '.',
    [string]$EvidencePath = 'evidence/completion-result.json',
    [string]$ExpectedCommitSha,
    [string]$ExpectedRepository,
    [string]$ExpectedRefName,
    [string]$OutputJson
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
Import-Module (Join-Path $PSScriptRoot '../../scripts/GovernanceValidation.psm1') -Force

$root = (Resolve-Path -LiteralPath $Path).Path
$results = [System.Collections.Generic.List[object]]::new()

function Resolve-ExistingEvidencePathCasing {
    param([string]$RelativePath)
    $current = $root
    foreach ($segment in @($RelativePath -split '[\\/]' | Where-Object { $_ -and $_ -ne '.' })) {
        # Ask the filesystem whether this spelling exists before resolving its stored name.
        # Exact matches distinguish case-sensitive siblings; a unique alias supports insensitive volumes.
        if (-not (Test-Path -LiteralPath (Join-Path $current $segment))) {
            throw "Evidence path '$RelativePath' does not exist."
        }
        $entries = @(Get-ChildItem -LiteralPath $current -Force)
        $match = @($entries | Where-Object { $_.Name -ceq $segment })
        if ($match.Count -eq 0) { $match = @($entries | Where-Object { $_.Name -ieq $segment }) }
        if ($match.Count -ne 1) { throw "Evidence path '$RelativePath' has ambiguous filesystem casing." }
        $current = $match[0].FullName
    }
    $current
}

try {
    $full = Resolve-SafePath -Root $root -ChildPath $EvidencePath
}
catch {
    $results.Add((New-ValidationResult -Status Failed -Message $_.Exception.Message -Path $EvidencePath))
}

if ($results.Count -eq 0 -and -not (Test-Path -LiteralPath $full -PathType Leaf)) {
    $results.Add((New-ValidationResult -Status Failed -Message 'Completion evidence missing.' -Path $EvidencePath))
}

if ($results.Count -eq 0) {
    foreach ($item in @(Test-GovernanceJsonDocument -Path $full -Kind 'completion-result')) {
        if ([IO.Path]::IsPathRooted([string]$item.path) -and
            [string]$item.path -eq [string]$full) {
            $item.path = $EvidencePath.Replace('\\','/')
        }
        $results.Add($item)
    }
}

if (-not @($results | Where-Object status -eq 'Failed')) {
    $evidence = Read-JsonFile -Path $full
    $artifactRoot = 'evidence'
    $resolvedArtifactRoot = Resolve-SafePath -Root $root -ChildPath $artifactRoot -AllowMissingLeaf
    $configPath = Join-Path $root 'governance.config.json'
    if (Test-Path -LiteralPath $configPath -PathType Leaf) {
        try {
            $config = Read-JsonFile -Path $configPath
            $configuredArtifactRoot = [string]$config.evidencePath
            if ([string]::IsNullOrWhiteSpace($configuredArtifactRoot)) {
                throw 'Governance configuration evidencePath is missing.'
            }
            if ([System.IO.Path]::IsPathRooted($configuredArtifactRoot) -or $configuredArtifactRoot -match '(^|[\\/])\.\.([\\/]|$)') {
                throw 'Governance configuration evidencePath must be repository-relative and must not contain parent-directory segments.'
            }
            $resolvedArtifactRoot = Resolve-SafePath -Root $root -ChildPath $configuredArtifactRoot -AllowMissingLeaf
            $artifactRoot = [System.IO.Path]::GetRelativePath($root, $resolvedArtifactRoot).Replace('\','/')
        }
        catch {
            $results.Add((New-ValidationResult -Status Failed -Message "Unable to resolve configured evidencePath: $($_.Exception.Message)" -Path 'governance.config.json'))
        }
    }
    if (-not (Test-Path -LiteralPath $resolvedArtifactRoot -PathType Container)) {
        $results.Add((New-ValidationResult -Status Failed -Message 'evidencePath must resolve to a directory.' -Path 'governance.config.json'))
    }
    $validatedSha = if ($evidence.validatedCommitSha) { [string]$evidence.validatedCommitSha } else { [string]$evidence.commitSha }
    $evidenceSha = if ($evidence.evidenceCommitSha) { [string]$evidence.evidenceCommitSha } else { $null }
    if ($ExpectedCommitSha -and $validatedSha -ne $ExpectedCommitSha) {
        $results.Add((New-ValidationResult -Status Failed -Message 'Commit SHA mismatch.' -Path $EvidencePath))
    }
    & git -C $root rev-parse --is-inside-work-tree 2>$null | Out-Null
    $hasGitRepository = ($LASTEXITCODE -eq 0)
    if ($hasGitRepository) {
        foreach ($shaCheck in @(@{ name='validatedCommitSha'; value=$validatedSha }, @{ name='evidenceCommitSha'; value=$evidenceSha })) {
            if (-not $shaCheck.value) { continue }
            & git -C $root cat-file -e "$($shaCheck.value)^{commit}" 2>$null
            if ($LASTEXITCODE -ne 0) {
                $results.Add((New-ValidationResult -Status Failed -Message "$($shaCheck.name) does not exist in this repository." -Path $EvidencePath))
            }
        }
        if ($validatedSha -and $evidenceSha) {
            & git -C $root merge-base --is-ancestor $validatedSha $evidenceSha 2>$null
            if ($LASTEXITCODE -ne 0) {
                $results.Add((New-ValidationResult -Status Failed -Message 'validatedCommitSha must be an ancestor of or equal to evidenceCommitSha.' -Path $EvidencePath))
            }
        }
    }
    $repositoryToCheck = if ($ExpectedRepository) {
        $ExpectedRepository
    }
    elseif ($evidence.executionContext -eq 'GitHubActions') {
        $env:GITHUB_REPOSITORY
    }
    else {
        $null
    }
    if ($repositoryToCheck -and $evidence.repository -ne $repositoryToCheck) {
        $results.Add((New-ValidationResult -Status Failed -Message 'Repository mismatch.' -Path $EvidencePath))
    }
    $refToCheck = if ($ExpectedRefName) {
        $ExpectedRefName
    }
    elseif ($evidence.executionContext -eq 'GitHubActions') {
        $env:GITHUB_REF_NAME
    }
    else {
        $null
    }
    if ($refToCheck -and $evidence.branch -ne $refToCheck) {
        $results.Add((New-ValidationResult -Status Failed -Message 'Branch/ref mismatch.' -Path $EvidencePath))
    }

    $githubExecution = @($evidence.tests | Where-Object name -eq 'GitHub-hosted workflow execution' | Select-Object -First 1)
    if ($evidence.executionContext -eq 'Local') {
        if ($githubExecution.Count -eq 0) {
            $results.Add((New-ValidationResult -Status Failed -Message 'Local evidence must record GitHub-hosted workflow execution.' -Path $EvidencePath))
        }
        elseif ($githubExecution[0].status -notin @('NotRun','Passed','Failed')) {
            $results.Add((New-ValidationResult -Status Failed -Message 'Local evidence must record GitHub-hosted workflow execution as NotRun or externally verified Passed or Failed.' -Path $EvidencePath))
        }
        if ($evidence.status -eq 'Passed') {
            $results.Add((New-ValidationResult -Status Failed -Message 'Local evidence cannot be overall Passed when GitHub-hosted execution is mandatory.' -Path $EvidencePath))
        }
        if ($evidence.githubRunId -or $evidence.artifactName) {
            $results.Add((New-ValidationResult -Status Failed -Message 'Local evidence must not claim GitHub run or artifact metadata.' -Path $EvidencePath))
        }
    }
    elseif ($evidence.executionContext -eq 'GitHubActions') {
        if ($evidenceSha) {
            $results.Add((New-ValidationResult -Status Failed -Message 'GitHubActions artifact evidence must have null evidenceCommitSha.' -Path $EvidencePath))
        }
        if (-not $evidence.githubRunId -or -not $evidence.githubRunAttempt -or -not $evidence.githubWorkflow) {
            $results.Add((New-ValidationResult -Status Failed -Message 'GitHubActions evidence must include run id, run attempt, and workflow name.' -Path $EvidencePath))
        }
        if ($evidence.status -eq 'Passed' -and ($githubExecution.Count -eq 0 -or $githubExecution[0].status -ne 'Passed')) {
            $results.Add((New-ValidationResult -Status Failed -Message 'GitHubActions Passed evidence requires a passed GitHub-hosted workflow execution record.' -Path $EvidencePath))
        }
    }

    $knownTestNames = @{}
    foreach ($test in @($evidence.tests)) {
        if ($knownTestNames.ContainsKey($test.name)) {
            $results.Add((New-ValidationResult -Status Failed -Message "Duplicate test evidence name '$($test.name)'." -Path $EvidencePath))
        }
        else {
            $knownTestNames[$test.name] = $true
        }
    }

    $artifactKeys = @{}
    foreach ($artifact in @($evidence.artifacts)) {
        $artifactKey = [string]$artifact.path
        if ($artifactKeys.ContainsKey($artifactKey)) {
            $results.Add((New-ValidationResult -Status Failed -Message "Duplicate artifact record '$artifactKey'." -Path $EvidencePath))
        }
        else {
            $artifactKeys[$artifactKey] = $true
        }
        try {
            if ([System.IO.Path]::IsPathRooted([string]$artifact.path) -or [string]$artifact.path -match '(^|[\\/])\.\.([\\/]|$)') {
                throw "Artifact path '$($artifact.path)' must be repository-relative and must not traverse outside the repository."
            }
            $artifactPath = Resolve-SafePath -Root $root -ChildPath $artifact.path
            $artifactFullPath = Resolve-ExistingEvidencePathCasing -RelativePath $artifact.path
            $artifactRootFullPath = (Resolve-ExistingEvidencePathCasing -RelativePath $artifactRoot).TrimEnd([System.IO.Path]::DirectorySeparatorChar, [System.IO.Path]::AltDirectorySeparatorChar)
            $pathComparison = [StringComparison]::Ordinal
            $artifactRootBoundary = $artifactRootFullPath + [System.IO.Path]::DirectorySeparatorChar
            if (-not ($artifactFullPath.Equals($artifactRootFullPath, $pathComparison) -or $artifactFullPath.StartsWith($artifactRootBoundary, $pathComparison))) {
                throw "Artifact path '$($artifact.path)' must be under the configured evidence directory '$artifactRoot'."
            }
            if (Test-Path -LiteralPath $artifactPath -PathType Leaf) {
                $actualSize = (Get-Item -LiteralPath $artifactPath).Length
                if ([int64]$artifact.sizeBytes -ne [int64]$actualSize) {
                    $results.Add((New-ValidationResult -Status Failed -Message 'Artifact size mismatch.' -Path $artifact.path))
                }
                $actual = (Get-FileHash -LiteralPath $artifactPath -Algorithm SHA256).Hash.ToLowerInvariant()
                if ($actual -ne $artifact.sha256.ToLowerInvariant()) {
                    $results.Add((New-ValidationResult -Status Failed -Message 'Artifact hash mismatch.' -Path $artifact.path))
                }
            }
            else {
                $results.Add((New-ValidationResult -Status Failed -Message 'Artifact listed but not present for hash verification.' -Path $artifact.path))
            }
        }
        catch {
            $results.Add((New-ValidationResult -Status Failed -Message $_.Exception.Message -Path $artifact.path))
        }

        if ($artifact.relatedTest -and -not $knownTestNames.ContainsKey($artifact.relatedTest)) {
            $results.Add((New-ValidationResult -Status Failed -Message "Artifact references unknown test '$($artifact.relatedTest)'." -Path $artifact.path))
        }
    }
}

if (-not @($results | Where-Object status -eq 'Failed')) {
    $results.Add((New-ValidationResult -Status Passed -Message 'Evidence validation completed.' -Path $EvidencePath -Severity info))
}

$report = New-ValidationReport -Results @($results)
Write-ValidationReport -Report $report -OutputJson $OutputJson
if ($report.failed -gt 0) { exit 1 }
exit 0
