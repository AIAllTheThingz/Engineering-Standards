Set-StrictMode -Version Latest

function New-ValidationResult {
    <#
    .SYNOPSIS
    Creates a standardized validation result.
    .DESCRIPTION
    Returns an ordered object used by scripts and actions for console and JSON reports.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][ValidateSet('Passed','Failed','NotRun','Blocked','NotApplicable')][string]$Status,
        [Parameter(Mandatory)][string]$Message,
        [string]$Path = '',
        [ValidateSet('info','warning','error')][string]$Severity = $(if ($Status -eq 'Passed' -or $Status -eq 'NotApplicable') { 'info' } else { 'error' }),
        [object]$Data = $null
    )

    [ordered]@{
        status = $Status
        severity = $Severity
        message = $Message
        path = $Path
        data = $Data
    }
}

function New-ValidationReport {
    <#
    .SYNOPSIS
    Creates a standard validation report.
    #>
    [CmdletBinding()]
    param([Parameter(Mandatory)][object[]]$Results)

    [ordered]@{
        generatedAtUtc = (Get-Date).ToUniversalTime().ToString('o')
        results = @($Results)
        failed = @($Results | Where-Object status -eq 'Failed').Count
        warnings = @($Results | Where-Object severity -eq 'warning').Count
        blocked = @($Results | Where-Object status -eq 'Blocked').Count
        notRun = @($Results | Where-Object status -eq 'NotRun').Count
    }
}

function Test-JsonMember {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]$InputObject,
        [Parameter(Mandatory)][string]$Name
    )

    if ($InputObject -is [System.Collections.IDictionary]) {
        return $InputObject.Contains($Name)
    }
    return ($InputObject.PSObject.Properties.Name -contains $Name)
}

function Get-JsonMemberValue {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]$InputObject,
        [Parameter(Mandatory)][string]$Name
    )

    if ($InputObject -is [System.Collections.IDictionary]) {
        if ($InputObject.Contains($Name)) { return $InputObject[$Name] }
        return $null
    }
    if ($InputObject.PSObject.Properties.Name -contains $Name) { return $InputObject.$Name }
    return $null
}

function Write-ValidationReport {
    <#
    .SYNOPSIS
    Writes a standard validation report to console and optional JSON.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][object]$Report,
        [string]$OutputJson
    )

    function ConvertTo-NeutralPathValue {
        param([object]$Value)
        if ($null -eq $Value) { return $null }
        if ($Value -is [string]) {
            $root = (Get-Location).Path
            if ($Value.StartsWith($root, [StringComparison]::OrdinalIgnoreCase)) {
                $relative = [System.IO.Path]::GetRelativePath($root, $Value).Replace('\','/')
                if ([string]::IsNullOrWhiteSpace($relative)) { return '.' }
                return $relative
            }
            return $Value
        }
        if ($Value -is [System.Collections.IDictionary]) {
            $copy = [ordered]@{}
            foreach ($key in $Value.Keys) { $copy[$key] = ConvertTo-NeutralPathValue -Value $Value[$key] }
            return $copy
        }
        if ($Value -is [pscustomobject]) {
            $copy = [ordered]@{}
            foreach ($property in $Value.PSObject.Properties) { $copy[$property.Name] = ConvertTo-NeutralPathValue -Value $property.Value }
            return $copy
        }
        if ($Value -is [System.Collections.IEnumerable] -and $Value -isnot [string]) {
            return @($Value | ForEach-Object { ConvertTo-NeutralPathValue -Value $_ })
        }
        return $Value
    }

    $Report = ConvertTo-NeutralPathValue -Value $Report
    if ($OutputJson) {
        $parent = Split-Path -Parent $OutputJson
        if ($parent) { New-Item -ItemType Directory -Path $parent -Force | Out-Null }
        $Report | ConvertTo-OrderedJson | Set-Content -LiteralPath $OutputJson -Encoding utf8
    }
    $Report.results | ForEach-Object { "[$($_.status)] $($_.path) $($_.message)" }
}

function Resolve-SafePath {
    <#
    .SYNOPSIS
    Resolves a path beneath a workspace root.
    .DESCRIPTION
    Rejects absolute or relative paths that escape the root directory.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][string]$Root,
        [Parameter(Mandatory)][string]$ChildPath,
        [switch]$AllowMissingLeaf
    )

    $rootFull = [System.IO.Path]::GetFullPath((Resolve-Path -LiteralPath $Root).Path)
    $candidate = if ([System.IO.Path]::IsPathRooted($ChildPath)) { $ChildPath } else { Join-Path $rootFull $ChildPath }
    $candidateFull = [System.IO.Path]::GetFullPath($candidate)
    $comparison = if ($IsWindows) { [StringComparison]::OrdinalIgnoreCase } else { [StringComparison]::Ordinal }
    $prefix = $rootFull.TrimEnd([System.IO.Path]::DirectorySeparatorChar, [System.IO.Path]::AltDirectorySeparatorChar) + [System.IO.Path]::DirectorySeparatorChar
    if (-not ($candidateFull.Equals($rootFull, $comparison) -or $candidateFull.StartsWith($prefix, $comparison))) {
        throw "Path '$ChildPath' resolves outside '$Root'."
    }
    $relative = [System.IO.Path]::GetRelativePath($rootFull, $candidateFull)
    $current = $rootFull
    foreach ($segment in @($relative -split '[\\/]' | Where-Object { $_ -and $_ -ne '.' })) {
        $current = Join-Path $current $segment
        if (-not (Test-Path -LiteralPath $current)) { break }
        $item = Get-Item -LiteralPath $current -Force
        if ($item.LinkType -or ($item.Attributes -band [System.IO.FileAttributes]::ReparsePoint)) {
            throw "Path '$ChildPath' traverses symbolic link or junction '$current'."
        }
    }
    if (-not $AllowMissingLeaf -and -not (Test-Path -LiteralPath $candidateFull)) {
        throw "Path '$ChildPath' does not exist beneath '$Root'."
    }
    $candidateFull
}

