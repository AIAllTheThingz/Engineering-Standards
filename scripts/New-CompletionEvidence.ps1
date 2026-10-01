<#
.SYNOPSIS
Generates completion evidence.
.DESCRIPTION
Creates a completion-result JSON document from supplied test records, commands, artifacts, warnings, and repository metadata.
.PARAMETER RepositoryPath
Repository root.
.PARAMETER SourceRepositoryPath
Optional checked-out source repository used for Git metadata and changed files
when evidence is stored in a separate workspace.
.PARAMETER OutputPath
Output evidence path relative to repository.
.PARAMETER GovernanceVersion
Governance version used for validation.
.PARAMETER RiskClassification
Risk classification.
.PARAMETER Repository
Explicit validated caller repository owner/name.
.PARAMETER Branch
Explicit validated caller branch or ref name.
.PARAMETER StandardsRepository
Repository that supplied the trusted reusable workflow.
.PARAMETER StandardsWorkflowSha
Immutable commit that supplied the trusted reusable workflow and validators.
.PARAMETER ValidationProfile
Validated profile selected for the caller.
.PARAMETER ChecksExecuted
Names of checks executed by the trusted aggregate validator.
.PARAMETER Status
Optional caller status. The script computes the effective overall status from test records and rejects contradictions.
.PARAMETER Summary
Summary of work.
.PARAMETER TestResultPath
Optional JSON array of test evidence records.
.PARAMETER ArtifactPath
Artifacts to hash and include.
.PARAMETER ChangedFile
Optional explicit repository-relative change inventory. When supplied, this
takes precedence over Git working-tree and commit change detection.
.PARAMETER CommandsExecuted
Exact commands that ran.
.PARAMETER CommandsNotExecuted
Commands not run and reasons.
.PARAMETER BlockedReason
Reason a required validation could not start when the computed status is Blocked.
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
    [string]$GovernanceVersion='1.1.0',
    [ValidateSet('Low','Moderate','High','Critical')][string]$RiskClassification='High',
    [ValidateSet('Passed','Failed','NotRun','NotApplicable','Blocked')][string]$Status='NotRun',
    [Parameter(Mandatory)][string]$Summary,
    [string]$TestResultPath,
    [string[]]$ArtifactPath=@(),
    [string[]]$CommandsExecuted=@(),
    [string[]]$CommandsNotExecuted=@(),
    [string]$BlockedReason,
    [string[]]$Warnings=@(),
    [string[]]$KnownLimitations=@(),
    [string[]]$RemainingRisks=@(),
    [string[]]$Exceptions=@(),
    [Alias('ExecutionContext')]
    [ValidateSet('Local','GitHubActions','PullRequest','Scheduled','Release')]
    [string]$EvidenceExecutionContext = $(if ($env:GITHUB_ACTIONS -eq 'true') { 'GitHubActions' } else { 'Local' }),
    [string]$ArtifactName,
    [string]$ValidatedCommitSha,
    [string]$ValidatedCommitTag,
    [AllowNull()][string]$EvidenceCommitSha = $null,
    [string]$ChangeCategory = 'mixed',
    [switch]$ApprovalRequired,
    [switch]$ProductionChange,
    [string]$DataClassification = 'Internal',
    [string]$Repository,
    [string]$Branch,
    [string]$StandardsRepository,
    [string]$StandardsWorkflowSha,
    [string]$ValidationProfile,
    [string[]]$ChecksExecuted = @(),
    [string[]]$ChangedFile = @(),
    [string]$SourceRepositoryPath
)
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
Import-Module (Join-Path $PSScriptRoot 'GovernanceValidation.psm1') -Force
$root = (Resolve-Path -LiteralPath $RepositoryPath).Path
$sourceRoot = if ($SourceRepositoryPath) { (Resolve-Path -LiteralPath $SourceRepositoryPath).Path } else { $root }
if ($EvidenceExecutionContext -eq 'GitHubActions' -and $SourceRepositoryPath) {
    $expectedSourceRoot = Resolve-SafePath -Root $root -ChildPath 'caller'
    $comparison = if ($IsWindows) { [StringComparison]::OrdinalIgnoreCase } else { [StringComparison]::Ordinal }
    if (-not $sourceRoot.Equals($expectedSourceRoot, $comparison)) {
        throw 'GitHub Actions SourceRepositoryPath must resolve to the dedicated caller workspace.'
    }
}
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
$effectiveBlockedReason = $null
if ($computedStatus -eq 'Blocked') {
    $effectiveBlockedReason = $BlockedReason
    if ([string]::IsNullOrWhiteSpace($effectiveBlockedReason)) {
        $blockedRecord = (@($tests | Where-Object { $_.status -eq 'Blocked' }) | Select-Object -First 1)
        if ($null -ne $blockedRecord -and -not [string]::IsNullOrWhiteSpace([string]$blockedRecord.blockedReason)) {
            $effectiveBlockedReason = [string]$blockedRecord.blockedReason
        }
        else {
            $effectiveBlockedReason = 'A required validation prerequisite was unavailable.'
        }
    }
}
$commit = if ($EvidenceExecutionContext -eq 'GitHubActions') { $env:GITHUB_SHA } else { $null }
if (-not $commit) {
    $commit = (& git -C $sourceRoot rev-parse HEAD 2>$null)
    if ($LASTEXITCODE -ne 0 -or -not $commit) { $commit = 'unknown' }
}
$validatedCommit = if ($ValidatedCommitSha) { $ValidatedCommitSha } else { $commit }

