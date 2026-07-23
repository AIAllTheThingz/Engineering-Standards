<#
.SYNOPSIS
Independently verifies a downloaded workflow evidence artifact.
.DESCRIPTION
Validates an extracted governance evidence artifact without trusting producer
claims alone. The script parses all JSON, validates completion evidence,
recalculates referenced file hashes and sizes, checks expected repository,
commit, branch, run ID, and conclusion, scans for absolute paths and
credential-like output, and rejects unexpected executable files.
.PARAMETER ArtifactPath
Directory containing extracted artifact files.
.PARAMETER ExpectedRepository
Expected owner/repository value.
.PARAMETER ExpectedCommitSha
Expected validated commit SHA.
.PARAMETER ExpectedBranch
Expected branch or ref name.
.PARAMETER ExpectedRunId
Expected GitHub Actions run ID.
.PARAMETER ExpectedConclusion
Expected workflow conclusion: success or failure.
.PARAMETER ZipPath
Optional original downloaded ZIP path. When supplied, its SHA-256 is reported.
.PARAMETER OutputJson
Optional path for a structured verification report.
.EXAMPLE
pwsh -File scripts/Test-WorkflowEvidenceArtifact.ps1 -ArtifactPath .tmp/artifact -ExpectedRepository AIAllTheThingz/Engineering-Standards -ExpectedCommitSha <sha> -ExpectedBranch master -ExpectedRunId 123 -ExpectedConclusion success
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory)][string]$ArtifactPath,
    [Parameter(Mandatory)][string]$ExpectedRepository,
    [Parameter(Mandatory)][string]$ExpectedCommitSha,
    [Parameter(Mandatory)][string]$ExpectedBranch,
    [Parameter(Mandatory)][string]$ExpectedRunId,
    [Parameter(Mandatory)][ValidateSet('success','failure')][string]$ExpectedConclusion,
    [string]$ZipPath,
    [string]$OutputJson
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
Import-Module (Join-Path $PSScriptRoot 'GovernanceValidation.psm1') -Force

$root = (Resolve-Path -LiteralPath $ArtifactPath).Path
$results = [System.Collections.Generic.List[object]]::new()

function Add-Result {
    param([string]$Status, [string]$Message, [string]$Path = '')
    $results.Add((New-ValidationResult -Status $Status -Message $Message -Path $Path))
}

function Test-RelativeArtifactPath {
    param([string]$RelativePath)
    -not ([System.IO.Path]::IsPathRooted($RelativePath) -or $RelativePath -match '(^|[\\/])\.\.([\\/]|$)')
}

$zipSha = $null
if ($ZipPath) {
    if (Test-Path -LiteralPath $ZipPath -PathType Leaf) {
        $zipSha = (Get-FileHash -LiteralPath $ZipPath -Algorithm SHA256).Hash.ToLowerInvariant()
        Add-Type -AssemblyName System.IO.Compression.FileSystem
        $zip = $null
        try {
            $zip = [System.IO.Compression.ZipFile]::OpenRead($ZipPath)
            $entryNames = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::OrdinalIgnoreCase)
            foreach ($entry in $zip.Entries) {
                $entryName = $entry.FullName.Replace('\','/')
                if (-not $entryName -or $entryName.EndsWith('/')) { continue }
                if (-not (Test-RelativeArtifactPath -RelativePath $entryName)) {
                    Add-Result Failed 'ZIP entry path is absolute or escapes the artifact root.' $entryName
                }
                if (-not $entryNames.Add($entryName)) {
                    Add-Result Failed 'ZIP contains duplicate artifact entries.' $entryName
                }
                if ($entryName -match '\.(exe|dll|so|dylib|bat|cmd|sh)$') {
                    Add-Result Failed 'ZIP contains unexpected executable entry.' $entryName
                }
            }
        }
        catch {
            Add-Result Failed "ZIP could not be inspected: $($_.Exception.Message)" $ZipPath
        }
        finally {
            if ($zip) { $zip.Dispose() }
        }
    }
    else {
        Add-Result Failed "ZIP path '$ZipPath' was not found." $ZipPath
    }
}

