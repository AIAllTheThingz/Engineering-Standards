Set-StrictMode -Version Latest

$script:GovernanceSchemaVersionsByKind = [ordered]@{
    'completion-result'     = @('1.0.0', '1.1.0')
    'test-evidence'         = @('1.0.0', '1.1.0')
    'artifact-record'       = @('1.0.0', '1.1.0')
    'project-manifest'      = @('1.0.0', '1.1.0', '1.2.0')
    'governance-config'     = @('1.0.0', '1.1.0', '1.2.0')
    'verified-run'          = @('1.0.0')
    'standards-consistency' = @('1.0.0')
}

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

function Test-StructuredOwnerIdentifier {
    [CmdletBinding()]
    param(
        [AllowNull()][object]$Type,
        [AllowNull()][object]$Identifier
    )

    $ownerType = [string]$Type
    $ownerIdentifier = [string]$Identifier
    switch -CaseSensitive ($ownerType) {
        'github-user' {
            return $ownerIdentifier -cmatch '^@[A-Za-z0-9](?:[A-Za-z0-9-]{0,37}[A-Za-z0-9])?$'
        }
        'github-team' {
            return $ownerIdentifier -cmatch '^@[A-Za-z0-9](?:[A-Za-z0-9-]{0,37}[A-Za-z0-9])?/[A-Za-z0-9](?:[A-Za-z0-9_.-]*[A-Za-z0-9])?$'
        }
        'email-contact' {
            return $ownerIdentifier -cmatch '^[A-Za-z0-9_.+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}$'
        }
        default {
            return $false
        }
    }
}

function Test-ExactStringSet {
    [CmdletBinding()]
    param(
        [AllowNull()][object[]]$Actual,
        [Parameter(Mandatory)][string[]]$Expected
    )

    $actualValues = @($Actual)
    if ($actualValues.Count -ne $Expected.Count) { return $false }

    $seen = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::Ordinal)
    foreach ($value in $actualValues) {
        if ($value -isnot [string] -or [string]::IsNullOrWhiteSpace([string]$value) -or -not $seen.Add([string]$value)) {
            return $false
        }
    }

    $expectedValues = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::Ordinal)
    foreach ($requiredValue in $Expected) {
        if ([string]::IsNullOrWhiteSpace($requiredValue) -or -not $expectedValues.Add($requiredValue) -or -not $seen.Contains($requiredValue)) { return $false }
    }
    return $true
}

function Get-RequiredCheckNameContractIssues {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][System.Collections.IDictionary]$Wrapper,
        [Parameter(Mandatory)][string]$Name
    )

    [object]$Value = $null
    if ($Wrapper.Contains('Value') -and -not [object]::ReferenceEquals($null, $Wrapper['Value'])) {
        $Value = $Wrapper['Value']
    }
    if ($null -eq $Value -or $Value -is [string] -or $Value -isnot [System.Collections.IList]) {
        return @("$Name must be a nonempty array.")
    }

    if ($Value.Count -eq 0) {
        return @("$Name must be a nonempty array.")
    }

    $issues = [System.Collections.Generic.List[string]]::new()
    $seen = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::Ordinal)
    for ($index = 0; $index -lt $Value.Count; $index++) {
        $valueItem = $Value[$index]
        if ($null -eq $valueItem -or $valueItem -isnot [string]) {
            $issues.Add("$Name members must be non-null strings.")
            continue
        }
        if ([string]::IsNullOrWhiteSpace($valueItem)) {
            $issues.Add("$Name members must not be blank.")
            continue
        }
        if ($valueItem.Length -lt 3 -or $valueItem.Length -gt 160) {
            $issues.Add("$Name members must be between 3 and 160 characters.")
        }
        if (-not $seen.Add($valueItem)) {
            $issues.Add("$Name members must be unique using ordinal, case-sensitive comparison.")
        }
    }
    $issues.ToArray()
}

