Set-StrictMode -Version Latest

# Preserve the established implementation and override only the version-aware
# standards-consistency semantics introduced by contract schema 1.1.0.
. (Join-Path $PSScriptRoot 'GovernanceValidation.Legacy.psm1')

$script:LegacyTestGovernanceJsonDocument = ${function:Test-GovernanceJsonDocument}
$script:GovernanceSchemaVersionsByKind['standards-consistency'] = @('1.0.0', '1.1.0')

function Test-GovernanceJsonDocument {
    <#
    .SYNOPSIS
    Validates known governance JSON documents.
    .DESCRIPTION
    Delegates established validation to the preserved implementation, then adds
    version-aware standards-consistency checks for the 1.0.0 legacy release
    readiness shape and the 1.1.0 split published/next-release state model.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][string]$Path,
        [Parameter(Mandatory)][ValidateSet('completion-result','test-evidence','artifact-record','project-manifest','governance-config','verified-run','standards-consistency')][string]$Kind
    )

    $legacyResults = @(& $script:LegacyTestGovernanceJsonDocument -Path $Path -Kind $Kind)
    if ($Kind -cne 'standards-consistency') {
        return @($legacyResults)
    }

    try {
        $json = Read-JsonFile -Path $Path
    }
    catch {
        return @($legacyResults)
    }

    $findings = [System.Collections.Generic.List[object]]::new()
    function Add-StandardsConsistencyFinding {
        param([Parameter(Mandatory)][string]$Message)
        $findings.Add((New-ValidationResult -Status Failed -Message $Message -Path $Path))
    }

    $statuses = @('Passed','Failed','NotRun','NotApplicable','Blocked')
    $schemaVersion = [string]$json.schemaVersion

    if ($schemaVersion -ceq '1.0.0') {
        foreach ($forbidden in @('publishedRelease', 'nextReleaseReadiness')) {
            if ($json.ContainsKey($forbidden)) {
                Add-StandardsConsistencyFinding "Standards-consistency schema 1.0.0 must not contain '$forbidden'; use schema 1.1.0 for split release state."
            }
        }

        if (-not $json.ContainsKey('releaseReadiness')) {
            Add-StandardsConsistencyFinding "Standards-consistency schema 1.0.0 requires legacy 'releaseReadiness'."
        }
        else {
            $legacyReadiness = $json.releaseReadiness
            foreach ($member in @('status','proposedVersion','proposedTag','targetCommitSha','releaseCreated','reason')) {
                if (-not (Test-JsonMember -InputObject $legacyReadiness -Name $member)) {
                    Add-StandardsConsistencyFinding "Legacy releaseReadiness is missing required member '$member'."
                }
            }
        }
    }
    elseif ($schemaVersion -ceq '1.1.0') {
        foreach ($member in @('publishedRelease','nextReleaseReadiness','releaseReadiness')) {
            if (-not $json.ContainsKey($member)) {
                Add-StandardsConsistencyFinding "Standards-consistency schema 1.1.0 is missing required member '$member'."
            }
        }

        if ($json.ContainsKey('publishedRelease')) {
            $published = $json.publishedRelease
            foreach ($member in @('status','version','tag','targetCommitSha','releaseCreated','reason')) {
                if (-not (Test-JsonMember -InputObject $published -Name $member)) {
                    Add-StandardsConsistencyFinding "publishedRelease is missing required member '$member'."
                }
            }
            if ((Test-JsonMember -InputObject $published -Name 'status') -and $statuses -cnotcontains [string]$published.status) {
                Add-StandardsConsistencyFinding "publishedRelease uses invalid status '$($published.status)'."
            }
            if ((Test-JsonMember -InputObject $published -Name 'version') -and [string]$published.version -cnotmatch '^\d+\.\d+\.\d+$') {
                Add-StandardsConsistencyFinding 'publishedRelease.version must use semantic version syntax.'
            }
            if ((Test-JsonMember -InputObject $published -Name 'version') -and (Test-JsonMember -InputObject $published -Name 'tag') -and [string]$published.tag -cne "v$($published.version)") {
                Add-StandardsConsistencyFinding 'publishedRelease.tag must match publishedRelease.version.'
            }
            if ((Test-JsonMember -InputObject $published -Name 'targetCommitSha') -and [string]$published.targetCommitSha -cnotmatch '^[0-9a-f]{40}$') {
                Add-StandardsConsistencyFinding 'publishedRelease.targetCommitSha must be a full lowercase commit SHA.'
            }
            if ((Test-JsonMember -InputObject $published -Name 'releaseCreated') -and $published.releaseCreated -isnot [bool]) {
                Add-StandardsConsistencyFinding 'publishedRelease.releaseCreated must be boolean.'
            }
        }

        if ($json.ContainsKey('nextReleaseReadiness')) {
            $next = $json.nextReleaseReadiness
            foreach ($member in @('status','proposedVersion','proposedTag','targetCommitSha','reason')) {
                if (-not (Test-JsonMember -InputObject $next -Name $member)) {
                    Add-StandardsConsistencyFinding "nextReleaseReadiness is missing required member '$member'."
                }
            }
            if ((Test-JsonMember -InputObject $next -Name 'status') -and $statuses -cnotcontains [string]$next.status) {
                Add-StandardsConsistencyFinding "nextReleaseReadiness uses invalid status '$($next.status)'."
            }
            elseif ([string]$next.status -in @('NotRun','NotApplicable')) {
                foreach ($member in @('proposedVersion','proposedTag','targetCommitSha')) {
                    if ($null -ne (Get-JsonMemberValue -InputObject $next -Name $member)) {
                        Add-StandardsConsistencyFinding "nextReleaseReadiness.$member must be null while status is '$($next.status)'."
                    }
                }
            }
            elseif ([string]$next.status -in @('Passed','Failed','Blocked')) {
                if ([string]$next.proposedVersion -cnotmatch '^\d+\.\d+\.\d+$') {
                    Add-StandardsConsistencyFinding 'nextReleaseReadiness.proposedVersion must use semantic version syntax for an active candidate state.'
                }
                if ([string]$next.proposedTag -cne "v$($next.proposedVersion)") {
                    Add-StandardsConsistencyFinding 'nextReleaseReadiness.proposedTag must match proposedVersion for an active candidate state.'
                }
                if ([string]$next.targetCommitSha -cnotmatch '^[0-9a-f]{40}$') {
                    Add-StandardsConsistencyFinding 'nextReleaseReadiness.targetCommitSha must be a full lowercase commit SHA for an active candidate state.'
                }
            }
        }

        if ($json.ContainsKey('releaseReadiness')) {
            $alias = $json.releaseReadiness
            if ([string]$alias.status -cne 'NotApplicable') {
                Add-StandardsConsistencyFinding "Deprecated releaseReadiness alias must use status 'NotApplicable'."
            }
            $allowedAliasMembers = @('status','reason')
            foreach ($member in @($alias.Keys)) {
                if ($allowedAliasMembers -cnotcontains [string]$member) {
                    Add-StandardsConsistencyFinding "Deprecated releaseReadiness alias must not contain '$member'."
                }
            }
        }
    }

    if ($findings.Count -eq 0) {
        return @($legacyResults)
    }

    @($legacyResults | Where-Object status -cne 'Passed') + @($findings)
}

Export-ModuleMember -Function @(
    'Get-GovernanceValidationRegistry',
    'Get-GovernanceValidationCategoryRegistry',
    'Get-GovernanceValidationProfile',
    'Resolve-GovernanceValidationPlan',
    'Get-GovernanceAggregateStatus',
    'Get-GovernanceMissingValidationPrerequisite',
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
