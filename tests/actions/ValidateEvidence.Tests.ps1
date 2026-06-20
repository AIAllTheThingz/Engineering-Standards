function New-TempEvidence {
    param(
        [string]$ArtifactPath = 'evidence/report.json',
        [string]$ArtifactContent = '{}',
        [string]$Status = 'Passed',
        [string]$TestStatus = 'Passed'
    )
    Remove-Item -LiteralPath $script:tempRoot -Recurse -Force -ErrorAction SilentlyContinue
    New-Item -ItemType Directory -Path (Join-Path $script:tempRoot 'evidence') -Force | Out-Null
    $fullArtifact = Join-Path $script:tempRoot $ArtifactPath
    New-Item -ItemType Directory -Path (Split-Path -Parent $fullArtifact) -Force | Out-Null
    Set-Content -LiteralPath $fullArtifact -Value $ArtifactContent -NoNewline
    $hash = (Get-FileHash -LiteralPath $fullArtifact -Algorithm SHA256).Hash.ToLowerInvariant()
    $size = (Get-Item -LiteralPath $fullArtifact).Length
    $evidence = Get-Content "$PSScriptRoot/../fixtures/valid/completion-result.json" -Raw | ConvertFrom-Json -AsHashtable
    $evidence.status = $Status
    $evidence.tests[0].status = $TestStatus
    $evidence.tests[0].exitCode = if ($TestStatus -eq 'Passed') { 0 } else { 1 }
    $evidence.tests[0].failureReason = if ($TestStatus -eq 'Passed') { $null } else { 'Mandatory test failed for fixture validation.' }
    $evidence.artifacts[0].path = $ArtifactPath
    $evidence.artifacts[0].sha256 = $hash
    $evidence.artifacts[0].sizeBytes = $size
    $evidence | ConvertTo-Json -Depth 30 | Set-Content -LiteralPath (Join-Path $script:tempRoot 'completion-result.json')
    $evidence.tests | ConvertTo-Json -Depth 30 | Set-Content -LiteralPath (Join-Path $script:tempRoot 'evidence/test-results.json')
}

