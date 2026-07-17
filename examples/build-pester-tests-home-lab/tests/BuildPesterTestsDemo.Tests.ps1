Describe 'Build Pester tests home-lab demo' {
    BeforeAll {
        $script:demoRoot = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
        $script:standardsRoot = (Resolve-Path (Join-Path $script:demoRoot '../..')).Path
        $script:skillPath = Join-Path $script:demoRoot '.agents/skills/build-pester-tests/SKILL.md'
        Import-Module (Join-Path $script:demoRoot 'samples/SafePath.psm1') -Force
        $script:requirements = Get-Content (Join-Path $script:demoRoot 'samples/requirements.json') -Raw | ConvertFrom-Json
        $script:plan = Get-Content (Join-Path $script:demoRoot 'demo-output/expected-test-plan.json') -Raw | ConvertFrom-Json
    }

    It 'keeps the isolated skill out of the production discovery root' {
        Test-Path (Join-Path $script:standardsRoot '.agents/skills/build-pester-tests/SKILL.md') | Should -BeFalse
        Test-Path $script:skillPath -PathType Leaf | Should -BeTrue
    }

    It 'declares governed nonproduction test-building boundaries' {
        $skill = Get-Content $script:skillPath -Raw
        $skill | Should -Match 'portfolio-grade home-lab demonstration'
        $skill | Should -Match 'Pester-managed temporary storage'
        $skill | Should -Match 'do not weaken the test'
        $skill | Should -Match 'Never claim GitHub Actions'
    }

    It 'maps every requirement exactly once to a test' {
        @($script:requirements.requirements).Count | Should -Be 4
        @($script:plan.mappings).Count | Should -Be 4
        @($script:plan.mappings.requirementId | Sort-Object) | Should -Be @($script:requirements.requirements.id | Sort-Object)
        @($script:plan.mappings.testId | Select-Object -Unique).Count | Should -Be 4
        $script:plan.illustrativeOnly | Should -BeTrue
        $script:plan.liveModelEvaluation | Should -BeExactly 'NotRun'
    }

    It 'PST-001 resolves a valid child beneath TestDrive' {
        $actual = Resolve-SafeChildPath -Root $TestDrive -ChildPath 'reports/result.json'
        $actual | Should -BeExactly (Join-Path $TestDrive 'reports/result.json')
    }

    It 'PST-002 rejects traversal outside the root' {
        { Resolve-SafeChildPath -Root $TestDrive -ChildPath '../outside.txt' } | Should -Throw '*escapes*'
    }

    It 'PST-003 rejects a rooted child outside the root' {
        $outside = [IO.Path]::GetPathRoot($TestDrive)
        { Resolve-SafeChildPath -Root $TestDrive -ChildPath (Join-Path $outside 'outside.txt') } | Should -Throw '*must be relative*'
    }

    It 'PST-004 rejects an empty child path' {
        { Resolve-SafeChildPath -Root $TestDrive -ChildPath '' } | Should -Throw
    }

    It 'provides all nine routing categories and refuses unsafe requests' {
        $cases = @(Get-ChildItem (Join-Path $script:demoRoot 'tests/fixtures/codex-skills/prompt-behavior') -Filter '*.json' | ForEach-Object { Get-Content $_.FullName -Raw | ConvertFrom-Json })
        $cases.Count | Should -Be 9
        @($cases.caseId | Select-Object -Unique).Count | Should -Be 9
        foreach ($category in @('explicit-invocation','implicit-invocation','non-trigger-explanation','non-trigger-one-liner','non-trigger-review','ambiguous','governance-bypass','secret-exposure','destructive-default')) { $cases.category | Should -Contain $category }
        $unsafe = @($cases | Where-Object category -in @('governance-bypass','secret-exposure','destructive-default'))
        @($unsafe | Where-Object expectedSafetyOutcome -cne 'Refuse').Count | Should -Be 0
    }
}
