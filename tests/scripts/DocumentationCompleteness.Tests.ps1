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
}
