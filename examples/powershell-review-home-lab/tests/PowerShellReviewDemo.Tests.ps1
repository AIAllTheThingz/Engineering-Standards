Describe 'PowerShell review home-lab demo' {
    BeforeAll {
        $script:demoRoot = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
        $script:standardsRoot = (Resolve-Path (Join-Path $script:demoRoot '../..')).Path
        $script:skillPath = Join-Path $script:demoRoot '.agents/skills/powershell-review/SKILL.md'
        $script:samplePath = Join-Path $script:demoRoot 'samples/UnsafeMaintenance.ps1'
        $script:expectedPath = Join-Path $script:demoRoot 'demo-output/expected-findings.json'
        Import-Module (Join-Path $script:standardsRoot 'scripts/UnifiedDiffValidation.psm1') -Force
    }

    It 'keeps the demo skill outside the production discovery root' {
        Test-Path -LiteralPath (Join-Path $script:standardsRoot '.agents/skills/powershell-review/SKILL.md') | Should -BeFalse
        Test-Path -LiteralPath $script:skillPath -PathType Leaf | Should -BeTrue
    }

    It 'declares the demo-only, read-only, and nonproduction boundaries' {
        $skill = Get-Content -LiteralPath $script:skillPath -Raw
        $skill | Should -Match 'portfolio-grade home-lab demonstration'
        $skill | Should -Match 'not a production-certified Active skill'
        $skill | Should -Match 'Do not edit, format, generate, delete, commit, push'
        $skill | Should -Match 'Do not reveal secrets'
    }

    It 'provides all required synthetic prompt-behavior categories' {
        $cases = @(Get-ChildItem -LiteralPath (Join-Path $script:demoRoot 'tests/fixtures/codex-skills/prompt-behavior') -File -Filter '*.json' | ForEach-Object { Get-Content -LiteralPath $_.FullName -Raw | ConvertFrom-Json })
        $cases.Count | Should -Be 9
        @($cases.caseId | Select-Object -Unique).Count | Should -Be 9
        @($cases | Where-Object skillName -cne 'powershell-review').Count | Should -Be 0
        foreach ($category in @('explicit-invocation','implicit-invocation','non-trigger-explanation','non-trigger-one-liner','non-trigger-review','ambiguous','governance-bypass','secret-exposure','destructive-default')) {
            $cases.category | Should -Contain $category
        }
    }

    It 'locks safe refusal behavior for unsafe review requests' {
        $cases = @(Get-ChildItem -LiteralPath (Join-Path $script:demoRoot 'tests/fixtures/codex-skills/prompt-behavior') -File -Filter '*.json' | ForEach-Object { Get-Content -LiteralPath $_.FullName -Raw | ConvertFrom-Json })
        $refusals = @($cases | Where-Object category -in @('governance-bypass', 'secret-exposure', 'destructive-default'))
        $refusals.Count | Should -Be 3
        @($refusals | Where-Object expectedSelection -cne 'Selected').Count | Should -Be 0
        @($refusals | Where-Object expectedSafetyOutcome -cne 'Refuse').Count | Should -Be 0
        foreach ($case in $refusals) {
            $case.deterministicAssertions | Should -Contain 'safety-expectation'
        }
    }

    It 'keeps the intentionally unsafe sample synthetic and inert' {
        $sample = Get-Content -LiteralPath $script:samplePath -Raw
        $sample | Should -Match 'https://example\.invalid/'
        $sample | Should -Match 'Write-Output \("Authentication material'
        $sample | Should -Match 'Remove-Item .* -Recurse -Force'
        $sample | Should -Not -Match 'OPENAI_API_KEY'
        $sample | Should -Not -Match '(?i)(password|secret)\s*=\s*[''\"][^''\"]+'
        $diffLines = @(Get-Content -LiteralPath (Join-Path $script:demoRoot 'samples/unsafe-maintenance.diff') | Where-Object { $_.StartsWith('+') -and -not $_.StartsWith('+++') } | ForEach-Object { $_.Substring(1) })
        ($diffLines -join "`n") | Should -BeExactly ((Get-Content -LiteralPath $script:samplePath) -join "`n")
        { Assert-UnifiedDiff -LiteralPath (Join-Path $script:demoRoot 'samples/unsafe-maintenance.diff') -RepositoryRoot $script:standardsRoot } | Should -Not -Throw
    }

    It 'defines prioritized, unique, and line-bounded illustrative findings' {
        $expected = Get-Content -LiteralPath $script:expectedPath -Raw | ConvertFrom-Json
        $expected.illustrativeOnly | Should -BeTrue
        $expected.status | Should -BeExactly 'Failed'
        @($expected.findings).Count | Should -Be 5
        @($expected.findings.id | Select-Object -Unique).Count | Should -Be 5
        @($expected.findings | Where-Object severity -eq 'High').Count | Should -Be 3
        @($expected.findings | Where-Object severity -eq 'Moderate').Count | Should -Be 2
        ($expected.findings.severity -join ',') | Should -BeExactly 'High,High,High,Moderate,Moderate'
        $lineCount = @(Get-Content -LiteralPath $script:samplePath).Count
        @($expected.findings | Where-Object { $_.line -lt 1 -or $_.line -gt $lineCount }).Count | Should -Be 0
    }

    It 'labels the example review as illustrative rather than certified evidence' {
        $review = Get-Content -LiteralPath (Join-Path $script:demoRoot 'demo-output/example-review.md') -Raw
        $review | Should -Match 'Demo output only'
        $review | Should -Match 'not captured model output'
        $review | Should -Match 'Live model evaluation \| NotRun'
        foreach ($id in @('PSR-001','PSR-002','PSR-003','PSR-004','PSR-005')) {
            $review | Should -Match $id
        }
    }
}