Describe 'Validate evidence action' {
    BeforeAll {
        $script:tempRoot = Join-Path ([System.IO.Path]::GetTempPath()) ("evidence-tests-" + [guid]::NewGuid())
        New-Item -ItemType Directory -Path $script:tempRoot -Force | Out-Null
        $script:NewTempEvidence = {
            param(
                [string]$ArtifactPath = 'evidence/report.json',
                [string]$ArtifactContent = '{}',
                [string]$Status = 'Passed',
                [string]$TestStatus = 'Passed'
            )
            Remove-Item -LiteralPath $script:tempRoot -Recurse -Force -ErrorAction SilentlyContinue
            New-Item -ItemType Directory -Path (Join-Path $script:tempRoot 'evidence') -Force | Out-Null
            $fullArtifact = Join-Path $script:tempRoot $ArtifactPath
            New-Item -ItemType Directory -Path (Split-Path -Parent $fullArtifact) -Force | Out-Null
            Set-Content -LiteralPath $fullArtifact -Value $ArtifactContent -NoNewline
            $hash = (Get-FileHash -LiteralPath $fullArtifact -Algorithm SHA256).Hash.ToLowerInvariant()
            $size = (Get-Item -LiteralPath $fullArtifact).Length
            $evidence = Get-Content "$PSScriptRoot/../fixtures/valid/completion-result.json" -Raw | ConvertFrom-Json -AsHashtable
            $evidence.status = $Status
            $evidence.tests[0].status = $TestStatus
            $evidence.tests[0].exitCode = if ($TestStatus -eq 'Passed') { 0 } else { 1 }
            $evidence.tests[0].failureReason = if ($TestStatus -eq 'Passed') { $null } else { 'Mandatory test failed for fixture validation.' }
            $evidence.artifacts[0].path = $ArtifactPath
            $evidence.artifacts[0].sha256 = $hash
            $evidence.artifacts[0].sizeBytes = $size
            $evidence | ConvertTo-Json -Depth 30 | Set-Content -LiteralPath (Join-Path $script:tempRoot 'completion-result.json')
            $evidence.tests | ConvertTo-Json -Depth 30 | Set-Content -LiteralPath (Join-Path $script:tempRoot 'evidence/test-results.json')
        }
    }

    AfterAll {
        if ($script:tempRoot -and (Test-Path -LiteralPath $script:tempRoot)) {
            Remove-Item -LiteralPath $script:tempRoot -Recurse -Force
        }
    }

    Context 'contradictory status' {
        It 'rejects Passed evidence with NotRun tests' {
            & pwsh -NoProfile -File "$PSScriptRoot/../../actions/validate-evidence/Invoke-EvidenceValidation.ps1" -Path "$PSScriptRoot/../.." -EvidencePath 'tests/fixtures/invalid/completion-result.json'
            $LASTEXITCODE | Should -Not -Be 0
        }
    }

    Context 'artifact integrity' {
        function script:Unused-TempEvidence {
            param(
                [string]$ArtifactPath = 'evidence/report.json',
                [string]$ArtifactContent = '{}',
                [string]$Status = 'Passed',
                [string]$TestStatus = 'Passed'
            )
            Remove-Item -LiteralPath $script:tempRoot -Recurse -Force -ErrorAction SilentlyContinue
            New-Item -ItemType Directory -Path (Join-Path $script:tempRoot 'evidence') -Force | Out-Null
            $fullArtifact = Join-Path $script:tempRoot $ArtifactPath
            New-Item -ItemType Directory -Path (Split-Path -Parent $fullArtifact) -Force | Out-Null
            Set-Content -LiteralPath $fullArtifact -Value $ArtifactContent -NoNewline
            $hash = (Get-FileHash -LiteralPath $fullArtifact -Algorithm SHA256).Hash.ToLowerInvariant()
            $size = (Get-Item -LiteralPath $fullArtifact).Length
            $evidence = Get-Content "$PSScriptRoot/../fixtures/valid/completion-result.json" -Raw | ConvertFrom-Json -AsHashtable
            $evidence.status = $Status
            $evidence.tests[0].status = $TestStatus
            $evidence.tests[0].exitCode = if ($TestStatus -eq 'Passed') { 0 } else { 1 }
            $evidence.tests[0].failureReason = if ($TestStatus -eq 'Passed') { $null } else { 'Mandatory test failed for fixture validation.' }
            $evidence.artifacts[0].path = $ArtifactPath
            $evidence.artifacts[0].sha256 = $hash
            $evidence.artifacts[0].sizeBytes = $size
            $evidence | ConvertTo-Json -Depth 30 | Set-Content -LiteralPath (Join-Path $script:tempRoot 'completion-result.json')
            $evidence.tests | ConvertTo-Json -Depth 30 | Set-Content -LiteralPath (Join-Path $script:tempRoot 'evidence/test-results.json')
        }

        It 'accepts a valid artifact hash and size' {
            & $script:NewTempEvidence
            & pwsh -NoProfile -File "$PSScriptRoot/../../actions/validate-evidence/Invoke-EvidenceValidation.ps1" -Path $script:tempRoot -EvidencePath 'completion-result.json'
            $LASTEXITCODE | Should -Be 0
        }

        It 'rejects an artifact hash mismatch' {
            & $script:NewTempEvidence
            $evidence = Get-Content "$PSScriptRoot/../fixtures/valid/completion-result.json" -Raw | ConvertFrom-Json -AsHashtable
            $evidence.artifacts[0].path = 'evidence/report.json'
            $evidence.artifacts[0].sha256 = 'bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb'
            $evidence | ConvertTo-Json -Depth 30 | Set-Content -LiteralPath (Join-Path $script:tempRoot 'completion-result.json')

            & pwsh -NoProfile -File "$PSScriptRoot/../../actions/validate-evidence/Invoke-EvidenceValidation.ps1" -Path $script:tempRoot -EvidencePath 'completion-result.json'
            $LASTEXITCODE | Should -Not -Be 0
        }

        It 'rejects a missing artifact' {
            & $script:NewTempEvidence
            Remove-Item -LiteralPath (Join-Path $script:tempRoot 'evidence/report.json') -Force
            & pwsh -NoProfile -File "$PSScriptRoot/../../actions/validate-evidence/Invoke-EvidenceValidation.ps1" -Path $script:tempRoot -EvidencePath 'completion-result.json'
            $LASTEXITCODE | Should -Not -Be 0
        }

        It 'rejects incorrect artifact size' {
            & $script:NewTempEvidence
            $evidence = Get-Content (Join-Path $script:tempRoot 'completion-result.json') -Raw | ConvertFrom-Json -AsHashtable
            $evidence.artifacts[0].sizeBytes = 999
            $evidence | ConvertTo-Json -Depth 30 | Set-Content -LiteralPath (Join-Path $script:tempRoot 'completion-result.json')
            & pwsh -NoProfile -File "$PSScriptRoot/../../actions/validate-evidence/Invoke-EvidenceValidation.ps1" -Path $script:tempRoot -EvidencePath 'completion-result.json'
            $LASTEXITCODE | Should -Not -Be 0
        }

        It 'rejects absolute and traversal artifact paths' -TestCases @(
            @{ Path = 'C:\temp\report.json' }
            @{ Path = '\\server\share\report.json' }
            @{ Path = '/tmp/report.json' }
            @{ Path = '../report.json' }
        ) {
            param($Path)
            & $script:NewTempEvidence
            $evidence = Get-Content (Join-Path $script:tempRoot 'completion-result.json') -Raw | ConvertFrom-Json -AsHashtable
            $evidence.artifacts[0].path = $Path
            $evidence | ConvertTo-Json -Depth 30 | Set-Content -LiteralPath (Join-Path $script:tempRoot 'completion-result.json')
            & pwsh -NoProfile -File "$PSScriptRoot/../../actions/validate-evidence/Invoke-EvidenceValidation.ps1" -Path $script:tempRoot -EvidencePath 'completion-result.json'
            $LASTEXITCODE | Should -Not -Be 0
        }

        It 'rejects duplicate artifact records' {
            & $script:NewTempEvidence
            $evidence = Get-Content (Join-Path $script:tempRoot 'completion-result.json') -Raw | ConvertFrom-Json -AsHashtable
            $evidence.artifacts = @($evidence.artifacts[0], $evidence.artifacts[0])
            $evidence | ConvertTo-Json -Depth 30 | Set-Content -LiteralPath (Join-Path $script:tempRoot 'completion-result.json')
            & pwsh -NoProfile -File "$PSScriptRoot/../../actions/validate-evidence/Invoke-EvidenceValidation.ps1" -Path $script:tempRoot -EvidencePath 'completion-result.json'
            $LASTEXITCODE | Should -Not -Be 0
        }
    }

    Context 'completion evidence generation' {
        It 'marks local GitHub-hosted execution NotRun and overall NotRun' {
            & $script:NewTempEvidence
            $outcomes = @{
                yaml='success'; workflow_architecture='success'; json_schemas='success'; markdown_links='success'
                documentation='success'; contract='success'; forbidden_patterns='success'; repository_health='success'
                powershell_parser='success'; pester='success'; psscriptanalyzer='success'; examples='success'
                evidence_validation='success'
            }
            $reports = @{
                yaml=''; workflow_architecture=''; json_schemas=''; markdown_links=''
                documentation=''; contract=''; forbidden_patterns=''; repository_health=''
                powershell_parser=''; pester=''; psscriptanalyzer=''; examples=''
                evidence_validation=''; github_execution=''
            }
            & "$PSScriptRoot/../../scripts/New-WorkflowTestEvidence.ps1" -RepositoryPath $script:tempRoot -OutputPath 'evidence/local-tests.json' -Outcomes $outcomes -Reports $reports -RunPester -RunDocumentation -RunExamples -Runtime 'Local PowerShell validation' -ToolVersion 'test'
            & pwsh -NoProfile -File "$PSScriptRoot/../../scripts/New-CompletionEvidence.ps1" -RepositoryPath $script:tempRoot -OutputPath 'evidence/local-completion-result.json' -ExecutionContext Local -Summary 'Local evidence must not claim GitHub-hosted workflow execution succeeded.' -TestResultPath 'evidence/local-tests.json' -ArtifactPath @('evidence/report.json','evidence/local-tests.json') -CommandsExecuted @('local test command') -CommandsNotExecuted @('GitHub-hosted Governance CI workflow execution')
            $generated = Get-Content -LiteralPath (Join-Path $script:tempRoot 'evidence/local-completion-result.json') -Raw | ConvertFrom-Json
            $generated.status | Should -Be 'NotRun'
            ($generated.tests | Where-Object name -eq 'GitHub-hosted workflow execution').status | Should -Be 'NotRun'
        }

        It 'computes Failed when a mandatory test failed' {
            & $script:NewTempEvidence -Status Failed -TestStatus Failed
            & pwsh -NoProfile -File "$PSScriptRoot/../../scripts/New-CompletionEvidence.ps1" -RepositoryPath $script:tempRoot -OutputPath 'evidence/generated.json' -Summary 'Generated evidence should preserve failed mandatory test status.' -TestResultPath 'evidence/test-results.json' -ArtifactPath @('evidence/report.json') -CommandsExecuted @('test command')
            $generated = Get-Content -LiteralPath (Join-Path $script:tempRoot 'evidence/generated.json') -Raw | ConvertFrom-Json
            $generated.status | Should -Be 'Failed'
        }

        It 'rejects a contradictory caller-supplied status' {
            & $script:NewTempEvidence -Status Failed -TestStatus Failed
            & pwsh -NoProfile -File "$PSScriptRoot/../../scripts/New-CompletionEvidence.ps1" -RepositoryPath $script:tempRoot -OutputPath 'evidence/generated.json' -Status Passed -Summary 'Generated evidence should reject contradictory passed status from caller.' -TestResultPath 'evidence/test-results.json' -ArtifactPath @('evidence/report.json') -CommandsExecuted @('test command')
            $LASTEXITCODE | Should -Not -Be 0
        }
    }
}
