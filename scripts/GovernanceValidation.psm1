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
        [Parameter(Mandatory)][ValidateSet('Passed','Failed','Warning','NotRun','Blocked')][string]$Status,
        [Parameter(Mandatory)][string]$Message,
        [string]$Path = '',
        [ValidateSet('info','warning','error')][string]$Severity = $(if ($Status -eq 'Passed') { 'info' } elseif ($Status -eq 'Warning') { 'warning' } else { 'error' }),
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
        warnings = @($Results | Where-Object status -eq 'Warning').Count
        blocked = @($Results | Where-Object status -eq 'Blocked').Count
        notRun = @($Results | Where-Object status -eq 'NotRun').Count
    }
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
    $prefix = $rootFull.TrimEnd([System.IO.Path]::DirectorySeparatorChar, [System.IO.Path]::AltDirectorySeparatorChar) + [System.IO.Path]::DirectorySeparatorChar
    if (-not ($candidateFull.Equals($rootFull, [StringComparison]::OrdinalIgnoreCase) -or $candidateFull.StartsWith($prefix, [StringComparison]::OrdinalIgnoreCase))) {
        throw "Path '$ChildPath' resolves outside '$Root'."
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
        [Parameter(Mandatory)][ValidateSet('completion-result','test-evidence','artifact-record','project-manifest','governance-config')][string]$Kind
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
        'completion-result' { @('schemaVersion','executionContext','repository','commitSha','branch','pullRequest','governanceVersion','riskClassification','status','startedAtUtc','completedAtUtc','summary','changedFiles','commandsExecuted','commandsNotExecuted','tests','artifacts','warnings','knownLimitations','remainingRisks','exceptions','approvals') }
        'test-evidence' { @('schemaVersion','name','category','status','command','workingDirectory','startedAtUtc','completedAtUtc','durationSeconds','runtime','toolVersion','exitCode','summary','warnings','failureReason') }
        'artifact-record' { @('schemaVersion','name','artifactType','path','mediaType','sizeBytes','sha256','createdAtUtc','producer','retention','sensitivity','relatedTest') }
        'project-manifest' { @('schemaVersion','projectName','repository','description','projectType','technologies','governanceVersion','riskClassification','dataClassification','owners','environments','applicableStandards','requiredWorkflows','externalIntegrations','secretsProvider','productionApprovalRequired','evidence','exceptions') }
        'governance-config' { @('schemaVersion','manifestPath','evidencePath','requiredDocumentationPaths','applicableAgentStandards','validationCategories','additionalForbiddenPatterns','reviewedAllowlist','controls','exceptions') }
    }

    foreach ($name in $required) {
        if (-not $json.ContainsKey($name)) {
            $results.Add((New-ValidationResult -Status Failed -Message "Missing required property '$name'." -Path $Path))
        }
    }
    if ($results.Count -gt 0) { return @($results) }

    if ($json.schemaVersion -ne '1.0.0') {
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

    if ($Kind -eq 'completion-result') {
        if ($json.governanceVersion -notmatch '^[0-9]+\.[0-9]+\.[0-9]+(-[A-Za-z0-9.-]+)?$') {
            $results.Add((New-ValidationResult -Status Failed -Message 'Governance version must be semantic version format.' -Path $Path))
        }
        if ([datetime]$json.completedAtUtc -lt [datetime]$json.startedAtUtc) {
            $results.Add((New-ValidationResult -Status Failed -Message 'Completion timestamp precedes start timestamp.' -Path $Path))
        }
        if ($json.status -eq 'NotRun' -and @($json.commandsNotExecuted).Count -lt 1) {
            $results.Add((New-ValidationResult -Status Failed -Message 'Overall NotRun evidence must list commands not executed.' -Path $Path))
        }
        if ($json.status -eq 'Passed') {
            if (@($json.remainingRisks).Count -gt 0) {
                $results.Add((New-ValidationResult -Status Failed -Message 'Overall Passed must not include remaining risks.' -Path $Path))
            }
            foreach ($test in @($json.tests)) {
                if ($test.status -in @('Failed','NotRun','Blocked')) {
                    $results.Add((New-ValidationResult -Status Failed -Message "Overall Passed conflicts with test '$($test.name)' status '$($test.status)'." -Path $Path))
                }
            }
        }
        $githubExecution = @($json.tests | Where-Object name -eq 'GitHub-hosted workflow execution' | Select-Object -First 1)
        if ($json.executionContext -eq 'Local') {
            if ($githubExecution.Count -eq 0 -or $githubExecution[0].status -ne 'NotRun') {
                $results.Add((New-ValidationResult -Status Failed -Message 'Local completion evidence must record GitHub-hosted workflow execution as NotRun.' -Path $Path))
            }
            if ($json.status -eq 'Passed') {
                $results.Add((New-ValidationResult -Status Failed -Message 'Local completion evidence cannot be Passed while GitHub-hosted execution is mandatory.' -Path $Path))
            }
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
    if ($Test.status -eq 'Passed') {
        if ($Test.exitCode -ne 0) {
            $results.Add((New-ValidationResult -Status Failed -Message "Passed test '$($Test.name)' must have exitCode 0." -Path $Path))
        }
        if ($null -ne $Test.failureReason) {
            $results.Add((New-ValidationResult -Status Failed -Message "Passed test '$($Test.name)' must not have failureReason." -Path $Path))
        }
    }
    if ($Test.status -in @('Failed','NotRun','Blocked')) {
        if ([string]::IsNullOrWhiteSpace([string]$Test.failureReason) -or ([string]$Test.failureReason).Length -lt 10) {
            $results.Add((New-ValidationResult -Status Failed -Message "Test '$($Test.name)' must include a meaningful failure reason for status '$($Test.status)'." -Path $Path))
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
    foreach ($item in @(Test-RelativeRepositoryPath -Value $Artifact.path -Name "artifact path for '$($Artifact.name)'" -Path $Path)) { $results.Add($item) }
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

Export-ModuleMember -Function @(
    'New-ValidationResult',
    'New-ValidationReport',
    'Write-ValidationReport',
    'Resolve-SafePath',
    'Test-RelativeRepositoryPath',
    'Test-UniqueValues',
    'Read-JsonFile',
    'Test-GovernanceJsonDocument',
    'Test-TestEvidenceObject',
    'Test-ArtifactRecordObject',
    'ConvertTo-OrderedJson'
)
