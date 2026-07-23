<#
.SYNOPSIS
Independently verifies a downloaded governed Bash workflow artifact.
.DESCRIPTION
Validates caller and standards identity, workflow and artifact identity, required
evidence, canonical outcomes, exact tool provenance, CycloneDX contents,
sanitization, and the expected success or controlled-failure conclusion.
.PARAMETER ArtifactPath
Extracted Bash evidence artifact directory.
.PARAMETER ExpectedRepository
Expected caller owner/repository.
.PARAMETER ExpectedCommitSha
Expected caller commit SHA.
.PARAMETER ExpectedBranch
Expected caller branch or ref.
.PARAMETER ExpectedRunId
Expected workflow run ID.
.PARAMETER ExpectedArtifactId
Artifact ID returned by the GitHub Actions API for the downloaded artifact.
.PARAMETER ExpectedArtifactName
Expected run-qualified artifact name.
.PARAMETER ExpectedStandardsRepository
Expected trusted standards repository.
.PARAMETER ExpectedStandardsWorkflowSha
Expected immutable standards workflow SHA.
.PARAMETER ExpectedConclusion
Expected workflow conclusion.
.PARAMETER ExpectedFailurePhase
For controlled failures, the one intended phase: syntax, shellcheck, formatting, or tests.
.PARAMETER ToolLockPath
Reviewed Bash functional tool lock used for independent comparison.
.PARAMETER ArtifactMetadataPath
GitHub Actions artifact API metadata downloaded independently for ExpectedArtifactId.
.PARAMETER ZipPath
Original downloaded artifact ZIP; its SHA-256 and contents are bound to the extracted directory.
.PARAMETER ExpectedJobId
Optional workflow job ID recorded in the verification report.
.PARAMETER OutputJson
Optional structured verification report.
.EXAMPLE
pwsh -NoProfile -File scripts/Test-BashWorkflowEvidenceArtifact.ps1 -ArtifactPath .tmp/bash-artifact -ArtifactMetadataPath .tmp/artifact-456.json -ZipPath .tmp/bash-evidence-123.zip -ExpectedRepository example-org/project -ExpectedCommitSha 0123456789012345678901234567890123456789 -ExpectedBranch feature/bash -ExpectedRunId 123 -ExpectedArtifactId 456 -ExpectedArtifactName bash-evidence-123 -ExpectedStandardsRepository AIAllTheThingz/Engineering-Standards -ExpectedStandardsWorkflowSha 0123456789012345678901234567890123456789 -ExpectedConclusion success
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory)][string]$ArtifactPath,
    [Parameter(Mandatory)][string]$ExpectedRepository,
    [Parameter(Mandatory)][ValidatePattern('^[0-9a-f]{40}$')][string]$ExpectedCommitSha,
    [Parameter(Mandatory)][string]$ExpectedBranch,
    [Parameter(Mandatory)][ValidatePattern('^[1-9][0-9]*$')][string]$ExpectedRunId,
    [Parameter(Mandatory)][ValidatePattern('^[1-9][0-9]*$')][string]$ExpectedArtifactId,
    [Parameter(Mandatory)][string]$ExpectedArtifactName,
    [Parameter(Mandatory)][string]$ExpectedStandardsRepository,
    [Parameter(Mandatory)][ValidatePattern('^[0-9a-f]{40}$')][string]$ExpectedStandardsWorkflowSha,
    [Parameter(Mandatory)][ValidateSet('success','failure')][string]$ExpectedConclusion,
    [ValidateSet('syntax','shellcheck','formatting','tests')][string]$ExpectedFailurePhase,
    [string]$ToolLockPath = (Join-Path $PSScriptRoot '../examples/bash-project/bash-toolchain.lock.json'),
    [Parameter(Mandatory)][string]$ArtifactMetadataPath,
    [Parameter(Mandatory)][string]$ZipPath,
    [string]$ExpectedJobId,
    [string]$OutputJson
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
Import-Module (Join-Path $PSScriptRoot 'GovernanceValidation.psm1') -Force