function Resolve-ValidatedCommitTag {
    param(
        [AllowNull()][string]$TagName,
        [Parameter(Mandatory)][string]$RepositoryRoot,
        [Parameter(Mandatory)][string]$CommitSha
    )

    if ([string]::IsNullOrWhiteSpace($TagName)) { return $null }
    $tag = $TagName.Trim()
    $reference = "refs/tags/$tag"
    & git -C $RepositoryRoot check-ref-format $reference 2>$null
    if ($LASTEXITCODE -ne 0) {
        throw "ValidatedCommitTag '$tag' is not a valid tag name."
    }
    $tagType = @(& git -C $RepositoryRoot cat-file -t $reference 2>$null)
    if ($LASTEXITCODE -ne 0 -or ($tagType -join '').Trim() -cne 'tag') {
        throw "ValidatedCommitTag '$tag' must resolve to an annotated tag object."
    }
    $peeledCommit = @(& git -C $RepositoryRoot rev-parse --verify "$reference^{}" 2>$null)
    if ($LASTEXITCODE -ne 0 -or -not $peeledCommit -or ($peeledCommit -join '').Trim() -ine $CommitSha.Trim()) {
        throw "ValidatedCommitTag '$tag' must resolve to validated commit '$CommitSha'."
    }
    return $tag
}

function Test-RawBytePrefix {
    param(
        [Parameter(Mandatory)][byte[]]$Value,
        [Parameter(Mandatory)][byte[]]$Prefix
    )
    if ($Value.Length -lt $Prefix.Length) { return $false }
    for ($index = 0; $index -lt $Prefix.Length; $index++) {
        if ($Value[$index] -ne $Prefix[$index]) { return $false }
    }
    return $true
}

function Get-TrustedRepositoryIdentity {
    # The repository identity that gates this repository's special fingerprint pairing. It must not come from the
    # receipt being validated: use the caller-supplied expectation, the Actions-provided repository, or the checkout's
    # origin remote. An unknown identity pairs nothing.
    param(
        [string]$RepositoryRoot,
        [string]$Expected
    )
    if (-not [string]::IsNullOrWhiteSpace($Expected)) { return $Expected }
    if (-not [string]::IsNullOrWhiteSpace($env:GITHUB_REPOSITORY)) { return $env:GITHUB_REPOSITORY }
    $origin = [string](& git -C $RepositoryRoot remote get-url origin 2>$null)
    if ($LASTEXITCODE -eq 0 -and $origin -match 'github\.com[:/]([^/]+)/([^/.]+)(\.git)?$') { return "$($Matches[1])/$($Matches[2])" }
    return ''
}

