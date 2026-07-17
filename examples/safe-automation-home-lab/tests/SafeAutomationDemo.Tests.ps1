Describe 'Safe automation home-lab demo' {
    BeforeAll {
        $script:root=(Resolve-Path (Join-Path $PSScriptRoot '..')).Path
        $script:standards=(Resolve-Path (Join-Path $script:root '../..')).Path
        $script:skill=Get-Content (Join-Path $script:root '.agents/skills/safe-automation/SKILL.md') -Raw
        $script:request=Get-Content (Join-Path $script:root 'samples/change-request.json') -Raw|ConvertFrom-Json
        $script:plan=Get-Content (Join-Path $script:root 'demo-output/expected-plan.json') -Raw|ConvertFrom-Json
    }
    It 'keeps the skill isolated from production discovery' {
        Test-Path (Join-Path $script:standards '.agents/skills/safe-automation/SKILL.md')|Should -BeFalse
        Test-Path (Join-Path $script:root '.agents/skills/safe-automation/SKILL.md')|Should -BeTrue
    }
    It 'declares plan-only and refusal boundaries' {
        $script:skill|Should -Match 'not a production-certified'
        $script:skill|Should -Match 'do not connect to hosts'
        $script:skill|Should -Match 'Refuse secret exposure'
        $script:skill|Should -Match 'unbounded targets'
    }
    It 'uses bounded nonproduction targets without embedded credentials' {
        $script:request.production|Should -BeFalse
        @($script:request.targets).Count|Should -BeLessOrEqual 2
        $script:request.maxParallel|Should -Be 1
        $script:request.credentialReference|Should -BeNullOrEmpty
    }
    It 'separates phases and defaults to dry run' {
        ($script:plan.phases -join ',')|Should -BeExactly 'Plan,Approve,Execute,Verify,Recover'
        $script:plan.dryRunDefault|Should -BeTrue
        $script:plan.approval.required|Should -BeTrue
        $script:plan.executionStatus|Should -BeExactly 'NotRun'
    }
    It 'defines idempotency rollback and sanitized observability' {
        $script:plan.idempotencyKey|Should -BeExactly $script:request.requestId
        $script:plan.rollbackTrigger|Should -BeExactly 'verification-failed'
        @($script:plan.preconditions).Count|Should -BeGreaterOrEqual 3
        ($script:plan.eventFields -join ',')|Should -BeExactly 'correlationId,phase,targetCount,decision,outcome'
        ($script:plan|ConvertTo-Json -Depth 8)|Should -Not -Match '(?i)password|token|secret'
    }
    It 'provides nine routing cases and refuses unsafe categories' {
        $cases=@(Get-ChildItem (Join-Path $script:root 'tests/fixtures/codex-skills/prompt-behavior') -Filter '*.json'|ForEach-Object{Get-Content $_.FullName -Raw|ConvertFrom-Json})
        $cases.Count|Should -Be 9
        foreach($category in @('explicit-invocation','implicit-invocation','non-trigger-explanation','non-trigger-one-liner','non-trigger-review','ambiguous','governance-bypass','secret-exposure','destructive-default')){$cases.category|Should -Contain $category}
        @($cases|Where-Object category -in @('governance-bypass','secret-exposure','destructive-default')|Where-Object expectedSafetyOutcome -cne 'Refuse').Count|Should -Be 0
    }
}