function Test-RelativeRepositoryPath {
    <#
    .SYNOPSIS
    Returns validation results for repository-relative path syntax.
    #>
    [CmdletBinding()]
    param(
        [AllowNull()][string]$Value,
        [Parameter(Mandatory)][string]$Name,
        [Parameter(Mandatory)][string]$Path,
        [string]$RequiredExtension
    )

    $results = [System.Collections.Generic.List[object]]::new()
    if ([string]::IsNullOrWhiteSpace($Value)) {
        $results.Add((New-ValidationResult -Status Failed -Message "$Name must not be empty." -Path $Path))
        return @($results)
    }
    if ([System.IO.Path]::IsPathRooted($Value) -or $Value -match '(^|[\\/])\.\.([\\/]|$)') {
        $results.Add((New-ValidationResult -Status Failed -Message "$Name must be a relative path that does not traverse outside the repository." -Path $Path))
    }
    if ($RequiredExtension -and -not $Value.EndsWith($RequiredExtension, [StringComparison]::OrdinalIgnoreCase)) {
        $results.Add((New-ValidationResult -Status Failed -Message "$Name must end with '$RequiredExtension'." -Path $Path))
    }
    @($results)
}

function Test-UniqueValues {
    <#
    .SYNOPSIS
    Returns validation results for duplicate values.
    #>
    [CmdletBinding()]
    param(
        [object[]]$Items,
        [Parameter(Mandatory)][string]$Name,
        [Parameter(Mandatory)][string]$Path
    )

    $results = [System.Collections.Generic.List[object]]::new()
    $seen = @{}
    foreach ($item in @($Items)) {
        $key = [string]$item
        if ($seen.ContainsKey($key)) {
            $results.Add((New-ValidationResult -Status Failed -Message "$Name contains duplicate value '$key'." -Path $Path))
        }
        else {
            $seen[$key] = $true
        }
    }
    @($results)
}

function Read-JsonFile {
    <#
    .SYNOPSIS
    Parses a JSON file.
    #>
    [CmdletBinding()]
    param([Parameter(Mandatory)][string]$Path)

    $raw = Get-Content -LiteralPath $Path -Raw
    try {
        $raw | ConvertFrom-Json -Depth 100 -AsHashtable
    }
    catch {
        $raw | ConvertFrom-Json -Depth 100
    }
}

