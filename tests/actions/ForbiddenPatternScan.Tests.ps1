Describe 'Forbidden pattern scan' {
    BeforeAll {
        $script:tempRoot = Join-Path ([System.IO.Path]::GetTempPath()) ("forbidden-scan-tests-" + [guid]::NewGuid())
        New-Item -ItemType Directory -Path $script:tempRoot -Force | Out-Null
    }

    AfterAll {
        if ($script:tempRoot -and (Test-Path -LiteralPath $script:tempRoot)) {
            Remove-Item -LiteralPath $script:tempRoot -Recurse -Force
        }
    }

    Context 'advisory mode' {
        It 'runs without failing the repository in advisory mode' {
            & pwsh -NoProfile -File "$PSScriptRoot/../../actions/forbidden-pattern-scan/Invoke-ForbiddenPatternScan.ps1" -Path "$PSScriptRoot/../.." -Advisory
            $LASTEXITCODE | Should -Be 0
        }
    }

    Context 'blocking findings' {
        It 'fails on an embedded credential assignment' {
            $repo = Join-Path $script:tempRoot 'blocking'
            New-Item -ItemType Directory -Path $repo -Force | Out-Null
            Set-Content -LiteralPath (Join-Path $repo 'config.txt') -Value (('pass' + 'word') + ' = super-secret-value')

            & pwsh -NoProfile -File "$PSScriptRoot/../../actions/forbidden-pattern-scan/Invoke-ForbiddenPatternScan.ps1" -Path $repo
            $LASTEXITCODE | Should -Not -Be 0
        }

        It 'honors an unexpired allowlist entry' {
            $repo = Join-Path $script:tempRoot 'allowlisted'
            New-Item -ItemType Directory -Path $repo -Force | Out-Null
            Set-Content -LiteralPath (Join-Path $repo 'config.txt') -Value (('pass' + 'word') + ' = super-secret-value')
            @{
                entries = @(
                    @{
                        patternId = 'embedded-credential-assignment'
                        path = 'config.txt'
                        owner = 'security@example.com'
                        reason = 'Synthetic scanner fixture, not a real credential.'
                        expiresOn = '2999-01-01'
                    }
                )
            } | ConvertTo-Json -Depth 10 | Set-Content -LiteralPath (Join-Path $repo 'allowlist.json')

            & pwsh -NoProfile -File "$PSScriptRoot/../../actions/forbidden-pattern-scan/Invoke-ForbiddenPatternScan.ps1" -Path $repo -AllowlistFile 'allowlist.json'
            $LASTEXITCODE | Should -Be 0
        }

        It 'does not honor expired allowlist entries' {
            $repo = Join-Path $script:tempRoot 'expired'
            New-Item -ItemType Directory -Path $repo -Force | Out-Null
            Set-Content -LiteralPath (Join-Path $repo 'config.txt') -Value (('pass' + 'word') + ' = super-secret-value')
            @{
                entries = @(
                    @{
                        patternId = 'embedded-credential-assignment'
                        path = 'config.txt'
                        owner = 'security@example.com'
                        reason = 'Expired synthetic scanner fixture.'
                        expiresOn = '2000-01-01'
                    }
                )
            } | ConvertTo-Json -Depth 10 | Set-Content -LiteralPath (Join-Path $repo 'allowlist.json')

            & pwsh -NoProfile -File "$PSScriptRoot/../../actions/forbidden-pattern-scan/Invoke-ForbiddenPatternScan.ps1" -Path $repo -AllowlistFile 'allowlist.json'
            $LASTEXITCODE | Should -Not -Be 0
        }
    }
}
