Describe 'Temporary Codex authority evidence refresh diagnostic' {
    BeforeAll {
        $script:repoRoot = (Resolve-Path -LiteralPath "$PSScriptRoot/../..").Path
        Import-Module (Join-Path $script:repoRoot 'scripts/CodexSkillBehaviorEvaluation.psm1') -Force
    }

    It 'writes recomputed blocked evidence into hosted governance artifacts' {
        $storedEvidencePath = Join-Path $script:repoRoot 'evidence/codex-skill-behavior.json'
        $storedEvidence = Get-Content -LiteralPath $storedEvidencePath -Raw | ConvertFrom-Json
        $storedForProvider = $storedEvidence
        $observationProvider = {
            param($case, $index, $config)
            $storedCase = @($storedForProvider.caseOutcomes | Where-Object caseId -eq $case.caseId)
            if ($storedCase.Count -ne 1) {
                return [pscustomobject]@{ status = 'Blocked'; failureReason = 'The stored case identity is missing or duplicated.' }
            }
            $storedSample = @($storedCase[0].samples | Where-Object sampleIndex -eq $index)
            if ($storedSample.Count -ne 1) {
                return [pscustomobject]@{ status = 'Blocked'; failureReason = 'The stored sample identity is missing or duplicated.' }
            }
            $storedSample[0]
        }.GetNewClosure()

        $headRef = [Environment]::GetEnvironmentVariable('GITHUB_HEAD_REF')
        $currentCommit = if ([string]::IsNullOrWhiteSpace($headRef)) {
            (& git -C $script:repoRoot rev-parse HEAD).Trim()
        }
        else {
            (& git -C $script:repoRoot rev-parse "origin/$headRef").Trim()
        }
        $refreshedEvidence = Invoke-CodexSkillBehaviorEvaluation `
            -Path $script:repoRoot `
            -ObservationProvider $observationProvider `
            -ExecutionMode $storedEvidence.executionMode `
            -RunnerVersion $storedEvidence.model.runnerVersion `
            -EvaluatedCommitSha $currentCommit

        $workflowEvidenceRoot = Join-Path (Split-Path -Parent $script:repoRoot) 'evidence'
        if (Test-Path -LiteralPath $workflowEvidenceRoot -PathType Container) {
            $refreshedEvidence | ConvertTo-Json -Depth 32 |
                Set-Content -LiteralPath (Join-Path $workflowEvidenceRoot 'codex-skill-behavior-refreshed.json') -Encoding utf8
            [ordered]@{
                schemaVersion = '1.0.0'
                authorityHash = $refreshedEvidence.authorityHash
                evaluatedCommitSha = $refreshedEvidence.evaluatedCommitSha
                status = $refreshedEvidence.status
            } | ConvertTo-Json -Depth 4 |
                Set-Content -LiteralPath (Join-Path $workflowEvidenceRoot 'authority-hash-diagnostic.json') -Encoding utf8
        }

        $refreshedEvidence.authorityHash | Should -Match '^[0-9a-f]{64}$'
        $refreshedEvidence.evaluatedCommitSha | Should -Be $currentCommit
        $refreshedEvidence.status | Should -Be 'Blocked'
        $refreshedEvidence.aggregates.samplesExpected | Should -Be 27
    }
}
