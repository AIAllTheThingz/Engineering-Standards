BeforeAll {
    Import-Module "$PSScriptRoot/../../scripts/GovernanceValidation.psm1" -Force
    $script:tempRoot = Join-Path ([System.IO.Path]::GetTempPath()) ("governance-module-tests-" + [guid]::NewGuid())
    New-Item -ItemType Directory -Path $script:tempRoot -Force | Out-Null
}

AfterAll {
    if ($script:tempRoot -and (Test-Path -LiteralPath $script:tempRoot)) {
        Remove-Item -LiteralPath $script:tempRoot -Recurse -Force
    }
}

Describe 'GovernanceValidation module' {
    Context 'safe path resolution' {
        It 'resolves a child path inside the root' {
            $file = Join-Path $script:tempRoot 'inside.txt'
            Set-Content -LiteralPath $file -Value 'ok'
            Resolve-SafePath -Root $script:tempRoot -ChildPath 'inside.txt' | Should -Be $file
        }

        It 'rejects traversal outside the root' {
            { Resolve-SafePath -Root $script:tempRoot -ChildPath '../outside.txt' } | Should -Throw
        }
    }

    Context 'test evidence semantics' {
        It 'rejects NotRun evidence with an exit code' {
            $doc = [ordered]@{
                schemaVersion = '1.0.0'
                name = 'Analyzer validation'
                category = 'lint'
                status = 'NotRun'
                command = 'Invoke-ScriptAnalyzer -Path .'
                workingDirectory = '.'
                startedAtUtc = '2026-06-19T00:00:00Z'
                completedAtUtc = '2026-06-19T00:00:00Z'
                durationSeconds = 0
                runtime = 'PowerShell 7'
                toolVersion = 'local'
                exitCode = 3
                summary = 'Analyzer did not run because the module is unavailable.'
                warnings = @()
                failureReason = 'PSScriptAnalyzer module is unavailable.'
            }
            $path = Join-Path $script:tempRoot 'bad-test-evidence.json'
            $doc | ConvertTo-Json -Depth 20 | Set-Content -LiteralPath $path
            $results = Test-GovernanceJsonDocument -Path $path -Kind 'test-evidence'
            @($results | Where-Object status -eq 'Failed').Count | Should -BeGreaterThan 0
        }

        It 'accepts valid Passed test evidence' {
            $path = "$PSScriptRoot/../fixtures/valid/test-evidence.json"
            $results = Test-GovernanceJsonDocument -Path $path -Kind 'test-evidence'
            @($results | Where-Object status -eq 'Failed').Count | Should -Be 0
        }
    }

    Context 'manifest semantics' {
        It 'requires production approval for High risk manifests' {
            $manifest = Get-Content "$PSScriptRoot/../fixtures/valid/project-manifest.json" -Raw | ConvertFrom-Json -AsHashtable
            $manifest.productionApprovalRequired = $false
            $path = Join-Path $script:tempRoot 'bad-manifest.json'
            $manifest | ConvertTo-Json -Depth 20 | Set-Content -LiteralPath $path
            $results = Test-GovernanceJsonDocument -Path $path -Kind 'project-manifest'
            @($results | Where-Object { $_.message -match 'production approval' }).Count | Should -Be 1
        }
    }
}
