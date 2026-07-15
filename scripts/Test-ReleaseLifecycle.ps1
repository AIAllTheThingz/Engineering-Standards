<#
.SYNOPSIS
Validates machine-readable pre-release, publication, and post-release gates.
.DESCRIPTION
Checks a release-lifecycle record for complete mandatory controls, immutable
commit binding, independently verified workflow artifacts, downstream canary
coverage, formal approvals, publication integrity, and post-release follow-up.
The command is read-only. DryRun records are validated as synthetic evidence;
Live records are also bound to the current Git HEAD and clean worktree.
.PARAMETER Path
Repository root containing VERSION, CHANGELOG.md, schemas, and compatibility data.
.PARAMETER EvidencePath
Repository-relative path to the release-lifecycle JSON record.
.PARAMETER Stage
Gate to enforce. Record validates consistency without requiring a Passed stage.
.PARAMETER OutputJson
Optional repository-relative or absolute JSON validation report path.
.EXAMPLE
pwsh -NoProfile -File scripts/Test-ReleaseLifecycle.ps1 -Path . -EvidencePath tests/fixtures/release-lifecycle/valid/pre-release.json -Stage PreRelease
.OUTPUTS
Standard validation results and an optional JSON report.
#>
[CmdletBinding()]
param(
    [Parameter()]
    [string]$Path = '.',

    [Parameter(Mandatory)]
    [string]$EvidencePath,

    [Parameter()]
    [ValidateSet('Record', 'PreRelease', 'Publication', 'PostRelease', 'All')]
    [string]$Stage = 'PreRelease',

    [Parameter()]
    [string]$OutputJson
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

Import-Module (Join-Path $PSScriptRoot 'GovernanceValidation.psm1') -Force

$root = (Resolve-Path -LiteralPath $Path).Path
$results = [System.Collections.Generic.List[object]]::new()
$allowedStatuses = @('Passed', 'Failed', 'Blocked', 'NotRun', 'NotApplicable')
$fullShaPattern = '^[0-9a-f]{40}$'
$sha256Pattern = '^[0-9a-f]{64}$'
$requiredPreReleaseChecks = @(
    'clean-worktree',
    'repository-validation',
    'pester',
    'psscriptanalyzer',
    'json-schemas',
    'workflow-architecture',
    'codex-skills',
    'documentation',
    'evidence',
    'release-consistency'
)
$requiredCanaryScenarios = [ordered]@{
    'success' = 'success'
    'controlled-failure' = 'failure'
    'governance-version-mismatch' = 'failure'
    'missing-required-file' = 'failure'
    'mandatory-control-disablement' = 'failure'
}

function Add-ReleaseFinding {
    param(
        [Parameter(Mandatory)][string]$Code,
        [Parameter(Mandatory)][string]$Message,
        [string]$FindingPath = $EvidencePath
    )

    $results.Add((New-ValidationResult -Status Failed -Message "$Code $Message" -Path $FindingPath -Data ([ordered]@{ code = $Code })))
}

function Get-Member {
    param(
        [AllowNull()][object]$Object,
        [Parameter(Mandatory)][string]$Name
    )

    if ($null -eq $Object) { return $null }
    Get-JsonMemberValue -InputObject $Object -Name $Name
}

function Test-RequiredMembers {
    param(
        [AllowNull()][object]$Object,
        [Parameter(Mandatory)][string[]]$Names,
        [Parameter(Mandatory)][string]$Context
    )

    if ($null -eq $Object -or $Object -is [string] -or $Object -is [System.Collections.IList]) {
        Add-ReleaseFinding -Code 'RLG001' -Message "$Context must be an object."
        return $false
    }

    $complete = $true
    foreach ($name in $Names) {
        if (-not (Test-JsonMember -InputObject $Object -Name $name)) {
            Add-ReleaseFinding -Code 'RLG001' -Message "$Context is missing required member '$name'."
            $complete = $false
        }
    }
    $complete
}

function Test-StatusRecord {
    param(
        [AllowNull()][object]$Object,
        [Parameter(Mandatory)][string]$Context,
        [switch]$RequirePassed
    )

    if (-not (Test-RequiredMembers -Object $Object -Names @('status', 'reason') -Context $Context)) { return $false }
    $status = [string](Get-Member -Object $Object -Name 'status')
    $reason = Get-Member -Object $Object -Name 'reason'
    if ($allowedStatuses -cnotcontains $status) {
        Add-ReleaseFinding -Code 'RLG002' -Message "$Context has unsupported status '$status'."
        return $false
    }
    if ($status -ceq 'Passed' -and $null -ne $reason) {
        Add-ReleaseFinding -Code 'RLG003' -Message "$Context is Passed and must have a null reason."
    }
    if ($status -cne 'Passed' -and ([string]::IsNullOrWhiteSpace([string]$reason) -or ([string]$reason).Length -lt 10)) {
        Add-ReleaseFinding -Code 'RLG004' -Message "$Context with status '$status' requires an actionable reason of at least 10 characters."
    }
    if ($RequirePassed -and $status -cne 'Passed') {
        Add-ReleaseFinding -Code 'RLG005' -Message "$Context must be Passed to satisfy the requested gate; found '$status'."
    }
    $status -ceq 'Passed'
}

function Test-ArtifactProof {
    param(
        [AllowNull()][object]$Artifact,
        [Parameter(Mandatory)][string]$Context
    )

    if (-not (Test-RequiredMembers -Object $Artifact -Names @('name', 'artifactId', 'sha256', 'downloaded', 'verified') -Context $Context)) { return }
    if ([string]::IsNullOrWhiteSpace([string](Get-Member -Object $Artifact -Name 'name'))) {
        Add-ReleaseFinding -Code 'RLG010' -Message "$Context must identify the artifact name."
    }
    if ([int64](Get-Member -Object $Artifact -Name 'artifactId') -lt 1) {
        Add-ReleaseFinding -Code 'RLG011' -Message "$Context artifactId must be positive."
    }
    if ([string](Get-Member -Object $Artifact -Name 'sha256') -cnotmatch $sha256Pattern) {
        Add-ReleaseFinding -Code 'RLG012' -Message "$Context sha256 must be a lowercase 64-character digest."
    }
    if ((Get-Member -Object $Artifact -Name 'downloaded') -isnot [bool] -or -not [bool](Get-Member -Object $Artifact -Name 'downloaded')) {
        Add-ReleaseFinding -Code 'RLG013' -Message "$Context must record an independent artifact download."
    }
    if ((Get-Member -Object $Artifact -Name 'verified') -isnot [bool] -or -not [bool](Get-Member -Object $Artifact -Name 'verified')) {
        Add-ReleaseFinding -Code 'RLG014' -Message "$Context must record successful independent verification."
    }
}

function Test-ExactTarget {
    param(
        [AllowNull()][object]$Object,
        [Parameter(Mandatory)][string]$Context,
        [Parameter(Mandatory)][string]$CandidateSha,
        [string]$Member = 'targetSha'
    )

    $actual = [string](Get-Member -Object $Object -Name $Member)
    if ($actual -cne $CandidateSha) {
        Add-ReleaseFinding -Code 'RLG020' -Message "$Context $Member '$actual' does not match candidateSha '$CandidateSha'."
    }
}

function Test-CanaryProof {
    param(
        [AllowNull()][object]$Canary,
        [Parameter(Mandatory)][string]$Context,
        [Parameter(Mandatory)][string]$CandidateSha,
        [switch]$PublishedReferenceRequired
    )

    if (-not (Test-RequiredMembers -Object $Canary -Names @('status', 'reason', 'repository', 'canaryCommitSha', 'standardsSha', 'scenarios') -Context $Context)) { return }
    $passed = Test-StatusRecord -Object $Canary -Context $Context -RequirePassed
    if (-not $passed) { return }
    if ([string](Get-Member -Object $Canary -Name 'repository') -cnotmatch '^[^/\s]+/[^/\s]+$') {
        Add-ReleaseFinding -Code 'RLG030' -Message "$Context repository must use owner/name syntax."
    }
    if ([string](Get-Member -Object $Canary -Name 'canaryCommitSha') -cnotmatch $fullShaPattern) {
        Add-ReleaseFinding -Code 'RLG031' -Message "$Context canaryCommitSha must be a full lowercase SHA."
    }
    Test-ExactTarget -Object $Canary -Context $Context -CandidateSha $CandidateSha -Member 'standardsSha'
    if ($PublishedReferenceRequired) {
        $publishedRef = [string](Get-Member -Object $Canary -Name 'publishedRef')
        if ($publishedRef -notmatch '^v[0-9]+\.[0-9]+\.[0-9]+(?:-[0-9A-Za-z.-]+)?$') {
            Add-ReleaseFinding -Code 'RLG032' -Message "$Context must identify the published immutable version ref."
        }
    }

    $scenarios = @(Get-Member -Object $Canary -Name 'scenarios')
    $seen = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::Ordinal)
    foreach ($scenario in $scenarios) {
        if (-not (Test-RequiredMembers -Object $scenario -Names @('name', 'runId', 'conclusion', 'expectedConclusion', 'verified', 'artifact') -Context "$Context scenario")) { continue }
        $name = [string](Get-Member -Object $scenario -Name 'name')
        if (-not $seen.Add($name)) {
            Add-ReleaseFinding -Code 'RLG033' -Message "$Context contains duplicate scenario '$name'."
            continue
        }
        if (-not $requiredCanaryScenarios.Contains($name)) {
            Add-ReleaseFinding -Code 'RLG034' -Message "$Context contains unknown scenario '$name'."
            continue
        }
        $expected = [string]$requiredCanaryScenarios[$name]
        if ([int64](Get-Member -Object $scenario -Name 'runId') -lt 1) {
            Add-ReleaseFinding -Code 'RLG035' -Message "$Context scenario '$name' runId must be positive."
        }
        if ([string](Get-Member -Object $scenario -Name 'expectedConclusion') -cne $expected -or [string](Get-Member -Object $scenario -Name 'conclusion') -cne $expected) {
            Add-ReleaseFinding -Code 'RLG036' -Message "$Context scenario '$name' must conclude '$expected' exactly."
        }
        if ((Get-Member -Object $scenario -Name 'verified') -isnot [bool] -or -not [bool](Get-Member -Object $scenario -Name 'verified')) {
            Add-ReleaseFinding -Code 'RLG037' -Message "$Context scenario '$name' must be independently verified."
        }
        Test-ArtifactProof -Artifact (Get-Member -Object $scenario -Name 'artifact') -Context "$Context scenario '$name' artifact"
    }
    foreach ($requiredName in $requiredCanaryScenarios.Keys) {
        if (-not $seen.Contains([string]$requiredName)) {
            Add-ReleaseFinding -Code 'RLG038' -Message "$Context is missing mandatory scenario '$requiredName'."
        }
    }
}

