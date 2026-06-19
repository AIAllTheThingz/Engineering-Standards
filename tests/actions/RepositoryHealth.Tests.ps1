Describe 'Repository health' {
    Context 'rebuilt repository' {
        It 'passes repository health validation' {
            & pwsh -NoProfile -File "$PSScriptRoot/../../actions/repository-health/Invoke-RepositoryHealth.ps1" -Path "$PSScriptRoot/../.."
            $LASTEXITCODE | Should -Be 0
        }
    }
}
