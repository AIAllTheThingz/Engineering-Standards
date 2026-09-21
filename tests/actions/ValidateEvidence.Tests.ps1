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
        It 'honors optional failed tests with overall <Overall>' -ForEach @('Passed','Blocked','NotRun','NotApplicable' | ForEach-Object { @{ Overall = $_ } }) {
            & $script:NewTempEvidence -Status $Overall -TestStatus Failed
            $evidencePath = Join-Path $script:tempRoot 'completion-result.json'
            $evidence = Get-Content $evidencePath -Raw | ConvertFrom-Json -AsHashtable
            $evidence.tests[0].requiredValidation = $false
            $evidence.blockedReason = 'Required prerequisite unavailable.'
            $evidence.notRunReason = 'Required validation has not run.'
            $evidence.commandsNotExecuted = @('required-validation')
            $evidence.notApplicableRationale = 'No required validation applies.'
            $evidence | ConvertTo-Json -Depth 30 | Set-Content $evidencePath
            & pwsh -NoProfile -File "$PSScriptRoot/../../actions/validate-evidence/Invoke-EvidenceValidation.ps1" -Path $script:tempRoot -EvidencePath 'completion-result.json'
            $LASTEXITCODE | Should -Be 0
            $evidence.tests[0].requiredValidation = 0
            $evidence | ConvertTo-Json -Depth 30 | Set-Content $evidencePath
            & pwsh -NoProfile -File "$PSScriptRoot/../../actions/validate-evidence/Invoke-EvidenceValidation.ps1" -Path $script:tempRoot -EvidencePath 'completion-result.json'
            $LASTEXITCODE | Should -Not -Be 0
            $evidence.tests[0].Remove('requiredValidation')
            $evidence | ConvertTo-Json -Depth 30 | Set-Content $evidencePath
            & pwsh -NoProfile -File "$PSScriptRoot/../../actions/validate-evidence/Invoke-EvidenceValidation.ps1" -Path $script:tempRoot -EvidencePath 'completion-result.json'
            $LASTEXITCODE | Should -Not -Be 0
        }

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

        It 'does not inherit GitHub repository or branch expectations for local fixture evidence' {
            & $script:NewTempEvidence
            $previousRepository = $env:GITHUB_REPOSITORY
            $previousRefName = $env:GITHUB_REF_NAME
            try {
                $env:GITHUB_REPOSITORY = 'AIAllTheThingz/Engineering-Standards'
                $env:GITHUB_REF_NAME = 'release-protection-finalize-20260627'
                & pwsh -NoProfile -File "$PSScriptRoot/../../actions/validate-evidence/Invoke-EvidenceValidation.ps1" -Path $script:tempRoot -EvidencePath 'completion-result.json'
                $LASTEXITCODE | Should -Be 0
            }
            finally {
                $env:GITHUB_REPOSITORY = $previousRepository
                $env:GITHUB_REF_NAME = $previousRefName
            }
        }

        It 'accepts local release evidence with externally verified GitHub artifact details' {
            & $script:NewTempEvidence -Status Blocked -TestStatus Passed
            $evidencePath = Join-Path $script:tempRoot 'completion-result.json'
            $evidence = Get-Content $evidencePath -Raw | ConvertFrom-Json -AsHashtable
            $evidence.executionContext = 'Local'
            $evidence.status = 'Blocked'
            $evidence.commitSha = '2222222222222222222222222222222222222222'
            $evidence.validatedCommitSha = '1111111111111111111111111111111111111111'
            $evidence.blockedReason = 'Release approval remains blocked pending independent approval.'
            $evidence.tests = @(
                $evidence.tests[0],
                [ordered]@{
                    schemaVersion = '1.1.0'
                    name = 'GitHub-hosted workflow execution'
                    category = 'workflow'
                    status = 'Passed'
                    requiredValidation = $true
                    evidenceSource = 'GitHubArtifact'
                    command = 'Governance CI run 123'
                    workingDirectory = '.'
                    startedAtUtc = '2026-06-19T00:00:00Z'
                    completedAtUtc = '2026-06-19T00:00:01Z'
                    durationSeconds = 1
                    runtime = 'GitHub Actions'
                    toolVersion = '7.x'
                    exitCode = 0
                    summary = 'GitHub-hosted workflow execution was independently verified from an artifact.'
                    warnings = @()
                    failureReason = $null
                    blockedReason = $null
                    notApplicableRationale = $null
                    details = [ordered]@{
                        runId = 123
                        runAttempt = 1
                        branch = '1/merge'
                        artifactId = 1234
                        artifactName = 'governance-evidence-123'
                        artifactSha256 = 'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa'
                    }
                },
                [ordered]@{
                    schemaVersion = '1.1.0'
                    name = 'Release approval'
                    category = 'manual'
                    status = 'Blocked'
                    requiredValidation = $true
                    evidenceSource = 'Manual'
                    command = 'Review release approval.'
                    workingDirectory = '.'
                    startedAtUtc = '2026-06-19T00:00:00Z'
                    completedAtUtc = '2026-06-19T00:00:01Z'
                    durationSeconds = 1
                    runtime = 'Repository governance review'
                    toolVersion = '1.1.0'
                    exitCode = $null
                    summary = 'Release approval is blocked pending independent approval.'
                    warnings = @()
                    failureReason = $null
                    blockedReason = 'Release approval is blocked pending independent approval.'
                    notApplicableRationale = $null
                }
            )
            $evidence | ConvertTo-Json -Depth 30 | Set-Content -LiteralPath $evidencePath

            & pwsh -NoProfile -File "$PSScriptRoot/../../actions/validate-evidence/Invoke-EvidenceValidation.ps1" -Path $script:tempRoot -EvidencePath 'completion-result.json'
            $LASTEXITCODE | Should -Be 0
        }

        It 'accepts a truthfully failed hosted outcome when its artifact is independently verified' {
            & $script:NewTempEvidence -Status Blocked -TestStatus Passed
            $evidencePath = Join-Path $script:tempRoot 'completion-result.json'
            $evidence = Get-Content $evidencePath -Raw | ConvertFrom-Json -AsHashtable
            $evidence.executionContext = 'Local'
            $evidence.status = 'Failed'
            $evidence.blockedReason = $null
            $evidence.tests = @(
                $evidence.tests[0],
                [ordered]@{
                    schemaVersion = '1.1.0'; name = 'GitHub-hosted workflow execution'; category = 'workflow'; status = 'Failed'; requiredValidation = $true
                    evidenceSource = 'GitHubArtifact'; command = 'Governance CI run 456'; workingDirectory = '.'
                    startedAtUtc = '2026-06-19T00:00:00Z'; completedAtUtc = '2026-06-19T00:00:01Z'; durationSeconds = 1
                    runtime = 'GitHub Actions'; toolVersion = '7.x'; exitCode = 1
                    summary = 'Hosted governance validation failed at a mandatory check.'; warnings = @()
                    failureReason = 'Documentation completeness failed.'; blockedReason = $null; notApplicableRationale = $null
                    details = [ordered]@{ runId = 456; runAttempt = 1; branch = '1/merge'; artifactId = 4567; artifactName = 'governance-evidence-456'; artifactSha256 = ('a' * 64) }
                }
            )
            $evidence | ConvertTo-Json -Depth 30 | Set-Content -LiteralPath $evidencePath

            & pwsh -NoProfile -File "$PSScriptRoot/../../actions/validate-evidence/Invoke-EvidenceValidation.ps1" -Path $script:tempRoot -EvidencePath 'completion-result.json'
            $LASTEXITCODE | Should -Be 0
        }

        It 'rejects a failed hosted outcome without independently verified artifact details' {
            & $script:NewTempEvidence -Status Failed -TestStatus Passed
            $evidencePath = Join-Path $script:tempRoot 'completion-result.json'
            $evidence = Get-Content $evidencePath -Raw | ConvertFrom-Json -AsHashtable
            $evidence.executionContext = 'Local'
            $evidence.status = 'Failed'
            $evidence.blockedReason = $null
            $evidence.tests[0].name = 'GitHub-hosted workflow execution'
            $evidence.tests[0].status = 'Failed'
            $evidence.tests[0].evidenceSource = 'local-summary'
            $evidence.tests[0].exitCode = 1
            $evidence.tests[0].failureReason = 'Hosted enforcement failed.'
            $evidence | ConvertTo-Json -Depth 30 | Set-Content -LiteralPath $evidencePath

            & pwsh -NoProfile -File "$PSScriptRoot/../../actions/validate-evidence/Invoke-EvidenceValidation.ps1" -Path $script:tempRoot -EvidencePath 'completion-result.json'
            $LASTEXITCODE | Should -Not -Be 0
        }

        It 'uses the configured evidencePath for artifact verification' {
            & $script:NewTempEvidence -ArtifactPath 'GovernanceEvidence/report.json'
            @{ evidencePath = 'GovernanceEvidence' } |
                ConvertTo-Json -Depth 10 |
                Set-Content -LiteralPath (Join-Path $script:tempRoot 'governance.config.json')

            & pwsh -NoProfile -File "$PSScriptRoot/../../actions/validate-evidence/Invoke-EvidenceValidation.ps1" -Path $script:tempRoot -EvidencePath 'completion-result.json'
            $LASTEXITCODE | Should -Be 0
        }

        It 'accepts filesystem-supported case aliases for the configured evidence directory' {
            & $script:NewTempEvidence -ArtifactPath 'Evidence/report.json'
            if (-not (Test-Path -LiteralPath (Join-Path $script:tempRoot 'EVIDENCE/report.json'))) {
                Set-ItResult -Skipped -Because 'This fixture filesystem is case-sensitive.'
                return
            }
            @{ evidencePath = 'EVIDENCE' } | ConvertTo-Json | Set-Content (Join-Path $script:tempRoot 'governance.config.json')
            & pwsh -NoProfile -File "$PSScriptRoot/../../actions/validate-evidence/Invoke-EvidenceValidation.ps1" -Path $script:tempRoot -EvidencePath 'completion-result.json'
            $LASTEXITCODE | Should -Be 0
        }

        It 'rejects a distinct case-sensitive sibling of the configured evidence directory' {
            & $script:NewTempEvidence
            if ($IsWindows) {
                & fsutil.exe file setCaseSensitiveInfo $script:tempRoot enable 2>&1 | Out-Null
                if ($LASTEXITCODE -ne 0) {
                    Set-ItResult -Skipped -Because 'NTFS per-directory case sensitivity cannot be enabled in this environment.'
                    return
                }
            }
            if (Test-Path -LiteralPath (Join-Path $script:tempRoot 'Evidence')) {
                Set-ItResult -Skipped -Because 'This fixture filesystem does not provide distinct case-sensitive siblings.'
                return
            }
            New-Item -ItemType Directory -Path (Join-Path $script:tempRoot 'Evidence') | Out-Null
            @{ evidencePath = 'Evidence' } | ConvertTo-Json | Set-Content (Join-Path $script:tempRoot 'governance.config.json')
            $output = @(& pwsh -NoProfile -File "$PSScriptRoot/../../actions/validate-evidence/Invoke-EvidenceValidation.ps1" -Path $script:tempRoot -EvidencePath 'completion-result.json' 2>&1)
            $LASTEXITCODE | Should -Not -Be 0
            $output -join "`n" | Should -Match 'must be under the configured evidence directory'
        }

        It 'rejects malformed hosted artifact metadata: <Name>' -ForEach @(
            @{ Name = 'empty'; Details = @{} }
            @{ Name = 'arbitrary'; Details = @{ note = 'verified' } }
            @{ Name = 'array'; Details = @('verified') }
            foreach ($branch in @('bad..ref','HEAD','refs/heads/main','topic.lock','bad ref')) {
                @{ Name = "branch $branch"; Details = @{ runId = 123; runAttempt = 1; artifactId = 456; branch = $branch; artifactName = 'governance-evidence-123'; artifactSha256 = ('a' * 64) } }
            }
            foreach ($field in @('runId','runAttempt','artifactId')) {
                $details = @{ runId = 123; runAttempt = 1; artifactId = 456; branch = '1/merge'; artifactName = 'governance-evidence-123'; artifactSha256 = ('a' * 64) }
                $details[$field] = [string]$details[$field]
                @{ Name = "string $field"; Details = $details }
            }
            foreach ($field in @('runId','runAttempt','artifactId','branch','artifactName','artifactSha256')) {
                $details = @{ runId = 123; runAttempt = 1; artifactId = 456; branch = '1/merge'; artifactName = 'governance-evidence-123'; artifactSha256 = ('a' * 64) }
                $details.Remove($field)
                @{ Name = "missing $field"; Details = $details }
            }
            foreach ($invalid in @(@{ field = 'runId'; value = $true }, @{ field = 'runAttempt'; value = 0 }, @{ field = 'artifactId'; value = 1.5 }, @{ field = 'branch'; value = ' ' }, @{ field = 'artifactSha256'; value = 'invalid' })) {
                $details = @{ runId = 123; runAttempt = 1; artifactId = 456; branch = '1/merge'; artifactName = 'governance-evidence-123'; artifactSha256 = ('a' * 64) }
                $details[$invalid.field] = $invalid.value
                @{ Name = "invalid $($invalid.field)"; Details = $details }
            }
        ) {
            Import-Module "$PSScriptRoot/../../scripts/GovernanceValidation.psm1" -Force
            foreach ($hostedStatus in @('Passed','Failed')) {
                & $script:NewTempEvidence -Status Failed -TestStatus Passed
                $evidencePath = Join-Path $script:tempRoot 'completion-result.json'
                $evidence = Get-Content $evidencePath -Raw | ConvertFrom-Json -AsHashtable
                $evidence.executionContext = 'Local'
                $evidence.tests[0].name = 'GitHub-hosted workflow execution'
                $evidence.tests[0].status = $hostedStatus
                $evidence.tests[0].evidenceSource = 'GitHubArtifact'
                $evidence.tests[0].details = $Details
                if ($hostedStatus -eq 'Failed') {
                    $evidence.tests[0].exitCode = 1
                    $evidence.tests[0].failureReason = 'Hosted enforcement failed.'
                }
                $evidence | ConvertTo-Json -Depth 30 | Set-Content $evidencePath
                $results = @(Test-GovernanceJsonDocument -Path $evidencePath -Kind completion-result)
                @($results | Where-Object { $_.status -eq 'Failed' -and $_.message -match 'GitHubArtifact' }).Count | Should -BeGreaterThan 0
                & pwsh -NoProfile -File "$PSScriptRoot/../../actions/validate-evidence/Invoke-EvidenceValidation.ps1" -Path $script:tempRoot -EvidencePath 'completion-result.json'
                $LASTEXITCODE | Should -Not -Be 0
            }
        }

        It 'accepts a repository-root evidencePath' {
            & $script:NewTempEvidence -ArtifactPath 'report.json'
            @{ evidencePath = '.' } |
                ConvertTo-Json -Depth 10 |
                Set-Content -LiteralPath (Join-Path $script:tempRoot 'governance.config.json')

            & pwsh -NoProfile -File "$PSScriptRoot/../../actions/validate-evidence/Invoke-EvidenceValidation.ps1" -Path $script:tempRoot -EvidencePath 'completion-result.json'
            $LASTEXITCODE | Should -Be 0
        }

        It 'rejects a file-valued configured evidence root' {
            & $script:NewTempEvidence -ArtifactPath 'README.md'
            @{ evidencePath = 'README.md' } | ConvertTo-Json | Set-Content (Join-Path $script:tempRoot 'governance.config.json')
            $output = @(& pwsh -NoProfile -File "$PSScriptRoot/../../actions/validate-evidence/Invoke-EvidenceValidation.ps1" -Path $script:tempRoot -EvidencePath 'completion-result.json' 2>&1)
            $LASTEXITCODE | Should -Not -Be 0
            $output -join "`n" | Should -Match 'evidencePath must resolve to a directory'
        }

        It 'rejects a blocked overall status with a failed required hosted outcome' {
            & $script:NewTempEvidence -Status Blocked -TestStatus Passed
            $evidencePath = Join-Path $script:tempRoot 'completion-result.json'
            $evidence = Get-Content $evidencePath -Raw | ConvertFrom-Json -AsHashtable
            $evidence.executionContext = 'Local'
            $evidence.status = 'Blocked'
            $evidence.blockedReason = 'Human acceptance remains pending.'
            $evidence.tests[0].name = 'GitHub-hosted workflow execution'
            $evidence.tests[0].status = 'Failed'
            $evidence.tests[0].evidenceSource = 'GitHubArtifact'
            $evidence.tests[0].details = [ordered]@{ runId = 789; runAttempt = 1; branch = '1/merge'; artifactId = 7890; artifactName = 'governance-evidence-789'; artifactSha256 = ('b' * 64) }
            $evidence.tests[0].failureReason = 'Hosted enforcement failed.'
            $evidence.tests[0].exitCode = 1
            $evidence | ConvertTo-Json -Depth 30 | Set-Content -LiteralPath $evidencePath

            & pwsh -NoProfile -File "$PSScriptRoot/../../actions/validate-evidence/Invoke-EvidenceValidation.ps1" -Path $script:tempRoot -EvidencePath 'completion-result.json'
            $LASTEXITCODE | Should -Not -Be 0
        }

        It 'rejects traversal in configured evidencePath' {
            & $script:NewTempEvidence
            @{ evidencePath = 'sub/../evidence' } |
                ConvertTo-Json -Depth 10 |
                Set-Content -LiteralPath (Join-Path $script:tempRoot 'governance.config.json')

            & pwsh -NoProfile -File "$PSScriptRoot/../../actions/validate-evidence/Invoke-EvidenceValidation.ps1" -Path $script:tempRoot -EvidencePath 'completion-result.json'
            $LASTEXITCODE | Should -Not -Be 0
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
                evidence_validation='success'; github_execution='notrun'
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
            & pwsh -NoProfile -File "$PSScriptRoot/../../scripts/New-CompletionEvidence.ps1" -RepositoryPath $script:tempRoot -OutputPath 'evidence/generated.json' -Status Passed -Summary 'Generated evidence should reject contradictory passed status from caller.' -TestResultPath 'evidence/test-results.json' -ArtifactPath @('evidence/report.json') -CommandsExecuted @('test command') 2>$null
            $LASTEXITCODE | Should -Not -Be 0
        }
    }
}
