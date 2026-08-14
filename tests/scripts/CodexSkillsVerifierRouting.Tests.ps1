BeforeAll {
    $repoRoot = (Resolve-Path (Join-Path $PSScriptRoot '../..')).Path
}

Describe 'Codex skill behavior verifier runtime routing' {
    It 'routes enterprise-powershell through the Actions verifier at runtime' {
        $harnessRoot = Join-Path $TestDrive 'enterprise-verifier-routing'
        New-Item -ItemType Directory -Path $harnessRoot -Force | Out-Null

        Copy-Item -LiteralPath (Join-Path $repoRoot 'scripts/Test-CodexSkills.ps1') -Destination (Join-Path $harnessRoot 'Test-CodexSkills.ps1')
        Copy-Item -LiteralPath (Join-Path $repoRoot 'scripts/CodexSkillsValidation.psm1') -Destination (Join-Path $harnessRoot 'CodexSkillsValidation.psm1')

        @'
[CmdletBinding()]
param([string]$Path = '.')
Set-Content -LiteralPath $env:CODEX_ACTIONS_VERIFIER_MARKER -Value 'invoked' -Encoding utf8
exit 0
'@ | Set-Content -LiteralPath (Join-Path $harnessRoot 'Test-CodexSkillBehaviorActionsEvidence.ps1') -Encoding utf8

        @'
[CmdletBinding()]
param([string]$Path = '.')
Set-Content -LiteralPath $env:CODEX_LEGACY_VERIFIER_MARKER -Value 'invoked' -Encoding utf8
exit 99
'@ | Set-Content -LiteralPath (Join-Path $harnessRoot 'Test-CodexSkillBehaviorEvidence.ps1') -Encoding utf8

        $actionsMarker = Join-Path $TestDrive 'actions-verifier.marker'
        $legacyMarker = Join-Path $TestDrive 'legacy-verifier.marker'
        $previousActionsMarker = $env:CODEX_ACTIONS_VERIFIER_MARKER
        $previousLegacyMarker = $env:CODEX_LEGACY_VERIFIER_MARKER
        try {
            $env:CODEX_ACTIONS_VERIFIER_MARKER = $actionsMarker
            $env:CODEX_LEGACY_VERIFIER_MARKER = $legacyMarker

            & pwsh -NoProfile -File (Join-Path $harnessRoot 'Test-CodexSkills.ps1') -Path $repoRoot *> $null
            $exitCode = $LASTEXITCODE
        }
        finally {
            if ($null -eq $previousActionsMarker) { Remove-Item Env:CODEX_ACTIONS_VERIFIER_MARKER -ErrorAction SilentlyContinue }
            else { $env:CODEX_ACTIONS_VERIFIER_MARKER = $previousActionsMarker }
            if ($null -eq $previousLegacyMarker) { Remove-Item Env:CODEX_LEGACY_VERIFIER_MARKER -ErrorAction SilentlyContinue }
            else { $env:CODEX_LEGACY_VERIFIER_MARKER = $previousLegacyMarker }
        }

        $exitCode | Should -Be 0
        Test-Path -LiteralPath $actionsMarker -PathType Leaf | Should -BeTrue
        Test-Path -LiteralPath $legacyMarker | Should -BeFalse
    }
}
