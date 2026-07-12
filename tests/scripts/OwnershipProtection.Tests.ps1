BeforeAll {
    Import-Module "$PSScriptRoot/../../scripts/OwnershipProtection.psm1" -Force
    $script:requiredPaths = @(
        '/AGENTS.md', '/.agents/skills/', '/agents/', '/governance/', '/schemas/', '/actions/',
        '/scripts/', '/tests/', '/.github/workflows/', '/workflows/', '/SECURITY.md', '/CODEOWNERS',
        '/project-manifest.json', '/governance.config.json', '/VERSION', '/CHANGELOG.md',
        '/docs/releases/', '/docs/RELEASE_STATUS.md', '/docs/RELEASE_PROCESS.md'
    )
    function New-CodeownersFixture([string[]]$Owners = @('@octocat')) {
        $ownerText = $Owners -join ' '
        (@("* $ownerText") + @($script:requiredPaths | ForEach-Object { "$_ $ownerText" })) -join "`n"
    }
}

Describe 'CODEOWNERS structural validation' {
    It 'accepts user owners in a user-owned repository' {
        $result = Test-CodeownersContent -Content (New-CodeownersFixture) -RepositoryOwnerType User
        @($result | Where-Object Status -eq 'Failed').Count | Should -Be 0
    }

    It 'rejects team owners in a user-owned repository' {
        $result = Test-CodeownersContent -Content (New-CodeownersFixture '@ContosoOrg/maintainers') -RepositoryOwnerType User
        @($result | Where-Object Message -match 'incompatible').Count | Should -BeGreaterThan 0
    }

    It 'accepts structurally valid teams for an organization-owned repository' {
        $result = Test-CodeownersContent -Content (New-CodeownersFixture '@ContosoOrg/maintainers') -RepositoryOwnerType Organization
        @($result | Where-Object Status -eq 'Failed').Count | Should -Be 0
    }

    It 'accepts user and team syntax when owner type is unknown without claiming eligibility' {
        foreach ($owner in @('@octocat', '@ContosoOrg/maintainers')) {
            $result = Test-CodeownersContent -Content (New-CodeownersFixture $owner) -RepositoryOwnerType Unknown
            @($result | Where-Object Status -eq 'Failed').Count | Should -Be 0
            @($result | Where-Object Message -match 'eligible').Count | Should -Be 0
        }
    }

    It 'rejects malformed and placeholder owner tokens' {
        @(Test-CodeownersContent -Content (New-CodeownersFixture '@bad/user/name') -RepositoryOwnerType Organization | Where-Object Message -match 'Malformed').Count | Should -BeGreaterThan 0
        @(Test-CodeownersContent -Content (New-CodeownersFixture '@placeholder') -RepositoryOwnerType User | Where-Object Message -match 'Placeholder').Count | Should -BeGreaterThan 0
    }

    It 'rejects empty or comment-only content and missing default coverage' {
        @(Test-CodeownersContent -Content '# comment' | Where-Object Status -eq 'Failed').Count | Should -BeGreaterThan 0
        $withoutDefault = @($script:requiredPaths | ForEach-Object { "$_ @octocat" }) -join "`n"
        @(Test-CodeownersContent -Content $withoutDefault | Where-Object Message -match 'default').Count | Should -Be 1
    }

    It 'rejects missing protected-path coverage' {
        $content = (New-CodeownersFixture) -replace '(?m)^/schemas/.*\r?\n?', ''
        @(Test-CodeownersContent -Content $content | Where-Object Path -eq '/schemas/').Count | Should -Be 1
    }

    Context 'owner tokens and comments' {
        BeforeAll {
            function Test-CodeownersRule([string]$Rule, [string]$OwnerType = 'Unknown') {
                Test-CodeownersContent -Content "* @root-owner`n$Rule" -RepositoryOwnerType $OwnerType -RequiredPaths @()
            }
        }

        It 'accepts users teams emails multiple owners comments blank lines and full-line comments' {
            $rules = @(
                '/user/ @octocat',
                '/team/ @ContosoOrg/maintainers',
                '/email/ docs@example.com',
                '/email2/ security.team@example.org',
                '/email3/ first.last+governance@example.co.uk',
                '/multiple/ @octocat @hubot',
                '/mixed/ @octocat docs@example.com',
                '/user-comment/ @octocat # script owner',
                '/email-comment/ docs@example.com # documentation owner',
                '/multiple-comment/ @octocat docs@example.com # owners'
            )
            foreach ($rule in $rules) {
                @(Test-CodeownersRule $rule | Where-Object Status -eq 'Failed').Count | Should -Be 0 -Because $rule
            }
            $withComments = "# full line`n`n* @root-owner`n/docs/ docs@example.com # contact"
            @(Test-CodeownersContent -Content $withComments -RequiredPaths @() | Where-Object Status -eq 'Failed').Count | Should -Be 0
        }

        It 'accepts placeholder-like names that are not complete placeholder segments' {
            foreach ($owner in @('@todoist', '@placeholder-tools', '@ContosoOrg/placeholder-tools', 'todoist@example.com', 'placeholder-tools@example.com')) {
                @(Test-CodeownersRule "/valid/ $owner" | Where-Object Status -eq 'Failed').Count | Should -Be 0 -Because $owner
            }
        }

        It 'accepts users teams and emails for unknown owner type without eligibility claims' {
            $result = Test-CodeownersRule '/owners/ @octocat @ContosoOrg/maintainers docs@example.com' Unknown
            @($result | Where-Object Status -eq 'Failed').Count | Should -Be 0
            @($result | Where-Object Message -match 'eligible').Count | Should -Be 0
        }

        It 'rejects missing malformed unsupported and placeholder owners with the correct path' {
            $invalidRules = @(
                '/missing/', '/comment-only/ # missing owner', '/bad-user/ @bad/user/name',
                '/bad-email1/ docs@', '/bad-email2/ @example.com', '/bad-email3/ docs@example',
                '/bad-email4/ docs@@example.com', '/random/ @octocat random-token # comment',
                '/bad-email5/ .docs@example.com', '/bad-email6/ docs..ops@example.com',
                '/bad-email7/ docs@example..com', '/bad-email8/ docs@example-.com',
                '/placeholder-user/ @placeholder', '/placeholder-org/ @changeme/team',
                '/placeholder-team/ @ContosoOrg/todo', '/placeholder-email/ placeholder@example.com'
            )
            foreach ($rule in $invalidRules) {
                $path = ($rule -split '\s+')[0]
                $result = Test-CodeownersRule $rule
                @($result | Where-Object { $_.Status -eq 'Failed' -and $_.Path -eq $path }).Count | Should -BeGreaterThan 0 -Because $rule
            }
        }

        It 'does not interpret inline comment text as an owner' {
            $result = Test-CodeownersRule '/scripts/ @octocat # not-an-owner random-token'
            @($result | Where-Object Status -eq 'Failed').Count | Should -Be 0
        }

        It 'treats the first hash as a comment because CODEOWNERS does not support escaping it' {
            foreach ($rule in @('/scripts/ @octocat \# comment', '/foo\#bar @octocat')) {
                $result = Test-CodeownersRule $rule
                @($result | Where-Object Status -eq 'Failed').Count | Should -BeGreaterThan 0 -Because $rule
            }
        }

        It 'rejects team owners only when explicit owner type is User' {
            @(Test-CodeownersRule '/team/ @ContosoOrg/maintainers' User | Where-Object Message -match 'incompatible').Count | Should -Be 1
            @(Test-CodeownersRule '/team/ @ContosoOrg/maintainers' Organization | Where-Object Status -eq 'Failed').Count | Should -Be 0
        }
    }
}