$root = (Resolve-Path -LiteralPath $ArtifactPath).Path
$lock = Read-JsonFile -Path (Resolve-Path -LiteralPath $ToolLockPath).Path
$results = [System.Collections.Generic.List[object]]::new()
$canonical = @('Passed','Failed','Blocked','NotRun','NotApplicable')
$requiredFiles = @(
    'bash-syntax.json',
    'bash-shellcheck.json',
    'bash-formatting.json',
    'bash-tests.json',
    'bash-toolchain.json',
    'bash-toolchain-bootstrap.json',
    'bash-project-sbom.cdx.json',
    'local-test-results.json',
    'completion-result.json',
    'evidence-validation.json',
    'step-outcomes.json'
)
function Add-Result {
    param([string]$Status, [string]$Message, [string]$Path = '')
    $results.Add((New-ValidationResult -Status $Status -Message $Message -Path $Path))
}

function Get-Json {
    param([string]$Name)
    $path = Join-Path $root $Name
    if (-not (Test-Path -LiteralPath $path -PathType Leaf)) { return $null }
    try { Read-JsonFile -Path $path }
    catch { Add-Result Failed "Invalid JSON: $($_.Exception.Message)" $Name; $null }
}

$artifactMetadata = $null
if (-not (Test-Path -LiteralPath $ArtifactMetadataPath -PathType Leaf)) {
    Add-Result Failed 'Independent artifact API metadata was not found.' $ArtifactMetadataPath
}
else {
    try { $artifactMetadata = Read-JsonFile -Path (Resolve-Path -LiteralPath $ArtifactMetadataPath).Path }
    catch { Add-Result Failed "Artifact API metadata is invalid: $($_.Exception.Message)" $ArtifactMetadataPath }
}
if ($artifactMetadata) {
    if ([string]$artifactMetadata.id -cne $ExpectedArtifactId) { Add-Result Failed 'Artifact API ID mismatch.' $ArtifactMetadataPath }
    if ([string]$artifactMetadata.name -cne $ExpectedArtifactName) { Add-Result Failed 'Artifact API name mismatch.' $ArtifactMetadataPath }
    if ($artifactMetadata.expired -eq $true) { Add-Result Failed 'Artifact API metadata marks the artifact expired.' $ArtifactMetadataPath }
    if ([string]$artifactMetadata.workflow_run.id -cne $ExpectedRunId) { Add-Result Failed 'Artifact API workflow run mismatch.' $ArtifactMetadataPath }
    if ([string]$artifactMetadata.workflow_run.head_sha -cne $ExpectedCommitSha) { Add-Result Failed 'Artifact API caller commit mismatch.' $ArtifactMetadataPath }
    if ([string]$artifactMetadata.workflow_run.head_branch -cne $ExpectedBranch) { Add-Result Failed 'Artifact API caller branch mismatch.' $ArtifactMetadataPath }
    if ([string]$artifactMetadata.digest -notmatch '^sha256:[0-9a-f]{64}$') { Add-Result Failed 'Artifact API digest is missing or malformed.' $ArtifactMetadataPath }
}

foreach ($name in $requiredFiles) {
    if (-not (Test-Path -LiteralPath (Join-Path $root $name) -PathType Leaf)) {
        Add-Result Failed 'Required Bash workflow evidence file is missing.' $name
    }
}