function Test-GovernanceJsonDocument {
    <#
    .SYNOPSIS
    Validates known governance JSON documents.
    .DESCRIPTION
    Performs offline structural and semantic validation for manifests, configs, test evidence, artifact records, and completion evidence.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][string]$Path,
        [Parameter(Mandatory)][ValidateSet('completion-result','test-evidence','artifact-record','project-manifest','governance-config','verified-run','standards-consistency')][string]$Kind
    )

    $results = [System.Collections.Generic.List[object]]::new()
    try {
        $json = Read-JsonFile -Path $Path
    }
    catch {
        return @(New-ValidationResult -Status Failed -Message "Invalid JSON: $($_.Exception.Message)" -Path $Path)
    }

    $statuses = @('Passed','Failed','NotRun','NotApplicable','Blocked')
    $risks = @('Low','Moderate','High','Critical')
    $dataClasses = @('Public','Internal','Confidential','Regulated')
    $required = switch ($Kind) {
        'completion-result' { @('schemaVersion','executionContext','repository','commitSha','validatedCommitSha','evidenceCommitSha','branch','pullRequest','governanceVersion','riskClassification','status','startedAtUtc','completedAtUtc','summary','changedFiles','commandsExecuted','commandsNotExecuted','tests','artifacts','warnings','knownLimitations','remainingRisks','exceptions','approvals') }
        'test-evidence' { @('schemaVersion','name','category','status','command','workingDirectory','startedAtUtc','completedAtUtc','durationSeconds','runtime','toolVersion','exitCode','summary','warnings','failureReason') }
        'artifact-record' { @('schemaVersion','name','artifactType','path','mediaType','sizeBytes','sha256','createdAtUtc','producer','retention','sensitivity','relatedTest') }
        'project-manifest' { @('schemaVersion','projectName','repository','description','projectType','technologies','governanceVersion','riskClassification','dataClassification','owners','environments','applicableStandards','requiredWorkflows','externalIntegrations','secretsProvider','productionApprovalRequired','evidence','exceptions') }
        'governance-config' { @('schemaVersion','manifestPath','evidencePath','requiredDocumentationPaths','applicableAgentStandards','validationCategories','additionalForbiddenPatterns','reviewedAllowlist','controls','exceptions') }
        'verified-run' { @('schemaVersion','repository','workflow','workflowFile','runId','runAttempt','validatedCommitSha','branch','trigger','conclusion','checkName','artifactName','artifactId','artifactSha256','verifiedAtUtc','verifiedBy','controlledFailureRunId','controlledFailureConclusion','notes') }
        'standards-consistency' { @('schemaVersion','repository','repositoryVersion','defaultBranch','riskClassification','generatedFromCommit','generatedAtUtc','canonicalStatusValues','canonicalRiskValues','documents','workflowReview','githubEvidence','branchProtection','releaseReadiness') }
    }

    foreach ($name in $required) {
        if (-not $json.ContainsKey($name)) {
            $results.Add((New-ValidationResult -Status Failed -Message "Missing required property '$name'." -Path $Path))
        }
    }
    if ($results.Count -gt 0) { return @($results) }

    if (@('1.0.0','1.1.0') -notcontains $json.schemaVersion) {
        $results.Add((New-ValidationResult -Status Failed -Message "Unsupported schemaVersion '$($json.schemaVersion)'." -Path $Path))
    }
    if ($json.ContainsKey('status') -and $statuses -notcontains $json.status) {
        $results.Add((New-ValidationResult -Status Failed -Message "Unknown status '$($json.status)'." -Path $Path))
    }
    if ($json.ContainsKey('riskClassification') -and $risks -notcontains $json.riskClassification) {
        $results.Add((New-ValidationResult -Status Failed -Message "Unknown risk classification '$($json.riskClassification)'." -Path $Path))
    }

    if ($Kind -eq 'test-evidence') {
        foreach ($item in @(Test-TestEvidenceObject -Test $json -Path $Path)) { $results.Add($item) }
    }

    if ($Kind -eq 'artifact-record') {
        foreach ($item in @(Test-ArtifactRecordObject -Artifact $json -Path $Path)) { $results.Add($item) }
    }

    if ($Kind -eq 'verified-run') {
        foreach ($item in @(Test-VerifiedRunObject -Run $json -Path $Path)) { $results.Add($item) }
    }

    if ($Kind -eq 'completion-result') {
        foreach ($shaField in @('commitSha','validatedCommitSha')) {
            if ($json[$shaField] -notmatch '^[A-Fa-f0-9]{40}$') {
                $results.Add((New-ValidationResult -Status Failed -Message "$shaField must be a full 40-character commit SHA." -Path $Path))
            }
        }
        if ($null -ne $json.evidenceCommitSha -and $json.evidenceCommitSha -notmatch '^[A-Fa-f0-9]{40}$') {
            $results.Add((New-ValidationResult -Status Failed -Message 'evidenceCommitSha must be null or a full 40-character commit SHA.' -Path $Path))
        }
        if ($json.governanceVersion -notmatch '^[0-9]+\.[0-9]+\.[0-9]+(-[A-Za-z0-9.-]+)?$') {
            $results.Add((New-ValidationResult -Status Failed -Message 'Governance version must be semantic version format.' -Path $Path))
        }
        if ([datetime]$json.completedAtUtc -lt [datetime]$json.startedAtUtc) {
            $results.Add((New-ValidationResult -Status Failed -Message 'Completion timestamp precedes start timestamp.' -Path $Path))
        }
        if ($json.status -eq 'NotRun' -and @($json.commandsNotExecuted).Count -lt 1) {
            $results.Add((New-ValidationResult -Status Failed -Message 'Overall NotRun evidence must list commands not executed.' -Path $Path))
        }
        if ($json.status -eq 'NotRun' -and [string]::IsNullOrWhiteSpace([string]$json.notRunReason)) {
            $results.Add((New-ValidationResult -Status Failed -Message 'Overall NotRun evidence must include notRunReason.' -Path $Path))
        }
        if ($json.status -eq 'Blocked' -and [string]::IsNullOrWhiteSpace([string]$json.blockedReason)) {
            $results.Add((New-ValidationResult -Status Failed -Message 'Overall Blocked evidence must include blockedReason.' -Path $Path))
        }
        if ($json.status -eq 'NotApplicable' -and [string]::IsNullOrWhiteSpace([string]$json.notApplicableRationale)) {
            $results.Add((New-ValidationResult -Status Failed -Message 'Overall NotApplicable evidence must include notApplicableRationale.' -Path $Path))
        }
        if ($json.status -eq 'Passed') {
            foreach ($test in @($json.tests)) {
                $requiredValidation = $true
                if ($test.PSObject.Properties.Name -contains 'requiredValidation') {
                    $requiredValidation = ($test.requiredValidation -ne $false)
                }
                if ($requiredValidation -and $test.status -in @('Failed','NotRun','Blocked')) {
                    $results.Add((New-ValidationResult -Status Failed -Message "Overall Passed conflicts with test '$($test.name)' status '$($test.status)'." -Path $Path))
                }
            }
            $approvalRequired = $false
            if ($json.ContainsKey('approvalRequired')) {
                $approvalRequired = ($json.approvalRequired -eq $true)
            }
            if ($approvalRequired -and @($json.approvals).Count -lt 1) {
                $results.Add((New-ValidationResult -Status Failed -Message 'Overall Passed evidence requiring approval must include at least one approval record.' -Path $Path))
            }
        }
        $githubExecution = @($json.tests | Where-Object name -eq 'GitHub-hosted workflow execution' | Select-Object -First 1)
        if ($json.executionContext -eq 'Local') {
            if ($githubExecution.Count -eq 0) {
                $results.Add((New-ValidationResult -Status Failed -Message 'Local completion evidence must record GitHub-hosted workflow execution.' -Path $Path))
            }
            elseif ($githubExecution[0].status -notin @('NotRun','Passed')) {
                $results.Add((New-ValidationResult -Status Failed -Message 'Local completion evidence must record GitHub-hosted workflow execution as NotRun or externally verified Passed.' -Path $Path))
            }
            elseif ($githubExecution[0].status -eq 'Passed') {
                $evidenceSource = Get-JsonMemberValue -InputObject $githubExecution[0] -Name 'evidenceSource'
                $details = Get-JsonMemberValue -InputObject $githubExecution[0] -Name 'details'
                if ($evidenceSource -ne 'GitHubArtifact' -or $null -eq $details) {
                    $results.Add((New-ValidationResult -Status Failed -Message 'Local evidence may mark GitHub-hosted workflow execution Passed only when backed by GitHubArtifact details.' -Path $Path))
                }
            }
            if ($json.status -eq 'Passed') {
                $results.Add((New-ValidationResult -Status Failed -Message 'Local completion evidence cannot be Passed while GitHub-hosted execution is mandatory.' -Path $Path))
            }
        }
        if ($json.executionContext -eq 'GitHubActions' -and $null -ne $json.evidenceCommitSha) {
            $results.Add((New-ValidationResult -Status Failed -Message 'GitHubActions artifact evidence must not claim a committed evidence SHA.' -Path $Path))
        }
        foreach ($item in @(Test-UniqueValues -Items @($json.changedFiles) -Name 'changedFiles' -Path $Path)) { $results.Add($item) }
        foreach ($item in @(Test-UniqueValues -Items @($json.warnings) -Name 'warnings' -Path $Path)) { $results.Add($item) }
        foreach ($item in @(Test-UniqueValues -Items @($json.knownLimitations) -Name 'knownLimitations' -Path $Path)) { $results.Add($item) }
        foreach ($item in @(Test-UniqueValues -Items @($json.remainingRisks) -Name 'remainingRisks' -Path $Path)) { $results.Add($item) }
        foreach ($changed in @($json.changedFiles)) {
            foreach ($item in @(Test-RelativeRepositoryPath -Value $changed -Name 'changedFiles item' -Path $Path)) { $results.Add($item) }
        }
        foreach ($test in @($json.tests)) {
            foreach ($item in @(Test-TestEvidenceObject -Test $test -Path $Path)) { $results.Add($item) }
        }
        foreach ($artifact in @($json.artifacts)) {
            foreach ($item in @(Test-ArtifactRecordObject -Artifact $artifact -Path $Path)) { $results.Add($item) }
            if ($json.status -eq 'Passed' -and $artifact.PSObject.Properties.Name -contains 'finality' -and $artifact.finality -eq 'partial') {
                $results.Add((New-ValidationResult -Status Failed -Message "Overall Passed evidence cannot rely on partial artifact '$($artifact.name)'." -Path $Path))
            }
        }
    }

    if ($Kind -eq 'governance-config') {
        foreach ($item in @(Test-RelativeRepositoryPath -Value $json.manifestPath -Name 'manifestPath' -Path $Path -RequiredExtension '.json')) { $results.Add($item) }
        foreach ($item in @(Test-RelativeRepositoryPath -Value $json.evidencePath -Name 'evidencePath' -Path $Path)) { $results.Add($item) }
        foreach ($item in @(Test-UniqueValues -Items @($json.requiredDocumentationPaths) -Name 'requiredDocumentationPaths' -Path $Path)) { $results.Add($item) }
        foreach ($item in @(Test-UniqueValues -Items @($json.applicableAgentStandards) -Name 'applicableAgentStandards' -Path $Path)) { $results.Add($item) }
        foreach ($item in @(Test-UniqueValues -Items @($json.validationCategories) -Name 'validationCategories' -Path $Path)) { $results.Add($item) }
        foreach ($docPath in @($json.requiredDocumentationPaths)) {
            foreach ($item in @(Test-RelativeRepositoryPath -Value $docPath -Name 'requiredDocumentationPaths item' -Path $Path -RequiredExtension '.md')) { $results.Add($item) }
        }
        foreach ($disabled in @($json.controls.mandatoryControlsDisabled)) {
            if (-not $disabled.exceptionReference -or $disabled.exceptionReference -notmatch '^GOV-[A-Z0-9-]+$') {
                $results.Add((New-ValidationResult -Status Failed -Message "Mandatory control '$($disabled.control)' lacks a valid exception reference." -Path $Path))
            }
            elseif (@($json.exceptions) -notcontains $disabled.exceptionReference) {
                $results.Add((New-ValidationResult -Status Failed -Message "Mandatory control '$($disabled.control)' references exception '$($disabled.exceptionReference)' that is not listed in exceptions." -Path $Path))
            }
        }
        foreach ($allow in @($json.reviewedAllowlist)) {
            if (-not $allow.reason -or $allow.reason.Length -lt 10) {
                $results.Add((New-ValidationResult -Status Failed -Message "Allowlist entry '$($allow.patternId)' lacks a meaningful reason." -Path $Path))
            }
            if (-not $allow.owner -or $allow.owner.Length -lt 3) {
                $results.Add((New-ValidationResult -Status Failed -Message "Allowlist entry '$($allow.patternId)' lacks an owner." -Path $Path))
            }
            foreach ($item in @(Test-RelativeRepositoryPath -Value $allow.path -Name 'allowlist path' -Path $Path)) { $results.Add($item) }
        }
    }

    if ($Kind -eq 'project-manifest') {
        if ($json.governanceVersion -notmatch '^[0-9]+\.[0-9]+\.[0-9]+(-[A-Za-z0-9.-]+)?$') {
            $results.Add((New-ValidationResult -Status Failed -Message 'Governance version must be semantic version format.' -Path $Path))
        }
        if ($dataClasses -notcontains $json.dataClassification) {
            $results.Add((New-ValidationResult -Status Failed -Message "Unknown data classification '$($json.dataClassification)'." -Path $Path))
        }
        if ($json.riskClassification -in @('High','Critical') -and $json.productionApprovalRequired -ne $true) {
            $results.Add((New-ValidationResult -Status Failed -Message 'High and Critical project manifests must require production approval.' -Path $Path))
        }
        foreach ($item in @(Test-UniqueValues -Items @($json.technologies) -Name 'technologies' -Path $Path)) { $results.Add($item) }
        foreach ($item in @(Test-UniqueValues -Items @($json.owners) -Name 'owners' -Path $Path)) { $results.Add($item) }
        foreach ($item in @(Test-UniqueValues -Items @($json.applicableStandards) -Name 'applicableStandards' -Path $Path)) { $results.Add($item) }
        foreach ($owner in @($json.owners)) {
            if ($owner -notmatch '^(@[A-Za-z0-9_.-]+/[A-Za-z0-9_.-]+|[A-Za-z0-9_.+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,})$') {
                $results.Add((New-ValidationResult -Status Failed -Message "Owner '$owner' must be a GitHub team handle or email address." -Path $Path))
            }
        }
        foreach ($standard in @($json.applicableStandards)) {
            foreach ($item in @(Test-RelativeRepositoryPath -Value $standard -Name 'applicableStandards item' -Path $Path -RequiredExtension '.md')) { $results.Add($item) }
        }
        foreach ($item in @(Test-RelativeRepositoryPath -Value $json.evidence.completionEvidencePath -Name 'completionEvidencePath' -Path $Path -RequiredExtension '.json')) { $results.Add($item) }
        foreach ($item in @(Test-RelativeRepositoryPath -Value $json.evidence.testEvidencePath -Name 'testEvidencePath' -Path $Path -RequiredExtension '.json')) { $results.Add($item) }
    }

    if ($Kind -eq 'standards-consistency') {
        if ($json.repository -ne 'AIAllTheThingz/Engineering-Standards') {
            $results.Add((New-ValidationResult -Status Failed -Message 'Consistency matrix repository must match AIAllTheThingz/Engineering-Standards.' -Path $Path))
        }
        if ($json.defaultBranch -ne 'master') {
            $results.Add((New-ValidationResult -Status Failed -Message 'Consistency matrix defaultBranch must be master.' -Path $Path))
        }
        if ($json.repositoryVersion -notmatch '^[0-9]+\.[0-9]+\.[0-9]+$') {
            $results.Add((New-ValidationResult -Status Failed -Message 'Consistency matrix repositoryVersion must be semantic version format.' -Path $Path))
        }
        if ($json.generatedFromCommit -notmatch '^[A-Fa-f0-9]{40}$') {
            $results.Add((New-ValidationResult -Status Failed -Message 'Consistency matrix generatedFromCommit must be a full 40-character commit SHA.' -Path $Path))
        }
        foreach ($status in $statuses) {
            if (@($json.canonicalStatusValues) -notcontains $status) {
                $results.Add((New-ValidationResult -Status Failed -Message "Consistency matrix missing canonical status '$status'." -Path $Path))
            }
        }
        foreach ($risk in $risks) {
            if (@($json.canonicalRiskValues) -notcontains $risk) {
                $results.Add((New-ValidationResult -Status Failed -Message "Consistency matrix missing canonical risk '$risk'." -Path $Path))
            }
        }
        $requiredDocumentPaths = @(
            'AGENTS.md',
            'agents/AGENTS_Base.md',
            'agents/AGENTS_PowerShell.md',
            'agents/AGENTS_DotNet.md',
            'agents/AGENTS_Database.md',
            'agents/AGENTS_WorkerService.md',
            'agents/AGENTS_Integration.md',
            'agents/AGENTS_Infrastructure.md',
            'agents/AGENTS_WebFrontend.md',
            'governance/ORGANIZATION_CONTRACT.md',
            'governance/COMPLETION_EVIDENCE.md',
            'governance/RISK_CLASSIFICATION.md',
            'governance/EXCEPTION_PROCESS.md',
            'governance/AI_GENERATED_CODE_POLICY.md'
        )
        $documentPaths = @($json.documents | ForEach-Object { $_.path })
        foreach ($requiredPath in $requiredDocumentPaths) {
            if ($documentPaths -notcontains $requiredPath) {
                $results.Add((New-ValidationResult -Status Failed -Message "Consistency matrix missing document '$requiredPath'." -Path $Path))
            }
        }
        foreach ($document in @($json.documents)) {
            foreach ($item in @(Test-RelativeRepositoryPath -Value $document.path -Name 'document path' -Path $Path -RequiredExtension '.md')) { $results.Add($item) }
            if ($document.declaredVersion -notmatch '^[0-9]+\.[0-9]+\.[0-9]+$') {
                $results.Add((New-ValidationResult -Status Failed -Message "Document '$($document.path)' has invalid declaredVersion." -Path $Path))
            }
            if ($document.lastReviewed -notmatch '^[0-9]{4}-[0-9]{2}-[0-9]{2}$') {
                $results.Add((New-ValidationResult -Status Failed -Message "Document '$($document.path)' has invalid lastReviewed date." -Path $Path))
            }
            foreach ($flag in @('notRunDefined','blockedDefined','fabricatedEvidenceProhibited','exceptionProcessReferenced','completionEvidenceReferenced')) {
                if ($document[$flag] -ne $true) {
                    $results.Add((New-ValidationResult -Status Failed -Message "Document '$($document.path)' does not satisfy $flag." -Path $Path))
                }
            }
        }
        foreach ($statusObjectName in @('workflowReview','githubEvidence','branchProtection','releaseReadiness')) {
            if ($statuses -notcontains $json[$statusObjectName].status) {
                $results.Add((New-ValidationResult -Status Failed -Message "Consistency matrix '$statusObjectName' uses invalid status '$($json[$statusObjectName].status)'." -Path $Path))
            }
        }
    }

    if ($results.Count -eq 0) {
        $results.Add((New-ValidationResult -Status Passed -Message "$Kind validation passed." -Path $Path -Severity info))
    }
    @($results)
}

