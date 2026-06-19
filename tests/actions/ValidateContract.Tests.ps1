Describe 'Validate contract action' {
    Context 'path safety' {
        It 'rejects traversal' {
            & pwsh -NoProfile -File "$PSScriptRoot/../../actions/validate-contract/Invoke-ContractValidation.ps1" -Path "$PSScriptRoot/../.." -ManifestPath '../outside.json'
            $LASTEXITCODE | Should -Not -Be 0
        }
    }
    Context 'valid repository' {
        It 'passes contract validation' {
            & pwsh -NoProfile -File "$PSScriptRoot/../../actions/validate-contract/Invoke-ContractValidation.ps1" -Path "$PSScriptRoot/../.."
            $LASTEXITCODE | Should -Be 0
        }
    }
}
