Set-StrictMode -Version Latest

# Import the established implementation into an isolated module scope. Its
# commands are prefixed internally and re-exported through stable public aliases.
$script:CoreModulePath = Join-Path $PSScriptRoot 'GovernanceValidation.Legacy.psm1'
Import-Module $script:CoreModulePath -Force -Prefix Legacy -Scope Local

$script:ForwardedCommands = [ordered]@{
    'Get-GovernanceValidationRegistry' = 'Get-LegacyGovernanceValidationRegistry'
    'Get-GovernanceValidationCategoryRegistry' = 'Get-LegacyGovernanceValidationCategoryRegistry'
    'Get-GovernanceValidationProfile' = 'Get-LegacyGovernanceValidationProfile'
    'Resolve-GovernanceValidationPlan' = 'Resolve-LegacyGovernanceValidationPlan'
    'Get-GovernanceAggregateStatus' = 'Get-LegacyGovernanceAggregateStatus'
    'Get-GovernanceMissingValidationPrerequisite' = 'Get-LegacyGovernanceMissingValidationPrerequisite'
    'New-ValidationResult' = 'New-LegacyValidationResult'
    'New-ValidationReport' = 'New-LegacyValidationReport'
    'Write-ValidationReport' = 'Write-LegacyValidationReport'
    'Resolve-SafePath' = 'Resolve-LegacySafePath'
    'Test-RelativeRepositoryPath' = 'Test-LegacyRelativeRepositoryPath'
    'Test-UniqueValues' = 'Test-LegacyUniqueValues'
    'Test-JsonMember' = 'Test-LegacyJsonMember'
    'Get-JsonMemberValue' = 'Get-LegacyJsonMemberValue'
    'Read-JsonFile' = 'Read-LegacyJsonFile'
    'Test-GovernanceContractSemantics' = 'Test-LegacyGovernanceContractSemantics'
    'Test-TestEvidenceObject' = 'Test-LegacyTestEvidenceObject'
    'Test-ArtifactRecordObject' = 'Test-LegacyArtifactRecordObject'
    'Test-VerifiedRunObject' = 'Test-LegacyVerifiedRunObject'
    'ConvertTo-OrderedJson' = 'ConvertTo-LegacyOrderedJson'
    'ConvertTo-SanitizedWorkflowOutputLine' = 'ConvertTo-LegacySanitizedWorkflowOutputLine'
    'ConvertTo-SanitizedWorkflowFailureMessage' = 'ConvertTo-LegacySanitizedWorkflowFailureMessage'
    'Write-GovernanceBootstrapFailureReport' = 'Write-LegacyGovernanceBootstrapFailureReport'
}
foreach ($publicName in $script:ForwardedCommands.Keys) {
    Set-Alias -Name $publicName -Value $script:ForwardedCommands[$publicName] -Scope Script -Force
}