function Test-TestEvidenceObject {
    <#
    .SYNOPSIS
    Validates a test evidence object.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]$Test,
        [Parameter(Mandatory)][string]$Path
    )

    $results = [System.Collections.Generic.List[object]]::new()
    $hasBlockedReason = Test-JsonMember -InputObject $Test -Name 'blockedReason'
    $hasNotApplicableRationale = Test-JsonMember -InputObject $Test -Name 'notApplicableRationale'

    if ($Test.status -eq 'Passed') {
        if ($Test.exitCode -ne 0) {
            $results.Add((New-ValidationResult -Status Failed -Message "Passed test '$($Test.name)' must have exitCode 0." -Path $Path))
        }
        if ($null -ne $Test.failureReason) {
            $results.Add((New-ValidationResult -Status Failed -Message "Passed test '$($Test.name)' must not have failureReason." -Path $Path))
        }
        if ($hasBlockedReason -and $null -ne $Test.blockedReason) {
            $results.Add((New-ValidationResult -Status Failed -Message "Passed test '$($Test.name)' must not have blockedReason." -Path $Path))
        }
        if ($hasNotApplicableRationale -and $null -ne $Test.notApplicableRationale) {
            $results.Add((New-ValidationResult -Status Failed -Message "Passed test '$($Test.name)' must not have notApplicableRationale." -Path $Path))
        }
    }
    if ($Test.status -in @('Failed','NotRun')) {
        if ([string]::IsNullOrWhiteSpace([string]$Test.failureReason) -or ([string]$Test.failureReason).Length -lt 10) {
            $results.Add((New-ValidationResult -Status Failed -Message "Test '$($Test.name)' must include a meaningful failure reason for status '$($Test.status)'." -Path $Path))
        }
    }
    if ($Test.status -eq 'Blocked') {
        if (-not $hasBlockedReason -or [string]::IsNullOrWhiteSpace([string]$Test.blockedReason) -or ([string]$Test.blockedReason).Length -lt 10) {
            $results.Add((New-ValidationResult -Status Failed -Message "Test '$($Test.name)' must include a meaningful blocked reason." -Path $Path))
        }
    }
    if ($Test.status -eq 'NotApplicable') {
        if (-not $hasNotApplicableRationale -or [string]::IsNullOrWhiteSpace([string]$Test.notApplicableRationale) -or ([string]$Test.notApplicableRationale).Length -lt 10) {
            $results.Add((New-ValidationResult -Status Failed -Message "Test '$($Test.name)' must include a meaningful notApplicable rationale." -Path $Path))
        }
        if ($null -ne $Test.exitCode) {
            $results.Add((New-ValidationResult -Status Failed -Message "NotApplicable test '$($Test.name)' must have null exitCode." -Path $Path))
        }
    }
    if ($Test.status -eq 'NotRun' -and $null -ne $Test.exitCode -and [int]$Test.exitCode -ne 3) {
        $results.Add((New-ValidationResult -Status Failed -Message "NotRun test '$($Test.name)' must have null exitCode or policy exitCode 3." -Path $Path))
    }
    if ($Test.completedAtUtc -and $Test.startedAtUtc -and [datetime]$Test.completedAtUtc -lt [datetime]$Test.startedAtUtc) {
        $results.Add((New-ValidationResult -Status Failed -Message "Test '$($Test.name)' completion timestamp precedes start timestamp." -Path $Path))
    }
    foreach ($item in @(Test-RelativeRepositoryPath -Value $Test.workingDirectory -Name "workingDirectory for '$($Test.name)'" -Path $Path)) { $results.Add($item) }
    @($results)
}