function Test-CompatibilityMatrix {
    param(
        [AllowNull()][object]$Reference,
        [Parameter(Mandatory)][object]$Metadata,
        [Parameter(Mandatory)][string]$Version
    )

    if (-not (Test-RequiredMembers -Object $Reference -Names @('path', 'schemaVersion') -Context 'compatibilityMatrix')) { return }
    $relativePath = [string](Get-Member -Object $Reference -Name 'path')
    try {
        $matrixPath = Resolve-SafePath -Root $root -ChildPath $relativePath
    }
    catch {
        Add-ReleaseFinding -Code 'RLG040' -Message "compatibilityMatrix path is unsafe: $($_.Exception.Message)"
        return
    }
    if (-not (Test-Path -LiteralPath $matrixPath -PathType Leaf)) {
        Add-ReleaseFinding -Code 'RLG041' -Message "Compatibility matrix '$relativePath' does not exist."
        return
    }
    try {
        $matrix = Read-JsonFile -Path $matrixPath
    }
    catch {
        Add-ReleaseFinding -Code 'RLG042' -Message "Compatibility matrix could not be parsed: $($_.Exception.Message)"
        return
    }
    if ([string](Get-Member -Object $matrix -Name 'schemaVersion') -cne [string](Get-Member -Object $Reference -Name 'schemaVersion')) {
        Add-ReleaseFinding -Code 'RLG043' -Message 'Compatibility matrix schemaVersion does not match the release record.'
    }
    $published = @((Get-Member -Object $matrix -Name 'governanceReleases') | Where-Object { [string](Get-Member -Object $_ -Name 'version') -ceq $Version })
    $unreleased = Get-Member -Object $matrix -Name 'unreleasedContract'
    $matchingUnreleased = $null -ne $unreleased -and [string](Get-Member -Object $unreleased -Name 'governanceVersion') -ceq $Version
    if ($published.Count -eq 0 -and -not $matchingUnreleased) {
        Add-ReleaseFinding -Code 'RLG044' -Message "Compatibility matrix has no published or unreleased contract for version '$Version'."
        return
    }
    $sources = @($published)
    if ($matchingUnreleased) { $sources += $unreleased }
    $matrixManifestVersions = @($sources | ForEach-Object { @(Get-Member -Object $_ -Name 'projectManifestSchemaVersions') } | Select-Object -Unique)
    $recordManifestVersions = @(Get-Member -Object $Metadata -Name 'supportedProjectManifestSchemaVersions')
    foreach ($schemaVersion in $recordManifestVersions) {
        if ($matrixManifestVersions -cnotcontains [string]$schemaVersion) {
            Add-ReleaseFinding -Code 'RLG045' -Message "Metadata project-manifest schema '$schemaVersion' is absent from the compatibility matrix."
        }
    }
    $workflowInterface = [string](Get-Member -Object $Metadata -Name 'workflowInterfaceVersion')
    $matrixInterfaces = @($sources | ForEach-Object { @(Get-Member -Object $_ -Name 'workflowInterfaceVersions') } | Select-Object -Unique)
    if ($matrixInterfaces -cnotcontains $workflowInterface) {
        Add-ReleaseFinding -Code 'RLG046' -Message "Workflow interface '$workflowInterface' is absent from the compatibility matrix."
    }
}

