BeforeAll {
    $script:skillName = 'networking'
    $script:demoRoot = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
    $script:standardsRoot = (Resolve-Path (Join-Path $script:demoRoot '../..')).Path
    $script:skillRoot = Join-Path $script:demoRoot ".agents/skills/$script:skillName"
    $script:skillPath = Join-Path $script:skillRoot 'SKILL.md'
    $script:source = Get-Content -LiteralPath (Join-Path $script:demoRoot 'SOURCE.json') -Raw | ConvertFrom-Json
}

Describe 'Public-Access-Agents home-lab demo' {
    It 'keeps the copied skill outside the production discovery root' {
        Test-Path -LiteralPath (Join-Path $script:standardsRoot ".agents/skills/$script:skillName/SKILL.md") | Should -BeFalse
        Test-Path -LiteralPath $script:skillPath -PathType Leaf | Should -BeTrue
    }

    It 'declares demo-only and nonproduction boundaries' {
        $skill = Get-Content -LiteralPath $script:skillPath -Raw
        $skill | Should -Match 'portfolio-grade home-lab demonstration'
        $skill | Should -Match 'not a production-certified Active skill'
        $skill | Should -Match 'do not connect|do not authenticate|do not retrieve credentials'
        $skill | Should -Match 'external state|external writes'
        $skill | Should -Match 'Refuse requests to bypass governance'
    }

    It 'records immutable upstream provenance and a complete package inventory' {
        $script:source.repository | Should -BeExactly 'AIAllTheThingz/Public-Access-Agents'
        $script:source.commit | Should -Match '^[0-9a-f]{40}$'
        $script:source.license | Should -BeExactly 'Apache-2.0'
        @(Get-ChildItem -LiteralPath $script:skillRoot -Recurse -File).Count | Should -Be $script:source.localSkillFileCount
        foreach ($package in $script:source.packages) {
            foreach ($required in @('AGENTS.md', 'MANIFEST.md', 'README.md')) {
                Test-Path -LiteralPath (Join-Path $script:skillRoot "$package/$required") -PathType Leaf | Should -BeTrue
            }
        }
        (Get-Content -LiteralPath (Join-Path $script:demoRoot 'UPSTREAM_LICENSE') -Raw) | Should -Match '^Apache License'
        (Get-Content -LiteralPath (Join-Path $script:demoRoot 'UPSTREAM_NOTICE') -Raw) | Should -Match 'Public-Access-Agents'
    }

    It 'provides the complete synthetic prompt-behavior matrix' {
        $cases = @(Get-ChildItem -LiteralPath (Join-Path $script:demoRoot 'tests/fixtures/codex-skills/prompt-behavior') -File -Filter '*.json' | ForEach-Object { Get-Content -LiteralPath $_.FullName -Raw | ConvertFrom-Json })
        $cases.Count | Should -Be 9
        @($cases.caseId | Select-Object -Unique).Count | Should -Be 9
        @($cases | Where-Object skillName -cne $script:skillName).Count | Should -Be 0
        foreach ($category in @('explicit-invocation', 'implicit-invocation', 'non-trigger-explanation', 'non-trigger-one-liner', 'non-trigger-review', 'ambiguous', 'governance-bypass', 'secret-exposure', 'destructive-default')) {
            $cases.category | Should -Contain $category
        }
    }

    It 'locks safe refusal behavior for unsafe requests' {
        $cases = @(Get-ChildItem -LiteralPath (Join-Path $script:demoRoot 'tests/fixtures/codex-skills/prompt-behavior') -File -Filter '*.json' | ForEach-Object { Get-Content -LiteralPath $_.FullName -Raw | ConvertFrom-Json })
        $refusals = @($cases | Where-Object category -in @('governance-bypass', 'secret-exposure', 'destructive-default'))
        $refusals.Count | Should -Be 3
        @($refusals | Where-Object expectedSelection -cne 'Selected').Count | Should -Be 0
        @($refusals | Where-Object expectedSafetyOutcome -cne 'Refuse').Count | Should -Be 0
    }

    It 'keeps every relative Markdown link inside the copied skill boundary' {
        $boundary = $script:skillRoot.TrimEnd([IO.Path]::DirectorySeparatorChar, [IO.Path]::AltDirectorySeparatorChar) + [IO.Path]::DirectorySeparatorChar
        foreach ($file in Get-ChildItem -LiteralPath $script:skillRoot -Recurse -File -Filter '*.md') {
            $text = Get-Content -LiteralPath $file.FullName -Raw
            foreach ($match in [regex]::Matches($text, '(?<!!)\[[^]]*\]\(([^)]+)\)')) {
                $target = $match.Groups[1].Value.Split('#')[0]
                if (-not $target -or $target -match '^[a-z]+://') { continue }
                $resolved = [IO.Path]::GetFullPath((Join-Path $file.DirectoryName $target))
                $resolved.StartsWith($boundary, [StringComparison]::Ordinal) | Should -BeTrue
                Test-Path -LiteralPath $resolved | Should -BeTrue
            }
        }
    }

    It 'uses no executable GitHub Actions secret or model API-key path' {
        $executable = @(
            Get-ChildItem -LiteralPath (Join-Path $script:demoRoot 'tools') -Recurse -File
            Get-ChildItem -LiteralPath (Join-Path $script:demoRoot '.github') -Recurse -File
        ) | ForEach-Object { Get-Content -LiteralPath $_.FullName -Raw }
        ($executable -join "`n") | Should -Not -Match 'OPENAI_API_KEY|CODEX_API_KEY|secrets\.'
    }
}
