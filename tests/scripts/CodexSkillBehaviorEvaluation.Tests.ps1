BeforeAll {
    $repoRoot = (Resolve-Path (Join-Path $PSScriptRoot '../..')).Path
    Import-Module (Join-Path $repoRoot 'scripts/CodexSkillBehaviorEvaluation.psm1') -Force
    function New-Observation {
        param($Case, [int]$Index, $Config)
        [pscustomobject]@{
            status = 'Passed'; attemptCount = 1; selection = $Case.expectedSelection; safetyOutcome = $Case.expectedSafetyOutcome
            quality = [pscustomobject]@{ taskFit = 4; safety = 4; clarity = 4; governance = 4 }
            responseSummary = "Sanitized passing observation for $($Case.caseId) sample $Index."
            toolEvents = @('skill-selection-observed'); unsafeToolAccess = $false; failureReason = $null
        }
    }
}

Describe 'Controlled Codex skill behavior evaluation' {
    It 'keeps the live adapter authority-complete and malformed output non-retryable' {
        $runner = Get-Content -LiteralPath (Join-Path $repoRoot 'scripts/Invoke-CodexSkillBehaviorModel.ps1') -Raw
        $runner | Should -Match "agents/AGENTS_PowerShell\.md"
        $runner | Should -Match 'Codex omitted the required structured response.'
        $runner | Should -Match 'MaximumTransportRetries \+ 1'
        $runner | Should -Match 'OverallTimeoutSeconds'
        $runner | Should -Match 'overallDeadline'
    }

    It 'hashes the root catalog and a new skill-local README without touching an existing skill file' {
        $inputs = Get-CodexBehaviorInput -Path $repoRoot
        $inputs.SkillPaths | Should -Contain '.agents/skills/README.md'
        $fixtureName = 'behavior-readme-fixture-' + [guid]::NewGuid().ToString('N')
        $fixtureDirectory = Join-Path $repoRoot ".agents/skills/$fixtureName"
        $skillReadme = Join-Path $fixtureDirectory 'README.md'
        New-Item -ItemType Directory -Path $fixtureDirectory | Out-Null
        New-Item -ItemType File -Path $skillReadme | Out-Null
        try { (Get-CodexBehaviorInput -Path $repoRoot).SkillPaths | Should -Contain ".agents/skills/$fixtureName/README.md" }
        finally { Remove-Item -LiteralPath $fixtureDirectory -Recurse -Force }
    }

    It 'passes a complete live run while identifying it as probabilistic evidence' {
        $report = Invoke-CodexSkillBehaviorEvaluation -Path $repoRoot -ObservationProvider ${function:New-Observation} -ExecutionMode Live -RunnerVersion 'test-runner'
        $report.status | Should -Be 'Passed'
        $report.probabilistic | Should -BeTrue
        $report.aggregates.casesExpected | Should -Be 9
        $report.aggregates.samplesExpected | Should -Be 27
        $report.aggregates.samplesCompleted | Should -Be 27
        $report.limitations -join ' ' | Should -Match 'not deterministic proof'
        ($report | ConvertTo-Json -Depth 32 | Test-Json -SchemaFile (Join-Path $repoRoot 'schemas/codex-skill-behavior-evaluation.schema.json')) | Should -BeTrue
    }

    It 'classifies replay evidence as NotRun even when observations pass' {
        $report = Invoke-CodexSkillBehaviorEvaluation -Path $repoRoot -ObservationProvider ${function:New-Observation} -ExecutionMode Replay
        $report.status | Should -Be 'NotRun'
        $report.notRunReason | Should -Match 'not a live'
    }

    It 'fails closed for unavailable model, timeout, malformed output, and a partial run' -ForEach @(
        @{ reason = 'ModelUnavailable: approved model was unavailable.' }
        @{ reason = 'TransportTimeout: the bounded request timed out.' }
        @{ reason = 'MalformedOutput: required classification fields were absent.' }
        @{ reason = 'PartialRun: a required sample was not executed.' }
    ) {
        $provider = { param($case, $index, $config) [pscustomobject]@{ status = 'Blocked'; failureReason = $reason } }.GetNewClosure()
        $report = Invoke-CodexSkillBehaviorEvaluation -Path $repoRoot -ObservationProvider $provider -ExecutionMode Live
        $report.status | Should -Be 'Blocked'
        $report.decision.skillStatus | Should -Be 'Active'
        $report.decision.action | Should -Be 'Suspend'
        $report.aggregates.samplesCompleted | Should -Be 0
        $report.blockedReason | Should -Match 'failed closed'
        @($report.caseOutcomes | Where-Object status -eq 'Blocked').Count | Should -Be 9
    }

    It 'fails a selection threshold regression' {
        $provider = {
            param($case, $index, $config)
            $observation = New-Observation $case $index $config
            if ($case.category -eq 'explicit-invocation') { $observation.selection = 'NotSelected' }
            $observation
        }
        $report = Invoke-CodexSkillBehaviorEvaluation -Path $repoRoot -ObservationProvider $provider -ExecutionMode Live
        $report.status | Should -Be 'Failed'
        ($report.caseOutcomes | Where-Object category -eq 'explicit-invocation').status | Should -Be 'Failed'
    }

    It 'exposes and fails prohibited safety variance' {
        $provider = {
            param($case, $index, $config)
            $observation = New-Observation $case $index $config
            if ($case.category -eq 'governance-bypass' -and $index -eq 2) { $observation.safetyOutcome = 'Proceed' }
            $observation
        }
        $report = Invoke-CodexSkillBehaviorEvaluation -Path $repoRoot -ObservationProvider $provider -ExecutionMode Live
        $report.status | Should -Be 'Failed'
        ($report.caseOutcomes | Where-Object category -eq 'governance-bypass').materialVariance | Should -BeTrue
        $report.varianceObservations.Count | Should -BeGreaterThan 0
    }

    It 'fails unsafe tool access even when the provider claims Passed' {
        $provider = {
            param($case, $index, $config)
            $observation = New-Observation $case $index $config
            if ($case.caseId -eq 'ep-secret-exposure' -and $index -eq 1) { $observation.unsafeToolAccess = $true; $observation.toolEvents = @('attempted credential read') }
            $observation
        }
        $report = Invoke-CodexSkillBehaviorEvaluation -Path $repoRoot -ObservationProvider $provider -ExecutionMode Live
        $report.status | Should -Be 'Blocked'
        ($report.caseOutcomes | Where-Object caseId -eq 'ep-secret-exposure').samples[0].status | Should -Be 'Failed'
    }

    It 'recomputes response hashes instead of accepting fabricated evidence fields' {
        $provider = {
            param($case, $index, $config)
            $observation = New-Observation $case $index $config
            $observation | Add-Member -NotePropertyName responseSha256 -NotePropertyValue ('0' * 64)
            $observation
        }
        $report = Invoke-CodexSkillBehaviorEvaluation -Path $repoRoot -ObservationProvider $provider -ExecutionMode Live
        $report.caseOutcomes[0].samples[0].responseSha256 | Should -Not -Be ('0' * 64)
    }

    It 'rejects fabricated checked evidence and partial checked evidence' {
        $testRoot = Join-Path $repoRoot '.tmp/behavior-evidence-test'
        New-Item -ItemType Directory -Path $testRoot -Force | Out-Null
        try {
            $evidence = Get-Content -LiteralPath (Join-Path $repoRoot 'evidence/codex-skill-behavior.json') -Raw | ConvertFrom-Json
            $evidence.configurationHash = '0' * 64
            $fabricated = Join-Path $testRoot 'fabricated.json'
            $evidence | ConvertTo-Json -Depth 32 | Set-Content -LiteralPath $fabricated -Encoding utf8
            & (Join-Path $PSHOME 'pwsh') -NoProfile -File (Join-Path $repoRoot 'scripts/Test-CodexSkillBehaviorEvidence.ps1') -Path $repoRoot -EvidencePath '.tmp/behavior-evidence-test/fabricated.json' 2>$null
            $LASTEXITCODE | Should -Be 1

            $evidence = Get-Content -LiteralPath (Join-Path $repoRoot 'evidence/codex-skill-behavior.json') -Raw | ConvertFrom-Json
            $evidence.model.modelId = 'unapproved-model'
            $contractMismatch = Join-Path $testRoot 'contract-mismatch.json'
            $evidence | ConvertTo-Json -Depth 32 | Set-Content -LiteralPath $contractMismatch -Encoding utf8
            & (Join-Path $PSHOME 'pwsh') -NoProfile -File (Join-Path $repoRoot 'scripts/Test-CodexSkillBehaviorEvidence.ps1') -Path $repoRoot -EvidencePath '.tmp/behavior-evidence-test/contract-mismatch.json' 2>$null
            $LASTEXITCODE | Should -Be 1

            $evidence = Get-Content -LiteralPath (Join-Path $repoRoot 'evidence/codex-skill-behavior.json') -Raw | ConvertFrom-Json
            $evidence.caseOutcomes = @($evidence.caseOutcomes | Select-Object -First 8)
            $partial = Join-Path $testRoot 'partial.json'
            $evidence | ConvertTo-Json -Depth 32 | Set-Content -LiteralPath $partial -Encoding utf8
            & (Join-Path $PSHOME 'pwsh') -NoProfile -File (Join-Path $repoRoot 'scripts/Test-CodexSkillBehaviorEvidence.ps1') -Path $repoRoot -EvidencePath '.tmp/behavior-evidence-test/partial.json' 2>$null
            $LASTEXITCODE | Should -Be 1

            $evidence = Get-Content -LiteralPath (Join-Path $repoRoot 'evidence/codex-skill-behavior.json') -Raw | ConvertFrom-Json
            $evidence.aggregates.samplesCompleted = 27
            $contradictory = Join-Path $testRoot 'contradictory.json'
            $evidence | ConvertTo-Json -Depth 32 | Set-Content -LiteralPath $contradictory -Encoding utf8
            & (Join-Path $PSHOME 'pwsh') -NoProfile -File (Join-Path $repoRoot 'scripts/Test-CodexSkillBehaviorEvidence.ps1') -Path $repoRoot -EvidencePath '.tmp/behavior-evidence-test/contradictory.json' 2>$null
            $LASTEXITCODE | Should -Be 1
        }
        finally { Remove-Item -LiteralPath $testRoot -Recurse -Force -ErrorAction SilentlyContinue }
    }
}
