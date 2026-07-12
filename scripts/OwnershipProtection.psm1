Set-StrictMode -Version Latest

function New-OwnershipResult {
    param(
        [Parameter(Mandatory)][ValidateSet('Passed', 'Failed', 'Blocked')][string]$Status,
        [Parameter(Mandatory)][string]$Message,
        [string]$Identity,
        [string]$Path
    )

    [pscustomobject]@{ Status = $Status; Message = $Message; Identity = $Identity; Path = $Path }
}

function Test-CodeownersContent {
    <#
    .SYNOPSIS
    Performs deterministic structural validation of CODEOWNERS content.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][AllowEmptyString()][string]$Content,
        [ValidateSet('User', 'Organization', 'Unknown')][string]$RepositoryOwnerType = 'Unknown',
        [string[]]$RequiredPaths = @(
            '/AGENTS.md', '/.agents/skills/', '/agents/', '/governance/', '/schemas/', '/actions/',
            '/scripts/', '/tests/', '/.github/workflows/', '/workflows/', '/SECURITY.md', '/CODEOWNERS',
            '/project-manifest.json', '/governance.config.json', '/VERSION', '/CHANGELOG.md',
            '/docs/releases/', '/docs/RELEASE_STATUS.md', '/docs/RELEASE_PROCESS.md'
        )
    )

    $results = [System.Collections.Generic.List[object]]::new()
    $rules = [System.Collections.Generic.List[object]]::new()
    $lines = @($Content -split "`r?`n")
    foreach ($line in $lines) {
        $commentIndex = $line.IndexOf('#')
        $ruleText = if ($commentIndex -ge 0) { $line.Substring(0, $commentIndex) } else { $line }
        $trimmed = $ruleText.Trim()
        if (-not $trimmed -or $trimmed.StartsWith('#')) { continue }
        $parts = @($trimmed -split '\s+' | Where-Object { $_ })
        if ($parts.Count -lt 2) {
            $results.Add((New-OwnershipResult -Status Failed -Message 'CODEOWNERS rule must include a path pattern and at least one owner.' -Path $parts[0]))
            continue
        }
        $owners = @($parts[1..($parts.Count - 1)])
        $rules.Add([pscustomobject]@{ Pattern = $parts[0]; Owners = $owners })
        foreach ($owner in $owners) {
            $isGitHubOwner = $owner -match '^@[A-Za-z0-9](?:[A-Za-z0-9-]{0,37}[A-Za-z0-9])?(?:/[A-Za-z0-9](?:[A-Za-z0-9_.-]*[A-Za-z0-9])?)?$'
            $isEmailOwner = $owner -match '^[A-Za-z0-9_+-]+(?:\.[A-Za-z0-9_+-]+)*@(?:[A-Za-z0-9](?:[A-Za-z0-9-]*[A-Za-z0-9])?\.)+[A-Za-z]{2,}$'
            if (-not $isGitHubOwner -and -not $isEmailOwner) {
                $results.Add((New-OwnershipResult -Status Failed -Message "Malformed CODEOWNERS owner token '$owner'." -Identity $owner -Path $parts[0]))
                continue
            }
            $isPlaceholder = if ($isEmailOwner) {
                ($owner -split '@', 2)[0] -match '(?i)^(?:placeholder|changeme|replace-me|todo)$'
            }
            else {
                $owner -match '(?i)(?:^@|/)(?:placeholder|changeme|replace-me|todo)(?:/|$)'
            }
            if ($isPlaceholder) {
                $results.Add((New-OwnershipResult -Status Failed -Message "Placeholder CODEOWNERS identity '$owner' is not allowed." -Identity $owner -Path $parts[0]))
            }
            if ($isGitHubOwner -and $RepositoryOwnerType -eq 'User' -and $owner.Contains('/')) {
                $results.Add((New-OwnershipResult -Status Failed -Message "Organization-team CODEOWNER '$owner' is incompatible with a user-owned repository." -Identity $owner -Path $parts[0]))
            }
        }
    }

    if ($rules.Count -eq 0) {
        $results.Add((New-OwnershipResult -Status Failed -Message 'CODEOWNERS must contain at least one active rule.'))
    }
    elseif (-not @($rules | Where-Object Pattern -eq '*')) {
        $results.Add((New-OwnershipResult -Status Failed -Message "CODEOWNERS must include default '*' coverage." -Path '*'))
    }

    foreach ($requiredPath in $RequiredPaths) {
        if (-not @($rules | Where-Object Pattern -eq $requiredPath)) {
            $results.Add((New-OwnershipResult -Status Failed -Message "CODEOWNERS lacks explicit high-risk path coverage for '$requiredPath'." -Path $requiredPath))
        }
    }

    if ($results.Count -eq 0) {
        $results.Add((New-OwnershipResult -Status Passed -Message 'CODEOWNERS structure and required path coverage are valid.'))
    }
    @($results)
}