function Test-ArtifactRecordObject {
    <#
    .SYNOPSIS
    Validates an artifact record object.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]$Artifact,
        [Parameter(Mandatory)][string]$Path
    )

    $results = [System.Collections.Generic.List[object]]::new()
    $dataClasses = @('Public','Internal','Confidential','Regulated')
    if ($Artifact.sha256 -notmatch '^[A-Fa-f0-9]{64}$') {
        $results.Add((New-ValidationResult -Status Failed -Message "Artifact '$($Artifact.name)' SHA-256 is invalid." -Path $Path))
    }
    if ($Artifact.mediaType -notmatch '^[a-z0-9.+-]+/[a-z0-9.+-]+$') {
        $results.Add((New-ValidationResult -Status Failed -Message "Artifact '$($Artifact.name)' mediaType must be an IANA-style media type." -Path $Path))
    }
    if ($Artifact.retention -in @('release','audit') -and $Artifact.sizeBytes -lt 1) {
        $results.Add((New-ValidationResult -Status Failed -Message "Artifact '$($Artifact.name)' with release or audit retention must have a positive size." -Path $Path))
    }
    if ($dataClasses -notcontains $Artifact.sensitivity) {
        $results.Add((New-ValidationResult -Status Failed -Message "Unknown artifact sensitivity '$($Artifact.sensitivity)'." -Path $Path))
    }
    if ($Artifact.PSObject.Properties.Name -contains 'finality' -and $Artifact.finality -eq 'final') {
        $hasIntegrityVerification = $Artifact.PSObject.Properties.Name -contains 'integrityVerification'
        if (-not $hasIntegrityVerification -or -not $Artifact.integrityVerification -or $Artifact.integrityVerification.status -notin @('Passed','NotApplicable')) {
            $results.Add((New-ValidationResult -Status Failed -Message "Final artifact '$($Artifact.name)' must include a passing or not-applicable integrityVerification record." -Path $Path))
        }
    }
    foreach ($item in @(Test-RelativeRepositoryPath -Value $Artifact.path -Name "artifact path for '$($Artifact.name)'" -Path $Path)) { $results.Add($item) }
    @($results)
}

