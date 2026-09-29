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
            $LASTEXITCODE | Should -Be 0
            $generated = Get-Content -LiteralPath (Join-Path $script:tempRoot 'evidence/local-completion-result.json') -Raw | ConvertFrom-Json
            $generated.status | Should -Be 'NotRun'
            ($generated.tests | Where-Object name -eq 'GitHub-hosted workflow execution').status | Should -Be 'NotRun'
        }

        It 'normalizes LF-governed artifacts before recording their integrity' {
            & $script:NewTempEvidence
            & git -C $script:tempRoot init --quiet
            $LASTEXITCODE | Should -Be 0
            Set-Content -LiteralPath (Join-Path $script:tempRoot '.gitattributes') -Value 'evidence/report.json text eol=lf' -NoNewline
            $artifactPath = Join-Path $script:tempRoot 'evidence/report.json'
            [System.IO.File]::WriteAllText($artifactPath, "{`r`n  `"status`": `"passed`"`r`n}`r`n", [System.Text.UTF8Encoding]::new($false))

            & pwsh -NoProfile -File "$PSScriptRoot/../../scripts/New-CompletionEvidence.ps1" -RepositoryPath $script:tempRoot -OutputPath 'evidence/generated.json' -Summary 'LF-governed artifact integrity fixture.' -ArtifactPath 'evidence/report.json'
            $LASTEXITCODE | Should -Be 0

            $generated = Get-Content -LiteralPath (Join-Path $script:tempRoot 'evidence/generated.json') -Raw | ConvertFrom-Json
            $artifact = @($generated.artifacts | Where-Object path -eq 'evidence/report.json')
            $artifact.Count | Should -Be 1
            $bytes = [System.IO.File]::ReadAllBytes($artifactPath)
            ($bytes -contains 13) | Should -BeFalse
            $artifact[0].sizeBytes | Should -Be $bytes.Length
            $artifact[0].sha256 | Should -Be ((Get-FileHash -LiteralPath $artifactPath -Algorithm SHA256).Hash.ToLowerInvariant())
        }

        It 'does not rewrite binary artifacts when Git attributes declare LF' {
            & $script:NewTempEvidence
            & git -C $script:tempRoot init --quiet
            $LASTEXITCODE | Should -Be 0
            Set-Content -LiteralPath (Join-Path $script:tempRoot '.gitattributes') -Value 'evidence/report.bin text=auto eol=lf' -NoNewline
            $artifactPath = Join-Path $script:tempRoot 'evidence/report.bin'
            [byte[]]$originalBytes = @(0, 13, 10, 255, 0, 13, 10, 1)
            [System.IO.File]::WriteAllBytes($artifactPath, $originalBytes)

            & pwsh -NoProfile -File "$PSScriptRoot/../../scripts/New-CompletionEvidence.ps1" -RepositoryPath $script:tempRoot -OutputPath 'evidence/generated.json' -Summary 'Binary artifact integrity fixture.' -ArtifactPath 'evidence/report.bin'
            $LASTEXITCODE | Should -Be 0

            $generated = Get-Content -LiteralPath (Join-Path $script:tempRoot 'evidence/generated.json') -Raw | ConvertFrom-Json
            $artifact = @($generated.artifacts | Where-Object path -eq 'evidence/report.bin')
            $artifact.Count | Should -Be 1
            [Convert]::ToHexString([System.IO.File]::ReadAllBytes($artifactPath)) | Should -Be ([Convert]::ToHexString($originalBytes))
            $artifact[0].sizeBytes | Should -Be $originalBytes.Length
            $artifact[0].sha256 | Should -Be ((Get-FileHash -LiteralPath $artifactPath -Algorithm SHA256).Hash.ToLowerInvariant())
        }

        It 'allows an unavailable validation tag but verifies an available tag against the recorded commit' {
            & $script:NewTempEvidence
            Set-Content -LiteralPath (Join-Path $script:tempRoot 'source.txt') -Value 'validated source' -NoNewline
            & git -C $script:tempRoot init --quiet
            $LASTEXITCODE | Should -Be 0
            & git -C $script:tempRoot config user.email 'evidence-test@example.invalid'
            & git -C $script:tempRoot config user.name 'Evidence Test'
            & git -C $script:tempRoot add --all
            & git -C $script:tempRoot commit --quiet -m 'validated source'
            $LASTEXITCODE | Should -Be 0
            $validatedCommit = (& git -C $script:tempRoot rev-parse HEAD).Trim()
            & git -C $script:tempRoot tag -a evidence/validated-source -m 'Durable validation source' $validatedCommit
            $LASTEXITCODE | Should -Be 0

            & pwsh -NoProfile -File "$PSScriptRoot/../../scripts/New-CompletionEvidence.ps1" `
                -RepositoryPath $script:tempRoot -SourceRepositoryPath $script:tempRoot `
                -OutputPath 'evidence/generated.json' -Summary 'Annotated validation-tag fixture.' `
                -ArtifactPath 'evidence/report.json' -ValidatedCommitSha $validatedCommit `
                -ValidatedCommitTag 'evidence/validated-source' -ExecutionContext Local
            $LASTEXITCODE | Should -Be 0
            $generated = Get-Content -LiteralPath (Join-Path $script:tempRoot 'evidence/generated.json') -Raw | ConvertFrom-Json
            $generated.commitSha | Should -BeExactly $validatedCommit
            $generated.validatedCommitTag | Should -BeExactly 'evidence/validated-source'

            $evidencePath = Join-Path $script:tempRoot 'completion-result.json'
            $evidence = Get-Content -LiteralPath $evidencePath -Raw | ConvertFrom-Json -AsHashtable
            $evidence.commitSha = $validatedCommit
            $evidence.validatedCommitSha = $validatedCommit
            $evidence.validatedCommitTag = 'evidence/validated-source'
            $evidence | ConvertTo-Json -Depth 30 | Set-Content -LiteralPath $evidencePath

            & pwsh -NoProfile -File "$PSScriptRoot/../../actions/validate-evidence/Invoke-EvidenceValidation.ps1" -Path $script:tempRoot -EvidencePath 'completion-result.json'
            $LASTEXITCODE | Should -Be 0

            Set-Content -LiteralPath (Join-Path $script:tempRoot 'source.txt') -Value 'other source' -NoNewline
            & git -C $script:tempRoot add source.txt
            & git -C $script:tempRoot commit --quiet -m 'other source'
            $LASTEXITCODE | Should -Be 0
            & git -C $script:tempRoot tag -d evidence/validated-source
            $LASTEXITCODE | Should -Be 0

            & pwsh -NoProfile -File "$PSScriptRoot/../../actions/validate-evidence/Invoke-EvidenceValidation.ps1" -Path $script:tempRoot -EvidencePath 'completion-result.json'
            $LASTEXITCODE | Should -Be 0

            & git -C $script:tempRoot tag -a evidence/validated-source -m 'Wrong target' HEAD
            $LASTEXITCODE | Should -Be 0
            $movedTagCommit = (& git -C $script:tempRoot rev-parse 'refs/tags/evidence/validated-source^{}').Trim()
            $movedTagCommit | Should -Not -BeExactly $validatedCommit
            $output = @(& pwsh -NoProfile -File "$PSScriptRoot/../../actions/validate-evidence/Invoke-EvidenceValidation.ps1" -Path $script:tempRoot -EvidencePath 'completion-result.json' 2>&1)
            $LASTEXITCODE | Should -Not -Be 0
            ($output -join "`n") | Should -Match 'validatedCommitTag does not resolve to validatedCommitSha'
        }

        It 'uses an explicit complete change inventory when supplied' {
            & $script:NewTempEvidence
            $changedFiles = @(
                'docs/README.md'
                'evidence/report.json'
                'scripts/validator.ps1'
                'src/app.py'
                'tests/app.Tests.ps1'
            )

            & "$PSScriptRoot/../../scripts/New-CompletionEvidence.ps1" -RepositoryPath $script:tempRoot -OutputPath 'evidence/generated.json' -Summary 'Explicit change inventory fixture.' -ArtifactPath 'evidence/report.json' -ChangedFile $changedFiles
            $? | Should -BeTrue

            $generated = Get-Content -LiteralPath (Join-Path $script:tempRoot 'evidence/generated.json') -Raw | ConvertFrom-Json
            $actualChangedFiles = @($generated.changedFiles | Sort-Object)
            $expectedChangedFiles = @($changedFiles | Sort-Object)
            $actualChangedFiles.Count | Should -Be $expectedChangedFiles.Count
            @(Compare-Object -ReferenceObject $expectedChangedFiles -DifferenceObject $actualChangedFiles).Count | Should -Be 0
            $generated.changedFileCategories.documentation | Should -Contain 'docs/README.md'
            $generated.changedFileCategories.generatedEvidence | Should -Contain 'evidence/report.json'
            $generated.changedFileCategories.configuration | Should -Contain 'scripts/validator.ps1'
            $generated.changedFileCategories.source | Should -Contain 'src/app.py'
            $generated.changedFileCategories.tests | Should -Contain 'tests/app.Tests.ps1'
        }

        It 'rejects unsafe explicit change inventory paths' {
            & $script:NewTempEvidence
            $output = @(& pwsh -NoProfile -File "$PSScriptRoot/../../scripts/New-CompletionEvidence.ps1" -RepositoryPath $script:tempRoot -OutputPath 'evidence/generated.json' -Summary 'Unsafe change inventory fixture.' -ChangedFile '../outside.json' 2>&1)
            $LASTEXITCODE | Should -Not -Be 0
            $plainOutput = ($output -join "`n") -replace '\x1b\[[0-?]*[ -/]*[@-~]', ''
            $plainOutput | Should -Match 'must be a non-empty repository-relative(?:\s*\|\s*)?\s*path without traversal'
        }

        It 'keeps checked-in Python artifact records aligned with canonical LF bytes' {
            $repositoryRoot = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot '../..')).Path
            $completionPath = Join-Path $repositoryRoot 'examples/python-project/evidence/local-completion-result.json'
            $completion = Get-Content -LiteralPath $completionPath -Raw | ConvertFrom-Json
            @($completion.artifacts).Count | Should -Be 9

            foreach ($artifact in @($completion.artifacts)) {
                $repositoryRelativePath = "examples/python-project/$($artifact.path)"
                $attribute = @(& git -C $repositoryRoot check-attr eol -- $repositoryRelativePath)
                $LASTEXITCODE | Should -Be 0
                ($attribute -join "`n") | Should -Match '(?m):\s*eol:\s*lf\s*$'

                $bytes = [System.IO.File]::ReadAllBytes((Join-Path $repositoryRoot $repositoryRelativePath))
                $normalized = [System.IO.MemoryStream]::new()
                try {
                    for ($index = 0; $index -lt $bytes.Length; $index++) {
                        if ($bytes[$index] -eq 13 -and $index + 1 -lt $bytes.Length -and $bytes[$index + 1] -eq 10) {
                            $normalized.WriteByte(10)
                            $index++
                            continue
                        }
                        $normalized.WriteByte($bytes[$index])
                    }
                    $canonicalBytes = $normalized.ToArray()
                }
                finally {
                    $normalized.Dispose()
                }

                $artifact.sizeBytes | Should -Be $canonicalBytes.Length
                $artifact.sha256 | Should -Be ([Convert]::ToHexString([System.Security.Cryptography.SHA256]::HashData($canonicalBytes)).ToLowerInvariant())
            }
        }

        It 'records the complete dependency-correction and governance-fix scope and categories' {
            $repositoryRoot = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot '../..')).Path
            $completionPath = Join-Path $repositoryRoot 'examples/python-project/evidence/local-completion-result.json'
            $completion = Get-Content -LiteralPath $completionPath -Raw | ConvertFrom-Json
            $expectedChangedFiles = @(
                '.github/workflows/python-ci-reusable.yml'
                'README.md'
                'actions/validate-evidence/Invoke-EvidenceValidation.ps1'
                'actions/validate-evidence/README.md'
                'CHANGELOG.md'
                'docs/ADOPTION_GUIDE.md'
                'docs/GOVERNANCE_ARCHITECTURE.md'
                'docs/MAINTAINER_GUIDE.md'
                'docs/releases/unreleased.md'
                'docs/TROUBLESHOOTING.md'
                'evidence/codex-skill-behavior.json'
                'examples/bash-project/evidence/bash-formatting.json'
                'examples/bash-project/evidence/bash-project-sbom.cdx.json'
                'examples/bash-project/evidence/bash-shellcheck.json'
                'examples/bash-project/evidence/bash-syntax.json'
                'examples/bash-project/evidence/bash-tests.json'
                'examples/bash-project/evidence/bash-toolchain-bootstrap.json'
                'examples/bash-project/evidence/bash-toolchain.json'
                'examples/bash-project/evidence/local-completion-result.json'
                'examples/bash-project/evidence/local-test-results.json'
                'examples/python-project/evidence/local-completion-result.json'
                'examples/python-project/evidence/local-test-results.json'
                'examples/python-project/evidence/python-build.json'
                'examples/python-project/evidence/python-dependency-audit.json'
                'examples/python-project/evidence/python-formatting.json'
                'examples/python-project/evidence/python-project-sbom.cdx.json'
                'examples/python-project/evidence/python-toolchain-sbom.cdx.json'
                'examples/python-project/evidence/python-ruff.json'
                'examples/python-project/evidence/python-tests.json'
                'examples/python-project/evidence/python-type-check.json'
                'examples/python-project/pyproject.toml'
                'examples/python-project/README.md'
                'examples/python-project/requirements-ci.in'
                'examples/python-project/requirements-ci.lock'
                'governance/COMPLETION_EVIDENCE.md'
                'schemas/completion-result.schema.json'
                'scripts/New-CompletionEvidence.ps1'
                'scripts/Normalize-PythonFunctionalEvidence.py'
                'scripts/python-project-validation.py'
                'tests/actions/ValidateEvidence.Tests.ps1'
                'tests/python/python_project_validation_tests.py'
                'tests/scripts/BashProjectSupport.Tests.ps1'
                'tests/scripts/PythonProjectSupport.Tests.ps1'
                'tests/scripts/StaticAnalysis.Tests.ps1'
            )
            $expectedCategories = [ordered]@{
                source = @(
                    'examples/python-project/pyproject.toml'
                    'examples/python-project/requirements-ci.in'
                    'examples/python-project/requirements-ci.lock'
                )
                documentation = @(
                    'CHANGELOG.md'
                    'README.md'
                    'actions/validate-evidence/README.md'
                    'docs/ADOPTION_GUIDE.md'
                    'docs/GOVERNANCE_ARCHITECTURE.md'
                    'docs/MAINTAINER_GUIDE.md'
                    'docs/releases/unreleased.md'
                    'docs/TROUBLESHOOTING.md'
                    'examples/python-project/README.md'
                    'governance/COMPLETION_EVIDENCE.md'
                )
                configuration = @(
                    '.github/workflows/python-ci-reusable.yml'
                    'actions/validate-evidence/Invoke-EvidenceValidation.ps1'
                    'schemas/completion-result.schema.json'
                    'scripts/New-CompletionEvidence.ps1'
                    'scripts/Normalize-PythonFunctionalEvidence.py'
                    'scripts/python-project-validation.py'
                )
                tests = @(
                    'tests/actions/ValidateEvidence.Tests.ps1'
                    'tests/python/python_project_validation_tests.py'
                    'tests/scripts/BashProjectSupport.Tests.ps1'
                    'tests/scripts/PythonProjectSupport.Tests.ps1'
                    'tests/scripts/StaticAnalysis.Tests.ps1'
                )
                generatedEvidence = @(
                    'examples/bash-project/evidence/bash-formatting.json'
                    'examples/bash-project/evidence/bash-project-sbom.cdx.json'
                    'examples/bash-project/evidence/bash-shellcheck.json'
                    'examples/bash-project/evidence/bash-syntax.json'
                    'examples/bash-project/evidence/bash-tests.json'
                    'examples/bash-project/evidence/bash-toolchain-bootstrap.json'
                    'examples/bash-project/evidence/bash-toolchain.json'
                    'examples/bash-project/evidence/local-completion-result.json'
                    'examples/bash-project/evidence/local-test-results.json'
                    'evidence/codex-skill-behavior.json'
                    'examples/python-project/evidence/local-completion-result.json'
                    'examples/python-project/evidence/local-test-results.json'
                    'examples/python-project/evidence/python-build.json'
                    'examples/python-project/evidence/python-dependency-audit.json'
                    'examples/python-project/evidence/python-formatting.json'
                    'examples/python-project/evidence/python-project-sbom.cdx.json'
                    'examples/python-project/evidence/python-toolchain-sbom.cdx.json'
                    'examples/python-project/evidence/python-ruff.json'
                    'examples/python-project/evidence/python-tests.json'
                    'examples/python-project/evidence/python-type-check.json'
                )
                generatedBuildOutput = @()
            }

            $actualChangedFiles = @($completion.changedFiles | Sort-Object)
            $expectedChangedFiles = @($expectedChangedFiles | Sort-Object)
            $actualChangedFiles.Count | Should -Be $expectedChangedFiles.Count
            @(Compare-Object -ReferenceObject $expectedChangedFiles -DifferenceObject $actualChangedFiles).Count | Should -Be 0

            $completion.validatedCommitTag | Should -BeExactly 'evidence/pr-121-validated-source-v9'
            $tagReference = "refs/tags/$($completion.validatedCommitTag)"
            & git -C $repositoryRoot show-ref --verify --quiet $tagReference
            if ($LASTEXITCODE -eq 0) {
                ((& git -C $repositoryRoot cat-file -t $tagReference) -join '').Trim() | Should -BeExactly 'tag'
                ((& git -C $repositoryRoot rev-parse "$tagReference^{}") -join '').Trim() | Should -BeExactly $completion.validatedCommitSha
            }

            $actualCategoryNames = @($completion.changedFileCategories.PSObject.Properties.Name | Sort-Object)
            $expectedCategoryNames = @($expectedCategories.Keys | Sort-Object)
            $actualCategoryNames.Count | Should -Be $expectedCategoryNames.Count
            @(Compare-Object -ReferenceObject $expectedCategoryNames -DifferenceObject $actualCategoryNames).Count | Should -Be 0

            foreach ($categoryName in $expectedCategories.Keys) {
                $actualCategoryFiles = @($completion.changedFileCategories.$categoryName | Sort-Object)
                $expectedCategoryFiles = @($expectedCategories[$categoryName] | Sort-Object)
                $actualCategoryFiles.Count | Should -Be $expectedCategoryFiles.Count
                @(Compare-Object -ReferenceObject $expectedCategoryFiles -DifferenceObject $actualCategoryFiles).Count | Should -Be 0
            }

            $categorizedFiles = @(
                foreach ($category in $completion.changedFileCategories.PSObject.Properties) {
                    @($category.Value)
                }
            ) | Sort-Object
            $categorizedFiles.Count | Should -Be $expectedChangedFiles.Count
            @(Compare-Object -ReferenceObject $expectedChangedFiles -DifferenceObject $categorizedFiles).Count | Should -Be 0
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