function Resolve-CodeownersIdentity {
    <#
    .SYNOPSIS
    Classifies an explicit live identity lookup without performing network access itself.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][string]$Identity,
        [Parameter(Mandatory)][ValidateSet('User', 'Organization')][string]$RepositoryOwnerType,
        [Parameter(Mandatory)][scriptblock]$Lookup
    )

    if ($RepositoryOwnerType -eq 'User' -and $Identity.Contains('/')) {
        return New-OwnershipResult -Status Failed -Message "Team identity '$Identity' cannot own a user-owned repository." -Identity $Identity
    }
    try {
        $response = & $Lookup $Identity
        if ($null -eq $response) {
            return New-OwnershipResult -Status Failed -Message "Identity '$Identity' did not resolve." -Identity $Identity
        }
        if ($response.StatusCode -in @(401, 403)) {
            return New-OwnershipResult -Status Blocked -Message "Identity lookup for '$Identity' was blocked by authentication or authorization." -Identity $Identity
        }
        if ($response.StatusCode -eq 404) {
            return New-OwnershipResult -Status Failed -Message "Identity '$Identity' is unresolved." -Identity $Identity
        }
        if ($response.StatusCode -ne 200 -or -not $response.HasRepositoryAccess -or -not $response.CanReview) {
            return New-OwnershipResult -Status Failed -Message "Identity '$Identity' is not an eligible repository reviewer." -Identity $Identity
        }
        return New-OwnershipResult -Status Passed -Message "Identity '$Identity' resolves and is eligible to review." -Identity $Identity
    }
    catch {
        return New-OwnershipResult -Status Blocked -Message "Identity lookup for '$Identity' could not be completed: $($_.Exception.Message)" -Identity $Identity
    }
}

function New-RepositoryProtectionPlan {
    <#
    .SYNOPSIS
    Produces a non-mutating branch-protection plan with lockout safeguards.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][ValidateRange(0, 100)][int]$EligibleReviewerCount,
        [Parameter(Mandatory)][ValidateRange(0, 100)][int]$IndependentReviewerCount,
        [ValidateSet('Low', 'Moderate', 'High', 'Critical')][string]$RiskClassification = 'High',
        [ValidateRange(0, 100)][int]$RequestedApprovalCount = 0,
        [ValidateRange(0, 100)][int]$IndependentCodeOwnerCount = $IndependentReviewerCount,
        [ValidateRange(0, 100)][int]$ReviewersOtherThanLastPusherCount = $IndependentReviewerCount,
        [switch]$RequestCodeOwnerReviews,
        [switch]$RequestLastPushApproval,
        [switch]$Execute
    )

    $policyApprovalCount = if ($RiskClassification -in @('High', 'Critical')) { 2 } else { 1 }
    $desiredApprovalCount = if ($RequestedApprovalCount -gt 0) { $RequestedApprovalCount } else { $policyApprovalCount }
    $recommendedApprovalCount = [Math]::Min($desiredApprovalCount, $IndependentReviewerCount)
    $codeowners = $RequestCodeOwnerReviews -and $IndependentCodeOwnerCount -ge 1
    $lastPush = $RequestLastPushApproval -and $EligibleReviewerCount -ge 2 -and $ReviewersOtherThanLastPusherCount -ge 1
    $warnings = [System.Collections.Generic.List[string]]::new()
    if ($desiredApprovalCount -gt $IndependentReviewerCount) { $warnings.Add("Requested approval count $desiredApprovalCount exceeds independent reviewer capacity $IndependentReviewerCount; strongest non-locking count is $recommendedApprovalCount.") }
    if ($RequestCodeOwnerReviews -and -not $codeowners) { $warnings.Add('CODEOWNERS review refused because no independent eligible reviewer is available.') }
    if ($RequestLastPushApproval -and -not $lastPush) { $warnings.Add('Last-push approval refused because the reviewer population would create lockout.') }

    [pscustomobject]@{
        Mode = if ($Execute) { 'ExecuteRequested' } else { 'DryRun' }
        MutationPerformed = $false
        RiskClassification = $RiskClassification
        PolicyApprovalCount = $policyApprovalCount
        RequestedApprovalCount = $desiredApprovalCount
        RequestedApprovalCountEnforceable = $desiredApprovalCount -le $IndependentReviewerCount
        RequiredApprovingReviewCount = $recommendedApprovalCount
        RequireCodeOwnerReviews = $codeowners
        RequireLastPushApproval = $lastPush
        Warnings = @($warnings)
    }
}

Export-ModuleMember -Function Test-CodeownersContent, Resolve-CodeownersIdentity, New-RepositoryProtectionPlan