function Test-VerifiedRunObject {
    <#
    .SYNOPSIS
    Validates verified GitHub run metadata.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]$Run,
        [Parameter(Mandatory)][string]$Path
    )

    $results = [System.Collections.Generic.List[object]]::new()
    if ($Run.repository -ne 'AIAllTheThingz/Engineering-Standards') {
        $results.Add((New-ValidationResult -Status Failed -Message 'Verified run repository must be AIAllTheThingz/Engineering-Standards.' -Path $Path))
    }
    if ($Run.workflow -ne 'Governance CI') {
        $results.Add((New-ValidationResult -Status Failed -Message 'Verified run workflow must be Governance CI.' -Path $Path))
    }
    if ($Run.workflowFile -ne '.github/workflows/governance-ci.yml') {
        $results.Add((New-ValidationResult -Status Failed -Message 'Verified run workflowFile must point to the entry workflow.' -Path $Path))
    }
    if ([int64]$Run.runId -le 0 -or [int64]$Run.runAttempt -le 0 -or [int64]$Run.artifactId -le 0 -or [int64]$Run.controlledFailureRunId -le 0) {
        $results.Add((New-ValidationResult -Status Failed -Message 'Verified run IDs, attempts, and artifact IDs must be positive.' -Path $Path))
    }
    if ($Run.validatedCommitSha -notmatch '^[A-Fa-f0-9]{40}$') {
        $results.Add((New-ValidationResult -Status Failed -Message 'validatedCommitSha must be a full 40-character commit SHA.' -Path $Path))
    }
    if ($Run.branch -ne 'master') {
        $results.Add((New-ValidationResult -Status Failed -Message 'Verified run branch must be master.' -Path $Path))
    }
    if (@('workflow_dispatch','push','pull_request','schedule') -notcontains $Run.trigger) {
        $results.Add((New-ValidationResult -Status Failed -Message 'Verified run trigger is not allowed.' -Path $Path))
    }
    if (@('success','failure','cancelled','timed_out','neutral','skipped') -notcontains $Run.conclusion) {
        $results.Add((New-ValidationResult -Status Failed -Message 'Verified run conclusion is not allowed.' -Path $Path))
    }
    if ($Run.conclusion -eq 'success' -and [string]::IsNullOrWhiteSpace([string]$Run.artifactName)) {
        $results.Add((New-ValidationResult -Status Failed -Message 'Successful verified run metadata must include an artifact name.' -Path $Path))
    }
    if ($Run.controlledFailureConclusion -ne 'failure') {
        $results.Add((New-ValidationResult -Status Failed -Message 'controlledFailureConclusion must be failure.' -Path $Path))
    }
    if ($Run.artifactSha256 -notmatch '^[A-Fa-f0-9]{64}$') {
        $results.Add((New-ValidationResult -Status Failed -Message 'artifactSha256 must be a SHA-256 digest.' -Path $Path))
    }
    try {
        [datetime]$Run.verifiedAtUtc | Out-Null
    }
    catch {
        $results.Add((New-ValidationResult -Status Failed -Message 'verifiedAtUtc must be a date-time value.' -Path $Path))
    }
    if ([string]::IsNullOrWhiteSpace([string]$Run.verifiedBy)) {
        $results.Add((New-ValidationResult -Status Failed -Message 'verifiedBy must identify the verifier.' -Path $Path))
    }
    @($results)
}

