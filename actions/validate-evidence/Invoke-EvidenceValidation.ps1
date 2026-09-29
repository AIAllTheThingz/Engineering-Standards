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

function Test-CompletionReceiptPayloadPath {
    param([Parameter(Mandatory)][string]$RelativePath)

    $normalized = $RelativePath.Replace('\','/')
    return (
        $normalized.StartsWith('examples/python-project/evidence/', [StringComparison]::Ordinal) -or
        $normalized.StartsWith('examples/bash-project/evidence/', [StringComparison]::Ordinal)
    )
}

function Get-RepositoryContentFingerprint {
    param(
        [Parameter(Mandatory)][string]$RepositoryPath,
        [Parameter(Mandatory)][string]$CommitReference
    )

    $gitRootOutput = @(& git -C $RepositoryPath rev-parse --show-toplevel 2>$null)
    if ($LASTEXITCODE -ne 0 -or -not $gitRootOutput) {
        throw 'Could not resolve the Git root for completion-evidence content identity.'
    }
    $gitRoot = ($gitRootOutput -join '').Trim()
    $commitOutput = @(& git -C $gitRoot rev-parse --verify "$CommitReference^{commit}" 2>$null)
    if ($LASTEXITCODE -ne 0 -or -not $commitOutput) {
        throw "Could not resolve commit '$CommitReference' for completion-evidence content identity."
    }
    $commitSha = ($commitOutput -join '').Trim()
    if ($commitSha -notmatch '^[A-Fa-f0-9]{40,64}$') {
        throw "Commit '$CommitReference' did not resolve to a Git object identifier."
    }
    $treeOutput = @(& git -C $gitRoot ls-tree -r --full-tree -z $commitSha 2>$null)
    if ($LASTEXITCODE -ne 0) {
        throw "Could not enumerate commit '$commitSha' for completion-evidence content identity."
    }
    $treeEntries = (($treeOutput -join "`n") -split "`0")
    $records = [System.Collections.Generic.List[string]]::new()
    foreach ($entry in $treeEntries) {
        if ([string]::IsNullOrEmpty([string]$entry)) { continue }
        $match = [regex]::Match(
            [string]$entry,
            '^(?<mode>[0-7]{6}) (?<type>blob|commit) (?<object>[A-Fa-f0-9]{40}|[A-Fa-f0-9]{64})\t(?<path>.+)$'
        )
        if (-not $match.Success) {
            throw "Commit '$commitSha' contains an unsupported tree entry."
        }
        $relativePath = $match.Groups['path'].Value
        if (
            [string]::IsNullOrWhiteSpace($relativePath) -or
            $relativePath.StartsWith('"', [StringComparison]::Ordinal) -or
            $relativePath -match '(^|/)\.\.(/|$)|^(?:/|[A-Za-z]:)|[\x00-\x1F]'
        ) {
            throw "Commit '$commitSha' contains an unsafe tree path."
        }
        if (Test-CompletionReceiptPayloadPath -RelativePath $relativePath) { continue }
        $records.Add((
            '{0}`0{1}`0{2}`0{3}' -f
            $match.Groups['mode'].Value,
            $match.Groups['type'].Value,
            $match.Groups['object'].Value.ToLowerInvariant(),
            $relativePath
        ))
    }
    $canonicalRecords = $records.ToArray()
    [Array]::Sort($canonicalRecords, [StringComparer]::Ordinal)
    $payload = "completion-evidence-content-v1`n$($canonicalRecords -join "`n")`n"
    return [Convert]::ToHexString(
        [System.Security.Cryptography.SHA256]::HashData([System.Text.Encoding]::UTF8.GetBytes($payload))
    ).ToLowerInvariant()
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
    $validatedTag = $null
    if ($evidence -is [System.Collections.IDictionary]) {
        if ($evidence.Contains('validatedCommitTag') -and $evidence['validatedCommitTag']) {
            $validatedTag = [string]$evidence['validatedCommitTag']
        }
    }
    else {
        $validatedTagProperty = $evidence.PSObject.Properties['validatedCommitTag']
        if ($validatedTagProperty -and $validatedTagProperty.Value) {
            $validatedTag = [string]$validatedTagProperty.Value
        }
    }
    $validatedContentSha256 = $null
    if ($evidence -is [System.Collections.IDictionary]) {
        if ($evidence.Contains('validatedContentSha256') -and $evidence['validatedContentSha256']) {
            $validatedContentSha256 = [string]$evidence['validatedContentSha256']
        }
    }
    else {
        $validatedContentProperty = $evidence.PSObject.Properties['validatedContentSha256']
        if ($validatedContentProperty -and $validatedContentProperty.Value) {
            $validatedContentSha256 = [string]$validatedContentProperty.Value
        }
    }
    $evidenceSha = if ($evidence.evidenceCommitSha) { [string]$evidence.evidenceCommitSha } else { $null }
    if ($ExpectedCommitSha -and $validatedSha -ne $ExpectedCommitSha) {
        $results.Add((New-ValidationResult -Status Failed -Message 'Commit SHA mismatch.' -Path $EvidencePath))
    }
    & git -C $root rev-parse --is-inside-work-tree 2>$null | Out-Null
    $hasGitRepository = ($LASTEXITCODE -eq 0)
    if ($hasGitRepository) {
        $validatedCommitExists = $false
        if ($validatedSha) {
            & git -C $root cat-file -e "$validatedSha^{commit}" 2>$null
            $validatedCommitExists = ($LASTEXITCODE -eq 0)
        }
        $evidenceCommitExists = $false
        if ($evidenceSha) {
            & git -C $root cat-file -e "$evidenceSha^{commit}" 2>$null
            $evidenceCommitExists = ($LASTEXITCODE -eq 0)
            if (-not $evidenceCommitExists) {
                $results.Add((New-ValidationResult -Status Failed -Message 'evidenceCommitSha does not exist in this repository.' -Path $EvidencePath))
            }
        }
        if (-not $validatedCommitExists) {
            if ($evidence.executionContext -eq 'Local' -and $validatedContentSha256) {
                try {
                    $workingTreeChanges = @(& git -C $root status --porcelain=v1 --untracked-files=all 2>$null)
                    if ($LASTEXITCODE -ne 0) {
                        throw 'Could not inspect the working tree for squash-safe Local content validation.'
                    }
                    if ($workingTreeChanges.Count -gt 0) {
                        throw 'squash-safe Local content validation requires a clean working tree.'
                    }
                    $currentContentSha256 = Get-RepositoryContentFingerprint -RepositoryPath $root -CommitReference 'HEAD'
                    if ($currentContentSha256 -ine $validatedContentSha256) {
                        throw 'validatedContentSha256 does not match the current repository content.'
                    }
                }
                catch {
                    $results.Add((New-ValidationResult -Status Failed -Message $_.Exception.Message -Path $EvidencePath))
                }
            }
            else {
                $results.Add((New-ValidationResult -Status Failed -Message 'validatedCommitSha does not exist in this repository.' -Path $EvidencePath))
            }
        }
        elseif ($validatedContentSha256) {
            try {
                $validatedCommitContentSha256 = Get-RepositoryContentFingerprint -RepositoryPath $root -CommitReference $validatedSha
                if ($validatedCommitContentSha256 -ine $validatedContentSha256) {
                    throw 'validatedContentSha256 does not match the named validatedCommitSha content.'
                }
            }
            catch {
                $results.Add((New-ValidationResult -Status Failed -Message $_.Exception.Message -Path $EvidencePath))
            }
        }
        if ($validatedTag) {
            $tagReference = "refs/tags/$validatedTag"
            & git -C $root check-ref-format $tagReference 2>$null
            if ($LASTEXITCODE -ne 0) {
                $results.Add((New-ValidationResult -Status Failed -Message 'validatedCommitTag is not a valid tag name.' -Path $EvidencePath))
            }
            else {
                & git -C $root show-ref --verify --quiet $tagReference
                if ($LASTEXITCODE -eq 0) {
                    $tagType = @(& git -C $root cat-file -t $tagReference 2>$null)
                    if ($LASTEXITCODE -ne 0 -or ($tagType -join '').Trim() -cne 'tag') {
                        $results.Add((New-ValidationResult -Status Failed -Message 'validatedCommitTag must resolve to an annotated tag object.' -Path $EvidencePath))
                    }
                    else {
                        $peeledTagCommit = @(& git -C $root rev-parse --verify "$tagReference^{}" 2>$null)
                        if ($LASTEXITCODE -ne 0 -or -not $peeledTagCommit -or ($peeledTagCommit -join '').Trim() -ine $validatedSha) {
                            $results.Add((New-ValidationResult -Status Failed -Message 'validatedCommitTag does not resolve to validatedCommitSha.' -Path $EvidencePath))
                        }
                    }
                }
            }
        }
        if ($validatedCommitExists -and $evidenceCommitExists) {
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