function Test-GovernanceJsonDocument {
    <#
    .SYNOPSIS
    Validates known governance JSON documents.
    .DESCRIPTION
    Delegates established validation to the preserved core module and adds
    version-aware standards-consistency checks for the 1.0.0 legacy release
    readiness shape and the 1.1.0 split published/next-release state model.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][string]$Path,
        [Parameter(Mandatory)][ValidateSet('completion-result','test-evidence','artifact-record','project-manifest','governance-config','verified-run','standards-consistency')][string]$Kind
    )

    if ($Kind -cne 'standards-consistency') {
        return @(Test-LegacyGovernanceJsonDocument -Path $Path -Kind $Kind)
    }

    try {
        $json = Read-LegacyJsonFile -Path $Path
    }
    catch {
        return @(Test-LegacyGovernanceJsonDocument -Path $Path -Kind $Kind)
    }

    $schemaVersion = [string]$json.schemaVersion
    $legacyResults = @()
    $temporaryPath = $null
    try {
        if ($schemaVersion -ceq '1.1.0') {
            $legacyCopy = ($json | ConvertTo-Json -Depth 100 | ConvertFrom-Json -Depth 100 -AsHashtable)
            $legacyCopy.schemaVersion = '1.0.0'
            $legacyCopy.Remove('publishedRelease')
            $legacyCopy.Remove('nextReleaseReadiness')
            $legacyCopy.releaseReadiness = [ordered]@{
                status = 'NotApplicable'
                reason = 'Compatibility projection used only for established catalog and status validation.'
            }
            $temporaryPath = Join-Path ([IO.Path]::GetTempPath()) ("standards-consistency-$([guid]::NewGuid().ToString('N')).json")
            $legacyCopy | ConvertTo-Json -Depth 100 | Set-Content -LiteralPath $temporaryPath -Encoding utf8
            $legacyResults = @(Test-LegacyGovernanceJsonDocument -Path $temporaryPath -Kind $Kind)
            foreach ($result in $legacyResults) {
                if ($result.PSObject.Properties.Name -contains 'path') { $result.path = $Path }
            }
        }
        else {
            $legacyResults = @(Test-LegacyGovernanceJsonDocument -Path $Path -Kind $Kind)
        }
    }
    finally {
        if ($temporaryPath -and (Test-Path -LiteralPath $temporaryPath -PathType Leaf)) {
            Remove-Item -LiteralPath $temporaryPath -Force
        }
    }

    $findings = [System.Collections.Generic.List[object]]::new()
    function Add-StandardsConsistencyFinding {
        param([Parameter(Mandatory)][string]$Message)
        $findings.Add((New-LegacyValidationResult -Status Failed -Message $Message -Path $Path))
    }

    $statuses = @('Passed','Failed','NotRun','NotApplicable','Blocked')

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
            foreach ($member in @('status','proposedVersion','proposedTag','targetCommitSha','releaseCreated','reason')) {
                if (-not (Test-LegacyJsonMember -InputObject $json.releaseReadiness -Name $member)) {
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
                if (-not (Test-LegacyJsonMember -InputObject $published -Name $member)) { Add-StandardsConsistencyFinding "publishedRelease is missing required member '$member'." }
            }
            if ((Test-LegacyJsonMember -InputObject $published -Name 'status') -and $statuses -cnotcontains [string]$published.status) { Add-StandardsConsistencyFinding "publishedRelease uses invalid status '$($published.status)'." }
            if ((Test-LegacyJsonMember -InputObject $published -Name 'version') -and [string]$published.version -cnotmatch '^\d+\.\d+\.\d+$') { Add-StandardsConsistencyFinding 'publishedRelease.version must use semantic version syntax.' }
            if ((Test-LegacyJsonMember -InputObject $published -Name 'version') -and (Test-LegacyJsonMember -InputObject $published -Name 'tag') -and [string]$published.tag -cne "v$($published.version)") { Add-StandardsConsistencyFinding 'publishedRelease.tag must match publishedRelease.version.' }
            if ((Test-LegacyJsonMember -InputObject $published -Name 'targetCommitSha') -and [string]$published.targetCommitSha -cnotmatch '^[0-9a-f]{40}$') { Add-StandardsConsistencyFinding 'publishedRelease.targetCommitSha must be a full lowercase commit SHA.' }
            if ((Test-LegacyJsonMember -InputObject $published -Name 'releaseCreated') -and $published.releaseCreated -isnot [bool]) { Add-StandardsConsistencyFinding 'publishedRelease.releaseCreated must be boolean.' }
        }
        if ($json.ContainsKey('nextReleaseReadiness')) {
            $next = $json.nextReleaseReadiness
            foreach ($member in @('status','proposedVersion','proposedTag','targetCommitSha','reason')) {
                if (-not (Test-LegacyJsonMember -InputObject $next -Name $member)) { Add-StandardsConsistencyFinding "nextReleaseReadiness is missing required member '$member'." }
            }
            if ((Test-LegacyJsonMember -InputObject $next -Name 'status') -and $statuses -cnotcontains [string]$next.status) { Add-StandardsConsistencyFinding "nextReleaseReadiness uses invalid status '$($next.status)'." }
            elseif ([string]$next.status -in @('NotRun','NotApplicable')) {
                foreach ($member in @('proposedVersion','proposedTag','targetCommitSha')) {
                    if ($null -ne (Get-LegacyJsonMemberValue -InputObject $next -Name $member)) { Add-StandardsConsistencyFinding "nextReleaseReadiness.$member must be null while status is '$($next.status)'." }
                }
            }
            elseif ([string]$next.status -in @('Passed','Failed','Blocked')) {
                if ([string]$next.proposedVersion -cnotmatch '^\d+\.\d+\.\d+$') { Add-StandardsConsistencyFinding 'nextReleaseReadiness.proposedVersion must use semantic version syntax for an active candidate state.' }
                if ([string]$next.proposedTag -cne "v$($next.proposedVersion)") { Add-StandardsConsistencyFinding 'nextReleaseReadiness.proposedTag must match proposedVersion for an active candidate state.' }
                if ([string]$next.targetCommitSha -cnotmatch '^[0-9a-f]{40}$') { Add-StandardsConsistencyFinding 'nextReleaseReadiness.targetCommitSha must be a full lowercase commit SHA for an active candidate state.' }
            }
        }
        if ($json.ContainsKey('releaseReadiness')) {
            $alias = $json.releaseReadiness
            if ([string]$alias.status -cne 'NotApplicable') { Add-StandardsConsistencyFinding "Deprecated releaseReadiness alias must use status 'NotApplicable'." }
            foreach ($member in @($alias.Keys)) {
                if (@('status','reason') -cnotcontains [string]$member) { Add-StandardsConsistencyFinding "Deprecated releaseReadiness alias must not contain '$member'." }
            }
        }
    }

    if ($findings.Count -eq 0) { return @($legacyResults) }
    @($legacyResults | Where-Object status -cne 'Passed') + @($findings)
}

Export-ModuleMember -Function (@('Test-GovernanceJsonDocument') + @($script:ForwardedCommands.Values)) -Alias @($script:ForwardedCommands.Keys)