$zipSha = $null
if (-not (Test-Path -LiteralPath $ZipPath -PathType Leaf)) {
    Add-Result Failed 'Artifact ZIP was not found.' $ZipPath
}
else {
        $zipSha = (Get-FileHash -LiteralPath $ZipPath -Algorithm SHA256).Hash.ToLowerInvariant()
        Add-Type -AssemblyName System.IO.Compression.FileSystem
        $zip = $null
        try {
            $zip = [IO.Compression.ZipFile]::OpenRead($ZipPath)
            $seen = [Collections.Generic.HashSet[string]]::new([StringComparer]::OrdinalIgnoreCase)
            foreach ($entry in $zip.Entries) {
                $name = $entry.FullName.Replace('\','/')
                if (-not $name -or $name.EndsWith('/')) { continue }
                if ([IO.Path]::IsPathRooted($name) -or $name -match '(^|/)\.\.(/|$)') { Add-Result Failed 'Artifact ZIP entry is unsafe.' $name }
                if (-not $seen.Add($name)) { Add-Result Failed 'Artifact ZIP has duplicate or case-colliding entries.' $name }
                if ($name -match '\.(exe|dll|so|dylib|bat|cmd|sh)$') { Add-Result Failed 'Artifact ZIP contains unexpected executable content.' $name }
                $extracted = Join-Path $root $name
                if (-not (Test-Path -LiteralPath $extracted -PathType Leaf)) { Add-Result Failed 'Artifact ZIP entry is missing from the extracted directory.' $name; continue }
                if ([int64]$entry.Length -ne (Get-Item -LiteralPath $extracted).Length) { Add-Result Failed 'Artifact ZIP entry size differs from the extracted file.' $name; continue }
                $stream = $null
                $hasher = $null
                try {
                    $stream = $entry.Open()
                    $hasher = [Security.Cryptography.SHA256]::Create()
                    $entryHash = ([BitConverter]::ToString($hasher.ComputeHash($stream))).Replace('-','').ToLowerInvariant()
                    $fileHash = (Get-FileHash -LiteralPath $extracted -Algorithm SHA256).Hash.ToLowerInvariant()
                    if ($entryHash -cne $fileHash) { Add-Result Failed 'Artifact ZIP entry content differs from the extracted file.' $name }
                }
                finally {
                    if ($hasher) { $hasher.Dispose() }
                    if ($stream) { $stream.Dispose() }
                }
            }
            foreach ($file in @(Get-ChildItem -LiteralPath $root -Recurse -File)) {
                $relative = [IO.Path]::GetRelativePath($root, $file.FullName).Replace('\','/')
                if (-not $seen.Contains($relative)) { Add-Result Failed 'Extracted artifact file is absent from the original ZIP.' $relative }
            }
        }
        catch { Add-Result Failed "Artifact ZIP inspection failed: $($_.Exception.Message)" $ZipPath }
        finally { if ($zip) { $zip.Dispose() } }
    if ($artifactMetadata -and $artifactMetadata.digest) {
        if ([string]$artifactMetadata.digest -cne "sha256:$zipSha") { Add-Result Failed 'Artifact API digest does not match the downloaded ZIP.' $ArtifactMetadataPath }
    }
}

$completion = Get-Json 'completion-result.json'
if ($completion) {
    foreach ($item in @(Test-GovernanceJsonDocument -Path (Join-Path $root 'completion-result.json') -Kind 'completion-result')) { $results.Add($item) }
    if ($completion.repository -cne $ExpectedRepository) { Add-Result Failed 'Caller repository identity mismatch.' 'completion-result.json' }
    if ($completion.commitSha -cne $ExpectedCommitSha -or $completion.validatedCommitSha -cne $ExpectedCommitSha) { Add-Result Failed 'Caller commit identity mismatch.' 'completion-result.json' }
    if ($completion.branch -cne $ExpectedBranch) { Add-Result Failed 'Caller branch identity mismatch.' 'completion-result.json' }
    if ([string]$completion.githubRunId -cne $ExpectedRunId) { Add-Result Failed 'Workflow run identity mismatch.' 'completion-result.json' }
    if ($completion.artifactName -cne $ExpectedArtifactName) { Add-Result Failed 'Artifact name identity mismatch.' 'completion-result.json' }
    if ($completion.executionContext -cne 'GitHubActions') { Add-Result Failed 'Hosted Bash evidence must use GitHubActions executionContext.' 'completion-result.json' }
    if ($null -ne $completion.evidenceCommitSha) { Add-Result Failed 'Hosted Bash evidence must not set evidenceCommitSha.' 'completion-result.json' }
    $workflowIdentity = $completion.technologyEvidence.infrastructure.governanceWorkflow
    if ($workflowIdentity.callerRepository -cne $ExpectedRepository -or $workflowIdentity.callerCommitSha -cne $ExpectedCommitSha) { Add-Result Failed 'Caller workflow identity mismatch.' 'completion-result.json' }
    if ($workflowIdentity.standardsRepository -cne $ExpectedStandardsRepository -or $workflowIdentity.standardsWorkflowSha -cne $ExpectedStandardsWorkflowSha) { Add-Result Failed 'Standards workflow identity mismatch.' 'completion-result.json' }
    $expectedStatus = if ($ExpectedConclusion -eq 'success') { 'Passed' } else { 'Failed' }
    if ($completion.status -cne $expectedStatus) { Add-Result Failed "Completion status must be $expectedStatus." 'completion-result.json' }
    $expectedCompletionArtifacts = @(
        'evidence/bash-syntax.json',
        'evidence/bash-shellcheck.json',
        'evidence/bash-formatting.json',
        'evidence/bash-tests.json',
        'evidence/bash-toolchain.json',
        'evidence/bash-toolchain-bootstrap.json',
        'evidence/bash-project-sbom.cdx.json'
    )
    $completionArtifactPaths = [Collections.Generic.HashSet[string]]::new([StringComparer]::Ordinal)
    foreach ($artifact in @($completion.artifacts)) {
        if (-not $completionArtifactPaths.Add([string]$artifact.path)) { Add-Result Failed 'Completion evidence contains a duplicate artifact path.' ([string]$artifact.path) }
        $relative = ([string]$artifact.path -replace '^evidence/','')
        if ([IO.Path]::IsPathRooted($relative) -or $relative -match '(^|[\/])\.\.([\/]|$)') { Add-Result Failed 'Completion artifact path is unsafe.' ([string]$artifact.path); continue }
        $candidate = Join-Path $root $relative
        if (-not (Test-Path -LiteralPath $candidate -PathType Leaf)) { Add-Result Failed 'Completion artifact is missing.' ([string]$artifact.path); continue }
        $actualHash = (Get-FileHash -LiteralPath $candidate -Algorithm SHA256).Hash.ToLowerInvariant()
        if ($actualHash -cne ([string]$artifact.sha256).ToLowerInvariant()) { Add-Result Failed 'Completion artifact SHA-256 mismatch.' ([string]$artifact.path) }
        if ([int64]$artifact.sizeBytes -ne (Get-Item -LiteralPath $candidate).Length) { Add-Result Failed 'Completion artifact size mismatch.' ([string]$artifact.path) }
    }
    foreach ($expectedPath in $expectedCompletionArtifacts) {
        if (-not $completionArtifactPaths.Contains($expectedPath)) { Add-Result Failed 'Completion evidence omits a required Bash artifact.' $expectedPath }
    }
    foreach ($actualPath in $completionArtifactPaths) {
        if ($expectedCompletionArtifacts -cnotcontains $actualPath) { Add-Result Failed 'Completion evidence lists an unexpected Bash artifact.' $actualPath }
    }
}

$phaseDocuments = [ordered]@{
    syntax = Get-Json 'bash-syntax.json'
    shellcheck = Get-Json 'bash-shellcheck.json'
    formatting = Get-Json 'bash-formatting.json'
    tests = Get-Json 'bash-tests.json'
}
$localTests = Get-Json 'local-test-results.json'
if ($null -eq $localTests -or @($localTests).Count -eq 0) {
    Add-Result Failed 'Aggregate Bash test evidence is empty or invalid.' 'local-test-results.json'
}
else {
    $requiredTestFields = @('schemaVersion','name','category','status','requiredValidation','evidenceSource','command','workingDirectory','startedAtUtc','completedAtUtc','durationSeconds','runtime','toolVersion','exitCode','summary','warnings')
    foreach ($test in @($localTests)) {
        if ($test -isnot [Collections.IDictionary]) { Add-Result Failed 'Aggregate Bash test evidence contains a non-object record.' 'local-test-results.json'; continue }
        foreach ($field in $requiredTestFields) {
            if (-not $test.ContainsKey($field)) { Add-Result Failed "Aggregate Bash test record is missing '$field'." 'local-test-results.json' }
        }
        if ($test.ContainsKey('status') -and $canonical -cnotcontains [string]$test.status) { Add-Result Failed 'Aggregate Bash test record uses a noncanonical status.' 'local-test-results.json' }
        if ($test.status -eq 'Passed' -and [int]$test.exitCode -ne 0) { Add-Result Failed 'Passed aggregate test record must have exit code zero.' 'local-test-results.json' }
        if ($test.status -in @('Blocked','NotRun') -and $null -ne $test.exitCode) { Add-Result Failed 'Blocked or NotRun aggregate test record must have a null exit code.' 'local-test-results.json' }
    }
}
$evidenceValidation = Get-Json 'evidence-validation.json'
if ($evidenceValidation) {
    foreach ($field in @('results','failed','blocked','notRun')) {
        if (-not $evidenceValidation.ContainsKey($field)) { Add-Result Failed "Evidence-validation report is missing '$field'." 'evidence-validation.json' }
    }
    if ([int]$evidenceValidation.failed -ne 0 -or [int]$evidenceValidation.blocked -ne 0 -or [int]$evidenceValidation.notRun -ne 0) {
        Add-Result Failed 'Completion-evidence validation did not pass cleanly.' 'evidence-validation.json'
    }
    $nonPassingValidationResults = @($evidenceValidation.results | Where-Object {
        $_ -isnot [Collections.IDictionary] -or
        -not $_.Contains('status') -or
        ([string]$_['status']) -cne 'Passed'
    })
    if ($nonPassingValidationResults.Count -gt 0) {
        Add-Result Failed 'Evidence-validation report contains a non-passing result.' 'evidence-validation.json'
    }
}
foreach ($entry in $phaseDocuments.GetEnumerator()) {
    if ($entry.Value -and $canonical -cnotcontains [string]$entry.Value.status) { Add-Result Failed 'Phase uses a noncanonical status.' "bash-$($entry.Key).json" }
}
if ($ExpectedConclusion -eq 'success') {
    foreach ($entry in $phaseDocuments.GetEnumerator()) {
        if (-not $entry.Value -or $entry.Value.status -cne 'Passed') { Add-Result Failed 'Successful workflow requires every Bash phase to pass.' "bash-$($entry.Key).json" }
    }
}
else {
    if (-not $ExpectedFailurePhase) { Add-Result Failed 'Controlled failure verification requires ExpectedFailurePhase.' }
    elseif ($phaseDocuments[$ExpectedFailurePhase].status -cne 'Failed') { Add-Result Failed 'Intended controlled-failure phase did not fail.' "bash-$ExpectedFailurePhase.json" }
    foreach ($entry in $phaseDocuments.GetEnumerator()) {
        if ($entry.Key -eq $ExpectedFailurePhase) { continue }
        $allowed = if ($entry.Key -eq 'tests' -and $ExpectedFailurePhase -ne 'tests') { @('NotRun') } else { @('Passed') }
        if ($allowed -cnotcontains [string]$entry.Value.status) { Add-Result Failed 'Unexpected additional controlled-failure outcome.' "bash-$($entry.Key).json" }
    }
}

$toolchain = Get-Json 'bash-toolchain.json'
$bootstrap = Get-Json 'bash-toolchain-bootstrap.json'
if ($toolchain) {
    if ($toolchain.status -cne 'Passed') { Add-Result Failed 'Toolchain provenance did not pass.' 'bash-toolchain.json' }
    if ([string]$toolchain.details.bash.version -notmatch '^5\.2\.') { Add-Result Failed 'Bash runtime version is not supported 5.2.' 'bash-toolchain.json' }
    if ([string]$toolchain.details.bash.executableSha256 -notmatch '^[0-9a-f]{64}$') { Add-Result Failed 'Bash executable hash is missing.' 'bash-toolchain.json' }
    foreach ($expected in @($lock.tools)) {
        $actual = @($toolchain.details.tools | Where-Object name -CEQ $expected.name)
        if ($actual.Count -ne 1 -or $actual[0].version -cne $expected.version -or $actual[0].artifactSha256 -cne $expected.sha256) { Add-Result Failed "Toolchain record mismatch for $($expected.name)." 'bash-toolchain.json' }
    }
}
if ($bootstrap) {
    if ($bootstrap.status -cne 'Passed') { Add-Result Failed 'Toolchain bootstrap did not pass.' 'bash-toolchain-bootstrap.json' }
    foreach ($expected in @($lock.tools)) {
        $actual = @($bootstrap.details.installed | Where-Object name -CEQ $expected.name)
        if ($actual.Count -ne 1 -or $actual[0].version -cne $expected.version -or $actual[0].artifactSha256 -cne $expected.sha256) { Add-Result Failed "Bootstrap artifact mismatch for $($expected.name)." 'bash-toolchain-bootstrap.json' }
    }
}

$sbom = Get-Json 'bash-project-sbom.cdx.json'
if ($sbom) {
    if ($sbom.bomFormat -cne 'CycloneDX' -or $sbom.specVersion -cne '1.5') { Add-Result Failed 'Bash SBOM must be CycloneDX 1.5.' 'bash-project-sbom.cdx.json' }
    foreach ($expected in @($lock.tools)) {
        $component = @($sbom.components | Where-Object {
            $_ -is [Collections.IDictionary] -and
            $_.Contains('purl') -and
            ([string]$_['purl']) -ceq ([string]$expected.purl)
        })
        if ($component.Count -ne 1 -or $component[0].version -cne $expected.version -or $component[0].hashes[0].content -cne $expected.sha256) { Add-Result Failed "SBOM component mismatch for $($expected.name)." 'bash-project-sbom.cdx.json' }
    }
}

$outcomes = Get-Json 'step-outcomes.json'
if ($outcomes) {
    $nonFunctionalOutcomes = @('initialize','boundary','python','bootstrap','regression','staging','normalization','completion','evidence')
    foreach ($name in @($nonFunctionalOutcomes + 'functional')) {
        if (-not $outcomes.ContainsKey($name)) { Add-Result Failed "Step outcome '$name' is missing." 'step-outcomes.json' }
    }
    $expectedFunctional = if ($ExpectedConclusion -eq 'success') { 'success' } else { 'failure' }
    if ($outcomes.functional -cne $expectedFunctional) { Add-Result Failed 'Functional step outcome does not match expected conclusion.' 'step-outcomes.json' }
    foreach ($name in $nonFunctionalOutcomes) {
        if ($outcomes[$name] -cne 'success') { Add-Result Failed "Mandatory step '$name' did not succeed." 'step-outcomes.json' }
    }
}

$files = @(Get-ChildItem -LiteralPath $root -Recurse -File)
$absoluteMatches = @($files | Select-String -Pattern '([A-Za-z]:\\|/(home|tmp|mnt|root|var|etc|opt|usr|workspace|github|run)(/|\\))' -ErrorAction SilentlyContinue)
foreach ($match in $absoluteMatches) { Add-Result Failed 'Absolute workstation path leaked into Bash evidence.' ([IO.Path]::GetRelativePath($root, $match.Path).Replace('\','/')) }
$secretPatterns = @(
    '(?i)(password|passwd|client[_-]?secret|api[_-]?key|access[_-]?token)\s*[:=]\s*\S{8,}',
    '(?i)Authorization\s*[:=]\s*(Bearer|Basic)\s+\S+',
    '(?i)\b(gh[pousr]_[A-Za-z0-9_]{20,}|github_pat_[A-Za-z0-9_]{20,})\b',
    '(?i)https?://[^/\s:@]+:[^@\s/]+@'
)
foreach ($pattern in $secretPatterns) {
    foreach ($match in @($files | Select-String -Pattern $pattern -ErrorAction SilentlyContinue)) { Add-Result Failed 'Credential-like output found in Bash evidence.' ([IO.Path]::GetRelativePath($root, $match.Path).Replace('\','/')) }
}

if (-not @($results | Where-Object status -eq 'Failed')) { Add-Result Passed 'Bash workflow evidence artifact verification completed.' }
$report = [ordered]@{
    schemaVersion = '1.0.0'
    generatedAtUtc = (Get-Date).ToUniversalTime().ToString('o')
    repository = $ExpectedRepository
    commitSha = $ExpectedCommitSha
    branch = $ExpectedBranch
    runId = $ExpectedRunId
    jobId = $(if ($ExpectedJobId) { $ExpectedJobId } else { $null })
    artifactId = $ExpectedArtifactId
    artifactName = $ExpectedArtifactName
    zipSha256 = $zipSha
    standardsRepository = $ExpectedStandardsRepository
    standardsWorkflowSha = $ExpectedStandardsWorkflowSha
    expectedConclusion = $ExpectedConclusion
    expectedFailurePhase = $(if ($ExpectedFailurePhase) { $ExpectedFailurePhase } else { $null })
    results = @($results)
    failed = @($results | Where-Object status -eq 'Failed').Count
}
if ($OutputJson) { $report | ConvertTo-OrderedJson | Set-Content -LiteralPath $OutputJson -Encoding utf8 }
$results | ForEach-Object { "[$($_.status)] $($_.path) $($_.message)" }
if ($report.failed -gt 0) { exit 1 }
