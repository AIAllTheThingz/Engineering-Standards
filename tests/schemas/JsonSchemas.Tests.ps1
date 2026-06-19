Describe 'JSON schema validation' {
    Context 'fixtures' {
        It 'accepts valid fixtures and rejects invalid fixtures' {
            & pwsh -NoProfile -File "$PSScriptRoot/../../scripts/Test-JsonSchemas.ps1" -Path "$PSScriptRoot/../.."
            $LASTEXITCODE | Should -Be 0
        }
    }
}
