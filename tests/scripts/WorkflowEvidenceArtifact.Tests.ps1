Describe 'Workflow evidence artifact verification' {
    BeforeAll {
        $script:tempRoot = Join-Path ([System.IO.Path]::GetTempPath()) ("artifact-verification-" + [guid]::NewGuid())
        New-Item -ItemType Directory -Path $script:tempRoot -Force | Out-Null
        $script:verifier = Resolve-Path "$PSScriptRoot/../../scripts/Test-WorkflowEvidenceArtifact.ps1"
        $script:sha = '1111111111111111111111111111111111111111'
    }

    AfterAll {
        if ($script:tempRoot -and (Test-Path -LiteralPath $script:tempRoot)) {
            Remove-Item -LiteralPath $script:tempRoot -Recurse -Force
        }
    }

    function script:New-ArtifactFixture {
        param([string]$Name = 'valid', [string]$Branch = 'master', [string]$RunId = '123', [string]$Status = 'Passed')
        $root = Join-Path $script:tempRoot $Name
        Remove-Item -LiteralPath $root -Recurse -Force -ErrorAction SilentlyContinue
        New-Item -ItemType Directory -Path $root -Force | Out-Null
        Set-Content -LiteralPath (Join-Path $root 'report.json') -Value '{"ok":true}' -NoNewline
        $hash = (Get-FileHash -LiteralPath (Join-Path $root 'report.json') -Algorithm SHA256).Hash.ToLowerInvariant()
        $size = (Get-Item -LiteralPath (Join-Path $root 'report.json')).Length
        $testStatus = if ($Status -eq 'Passed') { 'Passed' } else { 'Failed' }
        $failureReason = if ($testStatus -eq 'Passed') { $null } else { 'Controlled failure represented honestly.' }
        $evidence = [ordered]@{
            schemaVersion='1.0.0'; executionContext='GitHubActions'; githubRunId=$RunId; githubRunAttempt='1'; githubWorkflow='Governance CI'; artifactName="governance-evidence-$RunId"; repository='AIAllTheThingz/Engineering-Standards'; commitSha=$script:sha; validatedCommitSha=$script:sha; evidenceCommitSha=$null; branch=$Branch; pullRequest=$null; governanceVersion='1.0.0'; riskClassification='High'; status=$Status; startedAtUtc='2026-06-20T00:00:00Z'; completedAtUtc='2026-06-20T00:00:01Z'; summary='Fixture completion evidence for workflow artifact verification tests.'; changedFiles=@('README.md'); changedFileCategories=[ordered]@{source=@();documentation=@('README.md');configuration=@();tests=@();generatedEvidence=@();generatedBuildOutput=@()}; commandsExecuted=@('workflow'); commandsNotExecuted=@(); tests=@([ordered]@{schemaVersion='1.0.0';name='GitHub-hosted workflow execution';category='workflow';status=$testStatus;command='Governance CI';workingDirectory='.';startedAtUtc='2026-06-20T00:00:00Z';completedAtUtc='2026-06-20T00:00:01Z';durationSeconds=1;runtime='GitHub Actions';toolVersion='7.6.2';exitCode=$(if($testStatus -eq 'Passed'){0}else{1});summary='GitHub-hosted workflow execution completed.';warnings=@();failureReason=$failureReason}); artifacts=@([ordered]@{schemaVersion='1.0.0';name='report.json';artifactType='report';path='evidence/report.json';mediaType='application/json';sizeBytes=$size;sha256=$hash;createdAtUtc='2026-06-20T00:00:00Z';producer='test';retention='audit';sensitivity='Internal';relatedTest=$null}); warnings=@(); knownLimitations=@(); remainingRisks=@(); exceptions=@(); approvals=@()
        }
        $evidence | ConvertTo-Json -Depth 100 | Set-Content -LiteralPath (Join-Path $root 'completion-result.json')
        $root
    }

    It 'accepts a valid successful artifact' {
        $root = New-ArtifactFixture -Name 'success'
        & pwsh -NoProfile -File $script:verifier -ArtifactPath $root -ExpectedRepository 'AIAllTheThingz/Engineering-Standards' -ExpectedCommitSha $script:sha -ExpectedBranch master -ExpectedRunId 123 -ExpectedConclusion success
        $LASTEXITCODE | Should -Be 0
    }

    It 'accepts a failed artifact that preserves a specific sanitized reason' {
        $root = New-ArtifactFixture -Name 'specific-failure' -Status 'Failed'
        $completionPath = Join-Path $root 'completion-result.json'
        $completion = Get-Content -LiteralPath $completionPath -Raw | ConvertFrom-Json -AsHashtable
        $completion.tests[0].failureReason = "Governance version mismatch: workflow expects '1.1.0' but manifest declares '1.0.0'."
        $completion | ConvertTo-Json -Depth 100 | Set-Content -LiteralPath $completionPath
        & pwsh -NoProfile -File $script:verifier -ArtifactPath $root -ExpectedRepository 'AIAllTheThingz/Engineering-Standards' -ExpectedCommitSha $script:sha -ExpectedBranch master -ExpectedRunId 123 -ExpectedConclusion failure
        $LASTEXITCODE | Should -Be 0
    }

    It 'rejects expanded credential forms in artifact content' {
        $root = New-ArtifactFixture -Name 'credential-output'
        $completionPath = Join-Path $root 'completion-result.json'
        $completion = Get-Content -LiteralPath $completionPath -Raw | ConvertFrom-Json -AsHashtable
        $authorization = 'Author' + 'ization: Bearer unsafe-bearer-value'
        $pat = 'github_' + 'pat_' + 'abcdefghijklmnopqrstuvwxyz123456'
        $completion.summary = "$authorization https://user:password@example.invalid/path $pat"
        $completion | ConvertTo-Json -Depth 100 | Set-Content -LiteralPath $completionPath
        & pwsh -NoProfile -File $script:verifier -ArtifactPath $root -ExpectedRepository 'AIAllTheThingz/Engineering-Standards' -ExpectedCommitSha $script:sha -ExpectedBranch master -ExpectedRunId 123 -ExpectedConclusion success
        $LASTEXITCODE | Should -Not -Be 0
    }

    It 'accepts an explicit redaction placeholder in sanitized artifact content' {
        $root = New-ArtifactFixture -Name 'redacted-output'
        $redactedMarker = 'id-' + 'to' + 'ken=' + '[redacted]'
        @{ name="OIDC mutation $redactedMarker , expected rejection" } | ConvertTo-Json -Compress |
            Set-Content -LiteralPath (Join-Path $root 'pester-details.json')
        & pwsh -NoProfile -File $script:verifier -ArtifactPath $root -ExpectedRepository 'AIAllTheThingz/Engineering-Standards' -ExpectedCommitSha $script:sha -ExpectedBranch master -ExpectedRunId 123 -ExpectedConclusion success
        $LASTEXITCODE | Should -Be 0
    }

    It 'rejects wrong commit, wrong run id, modified file, absolute path, and unexpected executable' {
        $root = New-ArtifactFixture -Name 'bad'
        Set-Content -LiteralPath (Join-Path $root 'report.json') -Value '{"ok":false}' -NoNewline
        Set-Content -LiteralPath (Join-Path $root 'tool.exe') -Value 'nope'
        $completion = Get-Content -LiteralPath (Join-Path $root 'completion-result.json') -Raw | ConvertFrom-Json -AsHashtable
        $completion.summary = 'Fixture completion evidence mentions /home/runner/work/path to force path detection.'
        $completion | ConvertTo-Json -Depth 100 | Set-Content -LiteralPath (Join-Path $root 'completion-result.json')
        & pwsh -NoProfile -File $script:verifier -ArtifactPath $root -ExpectedRepository 'AIAllTheThingz/Engineering-Standards' -ExpectedCommitSha '2222222222222222222222222222222222222222' -ExpectedBranch main -ExpectedRunId 999 -ExpectedConclusion success
        $LASTEXITCODE | Should -Not -Be 0
    }
}
