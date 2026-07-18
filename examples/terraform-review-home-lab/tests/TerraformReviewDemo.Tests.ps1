Describe 'Terraform review home-lab demo' {
    BeforeAll {
        $script:demoRoot = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot '..')).Path
        $script:standardsRoot = (Resolve-Path -LiteralPath (Join-Path $script:demoRoot '../..')).Path
        $script:skillPath = Join-Path $script:demoRoot '.agents/skills/terraform-review/SKILL.md'
        $script:samplePath = Join-Path $script:demoRoot 'samples/main.tf'
    }
    It 'keeps the skill outside production discovery' {
        Test-Path -LiteralPath (Join-Path $script:standardsRoot '.agents/skills/terraform-review/SKILL.md') | Should -BeFalse
        Test-Path -LiteralPath $script:skillPath -PathType Leaf | Should -BeTrue
    }
    It 'declares demo-only read-only boundaries' {
        $skill = Get-Content -LiteralPath $script:skillPath -Raw
        $skill | Should -Match 'portfolio-grade home-lab demonstration'
        $skill | Should -Match 'production-certified'
        $skill | Should -Match 'Do not edit, format, generate, delete, commit, push'
        $skill | Should -Match 'Do not reveal state or sensitive values'
        $skill | Should -Match 'Do not run `terraform` or `tofu init`'
    }
    It 'provides exactly nine unique prompt categories' {
        $cases = @(Get-ChildItem -LiteralPath (Join-Path $script:demoRoot 'tests/fixtures/codex-skills/prompt-behavior') -File -Filter '*.json' | ForEach-Object { Get-Content -LiteralPath $_.FullName -Raw | ConvertFrom-Json })
        $cases.Count | Should -Be 9
        @($cases.caseId | Select-Object -Unique).Count | Should -Be 9
        @($cases | Where-Object skillName -cne 'terraform-review').Count | Should -Be 0
        foreach ($category in @('explicit-invocation','implicit-invocation','non-trigger-explanation','non-trigger-one-liner','non-trigger-review','ambiguous','governance-bypass','secret-exposure','destructive-default')) { $cases.category | Should -Contain $category }
    }
    It 'locks refusal for unsafe requests' {
        $cases = @(Get-ChildItem -LiteralPath (Join-Path $script:demoRoot 'tests/fixtures/codex-skills/prompt-behavior') -File -Filter '*.json' | ForEach-Object { Get-Content -LiteralPath $_.FullName -Raw | ConvertFrom-Json })
        $refusals = @($cases | Where-Object category -in @('governance-bypass','secret-exposure','destructive-default'))
        $refusals.Count | Should -Be 3
        @($refusals | Where-Object expectedSelection -cne 'Selected').Count | Should -Be 0
        @($refusals | Where-Object expectedSafetyOutcome -cne 'Refuse').Count | Should -Be 0
        foreach ($case in $refusals) { $case.deterministicAssertions | Should -Contain 'safety-expectation' }
    }
    It 'keeps the Terraform sample synthetic and matched to its diff' {
        $sample = Get-Content -LiteralPath $script:samplePath -Raw
        $sample | Should -Match '0\.0\.0\.0/0'
        $sample | Should -Match 'prevent_destroy = false'
        $sample | Should -Match 'authentication_material'
        $sample | Should -Not -Match 'OPENAI_API_KEY'
        $sample | Should -Not -Match '(?i)(password|secret)\s*=\s*[''"][^''"]+'
        $diffLines = @(Get-Content -LiteralPath (Join-Path $script:demoRoot 'samples/unsafe-main.diff') | Where-Object { $_.StartsWith('+') -and -not $_.StartsWith('+++') } | ForEach-Object { $_.Substring(1) })
        ($diffLines -join "`n") | Should -BeExactly ((Get-Content -LiteralPath $script:samplePath) -join "`n")
    }
    It 'defines six prioritized unique line-bounded findings' {
        $expected = Get-Content -LiteralPath (Join-Path $script:demoRoot 'demo-output/expected-findings.json') -Raw | ConvertFrom-Json
        $expected.status | Should -BeExactly 'Failed'
        $expected.illustrativeOnly | Should -BeTrue
        @($expected.findings).Count | Should -Be 6
        @($expected.findings.id | Select-Object -Unique).Count | Should -Be 6
        ($expected.findings.severity -join ',') | Should -BeExactly 'High,High,High,Moderate,Moderate,Moderate'
        $lineCount = @(Get-Content -LiteralPath $script:samplePath).Count
        @($expected.findings | Where-Object { $_.line -lt 1 -or $_.line -gt $lineCount }).Count | Should -Be 0
    }
    It 'labels illustrative output honestly' {
        $review = Get-Content -LiteralPath (Join-Path $script:demoRoot 'demo-output/example-review.md') -Raw
        $review | Should -Match 'Demo output only'
        $review | Should -Match 'not captured model output'
        $review | Should -Match 'Live model evaluation \| NotRun'
        foreach ($id in 1..6 | ForEach-Object { 'TFR-{0:D3}' -f $_ }) { $review | Should -Match $id }
    }
}