try {
    $evidenceFullPath = Resolve-SafePath -Root $root -ChildPath $EvidencePath
}
catch {
    Add-ReleaseFinding -Code 'RLG000' -Message "EvidencePath is unsafe: $($_.Exception.Message)"
    $report = New-ValidationReport -Results @($results)
    Write-ValidationReport -Report $report -OutputJson $OutputJson
    exit 1
}

if (-not (Test-Path -LiteralPath $evidenceFullPath -PathType Leaf)) {
    Add-ReleaseFinding -Code 'RLG000' -Message "Release lifecycle record '$EvidencePath' does not exist."
    $report = New-ValidationReport -Results @($results)
    Write-ValidationReport -Report $report -OutputJson $OutputJson
    exit 1
}

try {
    $record = Read-JsonFile -Path $evidenceFullPath
}
catch {
    Add-ReleaseFinding -Code 'RLG000' -Message "Release lifecycle record could not be parsed: $($_.Exception.Message)"
    $report = New-ValidationReport -Results @($results)
    Write-ValidationReport -Report $report -OutputJson $OutputJson
    exit 1
}

$topLevelRequired = @(
    'schemaVersion', 'recordType', 'mode', 'synthetic', 'repository', 'version',
    'candidateSha', 'finalHeadSha', 'createdAtUtc', 'createdBy', 'releaseNotes',
    'compatibilityMatrix', 'preRelease', 'publication', 'postRelease', 'exceptions'
)
$topLevelComplete = Test-RequiredMembers -Object $record -Names $topLevelRequired -Context 'release lifecycle record'
if ($topLevelComplete) {
    if ([string](Get-Member -Object $record -Name 'schemaVersion') -cne '1.0.0') {
        Add-ReleaseFinding -Code 'RLG050' -Message 'schemaVersion must be 1.0.0.'
    }
    if ([string](Get-Member -Object $record -Name 'recordType') -cne 'release-lifecycle') {
        Add-ReleaseFinding -Code 'RLG051' -Message "recordType must be 'release-lifecycle'."
    }
    $mode = [string](Get-Member -Object $record -Name 'mode')
    $synthetic = Get-Member -Object $record -Name 'synthetic'
    if (@('DryRun', 'Live') -cnotcontains $mode) {
        Add-ReleaseFinding -Code 'RLG052' -Message "mode must be DryRun or Live; found '$mode'."
    }
    if ($synthetic -isnot [bool]) {
        Add-ReleaseFinding -Code 'RLG053' -Message 'synthetic must be a boolean.'
    }
    elseif (($mode -ceq 'DryRun') -ne [bool]$synthetic) {
        Add-ReleaseFinding -Code 'RLG054' -Message 'DryRun records must be synthetic and Live records must not be synthetic.'
    }
    if ([string](Get-Member -Object $record -Name 'repository') -cnotmatch '^[^/\s]+/[^/\s]+$') {
        Add-ReleaseFinding -Code 'RLG055' -Message 'repository must use owner/name syntax.'
    }
    $version = [string](Get-Member -Object $record -Name 'version')
    if ($version -notmatch '^(0|[1-9]\d*)\.(0|[1-9]\d*)\.(0|[1-9]\d*)(?:-[0-9A-Za-z.-]+)?$') {
        Add-ReleaseFinding -Code 'RLG056' -Message "version '$version' is not canonical semantic version syntax."
    }
    $candidateSha = [string](Get-Member -Object $record -Name 'candidateSha')
    if ($candidateSha -cnotmatch $fullShaPattern) {
        Add-ReleaseFinding -Code 'RLG057' -Message 'candidateSha must be a full lowercase 40-character SHA.'
    }
    if ([string](Get-Member -Object $record -Name 'finalHeadSha') -cne $candidateSha) {
        Add-ReleaseFinding -Code 'RLG058' -Message 'finalHeadSha must equal candidateSha; approvals and evidence are stale after any head change.'
    }
    try { [datetimeoffset](Get-Member -Object $record -Name 'createdAtUtc') | Out-Null }
    catch { Add-ReleaseFinding -Code 'RLG059' -Message 'createdAtUtc must be an ISO-8601 date-time.' }
    if ([string]::IsNullOrWhiteSpace([string](Get-Member -Object $record -Name 'createdBy'))) {
        Add-ReleaseFinding -Code 'RLG060' -Message 'createdBy must identify the record owner.'
    }

    $releaseNotes = Get-Member -Object $record -Name 'releaseNotes'
    if (Test-RequiredMembers -Object $releaseNotes -Names @('path', 'reviewedSha256') -Context 'releaseNotes') {
        $releaseNotesPath = [string](Get-Member -Object $releaseNotes -Name 'path')
        try {
            $releaseNotesFullPath = Resolve-SafePath -Root $root -ChildPath $releaseNotesPath
            if (-not (Test-Path -LiteralPath $releaseNotesFullPath -PathType Leaf)) {
                Add-ReleaseFinding -Code 'RLG061' -Message "Release notes '$releaseNotesPath' do not exist."
            }
            else {
                $actualNotesHash = (Get-FileHash -LiteralPath $releaseNotesFullPath -Algorithm SHA256).Hash.ToLowerInvariant()
                if ([string](Get-Member -Object $releaseNotes -Name 'reviewedSha256') -cne $actualNotesHash) {
                    Add-ReleaseFinding -Code 'RLG062' -Message 'Reviewed release-notes hash does not match the repository file.'
                }
            }
        }
        catch { Add-ReleaseFinding -Code 'RLG063' -Message "Release notes path is unsafe: $($_.Exception.Message)" }
    }

    $requestedStages = if ($Stage -ceq 'All') { @('PreRelease', 'Publication', 'PostRelease') } elseif ($Stage -ceq 'Record') { @() } else { @($Stage) }
    $preRelease = Get-Member -Object $record -Name 'preRelease'
    $publication = Get-Member -Object $record -Name 'publication'
    $postRelease = Get-Member -Object $record -Name 'postRelease'
    $prePassed = Test-StatusRecord -Object $preRelease -Context 'preRelease' -RequirePassed:($requestedStages -ccontains 'PreRelease')
    $publicationPassed = Test-StatusRecord -Object $publication -Context 'publication' -RequirePassed:($requestedStages -ccontains 'Publication')
    $postPassed = Test-StatusRecord -Object $postRelease -Context 'postRelease' -RequirePassed:($requestedStages -ccontains 'PostRelease')

    if ($prePassed) {
        $preRequired = @('status', 'reason', 'checks', 'successRun', 'controlledFailureRun', 'downstreamCanary', 'metadataConsistency', 'approvals', 'protection')
        if (Test-RequiredMembers -Object $preRelease -Names $preRequired -Context 'preRelease') {
            $checks = @(Get-Member -Object $preRelease -Name 'checks')
            $seenChecks = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::Ordinal)
            foreach ($check in $checks) {
                if (-not (Test-RequiredMembers -Object $check -Names @('id', 'status', 'reason', 'summary', 'targetSha', 'evidence') -Context 'preRelease check')) { continue }
                $checkId = [string](Get-Member -Object $check -Name 'id')
                if (-not $seenChecks.Add($checkId)) { Add-ReleaseFinding -Code 'RLG070' -Message "preRelease has duplicate check '$checkId'." }
                if ($requiredPreReleaseChecks -cnotcontains $checkId) { Add-ReleaseFinding -Code 'RLG071' -Message "preRelease has unknown mandatory check '$checkId'." }
                [void](Test-StatusRecord -Object $check -Context "preRelease check '$checkId'" -RequirePassed)
                Test-ExactTarget -Object $check -Context "preRelease check '$checkId'" -CandidateSha $candidateSha
                if ([string]::IsNullOrWhiteSpace([string](Get-Member -Object $check -Name 'summary'))) { Add-ReleaseFinding -Code 'RLG072' -Message "preRelease check '$checkId' requires a summary." }
                if (@(Get-Member -Object $check -Name 'evidence').Count -eq 0) { Add-ReleaseFinding -Code 'RLG073' -Message "preRelease check '$checkId' requires at least one evidence reference." }
            }
            foreach ($requiredCheck in $requiredPreReleaseChecks) {
                if (-not $seenChecks.Contains($requiredCheck)) { Add-ReleaseFinding -Code 'RLG074' -Message "preRelease is missing mandatory check '$requiredCheck'." }
            }

            $successRun = Get-Member -Object $preRelease -Name 'successRun'
            if (Test-RequiredMembers -Object $successRun -Names @('status', 'reason', 'runId', 'conclusion', 'targetSha', 'artifact') -Context 'preRelease.successRun') {
                [void](Test-StatusRecord -Object $successRun -Context 'preRelease.successRun' -RequirePassed)
                if ([int64](Get-Member -Object $successRun -Name 'runId') -lt 1 -or [string](Get-Member -Object $successRun -Name 'conclusion') -cne 'success') {
                    Add-ReleaseFinding -Code 'RLG075' -Message 'Exact-target success run must have a positive runId and success conclusion.'
                }
                Test-ExactTarget -Object $successRun -Context 'preRelease.successRun' -CandidateSha $candidateSha
                Test-ArtifactProof -Artifact (Get-Member -Object $successRun -Name 'artifact') -Context 'preRelease.successRun artifact'
            }

            $controlledFailure = Get-Member -Object $preRelease -Name 'controlledFailureRun'
            $controlledMembers = @('status', 'reason', 'runId', 'conclusion', 'targetSha', 'failedStep', 'priorMandatoryStepsPassed', 'artifactUploadedBeforeFailure', 'artifact')
            if (Test-RequiredMembers -Object $controlledFailure -Names $controlledMembers -Context 'preRelease.controlledFailureRun') {
                [void](Test-StatusRecord -Object $controlledFailure -Context 'preRelease.controlledFailureRun' -RequirePassed)
                if ([int64](Get-Member -Object $controlledFailure -Name 'runId') -lt 1 -or [string](Get-Member -Object $controlledFailure -Name 'conclusion') -cne 'failure') {
                    Add-ReleaseFinding -Code 'RLG076' -Message 'Controlled-failure proof must have a positive runId and failure conclusion.'
                }
                Test-ExactTarget -Object $controlledFailure -Context 'preRelease.controlledFailureRun' -CandidateSha $candidateSha
                if ([string](Get-Member -Object $controlledFailure -Name 'failedStep') -cne 'Enforce mandatory governance result') {
                    Add-ReleaseFinding -Code 'RLG077' -Message "Controlled-failure proof must fail only at 'Enforce mandatory governance result'."
                }
                if ((Get-Member -Object $controlledFailure -Name 'priorMandatoryStepsPassed') -isnot [bool] -or -not [bool](Get-Member -Object $controlledFailure -Name 'priorMandatoryStepsPassed')) {
                    Add-ReleaseFinding -Code 'RLG078' -Message 'Controlled-failure proof must show all prior mandatory steps passed.'
                }
                if ((Get-Member -Object $controlledFailure -Name 'artifactUploadedBeforeFailure') -isnot [bool] -or -not [bool](Get-Member -Object $controlledFailure -Name 'artifactUploadedBeforeFailure')) {
                    Add-ReleaseFinding -Code 'RLG079' -Message 'Controlled-failure proof must show artifact upload completed before final enforcement.'
                }
                Test-ArtifactProof -Artifact (Get-Member -Object $controlledFailure -Name 'artifact') -Context 'preRelease.controlledFailureRun artifact'
            }

            Test-CanaryProof -Canary (Get-Member -Object $preRelease -Name 'downstreamCanary') -Context 'preRelease.downstreamCanary' -CandidateSha $candidateSha

            $metadata = Get-Member -Object $preRelease -Name 'metadataConsistency'
            $metadataMembers = @('status', 'reason', 'versionFile', 'changelogVersion', 'releaseNotesVersion', 'workflowInterfaceVersion', 'supportedProjectManifestSchemaVersions', 'migrationGuidance')
            if (Test-RequiredMembers -Object $metadata -Names $metadataMembers -Context 'preRelease.metadataConsistency') {
                [void](Test-StatusRecord -Object $metadata -Context 'preRelease.metadataConsistency' -RequirePassed)
                foreach ($field in @('versionFile', 'changelogVersion', 'releaseNotesVersion')) {
                    if ([string](Get-Member -Object $metadata -Name $field) -cne $version) { Add-ReleaseFinding -Code 'RLG080' -Message "metadataConsistency.$field must equal release version '$version'." }
                }
                $versionPath = Join-Path $root 'VERSION'
                if (-not (Test-Path -LiteralPath $versionPath -PathType Leaf) -or (Get-Content -LiteralPath $versionPath -Raw).Trim() -cne $version) {
                    Add-ReleaseFinding -Code 'RLG081' -Message "Repository VERSION does not equal release version '$version'."
                }
                $changelogPath = Join-Path $root 'CHANGELOG.md'
                if (-not (Test-Path -LiteralPath $changelogPath -PathType Leaf) -or (Get-Content -LiteralPath $changelogPath -Raw) -notmatch "(?m)^## \[$([regex]::Escape($version))\](?:\s|$)") {
                    Add-ReleaseFinding -Code 'RLG082' -Message "CHANGELOG.md has no version '$version' release section."
                }
                $migrationPath = [string](Get-Member -Object $metadata -Name 'migrationGuidance')
                try {
                    $migrationFullPath = Resolve-SafePath -Root $root -ChildPath $migrationPath
                    if (-not (Test-Path -LiteralPath $migrationFullPath -PathType Leaf)) { Add-ReleaseFinding -Code 'RLG083' -Message "Migration guidance '$migrationPath' does not exist." }
                }
                catch { Add-ReleaseFinding -Code 'RLG084' -Message "Migration guidance path is unsafe: $($_.Exception.Message)" }
                Test-CompatibilityMatrix -Reference (Get-Member -Object $record -Name 'compatibilityMatrix') -Metadata $metadata -Version $version
            }

            $approvals = @(Get-Member -Object $preRelease -Name 'approvals')
            if ($approvals.Count -eq 0) { Add-ReleaseFinding -Code 'RLG085' -Message 'preRelease requires at least one formal human approval.' }
            $approvedReviewers = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::OrdinalIgnoreCase)
            foreach ($approval in $approvals) {
                $approvalMembers = @('reviewer', 'isHuman', 'decision', 'targetSha', 'location', 'submittedAtUtc')
                if (-not (Test-RequiredMembers -Object $approval -Names $approvalMembers -Context 'preRelease approval')) { continue }
                $reviewer = [string](Get-Member -Object $approval -Name 'reviewer')
                if ([string]::IsNullOrWhiteSpace($reviewer) -or -not $approvedReviewers.Add($reviewer)) { Add-ReleaseFinding -Code 'RLG086' -Message 'Approval reviewers must be nonblank and unique.' }
                if ((Get-Member -Object $approval -Name 'isHuman') -isnot [bool] -or -not [bool](Get-Member -Object $approval -Name 'isHuman') -or [string](Get-Member -Object $approval -Name 'decision') -cne 'Approved') {
                    Add-ReleaseFinding -Code 'RLG087' -Message "Approval by '$reviewer' must be a formal human Approved decision."
                }
                Test-ExactTarget -Object $approval -Context "approval by '$reviewer'" -CandidateSha $candidateSha
                if ([string](Get-Member -Object $approval -Name 'location') -notmatch '^https://github\.com/.+') { Add-ReleaseFinding -Code 'RLG088' -Message "Approval by '$reviewer' requires a GitHub location." }
                try { [datetimeoffset](Get-Member -Object $approval -Name 'submittedAtUtc') | Out-Null }
                catch { Add-ReleaseFinding -Code 'RLG089' -Message "Approval by '$reviewer' has an invalid submittedAtUtc." }
            }

            $protection = Get-Member -Object $preRelease -Name 'protection'
            if (Test-RequiredMembers -Object $protection -Names @('branch', 'tag') -Context 'preRelease.protection') {
                foreach ($kind in @('branch', 'tag')) {
                    $protectionRecord = Get-Member -Object $protection -Name $kind
                    if (Test-RequiredMembers -Object $protectionRecord -Names @('status', 'reason', 'pattern', 'verifiedAtUtc') -Context "preRelease.protection.$kind") {
                        [void](Test-StatusRecord -Object $protectionRecord -Context "preRelease.protection.$kind" -RequirePassed)
                        if ([string]::IsNullOrWhiteSpace([string](Get-Member -Object $protectionRecord -Name 'pattern'))) { Add-ReleaseFinding -Code 'RLG090' -Message "$kind protection pattern must not be blank." }
                        try { [datetimeoffset](Get-Member -Object $protectionRecord -Name 'verifiedAtUtc') | Out-Null }
                        catch { Add-ReleaseFinding -Code 'RLG091' -Message "$kind protection verifiedAtUtc is invalid." }
                    }
                }
            }
        }
    }

    if ($publicationPassed) {
        if (-not $prePassed) { Add-ReleaseFinding -Code 'RLG100' -Message 'publication cannot pass unless preRelease is Passed.' }
        if (Test-RequiredMembers -Object $publication -Names @('status', 'reason', 'tag', 'githubRelease', 'artifacts') -Context 'publication') {
            $tag = Get-Member -Object $publication -Name 'tag'
            $tagMembers = @('status', 'reason', 'name', 'kind', 'objectSha', 'targetSha', 'protected', 'rewritten', 'verifiedAtUtc')
            if (Test-RequiredMembers -Object $tag -Names $tagMembers -Context 'publication.tag') {
                [void](Test-StatusRecord -Object $tag -Context 'publication.tag' -RequirePassed)
                if ([string](Get-Member -Object $tag -Name 'name') -cne "v$version" -or [string](Get-Member -Object $tag -Name 'kind') -cne 'annotated') { Add-ReleaseFinding -Code 'RLG101' -Message "Publication tag must be annotated tag 'v$version'." }
                if ([string](Get-Member -Object $tag -Name 'objectSha') -cnotmatch $fullShaPattern) { Add-ReleaseFinding -Code 'RLG102' -Message 'Publication annotated tag objectSha must be a full lowercase SHA.' }
                Test-ExactTarget -Object $tag -Context 'publication.tag' -CandidateSha $candidateSha
                if ((Get-Member -Object $tag -Name 'protected') -isnot [bool] -or -not [bool](Get-Member -Object $tag -Name 'protected')) { Add-ReleaseFinding -Code 'RLG103' -Message 'Publication tag must be protected.' }
                if ((Get-Member -Object $tag -Name 'rewritten') -isnot [bool] -or [bool](Get-Member -Object $tag -Name 'rewritten')) { Add-ReleaseFinding -Code 'RLG104' -Message 'Publication tag must record rewritten=false.' }
            }
            $release = Get-Member -Object $publication -Name 'githubRelease'
            $releaseMembers = @('status', 'reason', 'url', 'targetSha', 'draft', 'prerelease', 'notesSha256', 'publishedAtUtc')
            if (Test-RequiredMembers -Object $release -Names $releaseMembers -Context 'publication.githubRelease') {
                [void](Test-StatusRecord -Object $release -Context 'publication.githubRelease' -RequirePassed)
                Test-ExactTarget -Object $release -Context 'publication.githubRelease' -CandidateSha $candidateSha
                if ((Get-Member -Object $release -Name 'draft') -isnot [bool] -or [bool](Get-Member -Object $release -Name 'draft')) { Add-ReleaseFinding -Code 'RLG105' -Message 'Published GitHub Release must not be a draft.' }
                $isPrereleaseVersion = $version -match '-'
                if ((Get-Member -Object $release -Name 'prerelease') -isnot [bool] -or [bool](Get-Member -Object $release -Name 'prerelease') -ne $isPrereleaseVersion) { Add-ReleaseFinding -Code 'RLG106' -Message 'GitHub Release prerelease state does not match the semantic version.' }
                if ([string](Get-Member -Object $release -Name 'notesSha256') -cne [string](Get-Member -Object $releaseNotes -Name 'reviewedSha256')) { Add-ReleaseFinding -Code 'RLG107' -Message 'Published notes hash does not match reviewed release notes.' }
            }
            $publicationArtifacts = @(Get-Member -Object $publication -Name 'artifacts')
            if ($publicationArtifacts.Count -eq 0) { Add-ReleaseFinding -Code 'RLG108' -Message 'Publication requires at least one hashed artifact with provenance.' }
            foreach ($artifact in $publicationArtifacts) {
                if (Test-RequiredMembers -Object $artifact -Names @('name', 'sha256', 'provenance') -Context 'publication artifact') {
                    if ([string](Get-Member -Object $artifact -Name 'sha256') -cnotmatch $sha256Pattern) { Add-ReleaseFinding -Code 'RLG109' -Message 'Publication artifact sha256 is invalid.' }
                    if ([string]::IsNullOrWhiteSpace([string](Get-Member -Object $artifact -Name 'provenance'))) { Add-ReleaseFinding -Code 'RLG110' -Message 'Publication artifact provenance must not be blank.' }
                }
            }
        }
    }

    if ($postPassed) {
        if (-not $publicationPassed) { Add-ReleaseFinding -Code 'RLG120' -Message 'postRelease cannot pass unless publication is Passed.' }
        $postMembers = @('status', 'reason', 'refetchedTag', 'githubReleaseVerification', 'downstreamCanary', 'regressions', 'followUpIssues', 'recordPath', 'compatibilityMatrixUpdated')
        if (Test-RequiredMembers -Object $postRelease -Names $postMembers -Context 'postRelease') {
            $refetchedTag = Get-Member -Object $postRelease -Name 'refetchedTag'
            if (Test-RequiredMembers -Object $refetchedTag -Names @('status', 'reason', 'targetSha', 'verifiedAtUtc') -Context 'postRelease.refetchedTag') {
                [void](Test-StatusRecord -Object $refetchedTag -Context 'postRelease.refetchedTag' -RequirePassed)
                Test-ExactTarget -Object $refetchedTag -Context 'postRelease.refetchedTag' -CandidateSha $candidateSha
            }
            $releaseVerification = Get-Member -Object $postRelease -Name 'githubReleaseVerification'
            if (Test-RequiredMembers -Object $releaseVerification -Names @('status', 'reason', 'targetSha', 'draft', 'prerelease', 'verifiedAtUtc') -Context 'postRelease.githubReleaseVerification') {
                [void](Test-StatusRecord -Object $releaseVerification -Context 'postRelease.githubReleaseVerification' -RequirePassed)
                Test-ExactTarget -Object $releaseVerification -Context 'postRelease.githubReleaseVerification' -CandidateSha $candidateSha
                if ([bool](Get-Member -Object $releaseVerification -Name 'draft')) { Add-ReleaseFinding -Code 'RLG121' -Message 'Post-release verification found a draft GitHub Release.' }
            }
            Test-CanaryProof -Canary (Get-Member -Object $postRelease -Name 'downstreamCanary') -Context 'postRelease.downstreamCanary' -CandidateSha $candidateSha -PublishedReferenceRequired
            $regressions = @(Get-Member -Object $postRelease -Name 'regressions')
            $followUps = @(Get-Member -Object $postRelease -Name 'followUpIssues')
            $defects = @($regressions | Where-Object { [string](Get-Member -Object $_ -Name 'disposition') -ceq 'Defect' })
            if ($defects.Count -gt 0 -and $followUps.Count -lt $defects.Count) { Add-ReleaseFinding -Code 'RLG122' -Message 'Every downstream defect regression requires a follow-up issue.' }
            foreach ($followUp in $followUps) {
                if ([string]$followUp -notmatch '^https://github\.com/.+/issues/\d+$') { Add-ReleaseFinding -Code 'RLG123' -Message "Follow-up issue '$followUp' is not a canonical GitHub issue URL." }
            }
            $recordPath = [string](Get-Member -Object $postRelease -Name 'recordPath')
            try {
                $postRecordFullPath = Resolve-SafePath -Root $root -ChildPath $recordPath
                if (-not (Test-Path -LiteralPath $postRecordFullPath -PathType Leaf)) { Add-ReleaseFinding -Code 'RLG124' -Message "Post-release verification record '$recordPath' does not exist." }
            }
            catch { Add-ReleaseFinding -Code 'RLG125' -Message "Post-release record path is unsafe: $($_.Exception.Message)" }
            if ((Get-Member -Object $postRelease -Name 'compatibilityMatrixUpdated') -isnot [bool] -or -not [bool](Get-Member -Object $postRelease -Name 'compatibilityMatrixUpdated')) { Add-ReleaseFinding -Code 'RLG126' -Message 'Post-release gate requires compatibilityMatrixUpdated=true.' }
        }
    }

    if ($mode -ceq 'Live') {
        $gitDirectory = Join-Path $root '.git'
        if (-not (Test-Path -LiteralPath $gitDirectory)) {
            Add-ReleaseFinding -Code 'RLG130' -Message 'Live mode requires a Git checkout.'
        }
        else {
            $actualHead = (& git -C $root rev-parse HEAD 2>$null).Trim()
            if ($LASTEXITCODE -ne 0 -or $actualHead -cne $candidateSha) { Add-ReleaseFinding -Code 'RLG131' -Message "Live candidateSha '$candidateSha' does not match Git HEAD '$actualHead'." }
            $worktreeState = @(& git -C $root status --porcelain=v1 2>$null)
            if ($LASTEXITCODE -ne 0 -or $worktreeState.Count -gt 0) { Add-ReleaseFinding -Code 'RLG132' -Message 'Live release validation requires a clean worktree.' }
        }
    }
}

if ($results.Count -eq 0) {
    $results.Add((New-ValidationResult -Status Passed -Message "Release lifecycle $Stage validation passed for '$EvidencePath'." -Path $EvidencePath -Severity info))
}
$report = New-ValidationReport -Results @($results)
Write-ValidationReport -Report $report -OutputJson $OutputJson
if ($report.failed -gt 0) { exit 1 }
exit 0
