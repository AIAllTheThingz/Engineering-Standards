Describe 'Agent standards validation' {
    BeforeAll {
        $script:repoRoot = (Resolve-Path -LiteralPath "$PSScriptRoot/../..").Path

        function New-AgentStandardsFixture {
            $tempRoot = Join-Path ([System.IO.Path]::GetTempPath()) ("agent-standards-" + [guid]::NewGuid())
            New-Item -ItemType Directory -Path $tempRoot -Force | Out-Null
            New-Item -ItemType Directory -Path (Join-Path $tempRoot 'agents') -Force | Out-Null
            New-Item -ItemType Directory -Path (Join-Path $tempRoot 'governance') -Force | Out-Null
            New-Item -ItemType Directory -Path (Join-Path $tempRoot 'docs') -Force | Out-Null

            Copy-Item -LiteralPath (Join-Path $script:repoRoot 'AGENTS.md') -Destination (Join-Path $tempRoot 'AGENTS.md')
            Copy-Item -LiteralPath (Join-Path $script:repoRoot 'CHANGELOG.md') -Destination (Join-Path $tempRoot 'CHANGELOG.md')
            Copy-Item -Path (Join-Path $script:repoRoot 'agents/AGENTS_*.md') -Destination (Join-Path $tempRoot 'agents')
            Copy-Item -Path (Join-Path $script:repoRoot 'governance/*.md') -Destination (Join-Path $tempRoot 'governance')
            foreach ($doc in @('GOVERNANCE_ARCHITECTURE.md','MAINTAINER_GUIDE.md','ADOPTION_GUIDE.md','RELEASE_PROCESS.md')) {
                Copy-Item -LiteralPath (Join-Path $script:repoRoot "docs/$doc") -Destination (Join-Path $tempRoot 'docs')
            }
            $tempRoot
        }

        function Invoke-AgentStandardsValidator {
            param([string]$Path)
            & pwsh -NoProfile -File (Join-Path $script:repoRoot 'scripts/Test-AgentStandards.ps1') -Path $Path | Out-Null
            $LASTEXITCODE
        }
    }

    Context 'valid documents' {
        It 'passes for the repository documents' {
            Invoke-AgentStandardsValidator -Path $script:repoRoot | Should -Be 0
        }
    }

    Context 'invalid documents' {
        AfterEach {
            if ($script:tempRoot -and (Test-Path -LiteralPath $script:tempRoot)) {
                Remove-Item -LiteralPath $script:tempRoot -Recurse -Force
                $script:tempRoot = $null
            }
        }

        It 'fails self-inheritance in the base standard' {
            $script:tempRoot = New-AgentStandardsFixture
            Add-Content -LiteralPath (Join-Path $script:tempRoot 'agents/AGENTS_Base.md') -Value "`nThis file inherits AGENTS_Base.md."
            Invoke-AgentStandardsValidator -Path $script:tempRoot | Should -Not -Be 0
        }

        It 'fails a missing hierarchy' {
            $script:tempRoot = New-AgentStandardsFixture
            $path = Join-Path $script:tempRoot 'agents/AGENTS_Base.md'
            $text = (Get-Content -LiteralPath $path -Raw) -replace '(?i)Organization governance documents', 'Organization policy files'
            Set-Content -LiteralPath $path -Value $text -Encoding utf8
            Invoke-AgentStandardsValidator -Path $script:tempRoot | Should -Not -Be 0
        }

        It 'fails a missing work phase' {
            $script:tempRoot = New-AgentStandardsFixture
            $path = Join-Path $script:tempRoot 'agents/AGENTS_Base.md'
            $text = (Get-Content -LiteralPath $path -Raw).Replace('Phase 5 - Validation', 'Phase 5 - Checks')
            Set-Content -LiteralPath $path -Value $text -Encoding utf8
            Invoke-AgentStandardsValidator -Path $script:tempRoot | Should -Not -Be 0
        }

        It 'fails the wrong default branch' {
            $script:tempRoot = New-AgentStandardsFixture
            $path = Join-Path $script:tempRoot 'AGENTS.md'
            $text = (Get-Content -LiteralPath $path -Raw).Replace('`master`', '`main`')
            Set-Content -LiteralPath $path -Value $text -Encoding utf8
            Invoke-AgentStandardsValidator -Path $script:tempRoot | Should -Not -Be 0
        }

        It 'fails a missing base reference' {
            $script:tempRoot = New-AgentStandardsFixture
            $path = Join-Path $script:tempRoot 'AGENTS.md'
            $text = (Get-Content -LiteralPath $path -Raw).Replace('[agents/AGENTS_Base.md](agents/AGENTS_Base.md)', 'the central base standard')
            Set-Content -LiteralPath $path -Value $text -Encoding utf8
            Invoke-AgentStandardsValidator -Path $script:tempRoot | Should -Not -Be 0
        }

        It 'fails a missing completion status' {
            $script:tempRoot = New-AgentStandardsFixture
            $path = Join-Path $script:tempRoot 'agents/AGENTS_Base.md'
            $text = (Get-Content -LiteralPath $path -Raw).Replace('`Blocked`', '`Waiting`')
            Set-Content -LiteralPath $path -Value $text -Encoding utf8
            Invoke-AgentStandardsValidator -Path $script:tempRoot | Should -Not -Be 0
        }

        It 'fails placeholder text' {
            $script:tempRoot = New-AgentStandardsFixture
            Add-Content -LiteralPath (Join-Path $script:tempRoot 'AGENTS.md') -Value "`nTODO: fill this in."
            Invoke-AgentStandardsValidator -Path $script:tempRoot | Should -Not -Be 0
        }

        It 'fails a missing validation command' {
            $script:tempRoot = New-AgentStandardsFixture
            $path = Join-Path $script:tempRoot 'AGENTS.md'
            $text = (Get-Content -LiteralPath $path -Raw).Replace('git diff --check', 'git diff --stat')
            Set-Content -LiteralPath $path -Value $text -Encoding utf8
            Invoke-AgentStandardsValidator -Path $script:tempRoot | Should -Not -Be 0
        }

        It 'fails when the agent-standard validation command is missing' {
            $script:tempRoot = New-AgentStandardsFixture
            $path = Join-Path $script:tempRoot 'AGENTS.md'
            $text = (Get-Content -LiteralPath $path -Raw).Replace(
                'pwsh -NoProfile -File scripts/Test-AgentStandards.ps1 -Path .',
                'pwsh -NoProfile -File scripts/Test-AgentStandards.ps1 -Path agents'
            )
            Set-Content -LiteralPath $path -Value $text -Encoding utf8
            Invoke-AgentStandardsValidator -Path $script:tempRoot | Should -Not -Be 0
        }

        It 'fails an unsafe PowerShell path-boundary example' {
            $script:tempRoot = New-AgentStandardsFixture
            $path = Join-Path $script:tempRoot 'agents/AGENTS_PowerShell.md'
            $text = (Get-Content -LiteralPath $path -Raw).
                Replace('$candidate.StartsWith($rootBoundary, [System.StringComparison]::OrdinalIgnoreCase)', '$candidate.StartsWith($resolvedRoot, [System.StringComparison]::OrdinalIgnoreCase)').
                Replace('Prefix matching without a directory boundary is unsafe', 'Prefix matching is usually fine')
            Set-Content -LiteralPath $path -Value $text -Encoding utf8
            Invoke-AgentStandardsValidator -Path $script:tempRoot | Should -Not -Be 0
        }

        It 'fails missing PowerShell README parameter documentation requirements' {
            $script:tempRoot = New-AgentStandardsFixture
            $path = Join-Path $script:tempRoot 'agents/AGENTS_PowerShell.md'
            $text = (Get-Content -LiteralPath $path -Raw).Replace(
                'README documentation MUST include every public entry-point parameter and switch',
                'README documentation SHOULD describe common parameters'
            )
            Set-Content -LiteralPath $path -Value $text -Encoding utf8
            Invoke-AgentStandardsValidator -Path $script:tempRoot | Should -Not -Be 0
        }

        It 'fails a PowerShell signing example that silently selects the first certificate' {
            $script:tempRoot = New-AgentStandardsFixture
            $path = Join-Path $script:tempRoot 'agents/AGENTS_PowerShell.md'
            $text = (Get-Content -LiteralPath $path -Raw).
                Replace('$certificates.Count -gt 1', '$certificates.Count -lt 0').
                Replace('$certificate = $certificates[0]', '$certificate = $certificates | Select-Object -First 1')
            Set-Content -LiteralPath $path -Value $text -Encoding utf8
            Invoke-AgentStandardsValidator -Path $script:tempRoot | Should -Not -Be 0
        }
    }
}
