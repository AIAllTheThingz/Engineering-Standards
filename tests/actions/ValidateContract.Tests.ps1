Describe 'Validate contract action' {
    BeforeAll {
        $script:tempRoot = Join-Path ([System.IO.Path]::GetTempPath()) ("contract-tests-" + [guid]::NewGuid())
        New-Item -ItemType Directory -Path $script:tempRoot -Force | Out-Null
    }

    AfterAll {
        if ($script:tempRoot -and (Test-Path -LiteralPath $script:tempRoot)) {
            Remove-Item -LiteralPath $script:tempRoot -Recurse -Force
        }
    }

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

    Context 'invalid downstream repository' {
        It 'fails when required documentation is missing' {
            Copy-Item -LiteralPath "$PSScriptRoot/../fixtures/valid/project-manifest.json" -Destination (Join-Path $script:tempRoot 'project-manifest.json')
            Copy-Item -LiteralPath "$PSScriptRoot/../fixtures/valid/governance-config.json" -Destination (Join-Path $script:tempRoot 'governance.config.json')
            New-Item -ItemType Directory -Path (Join-Path $script:tempRoot 'agents') -Force | Out-Null
            Copy-Item -LiteralPath "$PSScriptRoot/../../agents/AGENTS_Base.md" -Destination (Join-Path $script:tempRoot 'agents/AGENTS_Base.md')
            Copy-Item -LiteralPath "$PSScriptRoot/../../agents/AGENTS_PowerShell.md" -Destination (Join-Path $script:tempRoot 'agents/AGENTS_PowerShell.md')
            Copy-Item -LiteralPath "$PSScriptRoot/../../agents/AGENTS_Integration.md" -Destination (Join-Path $script:tempRoot 'agents/AGENTS_Integration.md')
            Copy-Item -LiteralPath "$PSScriptRoot/../../agents/AGENTS_Infrastructure.md" -Destination (Join-Path $script:tempRoot 'agents/AGENTS_Infrastructure.md')

            & pwsh -NoProfile -File "$PSScriptRoot/../../actions/validate-contract/Invoke-ContractValidation.ps1" -Path $script:tempRoot
            $LASTEXITCODE | Should -Not -Be 0
        }
    }
}