function Get-CanonicalMaintainerRequiredCheckNames {
    [CmdletBinding()]
    [OutputType([string[]])]
    param()

    @(
        'Governance / Governance validation'
        'Candidate implementation validation / Candidate implementation validation'
    )
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

function Test-ExactRepositoryPathCasing {
    <#
    .SYNOPSIS
    Confirms that every declared path segment matches the filesystem entry exactly.
    .DESCRIPTION
    Prevents case-insensitive filesystems from silently resolving a declaration
    to a differently cased standards path than the manifest recorded.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][string]$Root,
        [Parameter(Mandatory)][string]$ChildPath
    )

    $current = (Resolve-Path -LiteralPath $Root).Path
    foreach ($segment in @($ChildPath -split '[\\/]' | Where-Object { $_ -and $_ -ne '.' })) {
        $exact = @(Get-ChildItem -LiteralPath $current -Force -ErrorAction SilentlyContinue | Where-Object { $_.Name -ceq $segment })
        if ($exact.Count -ne 1) { return $false }
        $current = $exact[0].FullName
    }
    return $true
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
    if (
        [System.IO.Path]::IsPathRooted($Value) -or
        $Value -cmatch '^[A-Za-z]:' -or
        $Value -cmatch '^[\\/]' -or
        $Value.Contains('..')
    ) {
        $results.Add((New-ValidationResult -Status Failed -Message "$Name must be a relative path that does not traverse outside the repository." -Path $Path))
    }
    if ($RequiredExtension -and -not $Value.EndsWith($RequiredExtension, [StringComparison]::Ordinal)) {
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

    $supportedSchemaVersions = @($script:GovernanceSchemaVersionsByKind[$Kind])
    $hasSupportedSchemaVersion = @($supportedSchemaVersions | Where-Object {
        [string]::Equals([string]$_, [string]$json.schemaVersion, [System.StringComparison]::Ordinal)
    }).Count -eq 1
    if (-not $hasSupportedSchemaVersion) {
        $results.Add((New-ValidationResult -Status Failed -Message "Unsupported schemaVersion '$($json.schemaVersion)' for governance document kind '$Kind'. Supported versions: $($supportedSchemaVersions -join ', ')." -Path $Path))
    }
    if ($json.schemaVersion -ceq '1.2.0' -and $Kind -in @('project-manifest', 'governance-config')) {
        $collectionRules = if ($Kind -ceq 'project-manifest') {
            @(
                @{ Name='technologies'; Minimum=1 },
                @{ Name='owners'; Minimum=1 },
                @{ Name='environments'; Minimum=0 },
                @{ Name='applicableStandards'; Minimum=1 },
                @{ Name='requiredWorkflows'; Minimum=0 },
                @{ Name='externalIntegrations'; Minimum=0 },
                @{ Name='exceptions'; Minimum=0 }
            )
        }
        else {
            @(
                @{ Name='requiredDocumentationPaths'; Minimum=1 },
                @{ Name='applicableAgentStandards'; Minimum=1 },
                @{ Name='validationCategories'; Minimum=1 },
                @{ Name='additionalForbiddenPatterns'; Minimum=0 },
                @{ Name='reviewedAllowlist'; Minimum=0 },
                @{ Name='exceptions'; Minimum=0 }
            )
        }
        foreach ($rule in $collectionRules) {
            $collectionValue = $json[$rule.Name]
            $isArray = $collectionValue -is [System.Collections.IList] -and $collectionValue -isnot [string]
            if (-not $isArray) {
                $results.Add((New-ValidationResult -Status Failed -Message "$($rule.Name) must be declared as an array." -Path $Path))
            }
            elseif ($collectionValue.Count -lt $rule.Minimum) {
                $results.Add((New-ValidationResult -Status Failed -Message "$($rule.Name) must be declared as a nonempty array." -Path $Path))
            }
        }
        if ($Kind -ceq 'governance-config') {
            $controlsValue = $json['controls']
            if ($controlsValue -isnot [System.Collections.IDictionary]) {
                $results.Add((New-ValidationResult -Status Failed -Message 'controls must be declared as an object.' -Path $Path))
            }
            else {
                $disabledControlsValue = Get-JsonMemberValue -InputObject $controlsValue -Name 'mandatoryControlsDisabled'
                if ($disabledControlsValue -is [string] -or $disabledControlsValue -isnot [System.Collections.IList]) {
                    $results.Add((New-ValidationResult -Status Failed -Message 'controls.mandatoryControlsDisabled must be declared as an array.' -Path $Path))
                }
            }
        }
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
        if ($json.schemaVersion -eq '1.2.0') {
            foreach ($name in @('governanceVersion','governanceCommitSha','workflowInterfaceVersion','workflowProfile','workflowInterface','requiredCheckNames')) {
                if (-not $json.ContainsKey($name)) { $results.Add((New-ValidationResult -Status Failed -Message "Missing required 1.2.0 property '$name'." -Path $Path)) }
            }
            if ($json.ContainsKey('workflowProfile') -and $json.workflowProfile -notin @('downstream','standards-maintainer')) { $results.Add((New-ValidationResult -Status Failed -Message "Unsupported workflowProfile '$($json.workflowProfile)'." -Path $Path)) }
            if ($json.ContainsKey('governanceCommitSha') -and $json.governanceCommitSha -notmatch '^[A-Fa-f0-9]{40}$') { $results.Add((New-ValidationResult -Status Failed -Message 'governanceCommitSha must be a full 40-character commit SHA.' -Path $Path)) }
        }
        foreach ($item in @(Test-RelativeRepositoryPath -Value $json.manifestPath -Name 'manifestPath' -Path $Path -RequiredExtension '.json')) { $results.Add($item) }
        foreach ($item in @(Test-RelativeRepositoryPath -Value $json.evidencePath -Name 'evidencePath' -Path $Path)) { $results.Add($item) }
        foreach ($item in @(Test-UniqueValues -Items @($json.requiredDocumentationPaths) -Name 'requiredDocumentationPaths' -Path $Path)) { $results.Add($item) }
        foreach ($item in @(Test-UniqueValues -Items @($json.applicableAgentStandards) -Name 'applicableAgentStandards' -Path $Path)) { $results.Add($item) }
        foreach ($item in @(Test-UniqueValues -Items @($json.validationCategories) -Name 'validationCategories' -Path $Path)) { $results.Add($item) }
        $supportedValidationCategories = @('Contract','JsonSchemas','YamlSyntax','WorkflowArchitecture','MarkdownLinks','DocumentationCompleteness','ForbiddenPatterns','RepositoryHealth','CodexSkills','Evidence','Examples','Pester','PSScriptAnalyzer','PowerShellParser')
        foreach ($category in @($json.validationCategories)) {
            if ($category -notin $supportedValidationCategories) {
                $results.Add((New-ValidationResult -Status Failed -Message "validationCategories contains unsupported value '$category'." -Path $Path))
            }
        }
        foreach ($docPath in @($json.requiredDocumentationPaths)) {
            foreach ($item in @(Test-RelativeRepositoryPath -Value $docPath -Name 'requiredDocumentationPaths item' -Path $Path -RequiredExtension '.md')) { $results.Add($item) }
        }
        if ($json.ContainsKey('ownership')) {
            $ownership = $json.ownership
            if ($null -eq $ownership -or -not ($ownership -is [System.Collections.IDictionary]) -or -not $ownership.Contains('requiredCodeownerPaths')) {
                $results.Add((New-ValidationResult -Status Failed -Message 'ownership must contain requiredCodeownerPaths.' -Path $Path))
            }
            else {
                foreach ($unknownOwnershipProperty in @($ownership.Keys | Where-Object { $_ -ne 'requiredCodeownerPaths' })) {
                    $results.Add((New-ValidationResult -Status Failed -Message "Unknown ownership property '$unknownOwnershipProperty'." -Path $Path))
                }
                $requiredCodeownerPaths = @($ownership.requiredCodeownerPaths)
                if ($requiredCodeownerPaths.Count -lt 1) {
                    $results.Add((New-ValidationResult -Status Failed -Message 'ownership.requiredCodeownerPaths must contain at least one path.' -Path $Path))
                }
                $seenRequiredCodeownerPaths = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::Ordinal)
                foreach ($requiredPath in $requiredCodeownerPaths) {
                    if ($requiredPath -is [string] -and -not $seenRequiredCodeownerPaths.Add($requiredPath)) {
                        $results.Add((New-ValidationResult -Status Failed -Message "ownership.requiredCodeownerPaths contains duplicate value '$requiredPath'." -Path $Path))
                    }
                    $validLiteralPath = $requiredPath -is [string] -and
                        $requiredPath -match '^/(?!/)(?:\.[A-Za-z0-9_-]|[A-Za-z0-9_-])(?:[A-Za-z0-9._-]*[A-Za-z0-9_-])?(?:/(?:\.[A-Za-z0-9_-]|[A-Za-z0-9_-])(?:[A-Za-z0-9._-]*[A-Za-z0-9_-])?)*/?$' -and
                        $requiredPath -notmatch '(?i)(?:^|/)(?:placeholder|changeme|replace-me|todo)(?:/|$)' -and
                        $requiredPath -notmatch '[*?\[\]#!\\\s:]'
                    if (-not $validLiteralPath) {
                        $results.Add((New-ValidationResult -Status Failed -Message "ownership.requiredCodeownerPaths value '$requiredPath' must be a rooted literal CODEOWNERS path without dot or trailing-dot segments, traversal, wildcards, placeholders, drive/UNC syntax, comments, or whitespace." -Path $Path))
                    }
                }
            }
        }
        foreach ($disabled in @($json.controls.mandatoryControlsDisabled)) {
            if (-not $disabled.exceptionReference -or $disabled.exceptionReference -notmatch '^GOV-[A-Z0-9-]+$') {
                $results.Add((New-ValidationResult -Status Failed -Message "Mandatory control '$($disabled.control)' lacks a valid exception reference." -Path $Path))
            }
            elseif (@($json.exceptions | ForEach-Object { if ($_ -is [string]) { $_ } else { $_.identifier } }) -notcontains $disabled.exceptionReference) {
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
        if ($json.schemaVersion -eq '1.2.0') {
            foreach ($name in @('governanceCommitSha','workflowInterfaceVersion','repositoryOwnerType','standardsConsumption')) {
                if (-not $json.ContainsKey($name)) { $results.Add((New-ValidationResult -Status Failed -Message "Missing required 1.2.0 property '$name'." -Path $Path)) }
            }
            if ($json.ContainsKey('governanceCommitSha') -and $json.governanceCommitSha -notmatch '^[A-Fa-f0-9]{40}$') { $results.Add((New-ValidationResult -Status Failed -Message 'governanceCommitSha must be a full 40-character commit SHA.' -Path $Path)) }
            if ($json.ContainsKey('workflowInterfaceVersion') -and $json.workflowInterfaceVersion -notmatch '^\d+\.\d+\.\d+(?:-[A-Za-z0-9.-]+)?$') { $results.Add((New-ValidationResult -Status Failed -Message 'workflowInterfaceVersion must use semantic version format.' -Path $Path)) }
        }
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
        $ownerIdentifiers = @($json.owners | ForEach-Object { if ($_ -is [string]) { $_ } else { $_.identifier } })
        foreach ($item in @(Test-UniqueValues -Items $ownerIdentifiers -Name 'owners' -Path $Path)) { $results.Add($item) }
        foreach ($item in @(Test-UniqueValues -Items @($json.applicableStandards) -Name 'applicableStandards' -Path $Path)) { $results.Add($item) }
        foreach ($owner in @($json.owners)) {
            if ($json.schemaVersion -eq '1.2.0') {
                if ($owner -isnot [System.Collections.IDictionary]) {
                    $results.Add((New-ValidationResult -Status Failed -Message 'Version 1.2.0 owners must be structured records.' -Path $Path))
                    continue
                }
                $ownerType = [string](Get-JsonMemberValue -InputObject $owner -Name 'type')
                $ownerIdentifier = [string](Get-JsonMemberValue -InputObject $owner -Name 'identifier')
                $supportedOwnerTypes = @('github-user', 'github-team', 'email-contact')
                if ($supportedOwnerTypes -cnotcontains $ownerType) {
                    $results.Add((New-ValidationResult -Status Failed -Message "Owner '$ownerIdentifier' uses unsupported owner type '$ownerType'." -Path $Path))
                }
                elseif (-not (Test-StructuredOwnerIdentifier -Type $ownerType -Identifier $ownerIdentifier)) {
                    $results.Add((New-ValidationResult -Status Failed -Message "Owner '$ownerIdentifier' is malformed for owner type '$ownerType'." -Path $Path))
                }
                if ([string]::IsNullOrWhiteSpace([string]$owner.responsibility) -or ([string]$owner.responsibility).Length -lt 20) {
                    $results.Add((New-ValidationResult -Status Failed -Message "Owner '$($owner.identifier)' lacks substantive responsibility." -Path $Path))
                }
                if ([string]::IsNullOrWhiteSpace([string]$owner.escalation)) {
                    $results.Add((New-ValidationResult -Status Failed -Message "Owner '$($owner.identifier)' lacks escalation." -Path $Path))
                }
                if ([string]$owner.identifier -match '(?i)(?:placeholder|changeme|replace-me|todo)') {
                    $results.Add((New-ValidationResult -Status Failed -Message "Owner '$($owner.identifier)' is a placeholder and is not allowed." -Path $Path))
                }
                if ($owner.type -eq 'github-team' -and $json.repositoryOwnerType -ne 'Organization') {
                    $results.Add((New-ValidationResult -Status Failed -Message 'GitHub team ownership requires repositoryOwnerType Organization.' -Path $Path))
                }
                continue
            }
            $isEmailOwner = $owner -match '^[A-Za-z0-9_.+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}$'
            if ($owner -notmatch '^(@[A-Za-z0-9](?:[A-Za-z0-9-]{0,37}[A-Za-z0-9])?(?:/[A-Za-z0-9](?:[A-Za-z0-9_.-]*[A-Za-z0-9])?)?|[A-Za-z0-9_.+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,})$') {
                $results.Add((New-ValidationResult -Status Failed -Message "Owner '$owner' must be a GitHub user handle, organization/team handle, or email address." -Path $Path))
            }
            $isPlaceholderOwner = if ($isEmailOwner) {
                ($owner -split '@', 2)[0] -match '(?i)^(?:placeholder|changeme|replace-me|todo)$'
            }
            else {
                $owner -match '(?i)(?:^@|/)(?:placeholder|changeme|replace-me|todo)(?:/|$)'
            }
            if ($isPlaceholderOwner) {
                $results.Add((New-ValidationResult -Status Failed -Message "Owner '$owner' is a placeholder and is not allowed." -Path $Path))
            }
        }
        foreach ($standard in @($json.applicableStandards)) {
            foreach ($item in @(Test-RelativeRepositoryPath -Value $standard -Name 'applicableStandards item' -Path $Path -RequiredExtension '.md')) { $results.Add($item) }
        }
        if ($json.schemaVersion -eq '1.2.0') {
            foreach ($item in @(Test-RelativeRepositoryPath -Value $json.evidence.local.completion -Name 'local completion evidence' -Path $Path -RequiredExtension '.json')) { $results.Add($item) }
            foreach ($item in @(Test-RelativeRepositoryPath -Value $json.evidence.local.tests -Name 'local test evidence' -Path $Path -RequiredExtension '.json')) { $results.Add($item) }
            foreach ($item in @(Test-RelativeRepositoryPath -Value $json.evidence.hosted.workspace -Name 'hosted evidence workspace' -Path $Path)) { $results.Add($item) }
            foreach ($item in @(Test-RelativeRepositoryPath -Value $json.evidence.hosted.completion -Name 'hosted completion evidence' -Path $Path -RequiredExtension '.json')) { $results.Add($item) }
            foreach ($item in @(Test-RelativeRepositoryPath -Value $json.evidence.hosted.tests -Name 'hosted test evidence' -Path $Path -RequiredExtension '.json')) { $results.Add($item) }
        }
        else {
            foreach ($item in @(Test-RelativeRepositoryPath -Value $json.evidence.completionEvidencePath -Name 'completionEvidencePath' -Path $Path -RequiredExtension '.json')) { $results.Add($item) }
            foreach ($item in @(Test-RelativeRepositoryPath -Value $json.evidence.testEvidencePath -Name 'testEvidencePath' -Path $Path -RequiredExtension '.json')) { $results.Add($item) }
        }
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

function Test-GovernanceContractSemantics {
    <#
    .SYNOPSIS
    Cross-validates the manifest, governance configuration, standards, workflow interface, evidence, and exceptions.
    .DESCRIPTION
    Performs deterministic offline validation. Trusted caller repository, standards repository, owner-type, commit, workflow, profile, check-name, and date values must be supplied by the caller rather than inferred from repository declarations.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][string]$Root,
        [Parameter(Mandatory)][System.Collections.IDictionary]$Manifest,
        [Parameter(Mandatory)][System.Collections.IDictionary]$Config,
        [string]$ExpectedRepository,
        [string]$ExpectedStandardsRepository,
        [ValidateSet('Unknown','User','Organization')][string]$RepositoryOwnerType = 'Unknown',
        [string]$ExpectedGovernanceCommitSha,
        [string]$ExpectedWorkflowInterfaceVersion,
        [string]$ExpectedWorkflowProfile,
        [string]$ExpectedRequiredCheckName,
        [datetime]$ValidationDateUtc = [datetime]::UtcNow
    )

    $results = [System.Collections.Generic.List[object]]::new()
    $path = Join-Path $Root 'project-manifest.json'
    function Add-Finding([string]$Id, [string]$Message, [string]$FindingPath = $path) {
        $results.Add((New-ValidationResult -Status Failed -Message "$Id $Message" -Path $FindingPath))
    }

    if ($ExpectedRepository -and -not [string]::Equals([string]$Manifest.repository, $ExpectedRepository, [System.StringComparison]::OrdinalIgnoreCase)) {
        Add-Finding 'GCS001' "Repository identity '$($Manifest.repository)' does not match trusted repository '$ExpectedRepository'."
    }

    foreach ($document in @($Manifest, $Config)) {
        if ($document.Contains('governanceVersion') -and $document.governanceVersion -notmatch '^\d+\.\d+\.\d+(?:-[A-Za-z0-9.-]+)?$') {
            Add-Finding 'GCS002' 'governanceVersion must contain a semantic release version, never a commit SHA.'
        }
        if ($document.Contains('governanceCommitSha') -and $document.governanceCommitSha -notmatch '^[A-Fa-f0-9]{40}$') {
            Add-Finding 'GCS002' 'governanceCommitSha must contain exactly 40 hexadecimal characters.'
        }
    }
    $usesSchemaVersion12 = $Manifest.schemaVersion -ceq '1.2.0' -or $Config.schemaVersion -ceq '1.2.0'
    if ($usesSchemaVersion12 -and $Manifest.schemaVersion -cne $Config.schemaVersion) {
        Add-Finding 'GCS002' 'Manifest and governance configuration schema versions must both be 1.2.0 when either document opts into schema version 1.2.0.'
    }
    if ($Manifest.Contains('governanceVersion') -and $Config.Contains('governanceVersion') -and $Manifest.governanceVersion -cne $Config.governanceVersion) {
        Add-Finding 'GCS002' 'Manifest and governance configuration governance versions disagree.'
    }
    if ($Manifest.Contains('governanceCommitSha') -and $Config.Contains('governanceCommitSha') -and $Manifest.governanceCommitSha -ne $Config.governanceCommitSha) {
        Add-Finding 'GCS002' 'Manifest and governance configuration governance commit SHAs disagree.'
    }
    if ($ExpectedGovernanceCommitSha -and $Manifest.schemaVersion -eq '1.2.0' -and $Manifest.governanceCommitSha -ne $ExpectedGovernanceCommitSha) {
        Add-Finding 'GCS002' 'Declared governance commit SHA does not match the trusted workflow standards SHA.'
    }

    if ($Manifest.schemaVersion -ceq '1.2.0') {
        $manifestRepositoryOwnerType = [string](Get-JsonMemberValue -InputObject $Manifest -Name 'repositoryOwnerType')
        if (@('User', 'Organization') -cnotcontains $manifestRepositoryOwnerType) {
            Add-Finding 'GCS003' "Manifest repositoryOwnerType '$manifestRepositoryOwnerType' is unsupported or noncanonical."
        }
        $seenOwners = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::OrdinalIgnoreCase)
        $enforceableOwners = 0
        foreach ($owner in @($Manifest.owners)) {
            if ($owner -isnot [System.Collections.IDictionary]) {
                Add-Finding 'GCS003' 'Version 1.2.0 owners must be structured records.'
                continue
            }
            $ownerType = [string](Get-JsonMemberValue -InputObject $owner -Name 'type')
            $identifier = [string](Get-JsonMemberValue -InputObject $owner -Name 'identifier')
            $supportedOwnerTypes = @('github-user', 'github-team', 'email-contact')
            if (-not $seenOwners.Add($identifier)) { Add-Finding 'GCS003' "Duplicate owner identifier '$identifier'." }
            if ($identifier -match '(?i)(?:placeholder|changeme|replace-me|todo)') { Add-Finding 'GCS003' "Owner '$identifier' is a placeholder." }
            $validIdentifier = $false
            if ($supportedOwnerTypes -cnotcontains $ownerType) {
                Add-Finding 'GCS003' "Owner '$identifier' uses unsupported owner type '$ownerType'."
            }
            else {
                $validIdentifier = Test-StructuredOwnerIdentifier -Type $ownerType -Identifier $identifier
                if (-not $validIdentifier) { Add-Finding 'GCS003' "Owner '$identifier' is malformed for owner type '$ownerType'." }
            }
            if ($validIdentifier -and $ownerType -ceq 'github-user') { $enforceableOwners++ }
            if ($validIdentifier -and $ownerType -ceq 'github-team') {
                $enforceableOwners++
                if ($manifestRepositoryOwnerType -cne 'Organization' -or $RepositoryOwnerType -ceq 'User') { Add-Finding 'GCS003' 'GitHub team ownership is invalid for a user-owned repository.' }
            }
            if ([string]::IsNullOrWhiteSpace([string]$owner.responsibility) -or ([string]$owner.responsibility).Length -lt 20) { Add-Finding 'GCS003' "Owner '$identifier' lacks substantive responsibility." }
            if ([string]::IsNullOrWhiteSpace([string]$owner.escalation)) { Add-Finding 'GCS003' "Owner '$identifier' lacks escalation." }
        }
        if ($enforceableOwners -lt 1) { Add-Finding 'GCS003' 'At least one GitHub user or team owner is required.' }
        if ($RepositoryOwnerType -cne 'Unknown' -and $manifestRepositoryOwnerType -cne $RepositoryOwnerType) { Add-Finding 'GCS003' 'Manifest repository owner type disagrees with trusted owner type.' }
    }

    $manifestStandards = @()
    $configStandards = @()
    if ($Manifest.schemaVersion -eq '1.2.0') {
        $standardCollections = @(
            @{ Label='Manifest applicableStandards'; Document=$Manifest; Member='applicableStandards'; Target='manifest' },
            @{ Label='Governance configuration applicableAgentStandards'; Document=$Config; Member='applicableAgentStandards'; Target='config' }
        )
        foreach ($collection in $standardCollections) {
            $value = Get-JsonMemberValue -InputObject $collection.Document -Name $collection.Member
            $validValues = [System.Collections.Generic.List[string]]::new()
            if ($null -eq $value -or $value -is [string] -or $value -isnot [System.Collections.IList] -or $value.Count -eq 0) {
                Add-Finding 'GCS004' "$($collection.Label) must be a nonempty array of standards paths."
            }
            else {
                $seenStandards = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::Ordinal)
                for ($standardIndex = 0; $standardIndex -lt $value.Count; $standardIndex++) {
                    $standardValue = $value[$standardIndex]
                    if ($null -eq $standardValue -or $standardValue -isnot [string]) {
                        Add-Finding 'GCS004' "$($collection.Label) entries must be non-null strings."
                        continue
                    }
                    $standard = [string]$standardValue
                    if ([string]::IsNullOrWhiteSpace($standard)) {
                        Add-Finding 'GCS004' "$($collection.Label) entries must not be blank."
                        continue
                    }
                    if ($standard -match '[\x00-\x1F\x7F]' -or [System.IO.Path]::IsPathRooted($standard) -or $standard -match '(^|[\\/])\.\.([\\/]|$)' -or $standard -cnotmatch '^agents/AGENTS_[A-Za-z]+\.md$') {
                        Add-Finding 'GCS004' "$($collection.Label) entry '$standard' is not a canonical safe standards path."
                        continue
                    }
                    if (-not $seenStandards.Add($standard)) {
                        Add-Finding 'GCS004' "$($collection.Label) contains duplicate entry '$standard'."
                        continue
                    }
                    $validValues.Add($standard)
                }
            }
            if ($collection.Target -eq 'manifest') { $manifestStandards = @($validValues) }
            else { $configStandards = @($validValues) }
        }

        $standardsConsumption = Get-JsonMemberValue -InputObject $Manifest -Name 'standardsConsumption'
        if ($standardsConsumption -isnot [System.Collections.IDictionary]) {
            Add-Finding 'GCS004' 'standardsConsumption must be an object with an explicit supported mode.'
        }
        else {
            $allowedFields = @('mode', 'sourceRepository', 'sourceCommitSha', 'localPath')
            foreach ($fieldName in @($standardsConsumption.Keys)) {
                if ($allowedFields -cnotcontains [string]$fieldName) {
                    Add-Finding 'GCS004' "standardsConsumption contains unsupported field '$fieldName'."
                }
            }

            $modeValue = Get-JsonMemberValue -InputObject $standardsConsumption -Name 'mode'
            $mode = if ($modeValue -is [string]) { [string]$modeValue } else { $null }
            $supportedMode = $mode -cin @('central-reference', 'vendored', 'local')
            if (-not $supportedMode) {
                Add-Finding 'GCS004' 'Standards consumption mode is missing or unsupported.'
            }
            else {
                $hasSourceRepository = Test-JsonMember -InputObject $standardsConsumption -Name 'sourceRepository'
                $hasSourceCommitSha = Test-JsonMember -InputObject $standardsConsumption -Name 'sourceCommitSha'
                $hasLocalPath = Test-JsonMember -InputObject $standardsConsumption -Name 'localPath'
                $sourceRepositoryValue = Get-JsonMemberValue -InputObject $standardsConsumption -Name 'sourceRepository'
                $sourceCommitShaValue = Get-JsonMemberValue -InputObject $standardsConsumption -Name 'sourceCommitSha'
                $localPathValue = Get-JsonMemberValue -InputObject $standardsConsumption -Name 'localPath'
                $sourceRepository = if ($sourceRepositoryValue -is [string]) { [string]$sourceRepositoryValue } else { $null }
                $sourceCommitSha = if ($sourceCommitShaValue -is [string]) { [string]$sourceCommitShaValue } else { $null }

                if ($mode -cin @('central-reference', 'vendored')) {
                    if (-not $hasSourceRepository) {
                        Add-Finding 'GCS004' "standardsConsumption.sourceRepository is required for $mode mode."
                    }
                    elseif ($null -eq $sourceRepository -or $sourceRepository -cnotmatch '^[A-Za-z0-9](?:[A-Za-z0-9-]{0,37}[A-Za-z0-9])?/[A-Za-z0-9](?:[A-Za-z0-9._-]{0,98}[A-Za-z0-9])?$') {
                        Add-Finding 'GCS004' 'standardsConsumption.sourceRepository must use valid owner/repository syntax.'
                    }
                    if (-not $hasSourceCommitSha -or $null -eq $sourceCommitSha -or $sourceCommitSha -cnotmatch '^[A-Fa-f0-9]{40}$') {
                        Add-Finding 'GCS004' "standardsConsumption.sourceCommitSha must contain exactly 40 hexadecimal characters for $mode mode."
                    }
                }

                if ($mode -ceq 'central-reference') {
                    if ($hasLocalPath) {
                        Add-Finding 'GCS004' 'central-reference standards consumption forbids localPath.'
                    }
                    if ($ExpectedStandardsRepository -and -not [string]::Equals($sourceRepository, $ExpectedStandardsRepository, [System.StringComparison]::OrdinalIgnoreCase)) {
                        Add-Finding 'GCS004' "Central standards source repository '$sourceRepository' does not match trusted standards repository '$ExpectedStandardsRepository'."
                    }
                    if ($ExpectedGovernanceCommitSha -and $sourceCommitSha -ne $ExpectedGovernanceCommitSha) {
                        Add-Finding 'GCS004' 'Central standards source commit SHA does not match the trusted workflow standards SHA.'
                    }
                    if ($Manifest.Contains('governanceCommitSha') -and $sourceCommitSha -ne $Manifest.governanceCommitSha) {
                        Add-Finding 'GCS004' 'Central standards source commit SHA disagrees with the declared governance commit SHA.'
                    }
                }
                elseif ($mode -ceq 'local') {
                    if ($hasSourceRepository) { Add-Finding 'GCS004' 'local standards consumption forbids sourceRepository.' }
                    if ($hasSourceCommitSha) { Add-Finding 'GCS004' 'local standards consumption forbids sourceCommitSha.' }
                }

                if ($mode -cin @('vendored', 'local')) {
                    if (-not $hasLocalPath -or $localPathValue -isnot [string] -or [string]::IsNullOrWhiteSpace([string]$localPathValue)) {
                        Add-Finding 'GCS004' "standardsConsumption.localPath is required for $mode mode."
                    }
                    elseif ([System.IO.Path]::IsPathRooted([string]$localPathValue) -or [string]$localPathValue -match '(^|[\\/])\.\.([\\/]|$)' -or [string]$localPathValue -match '[\x00-\x1F\x7F]') {
                        Add-Finding 'GCS004' "standardsConsumption.localPath must be a safe repository-relative path for $mode mode."
                    }
                    else {
                        try {
                            $authorityRoot = Resolve-SafePath -Root $Root -ChildPath ([string]$localPathValue)
                            $authorityItem = Get-Item -LiteralPath $authorityRoot -Force -ErrorAction Stop
                            if (-not $authorityItem.PSIsContainer) {
                                Add-Finding 'GCS004' "The $mode authoritative standards root must be an existing physical directory."
                            }
                            else {
                                foreach ($standard in $manifestStandards) {
                                    try {
                                        $standardTarget = Resolve-SafePath -Root $Root -ChildPath $standard
                                        $relativeToAuthority = [System.IO.Path]::GetRelativePath($authorityRoot, $standardTarget)
                                        if ([System.IO.Path]::IsPathRooted($relativeToAuthority) -or $relativeToAuthority -eq '..' -or $relativeToAuthority.StartsWith(('..' + [System.IO.Path]::DirectorySeparatorChar), [System.StringComparison]::Ordinal) -or $relativeToAuthority.StartsWith(('..' + [System.IO.Path]::AltDirectorySeparatorChar), [System.StringComparison]::Ordinal)) {
                                            Add-Finding 'GCS004' "Applicable standard '$standard' is outside the $mode authoritative standards root."
                                            continue
                                        }
                                        if (-not (Test-ExactRepositoryPathCasing -Root $Root -ChildPath $standard)) {
                                            Add-Finding 'GCS004' "Applicable standard '$standard' does not match the authoritative filesystem path exactly."
                                            continue
                                        }
                                        if (-not (Test-Path -LiteralPath $standardTarget -PathType Leaf)) {
                                            Add-Finding 'GCS004' "Applicable standard '$standard' must exist as a regular file beneath the $mode authoritative standards root."
                                        }
                                    }
                                    catch {
                                        Add-Finding 'GCS004' "Applicable standard '$standard' must exist as a regular file beneath the $mode authoritative standards root. $($_.Exception.Message)"
                                    }
                                }
                            }
                        }
                        catch { Add-Finding 'GCS004' $_.Exception.Message }
                    }
                }
            }
        }
    }

    $technologyStandards = @{
        powershell='agents/AGENTS_PowerShell.md'; dotnet='agents/AGENTS_DotNet.md'; web='agents/AGENTS_WebFrontend.md'; database='agents/AGENTS_Database.md';
        'worker-service'='agents/AGENTS_WorkerService.md'; integration='agents/AGENTS_Integration.md'; infrastructure='agents/AGENTS_Infrastructure.md'
    }
    if ($Manifest.schemaVersion -cne '1.2.0') {
        $manifestStandards = @($Manifest.applicableStandards)
        $configStandards = @($Config.applicableAgentStandards)
    }
    if ($Manifest.schemaVersion -ceq '1.2.0' -and @('powershell','dotnet','web','database','worker-service','integration','infrastructure','governance','mixed') -cnotcontains [string]$Manifest.projectType) {
        Add-Finding 'GCS005' "Project type '$($Manifest.projectType)' is unsupported or noncanonical."
    }
    if ($manifestStandards -cnotcontains 'agents/AGENTS_Base.md') { Add-Finding 'GCS005' 'The base agent standard is required.' }
    foreach ($technology in @($Manifest.technologies)) {
        if ($technologyStandards.ContainsKey([string]$technology) -and $manifestStandards -cnotcontains $technologyStandards[[string]$technology]) { Add-Finding 'GCS005' "Technology '$technology' requires '$($technologyStandards[[string]$technology])'." }
    }
    if ($Manifest.projectType -ceq 'governance') {
        foreach ($requiredStandard in @('agents/AGENTS_PowerShell.md','agents/AGENTS_Integration.md','agents/AGENTS_Infrastructure.md')) {
            if ($manifestStandards -cnotcontains $requiredStandard) { Add-Finding 'GCS005' "Governance and GitHub Actions repositories require '$requiredStandard'." }
        }
    }
    if (@(Compare-Object $manifestStandards $configStandards -CaseSensitive).Count -gt 0) { Add-Finding 'GCS006' 'Manifest and governance configuration applicable standards disagree.' }
    $agentsPath = Join-Path $Root 'AGENTS.md'
    if (Test-Path -LiteralPath $agentsPath -PathType Leaf) {
        $agentsText = Get-Content -Raw -LiteralPath $agentsPath
        foreach ($standard in $manifestStandards) { if ($agentsText -cnotmatch [regex]::Escape($standard)) { Add-Finding 'GCS006' "Root AGENTS.md does not declare '$standard'." $agentsPath } }
    }

    if ($Manifest.Contains('workflowInterfaceVersion') -and $Config.Contains('workflowInterfaceVersion') -and $Manifest.workflowInterfaceVersion -cne $Config.workflowInterfaceVersion) { Add-Finding 'GCS007' 'Manifest and configuration workflow interface versions disagree.' }
    if ($ExpectedWorkflowInterfaceVersion -and $Manifest.schemaVersion -ceq '1.2.0' -and $Manifest.workflowInterfaceVersion -cne $ExpectedWorkflowInterfaceVersion) { Add-Finding 'GCS007' 'Workflow interface version does not match trusted context.' }
    $workflowProfile = if ($Config.Contains('workflowProfile')) { [string]$Config.workflowProfile } else { $null }
    if ($Config.schemaVersion -ceq '1.2.0' -and @('downstream', 'standards-maintainer') -cnotcontains $workflowProfile) { Add-Finding 'GCS007' "Workflow profile '$workflowProfile' is unsupported or noncanonical." }
    if ($ExpectedWorkflowProfile -and $Config.schemaVersion -ceq '1.2.0' -and $workflowProfile -cne $ExpectedWorkflowProfile) { Add-Finding 'GCS007' 'Workflow profile does not match trusted context.' }
    if ($Config.schemaVersion -ceq '1.2.0') {
        $interface = $Config.workflowInterface
        if ($interface.path -cne '.github/workflows/governance-ci-reusable.yml' -or $interface.jobId -cne 'governance' -or $interface.jobName -cne 'Governance validation' -or $interface.artifactNamePattern -cne 'governance-evidence-${run_id}') { Add-Finding 'GCS007' 'Workflow interface declaration conflicts with the supported interface.' }
        $requiredInputs = @('project-path', 'governance-version', 'artifact-retention-days', 'controlled-failure-test')
        $requiredOutputs = @('evidence-path', 'artifact-name')
        if (-not (Test-ExactStringSet -Actual @($interface.inputs) -Expected $requiredInputs)) { Add-Finding 'GCS007' 'Workflow interface inputs do not exactly match the supported interface.' }
        if (-not (Test-ExactStringSet -Actual @($interface.outputs) -Expected $requiredOutputs)) { Add-Finding 'GCS007' 'Workflow interface outputs do not exactly match the supported interface.' }
    }

    $supportedCategories = @('Contract','JsonSchemas','YamlSyntax','WorkflowArchitecture','MarkdownLinks','DocumentationCompleteness','ForbiddenPatterns','RepositoryHealth','CodexSkills','Evidence','Examples','Pester','PSScriptAnalyzer','PowerShellParser')
    $maintainerOnlyCategories = @('JsonSchemas','YamlSyntax','WorkflowArchitecture','RepositoryHealth','Evidence','Examples','Pester','PSScriptAnalyzer','PowerShellParser')
    [object]$validationCategoriesValue = $null
    if ($Config.Contains('validationCategories')) { $validationCategoriesValue = $Config['validationCategories'] }
    $validationCategoriesIsArray = $validationCategoriesValue -is [System.Collections.IList] -and $validationCategoriesValue -isnot [string]
    if ($Config.schemaVersion -ceq '1.2.0') {
        $declaredCategories = if ($validationCategoriesIsArray) { @($validationCategoriesValue) } else { @() }
        if (-not $validationCategoriesIsArray -or $declaredCategories.Count -eq 0) {
            Add-Finding 'GCS008' 'validationCategories must be declared as a nonempty array.'
        }
    }
    else {
        $declaredCategories = @($validationCategoriesValue)
    }
    foreach ($category in $declaredCategories) { if ($category -cnotin $supportedCategories) { Add-Finding 'GCS008' "Unsupported validation category '$category'." } }
    if ($workflowProfile -ceq 'standards-maintainer') {
        foreach ($category in $supportedCategories) { if ($declaredCategories -cnotcontains $category) { Add-Finding 'GCS008' "Maintainer profile omits executed category '$category'." } }
    }
    elseif ($workflowProfile -ceq 'downstream') {
        if ($Config.schemaVersion -ceq '1.2.0') {
            if ($validationCategoriesIsArray -and $declaredCategories.Count -gt 0 -and $declaredCategories -cnotcontains 'Contract') {
                Add-Finding 'GCS008' "Downstream profile validationCategories declaration must include mandatory category 'Contract'."
            }
        }
        foreach ($category in $declaredCategories) {
            if ($category -cin $maintainerOnlyCategories) { Add-Finding 'GCS008' "Downstream profile cannot declare maintainer-only validation category '$category'." }
        }
    }

    if ($Manifest.schemaVersion -ceq '1.2.0') {
        if ($Manifest.evidence.hosted.workspace -cne 'evidence' -or $Manifest.evidence.hosted.completion -cne 'completion-result.json' -or $Manifest.evidence.hosted.tests -cne 'ci-test-results.json' -or $Manifest.evidence.hosted.artifactNamePattern -cne 'governance-evidence-${run_id}') { Add-Finding 'GCS009' 'Hosted evidence declaration conflicts with reusable workflow outputs.' }
        foreach ($localPath in @($Manifest.evidence.local.completion, $Manifest.evidence.local.tests)) {
            if (
                $localPath -isnot [string] -or
                [string]::IsNullOrWhiteSpace([string]$localPath) -or
                [System.IO.Path]::IsPathRooted([string]$localPath) -or
                [string]$localPath -cmatch '^[A-Za-z]:' -or
                [string]$localPath -cmatch '^[\\/]' -or
                ([string]$localPath).Contains('..') -or
                -not ([string]$localPath).EndsWith('.json', [System.StringComparison]::Ordinal)
            ) {
                Add-Finding 'GCS009' "Local evidence path '$localPath' must be a schema-valid repository-relative JSON path."
                continue
            }
            try { Resolve-SafePath -Root $Root -ChildPath ([string]$localPath) -AllowMissingLeaf | Out-Null } catch { Add-Finding 'GCS009' $_.Exception.Message }
        }
    }

    $exceptionById = @{}
    $activeExceptionIds = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::OrdinalIgnoreCase)
    $exceptionRecords = @($Manifest.exceptions) + @($Config.exceptions)
    $requiresStructuredExceptions = $Manifest.schemaVersion -eq '1.2.0' -or $Config.schemaVersion -eq '1.2.0'
    $requiredExceptionFields = @('identifier','status','scope','owner','approver','approvalDate','expiration','affectedControl','compensatingControls','remediationPlan','evidenceReference')
    foreach ($exception in $exceptionRecords) {
        if ($exception -is [string]) {
            if ($requiresStructuredExceptions) { Add-Finding 'GCS010' "Legacy exception reference '$exception' is not valid for schema version 1.2.0." }
            continue
        }
        if ($exception -isnot [System.Collections.IDictionary]) {
            Add-Finding 'GCS010' 'Exception record is malformed and must be a structured object.'
            continue
        }

        $missingFields = @($requiredExceptionFields | Where-Object { -not $exception.Contains($_) })
        $identifier = if ($exception.Contains('identifier')) { [string]$exception.identifier } else { '<missing>' }
        $malformed = $missingFields.Count -gt 0
        if ($missingFields.Count -gt 0) { Add-Finding 'GCS010' "Exception '$identifier' is missing required fields: $($missingFields -join ', ')." }
        $unexpectedFields = @($exception.Keys | Where-Object { $requiredExceptionFields -cnotcontains [string]$_ })
        if ($unexpectedFields.Count -gt 0) { Add-Finding 'GCS010' "Exception '$identifier' contains unsupported fields: $($unexpectedFields -join ', ')."; $malformed = $true }
        if (-not $exception.Contains('identifier') -or $exception.identifier -isnot [string] -or $identifier -cnotmatch '^GOV-[A-Z0-9-]+$') { Add-Finding 'GCS010' "Exception identifier '$identifier' is malformed."; $malformed = $true }
        if ($identifier -ne '<missing>') {
            if ($exceptionById.ContainsKey($identifier)) { Add-Finding 'GCS010' "Duplicate exception identifier '$identifier'."; continue }
            $exceptionById[$identifier] = $exception
        }

        $lengthRules = @{ scope=@(10,500); owner=@(2,254); approver=@(2,254); affectedControl=@(3,160); remediationPlan=@(20,1000) }
        foreach ($field in $lengthRules.Keys) {
            $value = if ($exception.Contains($field)) { [string]$exception[$field] } else { '' }
            if (-not $exception.Contains($field) -or $exception[$field] -isnot [string] -or $value.Length -lt $lengthRules[$field][0] -or $value.Length -gt $lengthRules[$field][1]) { $malformed = $true }
        }
        $evidenceReference = if ($exception.Contains('evidenceReference')) { [string]$exception.evidenceReference } else { '' }
        if (
            -not $exception.Contains('evidenceReference') -or
            $exception.evidenceReference -isnot [string] -or
            [string]::IsNullOrWhiteSpace($evidenceReference) -or
            [System.IO.Path]::IsPathRooted($evidenceReference) -or
            $evidenceReference -cmatch '^[A-Za-z]:' -or
            $evidenceReference -cmatch '^[\\/]' -or
            $evidenceReference.Contains('..')
        ) { $malformed = $true }
        $compensatingControls = @()
        $compensatingControlsValue = $null
        if ($exception.Contains('compensatingControls')) { $compensatingControlsValue = $exception['compensatingControls'] }
        $compensatingControlsIsArray = $compensatingControlsValue -is [System.Collections.IList] -and $compensatingControlsValue -isnot [string]
        if ($compensatingControlsIsArray) { $compensatingControls = @($compensatingControlsValue) }
        $seenCompensatingControls = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::Ordinal)
        if (
            -not $compensatingControlsIsArray -or
            $compensatingControls.Count -eq 0 -or
            @($compensatingControls | Where-Object { $_ -isnot [string] -or ([string]$_).Length -lt 10 }).Count -gt 0
        ) { $malformed = $true }
        foreach ($control in $compensatingControls) {
            if ($control -is [string] -and -not $seenCompensatingControls.Add([string]$control)) { $malformed = $true }
        }
        if ($malformed) { Add-Finding 'GCS010' "Exception '$identifier' is malformed." }

        $approvalDate = [datetime]::MinValue
        $expiration = [datetime]::MinValue
        $dateStyles = [System.Globalization.DateTimeStyles]::AssumeUniversal
        $approvalDateValid = $exception.Contains('approvalDate') -and $exception.approvalDate -is [string] -and [datetime]::TryParseExact([string]$exception.approvalDate, 'yyyy-MM-dd', [System.Globalization.CultureInfo]::InvariantCulture, $dateStyles, [ref]$approvalDate)
        $expirationValid = $exception.Contains('expiration') -and $exception.expiration -is [string] -and [datetime]::TryParseExact([string]$exception.expiration, 'yyyy-MM-dd', [System.Globalization.CultureInfo]::InvariantCulture, $dateStyles, [ref]$expiration)
        $validationDate = $ValidationDateUtc.ToUniversalTime().Date
        $status = if ($exception.Contains('status')) { [string]$exception.status } else { $null }
        if (-not $exception.Contains('status') -or $exception.status -isnot [string] -or @('Approved', 'Rejected', 'Revoked', 'Expired') -cnotcontains $status) { Add-Finding 'GCS010' "Exception '$identifier' status '$status' is unsupported or noncanonical."; $malformed = $true }
        $active = -not $malformed -and $status -ceq 'Approved' -and $approvalDateValid -and $expirationValid -and $approvalDate.Date -le $validationDate -and $expiration.Date -ge $validationDate -and $expiration.Date -ge $approvalDate.Date
        if (-not $active) { Add-Finding 'GCS010' "Exception '$identifier' is not an active, approved, and unexpired record." }
        elseif ($identifier -ne '<missing>') { [void]$activeExceptionIds.Add($identifier) }
    }
    foreach ($disabled in @($Config.controls.mandatoryControlsDisabled)) {
        if (-not $exceptionById.ContainsKey($disabled.exceptionReference) -or -not $activeExceptionIds.Contains([string]$disabled.exceptionReference) -or $exceptionById[$disabled.exceptionReference].affectedControl -cne $disabled.control) { Add-Finding 'GCS011' "Disabled control '$($disabled.control)' lacks an applicable active exception." }
    }

    if ($Config.schemaVersion -eq '1.2.0') {
        [object]$requiredCheckNamesValue = $null
        if ($Config.Contains('requiredCheckNames')) { $requiredCheckNamesValue = $Config['requiredCheckNames'] }
        $workflowInterfaceObject = Get-JsonMemberValue -InputObject $Config -Name 'workflowInterface'
        [object]$interfaceRequiredCheckNamesValue = $null
        if ($workflowInterfaceObject -is [System.Collections.IDictionary] -and $workflowInterfaceObject.Contains('requiredCheckNames')) {
            $interfaceRequiredCheckNamesValue = $workflowInterfaceObject['requiredCheckNames']
        }
        $requiredCheckIssues = @(Get-RequiredCheckNameContractIssues -Wrapper @{ Value = $requiredCheckNamesValue } -Name 'Config.requiredCheckNames')
        $interfaceRequiredCheckIssues = @(Get-RequiredCheckNameContractIssues -Wrapper @{ Value = $interfaceRequiredCheckNamesValue } -Name 'Config.workflowInterface.requiredCheckNames')
        foreach ($issue in @($requiredCheckIssues + $interfaceRequiredCheckIssues)) { Add-Finding 'GCS012' $issue }

        $requiredCheckNameList = [System.Collections.ArrayList]::new()
        if ($requiredCheckNamesValue -is [System.Collections.IList]) {
            for ($index = 0; $index -lt $requiredCheckNamesValue.Count; $index++) { [void]$requiredCheckNameList.Add($requiredCheckNamesValue[$index]) }
        }
        $interfaceRequiredCheckNameList = [System.Collections.ArrayList]::new()
        if ($interfaceRequiredCheckNamesValue -is [System.Collections.IList]) {
            for ($index = 0; $index -lt $interfaceRequiredCheckNamesValue.Count; $index++) { [void]$interfaceRequiredCheckNameList.Add($interfaceRequiredCheckNamesValue[$index]) }
        }
        [object[]]$requiredCheckNames = $requiredCheckNameList.ToArray()
        [object[]]$interfaceRequiredCheckNames = $interfaceRequiredCheckNameList.ToArray()
        $requiredCheckArraysValid = $requiredCheckIssues.Count -eq 0 -and $interfaceRequiredCheckIssues.Count -eq 0
        if ($ExpectedRequiredCheckName -and $requiredCheckNames -cnotcontains $ExpectedRequiredCheckName) { Add-Finding 'GCS012' "Required check '$ExpectedRequiredCheckName' is absent from the workflow contract." }
        if ($requiredCheckArraysValid -and -not (Test-ExactStringSet -Actual $requiredCheckNames -Expected ([string[]]$interfaceRequiredCheckNames))) { Add-Finding 'GCS012' 'Branch-protection and workflow-interface required check names must agree exactly as a case-sensitive set using ordinal comparison.' }

        if ($requiredCheckArraysValid -and $workflowProfile -ceq 'downstream') {
            $reusableJobName = [string](Get-JsonMemberValue -InputObject $workflowInterfaceObject -Name 'jobName')
            $downstreamCheckSuffix = ' / ' + $reusableJobName
            $hasDownstreamGovernanceCheck = @($requiredCheckNames | Where-Object {
                $candidateCheckName = [string]$_
                $candidateCheckName.EndsWith($downstreamCheckSuffix, [System.StringComparison]::Ordinal) -and
                    -not [string]::IsNullOrWhiteSpace($candidateCheckName.Substring(0, $candidateCheckName.Length - $downstreamCheckSuffix.Length))
            }).Count -gt 0
            if (-not $hasDownstreamGovernanceCheck) {
                Add-Finding 'GCS012' "Downstream required check names must include a caller check for workflow job '$reusableJobName'."
            }
        }

        if ($workflowProfile -ceq 'standards-maintainer' -and $Config.workflowInterfaceVersion -ceq '1.0.0') {
            foreach ($canonicalCheckName in @(Get-CanonicalMaintainerRequiredCheckNames)) {
                if ($requiredCheckNames -cnotcontains $canonicalCheckName) { Add-Finding 'GCS012' "Maintainer branch-protection checks omit canonical check '$canonicalCheckName'." }
                if ($interfaceRequiredCheckNames -cnotcontains $canonicalCheckName) { Add-Finding 'GCS012' "Maintainer workflow-interface checks omit canonical check '$canonicalCheckName'." }
            }
        }
    }

    if ($Manifest.projectType -ceq 'governance') {
        foreach ($schemaFile in @(Get-ChildItem -LiteralPath (Join-Path $Root 'schemas') -Filter '*.schema.json' -File -ErrorAction SilentlyContinue)) {
            $schema = Read-JsonFile -Path $schemaFile.FullName
            if (-not $schema.Contains('$id') -or $schema['$id'] -cnotmatch '^urn:aiallthethingz:engineering-standards:schema:[a-z0-9-]+$') { Add-Finding 'GCS013' "Schema '$($schemaFile.Name)' does not use the controlled namespace." $schemaFile.FullName }
        }
    }

    if ($results.Count -eq 0) { $results.Add((New-ValidationResult -Status Passed -Message 'Governance contract semantics are coherent.' -Path $Root -Severity info)) }
    @($results)
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
    'Test-GovernanceContractSemantics',
    'Test-TestEvidenceObject',
    'Test-ArtifactRecordObject',
    'Test-VerifiedRunObject',
    'ConvertTo-OrderedJson',
    'ConvertTo-SanitizedWorkflowOutputLine',
    'ConvertTo-SanitizedWorkflowFailureMessage',
    'Write-GovernanceBootstrapFailureReport'
)
