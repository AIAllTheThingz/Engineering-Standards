Describe 'Codex behavior evidence hash diagnostic' {
    It 'prints the current bounded hashes required to refresh Replay evidence' {
        $root = (Resolve-Path (Join-Path $PSScriptRoot '../..')).Path
        Import-Module (Join-Path $root 'scripts/CodexSkillBehaviorEvaluation.psm1') -Force

        $inputs = Get-CodexBehaviorInput -Path $root
        $skillInputHash = Get-BoundedInputHash -Root $root -RelativePaths $inputs.SkillPaths
        $evaluatedInputHash = Get-BoundedInputHash -Root $root -RelativePaths (Get-CodexBehaviorBoundInputPaths -Inputs $inputs)

        throw "HASH_DIAGNOSTIC skillInputHash=$skillInputHash evaluatedInputHash=$evaluatedInputHash"
    }
}
