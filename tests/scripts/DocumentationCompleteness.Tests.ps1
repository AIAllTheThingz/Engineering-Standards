Describe 'Documentation completeness' {
    Context 'repository documents' {
        It 'passes for the rebuilt repository' {
            & pwsh -NoProfile -File "$PSScriptRoot/../../scripts/Test-DocumentationCompleteness.ps1" -Path "$PSScriptRoot/../.."
            $LASTEXITCODE | Should -Be 0
        }
    }
}
