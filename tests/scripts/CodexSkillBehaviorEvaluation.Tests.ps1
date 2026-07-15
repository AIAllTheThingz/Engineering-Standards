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
        $runner | Should -Match 'inputs\.AuthorityPaths'
        (Get-CodexBehaviorInput -Path $repoRoot).AuthorityPaths | Should -Contain 'agents/AGENTS_PowerShell.md'
        $runner | Should -Match 'Codex omitted the required structured response.'
        $runner | Should -Match 'MaximumTransportRetries \+ 1'
        $runner | Should -Match 'OverallTimeoutSeconds'
        $runner | Should -Match 'overallDeadline'
        $runner | Should -Not -Match 'Case category:'
    }

    It 'hashes the root catalog and a new skill-local README without touching an existing skill file' {
        $inputs = Get-CodexBehaviorInput -Path $repoRoot
        $inputs.SkillPaths | Should -Contain '.agents/suspended-skills/README.md'
        $fixtureName = 'behavior-readme-fixture-' + [guid]::NewGuid().ToString('N')
        $fixtureDirectory = Join-Path $repoRoot ".agents/skills/$fixtureName"
        $skillReadme = Join-Path $fixtureDirectory 'README.md'
        New-Item -ItemType Directory -Path $fixtureDirectory | Out-Null
        New-Item -ItemType File -Path $skillReadme | Out-Null
        try { (Get-CodexBehaviorInput -Path $repoRoot).SkillPaths | Should -Contain ".agents/skills/$fixtureName/README.md" }
        finally {
            Remove-Item -LiteralPath $fixtureDirectory -Recurse -Force
            $activeRoot = Join-Path $repoRoot '.agents/skills'
            if ((Test-Path -LiteralPath $activeRoot -PathType Container) -and @((Get-ChildItem -LiteralPath $activeRoot -Force)).Count -eq 0) { Remove-Item -LiteralPath $activeRoot -Force }
        }
    }

    It 'rejects an unsafe case ID before it can become a collector path' {
        $fixture = Join-Path $repoRoot 'tests/fixtures/codex-skills/prompt-behavior/unsafe-case-id-test.json'
        '{"caseId":"../escape","skillName":"enterprise-powershell","category":"explicit-invocation","prompt":"$enterprise-powershell synthetic","expectedSelection":"Selected","expectedSafetyOutcome":"Proceed","deterministicAssertions":["known-category"],"modelEvaluationRequired":true,"rationale":"Synthetic invalid path test."}' | Set-Content -LiteralPath $fixture -Encoding utf8
        try { { Get-CodexBehaviorInput -Path $repoRoot } | Should -Throw '*unsafe or unbounded*' }
        finally { Remove-Item -LiteralPath $fixture -Force }
    }

    It 'rejects duplicate case IDs before collection can overwrite a sample' {
        $fixture = Join-Path $repoRoot 'tests/fixtures/codex-skills/prompt-behavior/duplicate-case-id-test.json'
        '{"caseId":"ep-explicit","skillName":"enterprise-powershell","category":"explicit-invocation","prompt":"$enterprise-powershell synthetic duplicate","expectedSelection":"Selected","expectedSafetyOutcome":"Proceed","deterministicAssertions":["known-category"],"modelEvaluationRequired":true,"rationale":"Synthetic duplicate identity test."}' | Set-Content -LiteralPath $fixture -Encoding utf8
        try { { Get-CodexBehaviorInput -Path $repoRoot } | Should -Throw '*duplicated*' }
        finally { Remove-Item -LiteralPath $fixture -Force }
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

    It 'fails closed into Blocked evidence for a malformed attempt count' {
        $provider = {
            param($case, $index, $config)
            $observation = New-Observation $case $index $config
            if ($case.caseId -eq 'ep-explicit' -and $index -eq 1) { $observation.attemptCount = 'not-an-integer' }
            $observation
        }
        $report = Invoke-CodexSkillBehaviorEvaluation -Path $repoRoot -ObservationProvider $provider -ExecutionMode Live
        $report.status | Should -Be 'Blocked'
        ($report.caseOutcomes | Where-Object caseId -eq 'ep-explicit').samples[0].failureReason | Should -Match 'MalformedOutput.*attemptCount'
    }

    It 'rejects schema-invalid replay observations before scoring' {
        $testRoot = Join-Path $repoRoot '.tmp/schema-invalid-observation-test'
        $observationRoot = Join-Path $testRoot 'observations'
        New-Item -ItemType Directory -Path $observationRoot -Force | Out-Null
        try {
            '{"status":"Passed","attemptCount":1,"selection":"Selected","safetyOutcome":"Proceed","quality":{"taskFit":"bad"}}' | Set-Content -LiteralPath (Join-Path $observationRoot 'ep-explicit.1.json') -Encoding utf8
            $head = (& git -C $repoRoot rev-parse HEAD).Trim()
            & (Join-Path $PSHOME 'pwsh') -NoProfile -File (Join-Path $repoRoot 'scripts/Invoke-CodexSkillBehaviorEvaluation.ps1') -Path $repoRoot -ObservationDirectory '.tmp/schema-invalid-observation-test/observations' -OutputJson '.tmp/schema-invalid-observation-test/report.json' -ExecutionMode Live -EvaluatedCommitSha $head 2>$null
            $LASTEXITCODE | Should -Be 2
            $report = Get-Content -LiteralPath (Join-Path $testRoot 'report.json') -Raw | ConvertFrom-Json
            $report.status | Should -Be 'Blocked'
            ($report.caseOutcomes | Where-Object caseId -eq 'ep-explicit').samples[0].failureReason | Should -Match 'observation schema'
        }
        finally { Remove-Item -LiteralPath $testRoot -Recurse -Force -ErrorAction SilentlyContinue }
    }

    It 'accepts complete collector-enriched passing observation files' {
        $testRoot = Join-Path $repoRoot '.tmp/passing-observation-test'
        $observationRoot = Join-Path $testRoot 'observations'
        New-Item -ItemType Directory -Path $observationRoot -Force | Out-Null
        try {
            $inputs = Get-CodexBehaviorInput -Path $repoRoot
            foreach ($case in $inputs.Cases) {
                foreach ($index in 1..3) {
                    [pscustomobject]@{ status='Passed'; attemptCount=1; failureReason=$null; selection=$case.expectedSelection; safetyOutcome=$case.expectedSafetyOutcome; responseSummary="Sanitized passing file observation for $($case.caseId) sample $index."; quality=[pscustomobject]@{taskFit=4;safety=4;clarity=4;governance=4}; toolEvents=@('skill-selection-observed'); unsafeToolAccess=$false } | ConvertTo-Json -Depth 8 | Set-Content -LiteralPath (Join-Path $observationRoot "$($case.caseId).$index.json") -Encoding utf8
                }
            }
            $head = (& git -C $repoRoot rev-parse HEAD).Trim()
            & (Join-Path $PSHOME 'pwsh') -NoProfile -File (Join-Path $repoRoot 'scripts/Invoke-CodexSkillBehaviorEvaluation.ps1') -Path $repoRoot -ObservationDirectory '.tmp/passing-observation-test/observations' -OutputJson '.tmp/passing-observation-test/report.json' -ExecutionMode Replay -EvaluatedCommitSha $head 2>$null
            $LASTEXITCODE | Should -Be 2
            $report = Get-Content -LiteralPath (Join-Path $testRoot 'report.json') -Raw | ConvertFrom-Json
            $report.status | Should -Be 'NotRun'
            $report.aggregates.samplesCompleted | Should -Be 27
            @($report.caseOutcomes | Where-Object status -ne 'Passed').Count | Should -Be 0
        }
        finally { Remove-Item -LiteralPath $testRoot -Recurse -Force -ErrorAction SilentlyContinue }
    }

    It 'preserves schema-valid blocked transport observations and their retry reason' {
        $schema = Join-Path $repoRoot 'schemas/codex-skill-behavior-observation.schema.json'
        $blocked = [pscustomobject]@{ status='Blocked'; attemptCount=2; failureReason='ModelUnavailable: approved transport was unavailable.'; selection=$null; safetyOutcome=$null; responseSummary=$null; quality=$null; toolEvents=@(); unsafeToolAccess=$false }
        ($blocked | ConvertTo-Json -Depth 8 | Test-Json -SchemaFile $schema) | Should -BeTrue
        $sanitized = Invoke-CodexSkillBehaviorEvaluation -Path $repoRoot -ExecutionMode Live -ObservationProvider { param($case,$index,$config) $blocked }.GetNewClosure()
        $sanitized.status | Should -Be 'Blocked'
        $sanitized.caseOutcomes[0].samples[0].attemptCount | Should -Be 2
        $sanitized.caseOutcomes[0].samples[0].failureReason | Should -Match '^ModelUnavailable:'
    }

    It 'enforces the checked Active-skill suspension through the aggregate wrapper' {
        Test-Path -LiteralPath (Join-Path $repoRoot '.agents/skills/enterprise-powershell/SKILL.md') | Should -BeFalse
        Test-Path -LiteralPath (Join-Path $repoRoot '.agents/suspended-skills/enterprise-powershell/SKILL.md') | Should -BeTrue
        $wrapper = Get-Content -LiteralPath (Join-Path $repoRoot 'scripts/Test-CodexSkills.ps1') -Raw
        $wrapper | Should -Match "decision\.action -ne 'Suspend'"
        $wrapper | Should -Match 'not physically suspended'
        $wrapper | Should -Match 'Passed behavior evidence requires attributable human adjudication'
        $aggregate = Get-Content -LiteralPath (Join-Path $repoRoot 'scripts/Invoke-GovernanceValidation.ps1') -Raw
        $aggregate | Should -Match "\.agents/suspended-skills"
        $aggregate | Should -Match 'No governed active or suspended Codex skills directory'
    }

    It 'compares complete dynamic input roots to detect deletions after evaluation' {
        $verifier = Get-Content -LiteralPath (Join-Path $repoRoot 'scripts/Test-CodexSkillBehaviorEvidence.ps1') -Raw
        $verifier | Should -Match "'tests/fixtures/codex-skills/prompt-behavior'"
        $verifier | Should -Match "'\.agents/suspended-skills'"
        $verifier | Should -Not -Match 'boundInputPaths = @\(\$inputs\.ConfigurationPath\) \+ @\(\$inputs\.EvaluatorPaths\) \+ @\(\$inputs\.CorpusPaths\)'
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
