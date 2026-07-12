Set-StrictMode -Version Latest

function New-OwnershipResult {
    param(
        [Parameter(Mandatory)][ValidateSet('Passed', 'Failed', 'Blocked')][string]$Status,
        [Parameter(Mandatory)][string]$Message,
        [string]$Identity,
        [string]$Path,
        [string]$RequiredPath,
        [string]$EffectivePattern,
        [string[]]$EffectiveOwners = @(),
        [int]$RuleIndex = 0,
        [int]$LineNumber = 0,
        [string]$RepositoryOwnerType,
        [string]$Reason = $Message
    )

    [pscustomobject]@{
        Status = $Status
        Message = $Message
        Reason = $Reason
        Identity = $Identity
        Path = $Path
        RequiredPath = $RequiredPath
        EffectivePattern = $EffectivePattern
        EffectiveOwners = @($EffectiveOwners)
        RuleIndex = $RuleIndex
        LineNumber = $LineNumber
        RepositoryOwnerType = $RepositoryOwnerType
        OwnerType = $RepositoryOwnerType
    }
}

function Test-SupportedCodeownersPattern {
    param([Parameter(Mandatory)][string]$Pattern)

    if ($Pattern -eq '*') { return $true }
    if ($Pattern -match '[!?\[\]\\]' -or $Pattern -match '//|(?:^|/)\.\.?(/|$)') { return $false }
    if ($Pattern -notmatch '^/?[A-Za-z0-9._*/-]+/?$') { return $false }
    $withoutSupportedDoubleStarSegments = $Pattern -replace '(?:(?<=^)|(?<=/))\*\*(?=/|$)', ''
    -not $withoutSupportedDoubleStarSegments.Contains('**')
}

function Test-CodeownersPatternMatch {
    param(
        [Parameter(Mandatory)][string]$Pattern,
        [Parameter(Mandatory)][string]$RequiredPath
    )

    if (-not (Test-SupportedCodeownersPattern -Pattern $Pattern)) { return $false }
    if ($Pattern -eq '*') { return $true }

    $candidate = '/' + $RequiredPath.TrimStart('/')
    $directoryPattern = $Pattern.EndsWith('/')
    $literalPattern = -not $Pattern.Contains('*')
    $patternWithoutTrailingDirectorySlash = $Pattern.TrimEnd('/')
    $rooted = $Pattern.StartsWith('/') -or $patternWithoutTrailingDirectorySlash.Contains('/')
    $body = $Pattern.Trim('/')
    $expression = [regex]::Escape($body)
    if ($expression -eq '\*\*') {
        $expression = '.*'
    }
    else {
        # A complete ** path segment consumes zero or more directories. Treating it
        # as plain .* would incorrectly require a directory in /foo/**/bar.
        $expression = $expression.Replace('\*\*/', '(?:[^/]+/)*')
        $expression = $expression.Replace('/\*\*/', '/(?:[^/]+/)*')
        if ($expression.EndsWith('/\*\*')) {
            $expression = $expression.Substring(0, $expression.Length - 5) + '(?:/.*)?'
        }
        $expression = $expression.Replace('\*', '[^/]*')
    }

    $prefix = if ($rooted) { '^/' } else { '(?:^|/)' }
    $suffix = if ($directoryPattern) {
        '(?:/.*)?/?$'
    }
    elseif ($literalPattern) {
        '(?:/.*)?$'
    }
    else {
        '$'
    }
    [regex]::IsMatch(
        $candidate,
        ($prefix + $expression + $suffix),
        [System.Text.RegularExpressions.RegexOptions]::CultureInvariant
    )
}

function Test-UnsupportedPatternCouldAffectPath {
    param(
        [Parameter(Mandatory)][string]$Pattern,
        [Parameter(Mandatory)][string]$RequiredPath
    )

    $candidate = '/' + $RequiredPath.TrimStart('/')
    $prefixInfo = Get-UnsupportedCodeownersPrefixInfo -Pattern $Pattern
    $prefix = $prefixInfo.Prefix
    if (-not $prefix) { return $true }
    if (-not $prefix.StartsWith('/')) { $prefix = '/' + $prefix }
    if ($prefixInfo.TruncatedAtSegmentStart) {
        $candidateBoundary = $candidate.TrimEnd('/')
        $prefixBoundary = $prefix.TrimEnd('/')
        return $candidateBoundary -eq $prefixBoundary -or
            $candidateBoundary.StartsWith($prefixBoundary + '/', [System.StringComparison]::Ordinal) -or
            $prefixBoundary.StartsWith($candidateBoundary + '/', [System.StringComparison]::Ordinal)
    }
    $candidate.StartsWith($prefix, [System.StringComparison]::Ordinal) -or
        $prefix.StartsWith($candidate.TrimEnd('/'), [System.StringComparison]::Ordinal)
}

