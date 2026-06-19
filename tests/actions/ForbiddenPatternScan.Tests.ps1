Describe 'Forbidden pattern scan' {
    Context 'advisory mode' {
        It 'runs without failing the repository in advisory mode' {
            & pwsh -NoProfile -File "$PSScriptRoot/../../actions/forbidden-pattern-scan/Invoke-ForbiddenPatternScan.ps1" -Path "$PSScriptRoot/../.." -Advisory
            $LASTEXITCODE | Should -Be 0
        }
    }
}