function ConvertTo-OrderedJson {
    <#
    .SYNOPSIS
    Serializes objects to JSON.
    #>
    [CmdletBinding()]
    param([Parameter(ValueFromPipeline)]$InputObject)
    process { $InputObject | ConvertTo-Json -Depth 100 }
}

function ConvertTo-SanitizedWorkflowOutputLine {
    <#
    .SYNOPSIS
    Converts one output object into inert, sanitized physical log lines.
    #>
    [CmdletBinding()]
    param(
        [AllowNull()][AllowEmptyString()]$InputObject,
        [string]$WorkspaceRoot,
        [string]$TemporaryRoot
    )

    $comparison = if ($IsWindows) { [StringComparison]::OrdinalIgnoreCase } else { [StringComparison]::Ordinal }
    $normalized = ([string]$InputObject).Replace("`r`n", "`n").Replace("`r", "`n")
    foreach ($physicalLine in $normalized.Split("`n")) {
        $line = [regex]::Replace($physicalLine, '[\x00-\x08\x0B\x0C\x0E-\x1F\x7F]', '')
        if ($WorkspaceRoot) { $line = $line.Replace($WorkspaceRoot, '[workspace]', $comparison) }
        if ($TemporaryRoot) { $line = $line.Replace($TemporaryRoot, '[temp]', $comparison) }
        if ($line -match '^\s*::') { $line = '[validator-output] ' + $line }
        Write-Output $line
    }
}