function Get-ReceiptExclusionPath {
    # Repository-relative location of the receipt: its directory (trailing slash) or, for a receipt at the
    # repository root, the file itself. A receipt outside the source tree excludes nothing.
    param(
        [Parameter(Mandatory)][string]$GitRoot,
        [AllowNull()][string]$ReceiptFullPath,
        [AllowNull()][string]$Repository
    )
    if ([string]::IsNullOrWhiteSpace($ReceiptFullPath)) { return @() }
    # Only Windows treats a backslash as a separator; on Linux it is a legal filename character.
    $trimCharacters = if ($IsWindows) { [char[]]@('\', '/') } else { [char[]]@('/') }
    $rootFull = [IO.Path]::GetFullPath($GitRoot).TrimEnd($trimCharacters)
    $receiptFull = [IO.Path]::GetFullPath($ReceiptFullPath)
    $comparison = if ($IsWindows) { [StringComparison]::OrdinalIgnoreCase } else { [StringComparison]::Ordinal }
    if (-not $receiptFull.StartsWith($rootFull + [IO.Path]::DirectorySeparatorChar, $comparison)) { return @() }
    $relative = $receiptFull.Substring($rootFull.Length + 1)
    if ($IsWindows) { $relative = $relative.Replace('\', '/') }
    # This repository's two example receipts bind each other's trees. Pair their directories only for those exact
    # receipt files in this repository; any other receipt, even inside those directories, excludes only its own directory.
    $centralEvidenceDirectories = @('examples/python-project/evidence/', 'examples/bash-project/evidence/')
    # Pair only for the two exact central receipt files, and only when the independently trusted repository identity
    # (never the receipt's own repository field) is this repository.
    $centralReceiptPaths = @('examples/python-project/evidence/local-completion-result.json', 'examples/bash-project/evidence/local-completion-result.json')
    $isCentralRepository = [string]::Equals($Repository, 'AIAllTheThingz/Engineering-Standards', [StringComparison]::Ordinal)
    $isCentralReceipt = $isCentralRepository -and @($centralReceiptPaths | Where-Object { [string]::Equals($_, $relative, $comparison) }).Count -gt 0
    if ($isCentralReceipt) { return $centralEvidenceDirectories }
    $slash = $relative.LastIndexOf('/')
    if ($slash -lt 0) { return @($relative) }
    return @($relative.Substring(0, $slash + 1))
}

function Test-ExcludedReceiptPath {
    param(
        [Parameter(Mandatory)][byte[]]$Value,
        [Parameter(Mandatory)][AllowEmptyCollection()][object[]]$Exclusions
    )
    foreach ($exclusion in $Exclusions) {
        [byte[]]$bytes = $exclusion
        if ($bytes[$bytes.Length - 1] -eq 47) {
            if (Test-RawBytePrefix -Value $Value -Prefix $bytes) { return $true }
        }
        elseif ($Value.Length -eq $bytes.Length -and (Test-RawBytePrefix -Value $Value -Prefix $bytes)) { return $true }
    }
    return $false
}

function Get-RawGitTreeFingerprint {
    param(
        [Parameter(Mandatory)][string]$RepositoryRoot,
        [Parameter(Mandatory)][string]$CommitSha,
        [Parameter(Mandatory)][string]$FailurePrefix,
        [string[]]$ExtraExcludedPaths = @()
    )

    $gitCommand = @(Get-Command git -CommandType Application -ErrorAction Stop)[0]
    $startInfo = [Diagnostics.ProcessStartInfo]::new($gitCommand.Source)
    $startInfo.UseShellExecute = $false
    $startInfo.RedirectStandardOutput = $true
    $startInfo.RedirectStandardError = $true
    $startInfo.CreateNoWindow = $true
    foreach ($argument in @('-C', $RepositoryRoot, 'ls-tree', '-r', '--full-tree', '-z', $CommitSha)) {
        [void]$startInfo.ArgumentList.Add($argument)
    }
    $process = [Diagnostics.Process]::new()
    $process.StartInfo = $startInfo
    $output = [IO.MemoryStream]::new()
    try {
        if (-not $process.Start()) { throw "$FailurePrefix could not start Git tree enumeration." }
        $standardErrorTask = $process.StandardError.ReadToEndAsync()
        $process.StandardOutput.BaseStream.CopyTo($output)
        $process.WaitForExit()
        $standardError = $standardErrorTask.GetAwaiter().GetResult()
        if ($process.ExitCode -ne 0) { throw "$FailurePrefix could not enumerate Git tree content: $standardError" }
        [byte[]]$treeBytes = $output.ToArray()
    }
    finally {
        $output.Dispose()
        $process.Dispose()
    }

    $receiptExclusions = @($ExtraExcludedPaths | Where-Object { -not [string]::IsNullOrEmpty($_) } | ForEach-Object { , [Text.Encoding]::UTF8.GetBytes($_) })
    $recordHex = [Collections.Generic.List[string]]::new()
    $segmentStart = 0
    for ($index = 0; $index -le $treeBytes.Length; $index++) {
        if ($index -lt $treeBytes.Length -and $treeBytes[$index] -ne 0) { continue }
        if ($index -eq $segmentStart) {
            $segmentStart = $index + 1
            continue
        }
        [byte[]]$entry = $treeBytes[$segmentStart..($index - 1)]
        $segmentStart = $index + 1
        $tabIndex = [Array]::IndexOf($entry, [byte]9)
        if ($tabIndex -le 0 -or $tabIndex -ge ($entry.Length - 1)) { throw "$FailurePrefix contains an unsupported tree entry." }
        $header = [Text.Encoding]::ASCII.GetString($entry[0..($tabIndex - 1)])
        $match = [regex]::Match($header, '^(?<mode>[0-7]{6}) (?<type>blob|commit) (?<object>[A-Fa-f0-9]{40}|[A-Fa-f0-9]{64})$')
        if (-not $match.Success) { throw "$FailurePrefix contains an unsupported tree entry header." }
        [byte[]]$pathBytes = $entry[($tabIndex + 1)..($entry.Length - 1)]
        if ($pathBytes.Length -eq 0) { throw "$FailurePrefix contains an empty tree path." }
        if ($receiptExclusions.Count -gt 0 -and (Test-ExcludedReceiptPath -Value $pathBytes -Exclusions $receiptExclusions)) { continue }
        $recordPrefix = ('{0}' + [char]0 + '{1}' + [char]0 + '{2}' + [char]0) -f $match.Groups['mode'].Value, $match.Groups['type'].Value, $match.Groups['object'].Value.ToLowerInvariant()
        [byte[]]$prefixBytes = [Text.Encoding]::ASCII.GetBytes($recordPrefix)
        [byte[]]$recordBytes = New-Object byte[] ($prefixBytes.Length + $pathBytes.Length)
        [Array]::Copy($prefixBytes, 0, $recordBytes, 0, $prefixBytes.Length)
        [Array]::Copy($pathBytes, 0, $recordBytes, $prefixBytes.Length, $pathBytes.Length)
        $recordHex.Add([Convert]::ToHexString($recordBytes).ToLowerInvariant())
    }

    $canonicalHex = $recordHex.ToArray()
    [Array]::Sort($canonicalHex, [StringComparer]::Ordinal)
    $payload = [IO.MemoryStream]::new()
    try {
        [byte[]]$headerBytes = [Text.Encoding]::ASCII.GetBytes("completion-evidence-content-v1`n")
        $payload.Write($headerBytes, 0, $headerBytes.Length)
        foreach ($hex in $canonicalHex) {
            [byte[]]$recordBytes = [Convert]::FromHexString($hex)
            $payload.Write($recordBytes, 0, $recordBytes.Length)
            $payload.WriteByte(10)
        }
        return [Convert]::ToHexString([Security.Cryptography.SHA256]::HashData($payload.ToArray())).ToLowerInvariant()
    }
    finally {
        $payload.Dispose()
    }
}

function Get-ValidatedContentFingerprint {
    param(
        [Parameter(Mandatory)][string]$RepositoryRoot,
        [Parameter(Mandatory)][string]$CommitSha,
        [AllowNull()][string]$ReceiptFullPath,
        [AllowNull()][string]$ReceiptRepository
    )
    if ($CommitSha -eq 'unknown') { return $null }
    if ($CommitSha -notmatch '^[A-Fa-f0-9]{40,64}$') { throw "Validated commit '$CommitSha' must be a Git object identifier." }
    $gitProbe = @(& git -C $RepositoryRoot rev-parse --is-inside-work-tree 2>$null)
    if ($LASTEXITCODE -ne 0 -or ($gitProbe -join '').Trim() -cne 'true') { return $null }
    & git -C $RepositoryRoot cat-file -e "$CommitSha^{commit}" 2>$null
    if ($LASTEXITCODE -ne 0) { throw "Validated commit '$CommitSha' is not available in SourceRepositoryPath." }
    $gitTopLevel = (@(& git -C $RepositoryRoot rev-parse --show-toplevel 2>$null) -join '').Trim()
    $receiptExclusions = if ($LASTEXITCODE -eq 0 -and $gitTopLevel) { @(Get-ReceiptExclusionPath -GitRoot $gitTopLevel -ReceiptFullPath $ReceiptFullPath -Repository $ReceiptRepository) } else { @() }
    return Get-RawGitTreeFingerprint -RepositoryRoot $RepositoryRoot -CommitSha $CommitSha -FailurePrefix "Validated commit '$CommitSha'" -ExtraExcludedPaths $receiptExclusions
}

$resolvedCommitTag = Resolve-ValidatedCommitTag -TagName $ValidatedCommitTag -RepositoryRoot $sourceRoot -CommitSha $validatedCommit
$effectiveBranch = $env:GITHUB_REF_NAME
if ($Branch) {
    $effectiveBranch = $Branch
}
elseif (-not $effectiveBranch) {
    $effectiveBranch = (& git -C $sourceRoot branch --show-current 2>$null)
    if ($LASTEXITCODE -ne 0 -or -not $effectiveBranch) { $effectiveBranch = 'unknown' }
}
$githubRunId = if ($EvidenceExecutionContext -eq 'GitHubActions' -and $env:GITHUB_RUN_ID) { $env:GITHUB_RUN_ID } else { $null }
$githubRunAttempt = if ($EvidenceExecutionContext -eq 'GitHubActions' -and $env:GITHUB_RUN_ATTEMPT) { $env:GITHUB_RUN_ATTEMPT } else { $null }
$githubWorkflow = if ($EvidenceExecutionContext -eq 'GitHubActions' -and $env:GITHUB_WORKFLOW) { $env:GITHUB_WORKFLOW } else { $null }

function Convert-RepositoryLfFile {
    param(
        [Parameter(Mandatory)][string]$Path,
        [Parameter(Mandatory)][string]$RepositoryRoot
    )

    # Git's text=auto attribute can still report eol=lf for arbitrary binary
    # files. Only normalize the explicit textual evidence formats this script
    # emits; every other artifact must be hashed without mutation.
    $extension = [System.IO.Path]::GetExtension($Path).ToLowerInvariant()
    if ($extension -notin @('.json', '.xml')) { return }

    $relativePath = [System.IO.Path]::GetRelativePath($RepositoryRoot, $Path).Replace('\', '/')
    if ($relativePath -eq '.' -or $relativePath -match '^(?:[A-Za-z]:|/|\.\.(?:/|$))') { return }

    $attribute = @(& git -C $RepositoryRoot check-attr eol -- $relativePath 2>$null)
    $attributeExitCode = $LASTEXITCODE
    if ($attributeExitCode -ne 0) {
        $global:LASTEXITCODE = 0
        return
    }
    if ($LASTEXITCODE -ne 0 -or ($attribute -join "`n") -notmatch '(?m):\s*eol:\s*lf\s*$') { return }

    $bytes = [System.IO.File]::ReadAllBytes($Path)
    $normalized = [System.IO.MemoryStream]::new()
    $changed = $false
    try {
        for ($index = 0; $index -lt $bytes.Length; $index++) {
            if ($bytes[$index] -eq 13 -and $index + 1 -lt $bytes.Length -and $bytes[$index + 1] -eq 10) {
                $normalized.WriteByte(10)
                $index++
                $changed = $true
                continue
            }
            $normalized.WriteByte($bytes[$index])
        }
        if ($changed) {
            [System.IO.File]::WriteAllBytes($Path, $normalized.ToArray())
        }
    }
    finally {
        $normalized.Dispose()
    }
}

$artifacts = @()
foreach ($artifact in $ArtifactPath) {
    if ($artifact -eq $OutputPath) { continue }
    $resolved = Resolve-SafePath -Root $root -ChildPath $artifact
    if (Test-Path -LiteralPath $resolved -PathType Leaf) {
        Convert-RepositoryLfFile -Path $resolved -RepositoryRoot $root
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
            'pester' { 'Pester'; break }
            'psscriptanalyzer' { 'PSScriptAnalyzer'; break }
            'examples' { 'Example-project validation'; break }
            'evidence-validation' { 'Completion-evidence validation'; break }
            'environment' { 'GitHub-hosted workflow execution'; break }
            'ci-test-results' { $null; break }
            default { $null }
        }
        $artifacts += [ordered]@{
            schemaVersion = '1.1.0'
            name = $item.Name
            artifactType = 'report'
            path = $artifact
            mediaType = $mediaType
            sizeBytes = $item.Length
            hashAlgorithm = 'SHA-256'
            sha256 = (Get-FileHash -LiteralPath $resolved -Algorithm SHA256).Hash.ToLowerInvariant()
            createdAtUtc = (Get-Date).ToUniversalTime().ToString('o')
            publishedAtUtc = $null
            producer = 'New-CompletionEvidence.ps1'
            retention = 'audit'
            sensitivity = 'Internal'
            classification = 'Internal'
            relatedTest = $related
            sourceCommitSha = $validatedCommit.Trim()
            validatedCommitSha = $validatedCommit.Trim()
            githubRunId = $githubRunId
            githubRunAttempt = $githubRunAttempt
            jobName = $githubWorkflow
            finality = 'final'
            signed = $null
            attested = $null
            authorizationBoundary = $EvidenceExecutionContext
            verifiedAtUtc = $null
            verifiedBy = $null
            expiresAtUtc = $null
            integrityVerification = [ordered]@{
                status = 'Passed'
                summary = 'Artifact hash was generated at evidence creation time.'
            }
        }
    }
}
function Get-OriginRepositoryName {
    param([string]$RepositoryRoot)
    $origin = (& git -C $RepositoryRoot remote get-url origin 2>$null)
    if ($LASTEXITCODE -ne 0 -or -not $origin) { return 'AIAllTheThingz/Engineering-Standards' }
    $value = [string]$origin
    if ($value -match 'github\.com[:/]([^/]+)/([^/.]+)(\.git)?$') { return "$($Matches[1])/$($Matches[2])" }
    return 'AIAllTheThingz/Engineering-Standards'
}

$receiptRepository = Get-TrustedRepositoryIdentity -RepositoryRoot $sourceRoot
$validatedContentSha256 = Get-ValidatedContentFingerprint -RepositoryRoot $sourceRoot -CommitSha $validatedCommit -ReceiptFullPath (Join-Path $root $OutputPath) -ReceiptRepository $receiptRepository

function Test-GeneratedBuildOutputPath {
    param([string]$Path)
    $normalized = $Path
    # Windows paths are case-insensitive; on Unix 'Dist/' and 'src/Bin/' are ordinary source directories.
    if ($IsWindows) {
        return $normalized -match '(^|/)(bin|obj|dist)(/|$)' -or $normalized -match '^(coverage|TestResults)(/|$)'
    }
    $normalized -cmatch '(^|/)(bin|obj|dist)(/|$)' -or $normalized -cmatch '^(coverage|TestResults)(/|$)'
}

function Convert-ChangedFilePath {
    param([Parameter(Mandatory)][string]$Path)

    $normalized = $Path
    # Only Windows treats a backslash as a separator; on Unix it is a legal literal filename character.
    if ($IsWindows) { $normalized = $normalized.Replace('\', '/') }
    while ($normalized.StartsWith('./', [StringComparison]::Ordinal)) {
        $normalized = $normalized.Substring(2)
    }
    # A drive prefix is only a root on Windows; on Unix 'C:module.py' is an ordinary relative filename.
    $rooted = $normalized.StartsWith('/', [StringComparison]::Ordinal) -or ($IsWindows -and $normalized -match '^[A-Za-z]:')
    if ($normalized.Length -eq 0 -or $rooted -or $normalized -match '(?:^|/)\.\.(?:/|$)') {
        throw "ChangedFile '$Path' must be a non-empty repository-relative path without traversal."
    }
    return $normalized
}

function Get-ChangedFileCategories {
    param([string[]]$Files)
    $categories = [ordered]@{
        source = @()
        documentation = @()
        configuration = @()
        tests = @()
        generatedEvidence = @()
        generatedBuildOutput = @()
    }
    foreach ($file in @($Files)) {
        if ($null -eq $file -or $file.Length -eq 0) { continue }
        $path = $file
        if (Test-GeneratedBuildOutputPath -Path $path) { $categories.generatedBuildOutput += $path; continue }
        if ($path -match '^evidence/' -or $path -match '/evidence/') { $categories.generatedEvidence += $path; continue }
        if ($path -match '(^|/)tests?/' -or $path -match '\.Tests\.ps1$') { $categories.tests += $path; continue }
        if ($path -match '\.md$') { $categories.documentation += $path; continue }
        if ($path -match '(^|/)(\.github|schemas|actions|scripts)/' -or $path -match '\.(json|ya?ml|ps1|psm1|psd1|gitignore)$') { $categories.configuration += $path; continue }
        $categories.source += $path
    }
    foreach ($key in @($categories.Keys)) { $categories[$key] = @($categories[$key] | Sort-Object -Unique -CaseSensitive) }
    $categories
}

$changedFiles = @(
    if (@($ChangedFile).Count -gt 0) {
        $ChangedFile | ForEach-Object { Convert-ChangedFilePath -Path $_ }
    }
    else {
        & git -C $sourceRoot status --short 2>$null | ForEach-Object { $_.Substring(3) }
    }
)
if ($changedFiles.Count -eq 0 -and $commit -ne 'unknown') {
    $changedFiles = @(& git -C $sourceRoot diff-tree --no-commit-id --name-only -r $commit 2>$null | ForEach-Object { $_ })
}
$changedFiles = @($changedFiles | Where-Object { -not (Test-GeneratedBuildOutputPath -Path $_) } | Sort-Object -Unique -CaseSensitive)
# 'unknown' is only the placeholder for an empty change set; a real file with that name is an ordinary path.
$changedFilesUnknown = $changedFiles.Count -eq 0
if ($changedFilesUnknown) { $changedFiles = @('unknown') }
$changedFileCategories = Get-ChangedFileCategories -Files $(if ($changedFilesUnknown) { @() } else { $changedFiles })
$evidence = [ordered]@{
    schemaVersion = '1.1.0'
    executionContext = $EvidenceExecutionContext
    githubRunId = $githubRunId
    githubRunAttempt = $githubRunAttempt
    githubWorkflow = $githubWorkflow
    githubJob = $githubWorkflow
    artifactName = $(if ($ArtifactName) { $ArtifactName } else { $null })
    repository = $(if ($Repository) { $Repository } elseif ($env:GITHUB_REPOSITORY) { $env:GITHUB_REPOSITORY } else { Get-OriginRepositoryName -RepositoryRoot $sourceRoot })
    commitSha = $validatedCommit.Trim()
    validatedCommitSha = $validatedCommit.Trim()
    validatedContentSha256 = $validatedContentSha256
    validatedCommitTag = $resolvedCommitTag
    evidenceCommitSha = $(if ($EvidenceCommitSha) { $EvidenceCommitSha.Trim() } else { $null })
    branch = $effectiveBranch.Trim()
    pullRequest = $null
    governanceVersion = $GovernanceVersion
    riskClassification = $RiskClassification
    changeCategory = $ChangeCategory
    status = $computedStatus
    startedAtUtc = (Get-Date).ToUniversalTime().ToString('o')
    completedAtUtc = (Get-Date).ToUniversalTime().ToString('o')
    durationSeconds = 0
    summary = $Summary
    changedFiles = @($changedFiles)
    changedFileCategories = $changedFileCategories
    environment = [ordered]@{
        name = $(if ($EvidenceExecutionContext -eq 'GitHubActions') { 'github-actions' } else { 'local' })
        type = $(if ($EvidenceExecutionContext -eq 'GitHubActions') { 'test' } else { 'development' })
        production = $false
        tenant = $null
        account = $null
        subscription = $null
        project = $null
        region = $null
        zone = $null
        cluster = $null
        namespace = $null
    }
    productionChange = $ProductionChange.IsPresent
    approvalRequired = $ApprovalRequired.IsPresent
    executionMode = [ordered]@{
        dryRun = $false
        whatIf = $false
        planOnly = $false
        applied = ($EvidenceExecutionContext -eq 'GitHubActions')
    }
    dataClassification = $DataClassification
    identityUsed = $(if ($EvidenceExecutionContext -eq 'GitHubActions') { 'GitHub Actions runner identity' } else { 'Local maintainer context' })
    credentialMode = $(if ($EvidenceExecutionContext -eq 'GitHubActions') { 'GitHub-provided ephemeral token' } else { 'Local workstation credentials' })
    notRunReason = $(if ($computedStatus -eq 'NotRun') { if (@($CommandsNotExecuted).Count -gt 0) { @($CommandsNotExecuted)[0] } else { 'Mandatory validation did not execute.' } } else { $null })
    blockedReason = $effectiveBlockedReason
    notApplicableRationale = $null
    commandsExecuted = @($CommandsExecuted)
    commandsNotExecuted = @($CommandsNotExecuted)
    tests = @($tests)
    artifacts = @($artifacts)
    warnings = @($Warnings)
    knownLimitations = @($KnownLimitations)
    remainingRisks = @($RemainingRisks)
    exceptions = @($Exceptions)
    approvals = @()
    operations = [ordered]@{
        maintenanceWindow = $null
        rollbackPlan = $null
        rollbackTestedStatus = 'NotApplicable'
        rollForwardPlan = $null
        backupRequired = $false
        backupVerification = $null
        restoreVerification = $null
        destructiveOperations = $false
    }
    technologyEvidence = [ordered]@{
        infrastructure = $(if ($StandardsRepository -or $StandardsWorkflowSha -or $ValidationProfile) {
            [ordered]@{
                governanceWorkflow = [ordered]@{
                    callerRepository = $(if ($Repository) { $Repository } elseif ($env:GITHUB_REPOSITORY) { $env:GITHUB_REPOSITORY } else { Get-OriginRepositoryName -RepositoryRoot $sourceRoot })
                    callerCommitSha = $validatedCommit.Trim()
                    standardsRepository = $StandardsRepository
                    standardsWorkflowSha = $StandardsWorkflowSha
                    validationProfile = $ValidationProfile
                    checksExecuted = @($ChecksExecuted)
                }
            }
        } else { @{} })
    }
}
$out = Resolve-SafePath -Root $root -ChildPath $OutputPath -AllowMissingLeaf
New-Item -ItemType Directory -Path (Split-Path -Parent $out) -Force | Out-Null
$evidence | ConvertTo-OrderedJson | Set-Content -LiteralPath $out -Encoding utf8
Convert-RepositoryLfFile -Path $out -RepositoryRoot $root
Write-Output "Completion evidence written to $out"
