Set-StrictMode -Version Latest

function New-ValidationResult {
    <#
    .SYNOPSIS
    Creates a standardized validation result.
    .DESCRIPTION
    Returns an ordered object used by scripts and actions for console and JSON reports.
    .PARAMETER Status
    Result status such as Passed, Failed, Warning, or NotRun.
    .PARAMETER Message
    Human-readable result message.
    .PARAMETER Path
    Related repository path.
    .PARAMETER Severity
    Severity label for reporting.
    .PARAMETER Data
    Optional structured data.
    .EXAMPLE
    New-ValidationResult -Status Failed -Message 'Missing README.md' -Path README.md
    .OUTPUTS
    System.Collections.Specialized.OrderedDictionary
    .NOTES
    Used by local validators and composite actions.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][ValidateSet('Passed','Failed','Warning','NotRun','Blocked')][string]$Status,
        [Parameter(Mandatory)][string]$Message,
        [string]$Path = '',
        [ValidateSet('info','warning','error')][string]$Severity = 'error',
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

function Resolve-SafePath {
    <#
    .SYNOPSIS
    Resolves a path beneath a workspace root.
    .DESCRIPTION
    Rejects absolute or relative paths that escape the root directory.
    .PARAMETER Root
    Workspace root.
    .PARAMETER ChildPath
    Candidate child path.
    .EXAMPLE
    Resolve-SafePath -Root . -ChildPath README.md
    .OUTPUTS
    System.String
    .NOTES
    This function does not create files.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][string]$Root,
        [Parameter(Mandatory)][string]$ChildPath
    )
    $rootFull = [System.IO.Path]::GetFullPath((Resolve-Path -LiteralPath $Root).Path)
    $candidate = if ([System.IO.Path]::IsPathRooted($ChildPath)) { $ChildPath } else { Join-Path $rootFull $ChildPath }
    $candidateFull = [System.IO.Path]::GetFullPath($candidate)
    $prefix = $rootFull.TrimEnd([System.IO.Path]::DirectorySeparatorChar) + [System.IO.Path]::DirectorySeparatorChar
    if (-not ($candidateFull.Equals($rootFull, [StringComparison]::OrdinalIgnoreCase) -or $candidateFull.StartsWith($prefix, [StringComparison]::OrdinalIgnoreCase))) {
        throw "Path '$ChildPath' resolves outside '$Root'."
    }
    $candidateFull
}

function Read-JsonFile {
    <#
    .SYNOPSIS
    Parses a JSON file.
    .DESCRIPTION
    Reads a JSON file with controlled error behavior and returns parsed data.
    .PARAMETER Path
    JSON file path.
    .EXAMPLE
    Read-JsonFile -Path project-manifest.json
    .OUTPUTS
    PSCustomObject
    .NOTES
    Uses -AsHashtable when available to support empty JSON property names in third-party lockfiles.
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
    Performs offline structural validation for manifests, configs, test evidence, artifact records, and completion evidence.
    .PARAMETER Path
    JSON path.
    .PARAMETER Kind
    Document kind.
    .EXAMPLE
    Test-GovernanceJsonDocument -Path project-manifest.json -Kind project-manifest
    .OUTPUTS
    Object[]
    .NOTES
    This offline validator supplements schema parsing; it does not execute repository content.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][string]$Path,
        [Parameter(Mandatory)][ValidateSet('completion-result','test-evidence','artifact-record','project-manifest','governance-config')][string]$Kind
    )
    $results = [System.Collections.Generic.List[object]]::new()
    try { $json = Read-JsonFile -Path $Path } catch { return @(New-ValidationResult -Status Failed -Message "Invalid JSON: $($_.Exception.Message)" -Path $Path) }
    $statuses = @('Passed','Failed','NotRun','NotApplicable','Blocked')
    $risks = @('Low','Moderate','High','Critical')
    $required = switch ($Kind) {
        'completion-result' { @('schemaVersion','repository','commitSha','branch','governanceVersion','riskClassification','status','startedAtUtc','completedAtUtc','summary','changedFiles','commandsExecuted','commandsNotExecuted','tests','artifacts','warnings','knownLimitations','remainingRisks','exceptions','approvals') }
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
    if ($json.ContainsKey('status') -and $statuses -notcontains $json.status) {
        $results.Add((New-ValidationResult -Status Failed -Message "Unknown status '$($json.status)'." -Path $Path))
    }
    if ($json.ContainsKey('riskClassification') -and $risks -notcontains $json.riskClassification) {
        $results.Add((New-ValidationResult -Status Failed -Message "Unknown risk classification '$($json.riskClassification)'." -Path $Path))
    }
    if ($Kind -eq 'artifact-record' -and $json.ContainsKey('sha256') -and $json.sha256 -notmatch '^[A-Fa-f0-9]{64}$') {
        $results.Add((New-ValidationResult -Status Failed -Message 'Artifact SHA-256 is invalid.' -Path $Path))
    }
    if ($Kind -eq 'completion-result' -and $json.status -eq 'Passed') {
        foreach ($test in @($json.tests)) {
            if ($test.status -in @('Failed','NotRun','Blocked')) {
                $results.Add((New-ValidationResult -Status Failed -Message "Overall Passed conflicts with test '$($test.name)' status '$($test.status)'." -Path $Path))
            }
        }
    }
    if ($Kind -eq 'governance-config') {
        foreach ($disabled in @($json.controls.mandatoryControlsDisabled)) {
            if (-not $disabled.exceptionReference -or $disabled.exceptionReference -notmatch '^GOV-[A-Z0-9-]+$') {
                $results.Add((New-ValidationResult -Status Failed -Message "Mandatory control '$($disabled.control)' lacks a valid exception reference." -Path $Path))
            }
        }
        foreach ($allow in @($json.reviewedAllowlist)) {
            if (-not $allow.reason -or $allow.reason.Length -lt 10) {
                $results.Add((New-ValidationResult -Status Failed -Message "Allowlist entry '$($allow.patternId)' lacks a meaningful reason." -Path $Path))
            }
        }
    }
    if ($results.Count -eq 0) {
        $results.Add((New-ValidationResult -Status Passed -Message "$Kind validation passed." -Path $Path -Severity info))
    }
    @($results)
}

function ConvertTo-OrderedJson {
    <#
    .SYNOPSIS
    Serializes objects to JSON.
    .DESCRIPTION
    Uses sufficient depth for evidence and validation reports.
    .PARAMETER InputObject
    Object to serialize.
    .EXAMPLE
    $report | ConvertTo-OrderedJson
    .OUTPUTS
    System.String
    .NOTES
    Use ordered hashtables for stable property ordering.
    #>
    [CmdletBinding()]
    param([Parameter(ValueFromPipeline)]$InputObject)
    process { $InputObject | ConvertTo-Json -Depth 100 }
}
