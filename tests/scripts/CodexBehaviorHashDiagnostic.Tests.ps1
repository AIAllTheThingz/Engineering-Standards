BeforeDiscovery {
    $script:root = (Resolve-Path (Join-Path $PSScriptRoot '../..')).Path
    Import-Module (Join-Path $script:root 'scripts/CodexSkillBehaviorEvaluation.psm1') -Force
    $inputs = Get-CodexBehaviorInput -Path $script:root
    $script:skillInputHash = Get-BoundedInputHash -Root $script:root -RelativePaths $inputs.SkillPaths
    $script:evaluatedInputHash = Get-BoundedInputHash -Root $script:root -RelativePaths (Get-CodexBehaviorBoundInputPaths -Inputs $inputs)
}

Describe 'Temporary Codex behavior hash diagnostic' {
    It "CODEX_SKILL_INPUT_HASH=$script:skillInputHash" {
        throw 'Intentional temporary diagnostic failure.'
    }

    It "CODEX_EVALUATED_INPUT_HASH=$script:evaluatedInputHash" {
        throw 'Intentional temporary diagnostic failure.'
    }
}
