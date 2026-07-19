Describe 'Temporary Codex authority hash diagnostic' {
    BeforeAll {
        $script:repoRoot = (Resolve-Path -LiteralPath "$PSScriptRoot/../..").Path
        Import-Module (Join-Path $script:repoRoot 'scripts/CodexSkillBehaviorEvaluation.psm1') -Force
    }

    It 'records the current authority hash in hosted governance evidence' {
        $inputs = Get-CodexBehaviorInput -Path $script:repoRoot
        $authorityHash = Get-BoundedInputHash -Root $script:repoRoot -RelativePaths $inputs.AuthorityPaths

        $workflowEvidenceRoot = Join-Path (Split-Path -Parent $script:repoRoot) 'evidence'
        if (Test-Path -LiteralPath $workflowEvidenceRoot -PathType Container) {
            [ordered]@{
                schemaVersion = '1.0.0'
                authorityHash = $authorityHash
                evaluatedCommitSha = (& git -C $script:repoRoot rev-parse HEAD).Trim()
            } | ConvertTo-Json -Depth 4 |
                Set-Content -LiteralPath (Join-Path $workflowEvidenceRoot 'authority-hash-diagnostic.json') -Encoding utf8
        }

        $authorityHash | Should -Match '^[0-9a-f]{64}$'
    }
}
