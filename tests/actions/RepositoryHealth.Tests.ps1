Describe 'Repository health' {
    Context 'rebuilt repository' {
        It 'passes repository health validation' {
            & pwsh -NoProfile -File "$PSScriptRoot/../../actions/repository-health/Invoke-RepositoryHealth.ps1" -Path "$PSScriptRoot/../.."
            $LASTEXITCODE | Should -Be 0
        }

        It 'does not track generated build output directories' {
            $root = Resolve-Path "$PSScriptRoot/../.."
            $tracked = @(& git -C $root ls-files | Where-Object {
                $_ -match '(^|/)(bin|obj|dist)(/|$)' -or $_ -match '^(coverage|TestResults)(/|$)'
            })
            $tracked.Count | Should -Be 0
        }
    }

    Context 'invalid repository' {
        BeforeAll {
            $script:tempRoot = Join-Path ([System.IO.Path]::GetTempPath()) ("repo-health-tests-" + [guid]::NewGuid())
            New-Item -ItemType Directory -Path $script:tempRoot -Force | Out-Null
            Set-Content -LiteralPath (Join-Path $script:tempRoot 'README.md') -Value '# Incomplete'
        }

        AfterAll {
            if ($script:tempRoot -and (Test-Path -LiteralPath $script:tempRoot)) {
                Remove-Item -LiteralPath $script:tempRoot -Recurse -Force
            }
        }

        It 'fails when required governance files are absent' {
            & pwsh -NoProfile -File "$PSScriptRoot/../../actions/repository-health/Invoke-RepositoryHealth.ps1" -Path $script:tempRoot
            $LASTEXITCODE | Should -Not -Be 0
        }
    }
}
