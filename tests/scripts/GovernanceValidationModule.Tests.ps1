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
        It 'accepts NotRun evidence with policy exit code 3' {
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
            @($results | Where-Object status -eq 'Failed').Count | Should -Be 0
        }

        It 'rejects NotRun evidence without a reason' {
            $doc = [ordered]@{
                schemaVersion = '1.1.0'
                name = 'Analyzer validation'
                category = 'lint'
                status = 'NotRun'
                requiredValidation = $true
                evidenceSource = 'local-execution'
                environment = 'developer-workstation'
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
                failureReason = $null
            }
            $path = Join-Path $script:tempRoot 'missing-notrun-reason.json'
            $doc | ConvertTo-Json -Depth 20 | Set-Content -LiteralPath $path
            $results = Test-GovernanceJsonDocument -Path $path -Kind 'test-evidence'
            @($results | Where-Object { $_.message -match 'meaningful failure reason' }).Count | Should -BeGreaterThan 0
        }

        It 'accepts valid Passed test evidence' {
            $path = "$PSScriptRoot/../fixtures/valid/test-evidence.json"
            $results = Test-GovernanceJsonDocument -Path $path -Kind 'test-evidence'
            @($results | Where-Object status -eq 'Failed').Count | Should -Be 0
        }
    }

    Context 'completion evidence semantics' {
        It 'rejects approval-required Passed evidence without approvals' {
            $doc = Get-Content "$PSScriptRoot/../fixtures/valid/completion-result-1.1.0.json" -Raw | ConvertFrom-Json -AsHashtable
            $doc.approvalRequired = $true
            $doc.executionContext = 'GitHubActions'
            $doc.status = 'Passed'
            $doc.notRunReason = $null
            $doc.commandsNotExecuted = @()
            $doc.githubRunId = '123456789'
            $doc.githubRunAttempt = '1'
            $doc.githubWorkflow = 'Governance CI'
            $doc.githubJob = 'Governance CI'
            $doc.tests[1].status = 'Passed'
            $doc.tests[1].failureReason = $null
            $doc.tests[1].exitCode = 0
            $doc.approvals = @()
            $path = Join-Path $script:tempRoot 'approval-missing.json'
            $doc | ConvertTo-Json -Depth 30 | Set-Content -LiteralPath $path
            $results = Test-GovernanceJsonDocument -Path $path -Kind 'completion-result'
            @($results | Where-Object { $_.message -match 'approval' }).Count | Should -BeGreaterThan 0
        }

        It 'rejects Blocked completion evidence without a blocked reason' {
            $doc = Get-Content "$PSScriptRoot/../fixtures/valid/completion-result-1.1.0.json" -Raw | ConvertFrom-Json -AsHashtable
            $doc.status = 'Blocked'
            $doc.blockedReason = $null
            $path = Join-Path $script:tempRoot 'blocked-missing-reason.json'
            $doc | ConvertTo-Json -Depth 30 | Set-Content -LiteralPath $path
            $results = Test-GovernanceJsonDocument -Path $path -Kind 'completion-result'
            @($results | Where-Object { $_.message -match 'Blocked' -or $_.message -match 'blockedReason' }).Count | Should -BeGreaterThan 0
        }

        It 'rejects unsupported future major schema versions' {
            $doc = Get-Content "$PSScriptRoot/../fixtures/valid/completion-result-1.1.0.json" -Raw | ConvertFrom-Json -AsHashtable
            $doc.schemaVersion = '2.0.0'
            $path = Join-Path $script:tempRoot 'future-major.json'
            $doc | ConvertTo-Json -Depth 30 | Set-Content -LiteralPath $path
            $results = Test-GovernanceJsonDocument -Path $path -Kind 'completion-result'
            @($results | Where-Object status -eq 'Failed').Count | Should -BeGreaterThan 0
        }
    }

    Context 'aggregate governance evidence' {
        It 'writes repository-relative validator script paths' {
            $repoRoot = Resolve-Path "$PSScriptRoot/../.."
            $outputPath = Join-Path $script:tempRoot 'aggregate-governance.json'

            & pwsh -NoProfile -File "$repoRoot/scripts/Invoke-GovernanceValidation.ps1" -Path $repoRoot -Category JsonSchemas -OutputJson $outputPath
            $LASTEXITCODE | Should -Be 0

            $report = Get-Content -LiteralPath $outputPath -Raw | ConvertFrom-Json
            $report.results.Count | Should -BeGreaterThan 0
            $report.results[0].path | Should -Be 'scripts/Test-JsonSchemas.ps1'
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