function Get-UnsupportedCodeownersLiteralPrefix {
    param([Parameter(Mandatory)][string]$Pattern)

    (Get-UnsupportedCodeownersPrefixInfo -Pattern $Pattern).Prefix
}

function Get-UnsupportedCodeownersPrefixInfo {
    param([Parameter(Mandatory)][string]$Pattern)

    $unsupportedIndex = $Pattern.Length
    $invalidCharacter = [regex]::Match($Pattern, '[^A-Za-z0-9._*/-]')
    if ($invalidCharacter.Success) { $unsupportedIndex = [Math]::Min($unsupportedIndex, $invalidCharacter.Index) }

    $invalidPathConstruct = [regex]::Match($Pattern, '//|(?:^|/)\.\.?(/|$)')
    if ($invalidPathConstruct.Success) { $unsupportedIndex = [Math]::Min($unsupportedIndex, $invalidPathConstruct.Index) }

    foreach ($starRun in [regex]::Matches($Pattern, '\*{2,}')) {
        $leftIsSegmentBoundary = $starRun.Index -eq 0 -or $Pattern[$starRun.Index - 1] -eq '/'
        $rightIndex = $starRun.Index + $starRun.Length
        $rightIsSegmentBoundary = $rightIndex -eq $Pattern.Length -or $Pattern[$rightIndex] -eq '/'
        $isSupportedGlobstar = $starRun.Length -eq 2 -and $leftIsSegmentBoundary -and $rightIsSegmentBoundary
        if (-not $isSupportedGlobstar) {
            $unsupportedIndex = [Math]::Min($unsupportedIndex, $starRun.Index)
        }
    }

    # This helper is called only after the complete pattern is known to be
    # unsupported. Any earlier wildcard makes the following literal text
    # uncertain, even when that wildcard would be supported in isolation.
    $firstWildcardIndex = $Pattern.IndexOf('*')
    if ($firstWildcardIndex -ge 0) {
        $unsupportedIndex = [Math]::Min($unsupportedIndex, $firstWildcardIndex)
    }

    [pscustomobject]@{
        Prefix = $Pattern.Substring(0, $unsupportedIndex).TrimEnd('*').TrimEnd('/')
        TruncatedAtSegmentStart = $unsupportedIndex -eq 0 -or $Pattern[$unsupportedIndex - 1] -eq '/'
    }
}