function ConvertTo-SanitizedWorkflowFailureMessage {
    <#
    .SYNOPSIS
    Produces a bounded, one-line failure message safe for workflow evidence.
    .DESCRIPTION
    Removes control characters, replaces workspace paths, neutralizes workflow
    commands, and redacts common credential forms without serializing exception
    objects, stack traces, or execution context.
    .PARAMETER InputObject
    Raw exception message or failure text to sanitize.
    .PARAMETER WorkspaceRoot
    Workflow workspace path replaced with a neutral marker.
    .PARAMETER TemporaryRoot
    Runner temporary path replaced with a neutral marker.
    .PARAMETER MaximumLength
    Maximum length of the resulting single-line message.
    #>
    [CmdletBinding()]
    param(
        [AllowNull()][AllowEmptyString()]$InputObject,
        [string]$WorkspaceRoot,
        [string]$TemporaryRoot,
        [ValidateRange(256, 16384)][int]$MaximumLength = 4096
    )

    $lines = @(
        ConvertTo-SanitizedWorkflowOutputLine `
            -InputObject ([string]$InputObject).Replace([char]0x2028, "`n").Replace([char]0x2029, "`n") `
            -WorkspaceRoot $WorkspaceRoot `
            -TemporaryRoot $TemporaryRoot
    )
    $message = ($lines | ForEach-Object {
        $line = [string]$_
        $line = [regex]::Replace($line, '(?i)\b(https?://)[^/\s:@]+:[^@\s/]+@', '$1[redacted]@')
        $line = [regex]::Replace($line, '(?i)(\bAuthorization\s*[:=]\s*)(?:Bearer|Basic)\s+[^\s|]+', '$1[redacted]')
        $line = [regex]::Replace($line, '(?i)\b(password|passwd|pwd|secret|client[_-]?secret|api[_-]?key|access[_-]?token|refresh[_-]?token|token)(\s*[:=]\s*)(?:"[^"]*"|''[^'']*''|[^\s|]+)', '$1$2[redacted]')
        $line = [regex]::Replace($line, '(?i)\b(?:gh[pousr]_[A-Za-z0-9_]{20,}|github_pat_[A-Za-z0-9_]{20,})\b', '[redacted]')
        $line.Trim()
    } | Where-Object { -not [string]::IsNullOrWhiteSpace($_) }) -join ' | '

    if ([string]::IsNullOrWhiteSpace($message)) { return $null }
    if ($message.Length -gt $MaximumLength) {
        $message = $message.Substring(0, $MaximumLength - 15) + '...[truncated]'
    }
    $message
}

function Write-GovernanceBootstrapFailureReport {
    <#
    .SYNOPSIS
    Writes a schema-shaped early-failure report without replacing existing evidence.
    .DESCRIPTION
    Writes a single failed bootstrap result into an existing physical evidence
    directory. Existing aggregate evidence is returned unchanged.
    .PARAMETER EvidenceRoot
    Existing physical evidence directory beneath the trusted workflow workspace.
    .PARAMETER FailureMessage
    Specific raw failure message to sanitize and record.
    .PARAMETER GenericFallbackMessage
    Fallback used only when no safe specific failure text remains.
    .PARAMETER CallerRepository
    GitHub owner/name of the caller repository.
    .PARAMETER CallerCommitSha
    Immutable caller commit identity.
    .PARAMETER ProjectPath
    Requested repository-relative caller project path.
    .PARAMETER StandardsRepository
    Trusted repository that supplied the reusable workflow.
    .PARAMETER StandardsWorkflowSha
    Immutable trusted workflow commit identity.
    .PARAMETER GovernanceVersion
    Governance interface version requested by the caller.
    .PARAMETER WorkspaceRoot
    Workflow workspace path to redact from the failure message.
    .PARAMETER TemporaryRoot
    Runner temporary path to redact from the failure message.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][string]$EvidenceRoot,
        [AllowNull()][AllowEmptyString()][string]$FailureMessage,
        [string]$GenericFallbackMessage = 'Input, workspace, manifest, configuration, or dependency validation failed before the aggregate report could be finalized.',
        [string]$CallerRepository,
        [string]$CallerCommitSha,
        [string]$ProjectPath = '.',
        [string]$StandardsRepository = 'AIAllTheThingz/Engineering-Standards',
        [string]$StandardsWorkflowSha,
        [string]$GovernanceVersion,
        [string]$WorkspaceRoot,
        [string]$TemporaryRoot
    )

    $evidenceItem = Get-Item -LiteralPath $EvidenceRoot -Force -ErrorAction Stop
    if (-not $evidenceItem.PSIsContainer -or $evidenceItem.LinkType -or ($evidenceItem.Attributes -band [System.IO.FileAttributes]::ReparsePoint)) {
        throw 'Bootstrap evidence root must be an existing physical directory.'
    }
    $reportPath = Join-Path $evidenceItem.FullName 'governance-validation.json'
    if (Test-Path -LiteralPath $reportPath -PathType Leaf) { return $reportPath }

    $safeFailure = ConvertTo-SanitizedWorkflowFailureMessage -InputObject $FailureMessage -WorkspaceRoot $WorkspaceRoot -TemporaryRoot $TemporaryRoot
    if ([string]::IsNullOrWhiteSpace($safeFailure)) {
        $safeFailure = ConvertTo-SanitizedWorkflowFailureMessage -InputObject $GenericFallbackMessage -WorkspaceRoot $WorkspaceRoot -TemporaryRoot $TemporaryRoot
    }
    if ([string]::IsNullOrWhiteSpace($safeFailure)) { $safeFailure = 'Trusted governance validation failed before the aggregate report could be finalized.' }

    $safeProjectPath = if (
        -not [string]::IsNullOrWhiteSpace($ProjectPath) -and
        -not [System.IO.Path]::IsPathRooted($ProjectPath) -and
        $ProjectPath -notmatch '(^|[\\/])\.\.([\\/]|$)' -and
        $ProjectPath -notmatch '[\x00-\x1F\x7F]'
    ) { $ProjectPath } else { '[invalid]' }
    $now = (Get-Date).ToUniversalTime().ToString('o')
    [ordered]@{
        schemaVersion = '1.0.0'
        generatedAtUtc = $now
        caller = [ordered]@{ repository=$CallerRepository; commitSha=$CallerCommitSha; workspace='caller'; projectPath=$safeProjectPath }
        standards = [ordered]@{ repository=$StandardsRepository; workflowSha=$StandardsWorkflowSha; workspace='standards' }
        evidenceWorkspace = 'evidence'
        governanceVersion = $GovernanceVersion
        riskClassification = 'High'
        validationProfile = 'unresolved'
        checksExecuted = @('BootstrapValidation')
        results = @([ordered]@{
            name='BootstrapValidation'; category='workflow'; status='Failed'; requiredValidation=$true
            command='standards/scripts/Invoke-GovernanceValidation.ps1'; toolPath='standards/scripts/Invoke-GovernanceValidation.ps1'; target='caller'
            startedAtUtc=$now; completedAtUtc=$now; durationSeconds=0; exitCode=1
            summary='Trusted governance validation failed before the aggregate report was finalized.'
            failureReason=$safeFailure
        })
        failed = 1
    } | ConvertTo-OrderedJson | Set-Content -LiteralPath $reportPath -Encoding utf8
    $reportPath
}

Export-ModuleMember -Function @(
    'New-ValidationResult',
    'New-ValidationReport',
    'Write-ValidationReport',
    'Resolve-SafePath',
    'Test-RelativeRepositoryPath',
    'Test-UniqueValues',
    'Test-JsonMember',
    'Get-JsonMemberValue',
    'Read-JsonFile',
    'Test-GovernanceJsonDocument',
    'Test-TestEvidenceObject',
    'Test-ArtifactRecordObject',
    'Test-VerifiedRunObject',
    'ConvertTo-OrderedJson',
    'ConvertTo-SanitizedWorkflowOutputLine',
    'ConvertTo-SanitizedWorkflowFailureMessage',
    'Write-GovernanceBootstrapFailureReport'
)