Describe 'Live CODEOWNERS identity result classification' {
    It 'fails unresolved 404 identities' {
        $result = Resolve-CodeownersIdentity -Identity '@missing-user' -RepositoryOwnerType User -Lookup { @{ StatusCode = 404 } }
        $result.Status | Should -Be 'Failed'
    }

    It 'blocks authentication and authorization failures' {
        foreach ($statusCode in @(401, 403)) {
            $result = Resolve-CodeownersIdentity -Identity '@octocat' -RepositoryOwnerType User -Lookup { @{ StatusCode = $statusCode } }
            $result.Status | Should -Be 'Blocked'
        }
    }

    It 'accepts eligible users and verified organization teams' {
        $lookup = { @{ StatusCode = 200; HasRepositoryAccess = $true; CanReview = $true } }
        (Resolve-CodeownersIdentity -Identity '@octocat' -RepositoryOwnerType User -Lookup $lookup).Status | Should -Be 'Passed'
        (Resolve-CodeownersIdentity -Identity '@ContosoOrg/maintainers' -RepositoryOwnerType Organization -Lookup $lookup).Status | Should -Be 'Passed'
    }
}

Describe 'Protection planning' {
    It 'refuses lockout-producing CODEOWNERS and last-push requirements' {
        $plan = New-RepositoryProtectionPlan -EligibleReviewerCount 1 -IndependentReviewerCount 0 -RequestCodeOwnerReviews -RequestLastPushApproval
        $plan.RequireCodeOwnerReviews | Should -BeFalse
        $plan.RequireLastPushApproval | Should -BeFalse
        $plan.Warnings.Count | Should -BeGreaterOrEqual 2
    }

    It 'permits both controls with multiple eligible reviewers' {
        $plan = New-RepositoryProtectionPlan -EligibleReviewerCount 3 -IndependentReviewerCount 2 -RiskClassification High -RequestCodeOwnerReviews -RequestLastPushApproval
        $plan.RequireCodeOwnerReviews | Should -BeTrue
        $plan.RequireLastPushApproval | Should -BeTrue
        $plan.RequiredApprovingReviewCount | Should -Be 2
    }

    It 'reports a High-risk policy gap and chooses the strongest non-locking count' {
        $plan = New-RepositoryProtectionPlan -EligibleReviewerCount 2 -IndependentReviewerCount 1 -RiskClassification High
        $plan.RequiredApprovingReviewCount | Should -Be 1
        $plan.RequestedApprovalCountEnforceable | Should -BeFalse
        $plan.Warnings.Count | Should -BeGreaterThan 0
    }

    It 'does not silently collapse Critical policy or excess requested approvals' {
        $critical = New-RepositoryProtectionPlan -EligibleReviewerCount 2 -IndependentReviewerCount 1 -RiskClassification Critical
        $critical.PolicyApprovalCount | Should -Be 2
        $critical.Warnings.Count | Should -BeGreaterThan 0
        $requested = New-RepositoryProtectionPlan -EligibleReviewerCount 3 -IndependentReviewerCount 2 -RequestedApprovalCount 3
        $requested.RequestedApprovalCountEnforceable | Should -BeFalse
        $requested.RequiredApprovingReviewCount | Should -Be 2
    }

    It 'requires independent code-owner and last-pusher reviewer capacity' {
        $plan = New-RepositoryProtectionPlan -EligibleReviewerCount 3 -IndependentReviewerCount 2 -IndependentCodeOwnerCount 0 -ReviewersOtherThanLastPusherCount 0 -RequestCodeOwnerReviews -RequestLastPushApproval
        $plan.RequireCodeOwnerReviews | Should -BeFalse
        $plan.RequireLastPushApproval | Should -BeFalse
    }

    It 'keeps dry-run and plan mode non-mutating' {
        $plan = New-RepositoryProtectionPlan -EligibleReviewerCount 3 -IndependentReviewerCount 2 -RequestCodeOwnerReviews -RequestLastPushApproval
        $plan.Mode | Should -Be 'DryRun'
        $plan.MutationPerformed | Should -BeFalse
    }
}