function Test-CodeownersOwnerToken {
    param(
        [Parameter(Mandatory)][string]$Owner,
        [Parameter(Mandatory)][ValidateSet('User', 'Organization', 'Unknown')][string]$RepositoryOwnerType
    )

    $isGitHubOwner = $Owner -match '^@[A-Za-z0-9](?:[A-Za-z0-9-]{0,37}[A-Za-z0-9])?(?:/[A-Za-z0-9](?:[A-Za-z0-9_.-]*[A-Za-z0-9])?)?$'
    $isEmailOwner = $Owner -match '^[A-Za-z0-9_+-]+(?:\.[A-Za-z0-9_+-]+)*@(?:[A-Za-z0-9](?:[A-Za-z0-9-]*[A-Za-z0-9])?\.)+[A-Za-z]{2,}$'
    $isPlaceholder = if ($isEmailOwner) {
        ($Owner -split '@', 2)[0] -match '(?i)^(?:placeholder|changeme|replace-me|todo)$'
    }
    elseif ($isGitHubOwner) {
        $Owner -match '(?i)(?:^@|/)(?:placeholder|changeme|replace-me|todo)(?:/|$)'
    }
    else { $false }

    [pscustomobject]@{
        IsValid = $isGitHubOwner -or $isEmailOwner
        IsPlaceholder = $isPlaceholder
        IsIncompatible = $isGitHubOwner -and $RepositoryOwnerType -eq 'User' -and $Owner.Contains('/')
    }
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
        [string[]]$RequiredPaths = @()
    )

    $results = [System.Collections.Generic.List[object]]::new()
    $rules = [System.Collections.Generic.List[object]]::new()
    $lines = @($Content -split "`r?`n")
    for ($lineOffset = 0; $lineOffset -lt $lines.Count; $lineOffset++) {
        $line = $lines[$lineOffset]
        $commentIndex = $line.IndexOf('#')
        $ruleText = if ($commentIndex -ge 0) { $line.Substring(0, $commentIndex) } else { $line }
        $trimmed = $ruleText.Trim()
        if (-not $trimmed -or $trimmed.StartsWith('#')) { continue }
        $parts = @($trimmed -split '\s+' | Where-Object { $_ })
        $owners = if ($parts.Count -ge 2) { @($parts[1..($parts.Count - 1)]) } else { @() }
        $ruleIndex = $rules.Count + 1
        $rules.Add([pscustomobject]@{
                Pattern = $parts[0]
                Owners = $owners
                RuleIndex = $ruleIndex
                LineNumber = $lineOffset + 1
            })
        if ($parts[0].EndsWith('\')) {
            $results.Add((New-OwnershipResult -Status Failed -Message "Unsupported CODEOWNERS escape syntax in pattern '$($parts[0])'." -Path $parts[0]))
        }
        foreach ($owner in $owners) {
            $ownerStatus = Test-CodeownersOwnerToken -Owner $owner -RepositoryOwnerType $RepositoryOwnerType
            if (-not $ownerStatus.IsValid) {
                $results.Add((New-OwnershipResult -Status Failed -Message "Malformed CODEOWNERS owner token '$owner'." -Identity $owner -Path $parts[0]))
                continue
            }
            if ($ownerStatus.IsPlaceholder) {
                $results.Add((New-OwnershipResult -Status Failed -Message "Placeholder CODEOWNERS identity '$owner' is not allowed." -Identity $owner -Path $parts[0]))
            }
            if ($ownerStatus.IsIncompatible) {
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
    else {
        $effectiveUniversalRule = @($rules | Where-Object Pattern -in @('*', '**', '/**', '**/', '/**/', '**/*', '/**/*'))[-1]
        $unsupportedUniversalCandidates = @($rules | Where-Object {
                $_.RuleIndex -gt $effectiveUniversalRule.RuleIndex -and
                -not (Test-SupportedCodeownersPattern -Pattern $_.Pattern) -and
                -not (Get-UnsupportedCodeownersLiteralPrefix -Pattern $_.Pattern)
            })
        $invalidDefaultOwners = @($effectiveUniversalRule.Owners | Where-Object {
                $ownerStatus = Test-CodeownersOwnerToken -Owner $_ -RepositoryOwnerType $RepositoryOwnerType
                -not $ownerStatus.IsValid -or $ownerStatus.IsPlaceholder -or $ownerStatus.IsIncompatible
            })
        $defaultResultArguments = @{
            Path = '*'
            RequiredPath = '*'
            Identity = @($effectiveUniversalRule.Owners) -join ', '
            EffectivePattern = $effectiveUniversalRule.Pattern
            EffectiveOwners = @($effectiveUniversalRule.Owners)
            RuleIndex = $effectiveUniversalRule.RuleIndex
            LineNumber = $effectiveUniversalRule.LineNumber
            RepositoryOwnerType = $RepositoryOwnerType
        }
        if ($unsupportedUniversalCandidates.Count -gt 0) {
            $unsupportedUniversalRule = $unsupportedUniversalCandidates[$unsupportedUniversalCandidates.Count - 1]
            $defaultResultArguments.Identity = @($unsupportedUniversalRule.Owners) -join ', '
            $defaultResultArguments.EffectivePattern = $unsupportedUniversalRule.Pattern
            $defaultResultArguments.EffectiveOwners = @($unsupportedUniversalRule.Owners)
            $defaultResultArguments.RuleIndex = $unsupportedUniversalRule.RuleIndex
            $defaultResultArguments.LineNumber = $unsupportedUniversalRule.LineNumber
            $results.Add((New-OwnershipResult -Status Failed -Message "Unsupported CODEOWNERS pattern '$($unsupportedUniversalRule.Pattern)' could replace generic fallback ownership; effective ownership cannot be determined safely." @defaultResultArguments))
        }
        elseif (@($effectiveUniversalRule.Owners).Count -eq 0 -or $invalidDefaultOwners.Count -gt 0) {
            $results.Add((New-OwnershipResult -Status Failed -Message "Effective universal CODEOWNERS rule '$($effectiveUniversalRule.Pattern)' must contain at least one valid compatible owner." @defaultResultArguments))
        }
        elseif (@($RequiredPaths).Count -eq 0) {
            $results.Add((New-OwnershipResult -Status Passed -Message "Effective universal CODEOWNERS rule '$($effectiveUniversalRule.Pattern)' provides fallback ownership." @defaultResultArguments))
        }
    }

    foreach ($requiredPath in @($RequiredPaths)) {
        $matchingRules = [System.Collections.Generic.List[object]]::new()
        $unsupportedRules = [System.Collections.Generic.List[object]]::new()
        foreach ($rule in $rules) {
            if (-not (Test-SupportedCodeownersPattern -Pattern $rule.Pattern)) {
                if (Test-UnsupportedPatternCouldAffectPath -Pattern $rule.Pattern -RequiredPath $requiredPath) {
                    $unsupportedRules.Add($rule)
                }
                continue
            }
            if (Test-CodeownersPatternMatch -Pattern $rule.Pattern -RequiredPath $requiredPath) {
                $matchingRules.Add($rule)
            }
        }

        $effectiveRule = if ($matchingRules.Count -gt 0) { $matchingRules[$matchingRules.Count - 1] } else { $null }
        $resultArguments = @{
            RequiredPath = $requiredPath
            Path = $requiredPath
            RepositoryOwnerType = $RepositoryOwnerType
        }
        if ($null -ne $effectiveRule) {
            $resultArguments.EffectivePattern = $effectiveRule.Pattern
            $resultArguments.EffectiveOwners = @($effectiveRule.Owners)
            $resultArguments.Identity = @($effectiveRule.Owners) -join ', '
            $resultArguments.RuleIndex = $effectiveRule.RuleIndex
            $resultArguments.LineNumber = $effectiveRule.LineNumber
        }

        $decisionRelevantUnsupportedRules = @($unsupportedRules | Where-Object {
                $null -eq $effectiveRule -or $_.RuleIndex -gt $effectiveRule.RuleIndex
            })
        if ($decisionRelevantUnsupportedRules.Count -gt 0) {
            $unsupportedRule = $decisionRelevantUnsupportedRules[$decisionRelevantUnsupportedRules.Count - 1]
            $resultArguments.EffectivePattern = $unsupportedRule.Pattern
            $resultArguments.EffectiveOwners = @($unsupportedRule.Owners)
            $resultArguments.Identity = @($unsupportedRule.Owners) -join ', '
            $resultArguments.RuleIndex = $unsupportedRule.RuleIndex
            $resultArguments.LineNumber = $unsupportedRule.LineNumber
            $results.Add((New-OwnershipResult -Status Failed -Message "Unsupported CODEOWNERS pattern '$($unsupportedRule.Pattern)' could affect required path '$requiredPath'; effective ownership cannot be determined safely." @resultArguments))
            continue
        }
        if ($null -eq $effectiveRule) {
            $results.Add((New-OwnershipResult -Status Failed -Message "No supported CODEOWNERS rule matches required path '$requiredPath'." @resultArguments))
            continue
        }
        if (@($effectiveRule.Owners).Count -eq 0) {
            $results.Add((New-OwnershipResult -Status Failed -Message "Effective CODEOWNERS rule '$($effectiveRule.Pattern)' for required path '$requiredPath' has no owners." @resultArguments))
            continue
        }

        $invalidEffectiveOwners = @($effectiveRule.Owners | Where-Object {
                $ownerStatus = Test-CodeownersOwnerToken -Owner $_ -RepositoryOwnerType $RepositoryOwnerType
                -not $ownerStatus.IsValid -or $ownerStatus.IsPlaceholder -or $ownerStatus.IsIncompatible
            })
        if ($invalidEffectiveOwners.Count -gt 0) {
            $results.Add((New-OwnershipResult -Status Failed -Message "Effective CODEOWNERS rule '$($effectiveRule.Pattern)' for required path '$requiredPath' contains invalid or incompatible owners: $($invalidEffectiveOwners -join ', ')." @resultArguments))
            continue
        }
        $results.Add((New-OwnershipResult -Status Passed -Message "Required path '$requiredPath' is effectively owned by rule '$($effectiveRule.Pattern)'." @resultArguments))
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
