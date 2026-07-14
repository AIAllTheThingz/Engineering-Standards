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
    Context 'workflow output sanitization' {
        It 'neutralizes every embedded workflow command physical line' {
            $inputText = "ordinary text`r`n::warning::warn`n  ::error::error`r::add-mask::secret`n::stop-commands::token`n::set-output name=x::value"
            $lines = @(ConvertTo-SanitizedWorkflowOutputLine -InputObject $inputText -WorkspaceRoot 'C:\workspace' -TemporaryRoot 'C:\temp')
            $lines.Count | Should -Be 6
            $lines[0] | Should -Be 'ordinary text'
            foreach ($line in $lines[1..5]) {
                $line | Should -Match '^\[validator-output\] '
                $line | Should -Not -Match '^\s*::'
            }
            ($lines -join "`n") | Should -Match '\[validator-output\] ::warning::warn'
            ($lines -join "`n") | Should -Match '\[validator-output\] ::add-mask::secret'
            ($lines -join "`n") | Should -Match '\[validator-output\] ::stop-commands::token'
            ($lines -join "`n") | Should -Match '\[validator-output\] ::set-output name=x::value'
        }

        It 'removes unsafe controls before redacting each physical line' {
            $lines = @(ConvertTo-SanitizedWorkflowOutputLine -InputObject "C:\work$([char]7)space\one`nC:\temp\two$([char]7)" -WorkspaceRoot 'C:\workspace' -TemporaryRoot 'C:\temp')
            $lines | Should -Be @('[workspace]\one','[temp]\two')
        }

        It 'sanitizes and bounds failure messages for downloadable evidence' {
            $pat = 'ghp_' + ('a' * 30)
            $credentialKey = 'to' + 'ken'
            $inputText = "C:\workspace\repo`r`n  ::error::bad$([char]7)`nAuthorization: Bearer bearer-value`n$credentialKey=token-value-12345`nhttps://user:password@example.invalid/path`n$pat"
            $message = ConvertTo-SanitizedWorkflowFailureMessage -InputObject $inputText -WorkspaceRoot 'C:\workspace' -TemporaryRoot 'C:\temp' -MaximumLength 512
            $message | Should -Match '\[workspace\]\\repo'
            $message | Should -Match '\[validator-output\]\s+::error::bad'
            $message | Should -Match 'Authorization: \[redacted\]'
            $message | Should -Match ($credentialKey + '=\[redacted\]')
            $message | Should -Match 'https://\[redacted\]@example.invalid/path'
            $message | Should -Not -Match 'bearer-value|token-value|password|ghp_'
            $message | Should -Not -Match "`r|`n|$([char]7)"
            $message.Length | Should -BeLessOrEqual 512
        }

        It 'uses a generic reason only when no safe specific message exists and never clobbers evidence' {
            $evidence = Join-Path $script:tempRoot 'bootstrap-evidence'
            New-Item -ItemType Directory -Path $evidence -Force | Out-Null
            Write-GovernanceBootstrapFailureReport -EvidenceRoot $evidence -FailureMessage 'Governance version mismatch: expected 1.1.0.' -CallerRepository 'ExampleOrg/repo' -CallerCommitSha ('1' * 40) -StandardsWorkflowSha ('2' * 40) -GovernanceVersion '1.1.0' | Out-Null
            Write-GovernanceBootstrapFailureReport -EvidenceRoot $evidence -FailureMessage '' -GenericFallbackMessage 'generic fallback' -CallerRepository 'ExampleOrg/repo' -CallerCommitSha ('1' * 40) -StandardsWorkflowSha ('2' * 40) -GovernanceVersion '1.1.0' | Out-Null
            $report = Get-Content -LiteralPath (Join-Path $evidence 'governance-validation.json') -Raw | ConvertFrom-Json
            $report.results[0].name | Should -Be 'BootstrapValidation'
            $report.results[0].failureReason | Should -Be 'Governance version mismatch: expected 1.1.0.'
            $report.failed | Should -Be 1
        }
    }

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
        It 'forwards the trusted repository owner type to repository-health behavior' {
            $repoRoot = Resolve-Path "$PSScriptRoot/../.."
            $callerRoot = Join-Path $script:tempRoot 'aggregate-owner-type-caller'
            New-Item -ItemType Directory -Path $callerRoot -Force | Out-Null
            Copy-Item -LiteralPath "$repoRoot/project-manifest.json" -Destination $callerRoot
            $config = Get-Content -LiteralPath "$repoRoot/governance.config.json" -Raw | ConvertFrom-Json -AsHashtable
            $config.ownership.requiredCodeownerPaths = @('/AGENTS.md')
            $config.validationCategories = @('RepositoryHealth')
            $config | ConvertTo-Json -Depth 20 | Set-Content -LiteralPath (Join-Path $callerRoot 'governance.config.json') -Encoding utf8
            Set-Content -LiteralPath (Join-Path $callerRoot 'AGENTS.md') -Value '# Synthetic instructions' -Encoding utf8
            Set-Content -LiteralPath (Join-Path $callerRoot 'CODEOWNERS') -Value "* @root-owner`n/AGENTS.md @ExampleOrg/maintainers" -Encoding utf8

            $userEvidence = Join-Path $script:tempRoot 'aggregate-owner-type-user-evidence'
            $userOutput = @(& pwsh -NoProfile -File "$repoRoot/scripts/Invoke-GovernanceValidation.ps1" -Path $callerRoot -Category RepositoryHealth -RepositoryOwnerType User -EvidenceRoot $userEvidence 2>&1)
            $LASTEXITCODE | Should -Not -Be 0
            $userOutput -join "`n" | Should -Match "incompatible with a User-owned repository"

            $organizationEvidence = Join-Path $script:tempRoot 'aggregate-owner-type-organization-evidence'
            $organizationOutput = @(& pwsh -NoProfile -File "$repoRoot/scripts/Invoke-GovernanceValidation.ps1" -Path $callerRoot -Category RepositoryHealth -RepositoryOwnerType Organization -EvidenceRoot $organizationEvidence 2>&1)
            $organizationOutput -join "`n" | Should -Not -Match "incompatible with a User-owned repository"
        }

        It 'rejects invalid and case-variant repository owner types at the aggregate entry point' {
            $repoRoot = Resolve-Path "$PSScriptRoot/../.."
            foreach ($ownerType in @('user', 'Enterprise', '')) {
                $output = @(& pwsh -NoProfile -File "$repoRoot/scripts/Invoke-GovernanceValidation.ps1" -Path $repoRoot -Category JsonSchemas -RepositoryOwnerType $ownerType 2>&1)
                $LASTEXITCODE | Should -Not -Be 0
                $output -join "`n" | Should -Match 'RepositoryOwnerType must be exactly Unknown, User, or Organization'
            }
        }

        It 'writes repository-relative validator script paths' {
            $repoRoot = Resolve-Path "$PSScriptRoot/../.."
            $outputPath = Join-Path $script:tempRoot 'aggregate-governance.json'

            $priorGitHubActions = $env:GITHUB_ACTIONS
            try {
                $env:GITHUB_ACTIONS = $null
                & pwsh -NoProfile -File "$repoRoot/scripts/Invoke-GovernanceValidation.ps1" -Path $repoRoot -Category JsonSchemas -OutputJson $outputPath
            }
            finally {
                $env:GITHUB_ACTIONS = $priorGitHubActions
            }
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

        It 'rejects placeholder email local parts case-insensitively' {
            foreach ($fixture in Get-ChildItem "$PSScriptRoot/../fixtures/invalid" -Filter 'project-manifest*placeholder-email*.json') {
                $results = Test-GovernanceJsonDocument -Path $fixture.FullName -Kind 'project-manifest'
                @($results | Where-Object { $_.status -eq 'Failed' -and $_.message -match 'placeholder' }).Count | Should -Be 1 -Because $fixture.Name
            }
        }

        It 'accepts similar legitimate email local parts' {
            $results = Test-GovernanceJsonDocument -Path "$PSScriptRoot/../fixtures/valid/project-manifest-similar-email-owner.json" -Kind 'project-manifest'
            @($results | Where-Object status -eq 'Failed').Count | Should -Be 0
        }

        It 'accepts a one-character GitHub user and rejects a bare at sign' {
            $validResults = Test-GovernanceJsonDocument -Path "$PSScriptRoot/../fixtures/valid/project-manifest-one-character-user-owner.json" -Kind 'project-manifest'
            @($validResults | Where-Object status -eq 'Failed').Count | Should -Be 0

            $invalidResults = Test-GovernanceJsonDocument -Path "$PSScriptRoot/../fixtures/invalid/project-manifest-bare-user-owner.json" -Kind 'project-manifest'
            @($invalidResults | Where-Object { $_.status -eq 'Failed' -and $_.message -match 'GitHub user handle' }).Count | Should -Be 1
        }
    }

    Context 'governance configuration ownership semantics' {
        It 'accepts an omitted ownership configuration for backward compatibility' {
            $results = Test-GovernanceJsonDocument -Path "$PSScriptRoot/../fixtures/valid/governance-config.json" -Kind 'governance-config'
            @($results | Where-Object status -eq 'Failed').Count | Should -Be 0
        }

        It 'accepts PowerShellParser as a declared validation category' {
            $document = Get-Content "$PSScriptRoot/../fixtures/valid/governance-config-1.2.0.json" -Raw | ConvertFrom-Json -AsHashtable
            $document.validationCategories = @('Contract', 'PowerShellParser')
            $path = Join-Path $script:tempRoot 'powershell-parser-governance-config.json'
            $document | ConvertTo-Json -Depth 20 | Set-Content -LiteralPath $path
            $results = Test-GovernanceJsonDocument -Path $path -Kind 'governance-config'
            @($results | Where-Object status -eq 'Failed').Count | Should -Be 0
        }

        It 'accepts unique rooted literal required CODEOWNERS paths' {
            $results = Test-GovernanceJsonDocument -Path "$PSScriptRoot/../fixtures/valid/governance-config-required-codeowner-paths.json" -Kind 'governance-config'
            @($results | Where-Object status -eq 'Failed').Count | Should -Be 0
        }

        It 'treats case-distinct required CODEOWNERS paths as unique' {
            $document = Get-Content "$PSScriptRoot/../fixtures/valid/governance-config-required-codeowner-paths.json" -Raw | ConvertFrom-Json -AsHashtable
            $document.ownership.requiredCodeownerPaths = @('/src/', '/SRC/')
            $path = Join-Path $script:tempRoot 'case-distinct-governance-config.json'
            $document | ConvertTo-Json -Depth 20 | Set-Content -LiteralPath $path
            $results = Test-GovernanceJsonDocument -Path $path -Kind 'governance-config'
            @($results | Where-Object status -eq 'Failed').Count | Should -Be 0
        }

        It 'rejects unsafe, duplicate, empty, wildcard, and placeholder required CODEOWNERS paths' {
            foreach ($fixture in Get-ChildItem "$PSScriptRoot/../fixtures/invalid" -Filter 'governance-config-codeowner-*.json') {
                $results = Test-GovernanceJsonDocument -Path $fixture.FullName -Kind 'governance-config'
                @($results | Where-Object status -eq 'Failed').Count | Should -BeGreaterThan 0 -Because $fixture.Name
            }
        }
    }
}