$files = @(Get-ChildItem -LiteralPath $root -Recurse -File)
$relativeFiles = @($files | ForEach-Object { [System.IO.Path]::GetRelativePath($root, $_.FullName).Replace('\','/') })
foreach ($relative in $relativeFiles) {
    if (-not (Test-RelativeArtifactPath -RelativePath $relative)) {
        Add-Result Failed 'Artifact file path is absolute or escapes the artifact root.' $relative
    }
}

foreach ($jsonFile in @($files | Where-Object Extension -eq '.json')) {
    try { Read-JsonFile -Path $jsonFile.FullName | Out-Null }
    catch { Add-Result Failed "Invalid JSON: $($_.Exception.Message)" ([System.IO.Path]::GetRelativePath($root, $jsonFile.FullName).Replace('\','/')) }
}

$completionPath = Join-Path $root 'completion-result.json'
if (-not (Test-Path -LiteralPath $completionPath -PathType Leaf)) {
    Add-Result Failed 'completion-result.json is required.' 'completion-result.json'
}
else {
    $completion = Read-JsonFile -Path $completionPath
    foreach ($item in @(Test-GovernanceJsonDocument -Path $completionPath -Kind 'completion-result')) { $results.Add($item) }
    if ($completion.repository -ne $ExpectedRepository) { Add-Result Failed 'Repository metadata mismatch.' 'completion-result.json' }
    if ($completion.validatedCommitSha -ne $ExpectedCommitSha -or $completion.commitSha -ne $ExpectedCommitSha) { Add-Result Failed 'Commit metadata mismatch.' 'completion-result.json' }
    if ($completion.branch -ne $ExpectedBranch) { Add-Result Failed 'Branch metadata mismatch.' 'completion-result.json' }
    if ([string]$completion.githubRunId -ne [string]$ExpectedRunId) { Add-Result Failed 'Run ID metadata mismatch.' 'completion-result.json' }
    $expectedStatus = if ($ExpectedConclusion -eq 'success') { 'Passed' } else { 'Failed' }
    if ($completion.status -ne $expectedStatus) { Add-Result Failed "Completion status must be $expectedStatus." 'completion-result.json' }
    if ($completion.executionContext -ne 'GitHubActions') { Add-Result Failed 'Artifact evidence must use GitHubActions executionContext.' 'completion-result.json' }
    if ($null -ne $completion.evidenceCommitSha) { Add-Result Failed 'Artifact evidence must not set evidenceCommitSha.' 'completion-result.json' }

    foreach ($artifact in @($completion.artifacts)) {
        $path = [string]$artifact.path
        if (-not (Test-RelativeArtifactPath -RelativePath $path)) {
            Add-Result Failed 'Referenced artifact path is unsafe.' $path
            continue
        }
        $candidate = Join-Path $root ($path -replace '^evidence/', '')
        if (-not (Test-Path -LiteralPath $candidate -PathType Leaf)) {
            Add-Result Failed 'Referenced artifact is missing.' $path
            continue
        }
        $item = Get-Item -LiteralPath $candidate
        if ([int64]$artifact.sizeBytes -ne [int64]$item.Length) { Add-Result Failed 'Referenced artifact size mismatch.' $path }
        $actualHash = (Get-FileHash -LiteralPath $candidate -Algorithm SHA256).Hash.ToLowerInvariant()
        if ($actualHash -ne ([string]$artifact.sha256).ToLowerInvariant()) { Add-Result Failed 'Referenced artifact hash mismatch.' $path }
        if ($item.Extension -eq '.json' -and $artifact.mediaType -ne 'application/json') { Add-Result Failed 'JSON artifact media type mismatch.' $path }
    }
}

$absoluteMatches = @(Select-String -LiteralPath $files.FullName -Pattern '([A-Za-z]:\\|^\\\\[^\\]|/home/runner|/tmp/)' -ErrorAction SilentlyContinue)
foreach ($match in $absoluteMatches) { Add-Result Failed 'Absolute path leaked into artifact.' ([System.IO.Path]::GetRelativePath($root, $match.Path).Replace('\','/')) }

$secretPatterns = @(
    '(?i)(password|passwd|pwd|secret|client[_-]?secret|api[_-]?key|access[_-]?token|refresh[_-]?token|token)\s*[:=]\s*(?!\[redacted\](?:\s|[,}\]"]|$))\S{8,}',
    '(?i)Authorization\s*[:=]\s*(Bearer|Basic)\s+\S+',
    '(?i)\b(gh[pousr]_[A-Za-z0-9_]{20,}|github_pat_[A-Za-z0-9_]{20,})\b',
    '(?i)https?://[^/\s:@]+:[^@\s/]+@'
)
$secretMatches = @($secretPatterns | ForEach-Object { Select-String -LiteralPath $files.FullName -Pattern $_ -ErrorAction SilentlyContinue })
foreach ($match in $secretMatches) { Add-Result Failed 'Credential-like output found in artifact.' ([System.IO.Path]::GetRelativePath($root, $match.Path).Replace('\','/')) }

$executables = @($relativeFiles | Where-Object { $_ -match '\.(exe|dll|so|dylib|bat|cmd|sh)$' })
foreach ($exe in $executables) { Add-Result Failed 'Unexpected executable file found in artifact.' $exe }

if (-not @($results | Where-Object status -eq 'Failed')) {
    Add-Result Passed 'Workflow evidence artifact verification completed.'
}

$report = [ordered]@{
    schemaVersion = '1.0.0'
    generatedAtUtc = (Get-Date).ToUniversalTime().ToString('o')
    artifactPath = $root
    zipSha256 = $zipSha
    fileCount = $files.Count
    results = @($results)
    failed = @($results | Where-Object status -eq 'Failed').Count
}
if ($OutputJson) {
    $report | ConvertTo-OrderedJson | Set-Content -LiteralPath $OutputJson -Encoding utf8
}
$results | ForEach-Object { "[$($_.status)] $($_.path) $($_.message)" }
if ($report.failed -gt 0) { exit 1 }
