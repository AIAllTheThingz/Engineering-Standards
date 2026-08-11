Describe 'Codex behavior manual hash diagnostic' {
    BeforeAll {
        $script:root = (Resolve-Path (Join-Path $PSScriptRoot '../..')).Path
        Import-Module (Join-Path $script:root 'scripts/CodexSkillBehaviorEvaluation.psm1') -Force
    }

    It 'emits the current manual bounded hashes for status-sync evidence refresh' {
        $inputs = Get-CodexBehaviorInput -Path $script:root
        $hashes = [ordered]@{
            configurationHash = Get-BoundedInputHash -Root $script:root -RelativePaths @($inputs.ConfigurationPath)
            evaluatorHash = Get-BoundedInputHash -Root $script:root -RelativePaths $inputs.EvaluatorPaths
            persistenceBoundaryHash = Get-BoundedInputHash -Root $script:root -RelativePaths $inputs.PersistenceBoundaryPaths
            corpusHash = Get-BoundedInputHash -Root $script:root -RelativePaths $inputs.CorpusPaths
            skillInputHash = Get-BoundedInputHash -Root $script:root -RelativePaths $inputs.SkillPaths
            authorityHash = Get-BoundedInputHash -Root $script:root -RelativePaths $inputs.AuthorityPaths
            evaluatedInputHash = Get-BoundedInputHash -Root $script:root -RelativePaths (Get-CodexBehaviorBoundInputPaths -Inputs $inputs)
        }
        Write-Host ('CODEX_MANUAL_HASH_DIAGNOSTIC=' + ($hashes | ConvertTo-Json -Compress))
        foreach ($value in $hashes.Values) {
            $value | Should -Match '^[0-9a-f]{64}$'
        }
    }
}
