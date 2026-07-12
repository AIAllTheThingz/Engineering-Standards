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
        $plan.Warnings.Count | Should -Be 2
    }

    It 'permits both controls with multiple eligible reviewers' {
        $plan = New-RepositoryProtectionPlan -EligibleReviewerCount 3 -IndependentReviewerCount 2 -RequestCodeOwnerReviews -RequestLastPushApproval
        $plan.RequireCodeOwnerReviews | Should -BeTrue
        $plan.RequireLastPushApproval | Should -BeTrue
        $plan.RequiredApprovingReviewCount | Should -Be 1
    }

    It 'keeps dry-run and plan mode non-mutating' {
        $plan = New-RepositoryProtectionPlan -EligibleReviewerCount 3 -IndependentReviewerCount 2 -RequestCodeOwnerReviews -RequestLastPushApproval
        $plan.Mode | Should -Be 'DryRun'
        $plan.MutationPerformed | Should -BeFalse
    }
}
