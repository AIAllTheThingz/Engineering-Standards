BeforeDiscovery {
    $script:root = (Resolve-Path (Join-Path $PSScriptRoot '../..')).Path
    Import-Module (Join-Path $script:root 'scripts/CodexSkillBehaviorEvaluation.psm1') -Force
    $inputs = Get-CodexBehaviorInput -Path $script:root
    $script:evaluatedInputHash = Get-BoundedInputHash -Root $script:root -RelativePaths (Get-CodexBehaviorBoundInputPaths -Inputs $inputs)
}

Describe 'Codex behavior manual hash diagnostic' {
    It "CODEX_MANUAL_EVALUATED_INPUT_HASH=$script:evaluatedInputHash" {
        throw 'Intentional temporary diagnostic failure.'
    }
}
