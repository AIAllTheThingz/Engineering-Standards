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
}
