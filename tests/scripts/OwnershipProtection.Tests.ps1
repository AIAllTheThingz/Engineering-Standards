BeforeAll {
    Import-Module "$PSScriptRoot/../../scripts/OwnershipProtection.psm1" -Force
    $script:requiredPaths = @(
        '/AGENTS.md', '/.agents/suspended-skills/', '/agents/', '/governance/', '/schemas/', '/actions/',
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
        @(Test-CodeownersContent -Content $content -RequiredPaths $script:requiredPaths | Where-Object Path -eq '/schemas/').Count | Should -Be 1
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

        It 'rejects malformed unsupported and placeholder owners with the correct path' {
            $invalidRules = @(
                '/bad-user/ @bad/user/name',
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

        It 'allows an ownerless rule when it does not remove required ownership' {
            $result = Test-CodeownersRule '/generated/'
            @($result | Where-Object Status -eq 'Failed').Count | Should -Be 0
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

    Context 'last matching rule precedence' {
        It 'fails fallback validation when a later universal rule removes default ownership' {
            foreach ($universalPattern in @('/**', '**/', '/**/', '**/*', '/**/*')) {
                $finding = @(Test-CodeownersContent -Content "* @root-owner`n$universalPattern" | Where-Object RequiredPath -eq '*')[-1]
                $finding.Status | Should -Be 'Failed' -Because $universalPattern
                $finding.EffectivePattern | Should -Be $universalPattern
                $finding.EffectiveOwners.Count | Should -Be 0
                $finding.RuleIndex | Should -Be 2
                $finding.Reason | Should -Match 'universal CODEOWNERS rule'
            }
        }

        It 'fails fallback validation for malformed or incompatible universal owners' {
            $malformed = @(Test-CodeownersContent -Content "* @root-owner`n/** bad-owner" | Where-Object RequiredPath -eq '*')[-1]
            $malformed.Status | Should -Be 'Failed'
            $malformed.EffectiveOwners | Should -Be @('bad-owner')

            $incompatible = @(Test-CodeownersContent -Content "* @root-owner`n/** @ContosoOrg/team" -RepositoryOwnerType User | Where-Object RequiredPath -eq '*')[-1]
            $incompatible.Status | Should -Be 'Failed'
            $incompatible.OwnerType | Should -Be 'User'
            $incompatible.EffectivePattern | Should -Be '/**'
        }

        It 'uses a valid later universal rule for generic fallback ownership' {
            $finding = @(Test-CodeownersContent -Content "* @root-owner`n/** security@example.com" | Where-Object RequiredPath -eq '*')[-1]
            $finding.Status | Should -Be 'Passed'
            $finding.EffectivePattern | Should -Be '/**'
            $finding.EffectiveOwners | Should -Be @('security@example.com')
        }

        It 'fails generic fallback closed for a later potentially universal unsupported pattern' {
            foreach ($rule in @('***', '*** bad-owner')) {
                $finding = @(Test-CodeownersContent -Content "* @root-owner`n$rule" | Where-Object RequiredPath -eq '*')[-1]
                $finding.Status | Should -Be 'Failed' -Because $rule
                $finding.EffectivePattern | Should -Be '***'
                $finding.RuleIndex | Should -Be 2
                $finding.Reason | Should -Match 'could replace generic fallback ownership'
            }
        }

        It 'uses an exact required path when no later rule matches' {
            $result = Test-CodeownersContent -Content "* @root-owner`n/scripts/ @script-owner" -RequiredPaths '/scripts/'
            $finding = @($result | Where-Object RequiredPath -eq '/scripts/')[-1]
            $finding.Status | Should -Be 'Passed'
            $finding.EffectivePattern | Should -Be '/scripts/'
            $finding.EffectiveOwners | Should -Be @('@script-owner')
            $finding.RuleIndex | Should -Be 2
            $finding.LineNumber | Should -Be 2
            $finding.RepositoryOwnerType | Should -Be 'Unknown'
            $finding.Path | Should -Be '/scripts/'
            $finding.Identity | Should -Be '@script-owner'
        }

        It 'uses a later exact override after the broad default' {
            $result = Test-CodeownersContent -Content "* @root-owner`n/scripts/ @script-owner" -RequiredPaths '/scripts/'
            @($result | Where-Object RequiredPath -eq '/scripts/')[-1].EffectiveOwners | Should -Be @('@script-owner')
        }

        It 'uses a later broad override after an exact rule' {
            $result = Test-CodeownersContent -Content "* @root-owner`n/scripts/ @script-owner`n/** @broad-owner" -RequiredPaths '/scripts/'
            $finding = @($result | Where-Object RequiredPath -eq '/scripts/')[-1]
            $finding.Status | Should -Be 'Passed'
            $finding.EffectivePattern | Should -Be '/**'
            $finding.EffectiveOwners | Should -Be @('@broad-owner')
            $finding.RuleIndex | Should -Be 3
        }

        It 'fails when a later ownerless rule removes required ownership' {
            $result = Test-CodeownersContent -Content "* @root-owner`n/scripts/ @script-owner`n/scripts/" -RequiredPaths '/scripts/'
            $finding = @($result | Where-Object RequiredPath -eq '/scripts/')[-1]
            $finding.Status | Should -Be 'Failed'
            $finding.Reason | Should -Match 'has no owners'
            $finding.EffectiveOwners.Count | Should -Be 0
            $finding.LineNumber | Should -Be 3
        }

        It 'fails when a later rule replaces a valid user with a malformed owner' {
            $result = Test-CodeownersContent -Content "* @root-owner`n/scripts/ @script-owner`n/scripts/ bad-owner" -RequiredPaths '/scripts/'
            $finding = @($result | Where-Object RequiredPath -eq '/scripts/')[-1]
            $finding.Status | Should -Be 'Failed'
            $finding.Reason | Should -Match 'invalid or incompatible'
            $finding.EffectiveOwners | Should -Be @('bad-owner')
        }

        It 'fails when a later team rule is effective for a user-owned repository' {
            $result = Test-CodeownersContent -Content "* @root-owner`n/scripts/ @script-owner`n/scripts/ @ContosoOrg/team" -RepositoryOwnerType User -RequiredPaths '/scripts/'
            $finding = @($result | Where-Object RequiredPath -eq '/scripts/')[-1]
            $finding.Status | Should -Be 'Failed'
            $finding.Reason | Should -Match 'invalid or incompatible'
            $finding.OwnerType | Should -Be 'User'
        }

        It 'selects only the final matching rule and ignores later nonmatching rules' {
            $content = "* @root-owner`n/scripts/ @first`n/scripts/* @second`n/docs/ @docs-owner"
            $finding = @(Test-CodeownersContent -Content $content -RequiredPaths '/scripts/' | Where-Object RequiredPath -eq '/scripts/')[-1]
            $finding.Status | Should -Be 'Passed'
            $finding.EffectivePattern | Should -Be '/scripts/*'
            $finding.EffectiveOwners | Should -Be @('@second')
        }

        It 'applies directory ownership below the directory without matching similar path names' {
            $content = "* @root-owner`n/scripts/tools.ps1 @exact`n/scripts/ @directory-owner`n/scripts-old/ @other-owner"
            $finding = @(Test-CodeownersContent -Content $content -RequiredPaths '/scripts/tools.ps1' | Where-Object RequiredPath -eq '/scripts/tools.ps1')[-1]
            $finding.Status | Should -Be 'Passed'
            $finding.EffectivePattern | Should -Be '/scripts/'
            $finding.EffectiveOwners | Should -Be @('@directory-owner')
        }

        It 'preserves inline comments and email owners during precedence evaluation' {
            $content = "# full-line comment`n* @root-owner`n/docs/ @docs-owner`n/docs/ security@example.com # final contact"
            $finding = @(Test-CodeownersContent -Content $content -RequiredPaths '/docs/' | Where-Object RequiredPath -eq '/docs/')[-1]
            $finding.Status | Should -Be 'Passed'
            $finding.EffectiveOwners | Should -Be @('security@example.com')
            $finding.LineNumber | Should -Be 4
        }

        It 'fails clearly for a decision-relevant unsupported pattern' {
            $content = "* @root-owner`n/scripts/ @script-owner`n/scripts/[ab]* @ambiguous-owner"
            $finding = @(Test-CodeownersContent -Content $content -RequiredPaths '/scripts/' | Where-Object RequiredPath -eq '/scripts/')[-1]
            $finding.Status | Should -Be 'Failed'
            $finding.Reason | Should -Match 'Unsupported CODEOWNERS pattern'
            $finding.EffectivePattern | Should -Be '/scripts/[ab]*'
            $finding.RuleIndex | Should -Be 3
        }

        It 'does not let an unsupported pattern for another path block a required decision' {
            $content = "* @root-owner`n/scripts/ @script-owner`n/docs/[ab]* @ambiguous-owner"
            $finding = @(Test-CodeownersContent -Content $content -RequiredPaths '/scripts/' | Where-Object RequiredPath -eq '/scripts/')[-1]
            $finding.Status | Should -Be 'Passed'
            $finding.EffectivePattern | Should -Be '/scripts/'
        }

        It 'fails closed for slashless unsupported basename patterns at the root and nested depths' {
            $cases = @(
                @{ Pattern = 'foo?'; RequiredPath = '/foo1' },
                @{ Pattern = 'foo?'; RequiredPath = '/nested/foo1' },
                @{ Pattern = 'foo[0-9]'; RequiredPath = '/foo7' },
                @{ Pattern = 'foo[0-9]'; RequiredPath = '/nested/foo7' }
            )
            foreach ($case in $cases) {
                $content = "* @root-owner`n$($case.Pattern) @ambiguous-owner"
                $finding = @(Test-CodeownersContent -Content $content -RequiredPaths $case.RequiredPath | Where-Object RequiredPath -eq $case.RequiredPath)[-1]
                $finding.Status | Should -Be 'Failed' -Because "$($case.Pattern) can affect $($case.RequiredPath)"
                $finding.Message | Should -Match 'Unsupported CODEOWNERS pattern'
                $finding.EffectivePattern | Should -Be $case.Pattern
                $finding.RuleIndex | Should -Be 2
            }
        }

        It 'does not overapply slashless unsupported patterns to unrelated or similar basenames' {
            $cases = @(
                @{ Pattern = 'foo?'; RequiredPath = '/nested/bar1' },
                @{ Pattern = 'foo?'; RequiredPath = '/nested/foobar' },
                @{ Pattern = 'foo?'; RequiredPath = '/nested/foo12' },
                @{ Pattern = 'foo[0-9]'; RequiredPath = '/nested/bar7' },
                @{ Pattern = 'foo[0-9]'; RequiredPath = '/nested/foobar' },
                @{ Pattern = 'foo[0-9]'; RequiredPath = '/nested/fooA' },
                @{ Pattern = 'foo[0-9]'; RequiredPath = '/nested/foo12' }
            )
            foreach ($case in $cases) {
                $content = "* @root-owner`n$($case.Pattern) @ambiguous-owner"
                $finding = @(Test-CodeownersContent -Content $content -RequiredPaths $case.RequiredPath | Where-Object RequiredPath -eq $case.RequiredPath)[-1]
                $finding.Status | Should -Be 'Passed' -Because "$($case.Pattern) cannot affect $($case.RequiredPath)"
                $finding.EffectivePattern | Should -Be '*'
                $finding.EffectiveOwners | Should -Be @('@root-owner')
            }
        }

        It 'fails malformed slashless bracket ranges closed without throwing' {
            foreach ($requiredPath in @('/foo7', '/nested/foo7', '/nested/fooA')) {
                $content = "* @root-owner`nfoo[9-0] @ambiguous-owner"
                { Test-CodeownersContent -Content $content -RequiredPaths $requiredPath } | Should -Not -Throw
                $finding = @(Test-CodeownersContent -Content $content -RequiredPaths $requiredPath | Where-Object RequiredPath -eq $requiredPath)[-1]
                $finding.Status | Should -Be 'Failed' -Because "an invalid class is conservatively one segment character for $requiredPath"
                $finding.Message | Should -Match 'Unsupported CODEOWNERS pattern'
                $finding.EffectivePattern | Should -Be 'foo[9-0]'
                $finding.RuleIndex | Should -Be 2
            }

            $unrelatedPath = '/nested/bar7'
            $finding = @(Test-CodeownersContent -Content "* @root-owner`nfoo[9-0] @ambiguous-owner" -RequiredPaths $unrelatedPath | Where-Object RequiredPath -eq $unrelatedPath)[-1]
            $finding.Status | Should -Be 'Passed'
            $finding.EffectivePattern | Should -Be '*'
        }

        It 'does not let an earlier unsupported candidate override a later supported match' {
            $content = "* @root-owner`n/scripts/[ab]* @ambiguous-owner`n/scripts/ @script-owner"
            $finding = @(Test-CodeownersContent -Content $content -RequiredPaths '/scripts/' | Where-Object RequiredPath -eq '/scripts/')[-1]
            $finding.Status | Should -Be 'Passed'
            $finding.EffectivePattern | Should -Be '/scripts/'
            $finding.RuleIndex | Should -Be 3
        }

        It 'matches paths case-sensitively like GitHub' {
            $content = "* @root-owner`n/Scripts/ @wrong-case-owner"
            $finding = @(Test-CodeownersContent -Content $content -RequiredPaths '/scripts/' | Where-Object RequiredPath -eq '/scripts/')[-1]
            $finding.Status | Should -Be 'Passed'
            $finding.EffectivePattern | Should -Be '*'
            @($finding.EffectiveOwners) | Should -Be @('@root-owner')
        }

        It 'fails closed for embedded double-star forms outside the supported subset' {
            $content = "* @root-owner`n/scripts/ @script-owner`n/scripts/ab**cd @ambiguous-owner"
            $finding = @(Test-CodeownersContent -Content $content -RequiredPaths '/scripts/' | Where-Object RequiredPath -eq '/scripts/')[-1]
            $finding.Status | Should -Be 'Failed'
            $finding.Message | Should -Match 'Unsupported CODEOWNERS pattern'
            $finding.EffectivePattern | Should -Be '/scripts/ab**cd'
        }

        It 'uses the literal prefix of an embedded double-star to fail a concrete affected path closed' {
            $content = "* @root-owner`n/scripts/ @script-owner`n/scripts/ab**cd @ambiguous-owner"
            $finding = @(Test-CodeownersContent -Content $content -RequiredPaths '/scripts/abZZcd' | Where-Object RequiredPath -eq '/scripts/abZZcd')[-1]
            $finding.Status | Should -Be 'Failed'
            $finding.Message | Should -Match 'Unsupported CODEOWNERS pattern'
            $finding.EffectivePattern | Should -Be '/scripts/ab**cd'
            $finding.RuleIndex | Should -Be 3
        }

        It 'stops unsupported-pattern relevance at an earlier wildcard' {
            $cases = @(
                @{ Pattern = '/scripts/a*ab**cd'; RequiredPath = '/scripts/axabZZcd' },
                @{ Pattern = '/scripts/*ab**cd'; RequiredPath = '/scripts/xxabYYcd' },
                @{ Pattern = '/scripts/**/ab**cd'; RequiredPath = '/scripts/x/abYYcd' }
            )
            foreach ($case in $cases) {
                $content = "* @root-owner`n/scripts/ @script-owner`n$($case.Pattern) @ambiguous-owner"
                $finding = @(Test-CodeownersContent -Content $content -RequiredPaths $case.RequiredPath | Where-Object RequiredPath -eq $case.RequiredPath)[-1]
                $finding.Status | Should -Be 'Failed' -Because $case.Pattern
                $finding.Message | Should -Match 'Unsupported CODEOWNERS pattern'
                $finding.EffectivePattern | Should -Be $case.Pattern
                $finding.RuleIndex | Should -Be 3
            }
        }

        It 'does not cross a path-segment boundary for unsupported relevance' {
            $cases = @(
                @{ Pattern = '/docs/[ab]'; RequiredPath = '/docs-old/file.md' },
                @{ Pattern = '/scripts/*ab**cd'; RequiredPath = '/scripts-old/tool.ps1' }
            )
            foreach ($case in $cases) {
                $content = "* @root-owner`n$($case.Pattern) @ambiguous-owner"
                $finding = @(Test-CodeownersContent -Content $content -RequiredPaths $case.RequiredPath | Where-Object RequiredPath -eq $case.RequiredPath)[-1]
                $finding.Status | Should -Be 'Passed' -Because $case.Pattern
                $finding.EffectivePattern | Should -Be '*'
            }
        }

        It 'retains mid-segment unsupported-prefix relevance' {
            $content = "* @root-owner`n/scripts/a*ab**cd @ambiguous-owner"
            $finding = @(Test-CodeownersContent -Content $content -RequiredPaths '/scripts/axabZZcd' | Where-Object RequiredPath -eq '/scripts/axabZZcd')[-1]
            $finding.Status | Should -Be 'Failed'
            $finding.EffectivePattern | Should -Be '/scripts/a*ab**cd'
        }

        It 'matches a complete globstar segment across zero directories' {
            $content = "* @root-owner`n/foo/**/bar @bar-owner"
            $finding = @(Test-CodeownersContent -Content $content -RequiredPaths '/foo/bar' | Where-Object RequiredPath -eq '/foo/bar')[-1]
            $finding.Status | Should -Be 'Passed'
            $finding.EffectivePattern | Should -Be '/foo/**/bar'
            $finding.EffectiveOwners | Should -Be @('@bar-owner')
        }

        It 'matches a complete globstar segment across multiple directories' {
            $content = "* @root-owner`n/foo/**/bar @bar-owner"
            foreach ($requiredPath in @('/foo/x/bar', '/foo/x/y/bar')) {
                $finding = @(Test-CodeownersContent -Content $content -RequiredPaths $requiredPath | Where-Object RequiredPath -eq $requiredPath)[-1]
                $finding.Status | Should -Be 'Passed' -Because $requiredPath
                $finding.EffectivePattern | Should -Be '/foo/**/bar'
                $finding.EffectiveOwners | Should -Be @('@bar-owner')
            }
        }

        It 'anchors non-leading patterns that contain an internal slash to the repository root' {
            $content = "* @root-owner`ndocs/* @docs-owner"
            $rootFinding = @(Test-CodeownersContent -Content $content -RequiredPaths '/docs/file.md' | Where-Object RequiredPath -eq '/docs/file.md')[-1]
            $rootFinding.Status | Should -Be 'Passed'
            $rootFinding.EffectivePattern | Should -Be 'docs/*'
            $rootFinding.EffectiveOwners | Should -Be @('@docs-owner')

            $nestedFinding = @(Test-CodeownersContent -Content $content -RequiredPaths '/foo/docs/file.md' | Where-Object RequiredPath -eq '/foo/docs/file.md')[-1]
            $nestedFinding.Status | Should -Be 'Passed'
            $nestedFinding.EffectivePattern | Should -Be '*'
            $nestedFinding.EffectiveOwners | Should -Be @('@root-owner')
        }

        It 'matches a trailing-slash name without an internal slash at any depth' {
            $content = "* @root-owner`napps/ @apps-owner"
            foreach ($requiredPath in @('/apps/', '/src/apps/', '/src/apps/file.txt')) {
                $finding = @(Test-CodeownersContent -Content $content -RequiredPaths $requiredPath | Where-Object RequiredPath -eq $requiredPath)[-1]
                $finding.Status | Should -Be 'Passed' -Because $requiredPath
                $finding.EffectivePattern | Should -Be 'apps/'
                $finding.EffectiveOwners | Should -Be @('@apps-owner')
            }
        }

        It 'preserves leading globstar matching at the root and any depth' {
            $content = "* @root-owner`n**/logs @logs-owner"
            foreach ($requiredPath in @('/logs', '/src/logs', '/src/feature/logs')) {
                $finding = @(Test-CodeownersContent -Content $content -RequiredPaths $requiredPath | Where-Object RequiredPath -eq $requiredPath)[-1]
                $finding.Status | Should -Be 'Passed' -Because $requiredPath
                $finding.EffectivePattern | Should -Be '**/logs'
                $finding.EffectiveOwners | Should -Be @('@logs-owner')
            }
        }

        It 'matches a literal directory pattern exactly and through descendants' {
            $content = "* @root-owner`n/apps/ @apps-owner`n/apps/github @github-owner"
            foreach ($requiredPath in @('/apps/github', '/apps/github/file.txt', '/apps/github/src/tool.ps1')) {
                $finding = @(Test-CodeownersContent -Content $content -RequiredPaths $requiredPath | Where-Object RequiredPath -eq $requiredPath)[-1]
                $finding.Status | Should -Be 'Passed' -Because $requiredPath
                $finding.EffectivePattern | Should -Be '/apps/github'
                $finding.EffectiveOwners | Should -Be @('@github-owner')
            }
        }

        It 'lets a later ownerless literal directory override descendants' {
            $content = "* @root-owner`n/apps/ @apps-owner`n/apps/github"
            $finding = @(Test-CodeownersContent -Content $content -RequiredPaths '/apps/github/file.txt' | Where-Object RequiredPath -eq '/apps/github/file.txt')[-1]
            $finding.Status | Should -Be 'Failed'
            $finding.EffectivePattern | Should -Be '/apps/github'
            $finding.EffectiveOwners.Count | Should -Be 0
            $finding.RuleIndex | Should -Be 3
        }

        It 'does not extend a literal pattern across a similar-name boundary' {
            $content = "* @root-owner`n/apps/ @apps-owner`n/apps/github @github-owner"
            foreach ($requiredPath in @('/apps/github-old', '/apps/github.txt')) {
                $finding = @(Test-CodeownersContent -Content $content -RequiredPaths $requiredPath | Where-Object RequiredPath -eq $requiredPath)[-1]
                $finding.Status | Should -Be 'Passed' -Because $requiredPath
                $finding.EffectivePattern | Should -Be '/apps/'
                $finding.EffectiveOwners | Should -Be @('@apps-owner')
            }
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
