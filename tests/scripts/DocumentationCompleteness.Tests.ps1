Describe 'Documentation completeness' {
    Context 'repository documents' {
        It 'passes for the rebuilt repository' {
            & pwsh -NoProfile -File "$PSScriptRoot/../../scripts/Test-DocumentationCompleteness.ps1" -Path "$PSScriptRoot/../.."
            $LASTEXITCODE | Should -Be 0
        }
    }

    Context 'invalid documentation' {
        BeforeAll {
            $script:tempRoot = Join-Path ([System.IO.Path]::GetTempPath()) ("doc-tests-" + [guid]::NewGuid())
            New-Item -ItemType Directory -Path $script:tempRoot -Force | Out-Null
            Copy-Item -LiteralPath "$PSScriptRoot/../../README.md" -Destination (Join-Path $script:tempRoot 'README.md')
            Copy-Item -LiteralPath "$PSScriptRoot/../../SECURITY.md" -Destination (Join-Path $script:tempRoot 'SECURITY.md')
            Copy-Item -LiteralPath "$PSScriptRoot/../../CONTRIBUTING.md" -Destination (Join-Path $script:tempRoot 'CONTRIBUTING.md')
            foreach ($dir in @('governance','agents','docs')) {
                New-Item -ItemType Directory -Path (Join-Path $script:tempRoot $dir) -Force | Out-Null
                Get-ChildItem -LiteralPath "$PSScriptRoot/../../$dir" -Filter '*.md' -File | ForEach-Object {
                    Copy-Item -LiteralPath $_.FullName -Destination (Join-Path $script:tempRoot $dir)
                }
            }
            Set-Content -LiteralPath (Join-Path $script:tempRoot 'docs/MAINTAINER_GUIDE.md') -Value "# Maintainer Guide`n`nToo short."
        }

        AfterAll {
            if ($script:tempRoot -and (Test-Path -LiteralPath $script:tempRoot)) {
                Remove-Item -LiteralPath $script:tempRoot -Recurse -Force
            }
        }

        It 'fails shallow authoritative documents' {
            & pwsh -NoProfile -File "$PSScriptRoot/../../scripts/Test-DocumentationCompleteness.ps1" -Path $script:tempRoot
            $LASTEXITCODE | Should -Not -Be 0
        }
    }

    Context 'downstream canary guide enforcement' {
        BeforeAll {
            $script:canaryTempRoot = Join-Path ([System.IO.Path]::GetTempPath()) ("canary-doc-tests-" + [guid]::NewGuid())
            New-Item -ItemType Directory -Path $script:canaryTempRoot -Force | Out-Null
            foreach ($file in @('README.md','SECURITY.md','CONTRIBUTING.md')) {
                Copy-Item -LiteralPath "$PSScriptRoot/../../$file" -Destination (Join-Path $script:canaryTempRoot $file)
            }
            foreach ($dir in @('governance','agents','docs')) {
                New-Item -ItemType Directory -Path (Join-Path $script:canaryTempRoot $dir) -Force | Out-Null
                Get-ChildItem -LiteralPath "$PSScriptRoot/../../$dir" -Filter '*.md' -File | ForEach-Object {
                    Copy-Item -LiteralPath $_.FullName -Destination (Join-Path $script:canaryTempRoot $dir)
                }
            }
            $script:canaryGuideSource = "$PSScriptRoot/../../docs/DOWNSTREAM_CANARY.md"
            $script:canaryGuideFixture = Join-Path $script:canaryTempRoot 'docs/DOWNSTREAM_CANARY.md'
            $script:documentationValidator = "$PSScriptRoot/../../scripts/Test-DocumentationCompleteness.ps1"
        }

        BeforeEach {
            Copy-Item -LiteralPath $script:canaryGuideSource -Destination $script:canaryGuideFixture -Force
        }

        AfterAll {
            if ($script:canaryTempRoot -and (Test-Path -LiteralPath $script:canaryTempRoot)) {
                Remove-Item -LiteralPath $script:canaryTempRoot -Recurse -Force
            }
        }

        It 'accepts the current authoritative canary guide' {
            & pwsh -NoProfile -File $script:documentationValidator -Path "$PSScriptRoot/../.."
            $LASTEXITCODE | Should -Be 0
        }

        It 'fails when the authoritative canary guide is missing' {
            Remove-Item -LiteralPath $script:canaryGuideFixture
            $output = @(& pwsh -NoProfile -File $script:documentationValidator -Path $script:canaryTempRoot 2>&1)
            $LASTEXITCODE | Should -Not -Be 0
            $output -join "`n" | Should -Match 'docs/DOWNSTREAM_CANARY\.md.*missing'
        }

        It 'evaluates the authoritative canary guide word count' {
            Set-Content -LiteralPath $script:canaryGuideFixture -Value "# Canary`n`n## Validation`nMUST validate.`n`n## Evidence`nEvidence.`n`n## Exception`nException.`n`n## Related`nRelated." -Encoding utf8
            $output = @(& pwsh -NoProfile -File $script:documentationValidator -Path $script:canaryTempRoot 2>&1)
            $LASTEXITCODE | Should -Not -Be 0
            $output -join "`n" | Should -Match 'DOWNSTREAM_CANARY\.md.*too shallow'
        }

        It 'evaluates required concepts in the authoritative canary guide' {
            $text = (Get-Content -LiteralPath $script:canaryGuideFixture -Raw) -replace '(?i)exception', 'waiver'
            Set-Content -LiteralPath $script:canaryGuideFixture -Value $text -Encoding utf8
            $output = @(& pwsh -NoProfile -File $script:documentationValidator -Path $script:canaryTempRoot 2>&1)
            $LASTEXITCODE | Should -Not -Be 0
            $output -join "`n" | Should -Match "DOWNSTREAM_CANARY\.md.*missing required concept 'Exception'"
        }

        It 'evaluates heading count in the authoritative canary guide' {
            $words = ('governance ' * 320)
            Set-Content -LiteralPath $script:canaryGuideFixture -Value "# Canary`n`nMUST Validation Evidence Exception Related $words`n`n## Operation`n$words`n`n## Verification`n$words`n`n## Recovery`n$words" -Encoding utf8
            $output = @(& pwsh -NoProfile -File $script:documentationValidator -Path $script:canaryTempRoot 2>&1)
            $LASTEXITCODE | Should -Not -Be 0
            $output -join "`n" | Should -Match 'DOWNSTREAM_CANARY\.md.*too few meaningful sections'
        }

        It 'detects an empty heading in the authoritative canary guide' {
            Add-Content -LiteralPath $script:canaryGuideFixture -Value "`n## Empty Canary Heading`n"
            $output = @(& pwsh -NoProfile -File $script:documentationValidator -Path $script:canaryTempRoot 2>&1)
            $LASTEXITCODE | Should -Not -Be 0
            $output -join "`n" | Should -Match 'DOWNSTREAM_CANARY\.md.*empty heading'
        }
    }

    Context 'backlog reference enforcement' {
        BeforeAll {
            $script:backlogTempRoot = Join-Path ([System.IO.Path]::GetTempPath()) ("backlog-doc-tests-" + [guid]::NewGuid())
            New-Item -ItemType Directory -Path $script:backlogTempRoot -Force | Out-Null
            foreach ($file in @('README.md','SECURITY.md','CONTRIBUTING.md')) {
                Copy-Item -LiteralPath "$PSScriptRoot/../../$file" -Destination (Join-Path $script:backlogTempRoot $file)
            }
            foreach ($dir in @('governance','agents','docs')) {
                New-Item -ItemType Directory -Path (Join-Path $script:backlogTempRoot $dir) -Force | Out-Null
                Get-ChildItem -LiteralPath "$PSScriptRoot/../../$dir" -Filter '*.md' -File | ForEach-Object {
                    Copy-Item -LiteralPath $_.FullName -Destination (Join-Path $script:backlogTempRoot $dir)
                }
            }
            $script:skillPlanSource = "$PSScriptRoot/../../docs/CODEX_SKILLS.md"
            $script:skillPlanFixture = Join-Path $script:backlogTempRoot 'docs/CODEX_SKILLS.md'
            $script:backlogGuideFixture = Join-Path $script:backlogTempRoot 'docs/BACKLOG_MANAGEMENT.md'
            $script:backlogDocumentationValidator = "$PSScriptRoot/../../scripts/Test-DocumentationCompleteness.ps1"
        }

        BeforeEach {
            Copy-Item -LiteralPath $script:skillPlanSource -Destination $script:skillPlanFixture -Force
            Copy-Item -LiteralPath "$PSScriptRoot/../../docs/BACKLOG_MANAGEMENT.md" -Destination $script:backlogGuideFixture -Force
        }

        AfterAll {
            if ($script:backlogTempRoot -and (Test-Path -LiteralPath $script:backlogTempRoot)) {
                Remove-Item -LiteralPath $script:backlogTempRoot -Recurse -Force
            }
        }

        It 'accepts the current issue-linked demo resolution inventory' {
            & pwsh -NoProfile -File $script:backlogDocumentationValidator -Path "$PSScriptRoot/../.."
            $LASTEXITCODE | Should -Be 0
        }

        It 'fails when a demo-resolved skill loses its authoritative issue link' {
            $text = (Get-Content -LiteralPath $script:skillPlanFixture -Raw) -replace '\[#43\]\(https://github\.com/AIAllTheThingz/Engineering-Standards/issues/43\)', 'Issue pending'
            Set-Content -LiteralPath $script:skillPlanFixture -Value $text -Encoding utf8
            $output = @(& pwsh -NoProfile -File $script:backlogDocumentationValidator -Path $script:backlogTempRoot 2>&1)
            $LASTEXITCODE | Should -Not -Be 0
            $output -join "`n" | Should -Match "powershell-review.*authoritative GitHub issue-linked"
        }

        It 'fails when a demo-resolved skill is also represented as prose-only work' {
            Add-Content -LiteralPath $script:skillPlanFixture -Value "`n1. ``powershell-review```n"
            $output = @(& pwsh -NoProfile -File $script:backlogDocumentationValidator -Path $script:backlogTempRoot 2>&1)
            $LASTEXITCODE | Should -Not -Be 0
            $output -join "`n" | Should -Match "powershell-review.*prose-only"
        }

        It 'fails when the authoritative backlog guide is missing' {
            Remove-Item -LiteralPath $script:backlogGuideFixture
            $output = @(& pwsh -NoProfile -File $script:backlogDocumentationValidator -Path $script:backlogTempRoot 2>&1)
            $LASTEXITCODE | Should -Not -Be 0
            $output -join "`n" | Should -Match 'BACKLOG_MANAGEMENT\.md.*missing'
        }
    }
}
