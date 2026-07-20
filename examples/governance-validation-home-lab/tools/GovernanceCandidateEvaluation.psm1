Set-StrictMode -Version Latest

function Test-SyntheticGovernanceCandidate {
    <#
    .SYNOPSIS
    Evaluates synthetic candidate metadata without executing candidate controls.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$Path
    )

    $document = Get-Content -LiteralPath $Path -Raw | ConvertFrom-Json
    $allowedFields = @('id', 'manifestPresent', 'documentationPresent')
    $results = foreach ($candidate in @($document.candidates)) {
        $rejectedFields = @(
            $candidate.PSObject.Properties.Name |
                Where-Object { $_ -cnotin $allowedFields } |
                Sort-Object
        )
        $checks = [ordered]@{
            Contract = if ($candidate.manifestPresent -eq $true) { 'Passed' } else { 'Failed' }
            DocumentationCompleteness = if ($candidate.documentationPresent -eq $true) { 'Passed' } else { 'Failed' }
            CandidateControlIsolation = if ($rejectedFields.Count -eq 0) { 'Passed' } else { 'Failed' }
        }
        [pscustomobject]@{
            candidateId = [string]$candidate.id
            status = if (@($checks.Values | Where-Object { $_ -eq 'Failed' }).Count -gt 0) { 'Failed' } else { 'Passed' }
            checks = [pscustomobject]$checks
            rejectedCandidateFields = $rejectedFields
        }
    }

    [pscustomobject]@{
        illustrativeOnly = $true
        executionContext = 'Local'
        hostedExecution = 'NotRun'
        artifactsVerified = $false
        trustedValidatorSource = 'AIAllTheThingz/Engineering-Standards@89c06c93d82d7777b6efed4326c2b33d7c31cd88'
        candidateCommandsExecuted = 0
        results = @($results)
    }
}

Export-ModuleMember -Function Test-SyntheticGovernanceCandidate
