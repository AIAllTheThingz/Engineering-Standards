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

        It 'fails Contract-only validation when <Mode> provenance relies on trusted central files' -ForEach @(
            @{ Mode='local' },
            @{ Mode='vendored' }
        ) {
            $callerRoot = Join-Path $script:tempRoot ("false-provenance-$Mode-" + [guid]::NewGuid())
            New-Item -ItemType Directory -Path (Join-Path $callerRoot 'agents') -Force | Out-Null
            Copy-Item -LiteralPath "$PSScriptRoot/../../AGENTS.md" -Destination (Join-Path $callerRoot 'AGENTS.md')

            $manifest = Get-Content -LiteralPath "$PSScriptRoot/../../project-manifest.json" -Raw | ConvertFrom-Json -AsHashtable
            $config = Get-Content -LiteralPath "$PSScriptRoot/../../governance.config.json" -Raw | ConvertFrom-Json -AsHashtable
            $manifest.standardsConsumption = @{ mode=$Mode; localPath='agents' }
            if ($Mode -eq 'vendored') {
                $manifest.standardsConsumption.sourceRepository = 'ExampleOrg/Vendored-Standards'
                $manifest.standardsConsumption.sourceCommitSha = ('b' * 40)
            }
            $config.requiredDocumentationPaths = @('AGENTS.md')
            $manifest | ConvertTo-Json -Depth 30 | Set-Content -LiteralPath (Join-Path $callerRoot 'project-manifest.json')
            $config | ConvertTo-Json -Depth 30 | Set-Content -LiteralPath (Join-Path $callerRoot 'governance.config.json')

            $output = @(& pwsh -NoProfile -File "$PSScriptRoot/../../actions/validate-contract/Invoke-ContractValidation.ps1" `
                -Path $callerRoot `
                -ExpectedRepository 'AIAllTheThingz/Engineering-Standards' `
                -ExpectedStandardsRepository 'AIAllTheThingz/Engineering-Standards' `
                -RepositoryOwnerType User `
                -ExpectedGovernanceCommitSha 'f378c4b64d3d79d96cd2874d543696dd52e6283d' `
                -ExpectedWorkflowInterfaceVersion '1.0.0' `
                -ExpectedWorkflowProfile 'standards-maintainer' `
                -ExpectedRequiredCheckName 'Governance / Governance validation')

            $LASTEXITCODE | Should -Not -Be 0
            ($output -join "`n") | Should -Match 'GCS004.*regular file.*authoritative'
        }

        It 'passes Contract-only validation for a complete <Mode> authoritative standards tree' -ForEach @(
            @{ Mode='local' },
            @{ Mode='vendored' }
        ) {
            $callerRoot = Join-Path $script:tempRoot ("valid-provenance-$Mode-" + [guid]::NewGuid())
            New-Item -ItemType Directory -Path (Join-Path $callerRoot 'agents') -Force | Out-Null
            Copy-Item -LiteralPath "$PSScriptRoot/../../AGENTS.md" -Destination (Join-Path $callerRoot 'AGENTS.md')
            foreach ($name in @('AGENTS_Base.md','AGENTS_PowerShell.md','AGENTS_Integration.md','AGENTS_Infrastructure.md')) {
                Copy-Item -LiteralPath (Join-Path "$PSScriptRoot/../../agents" $name) -Destination (Join-Path $callerRoot "agents/$name")
            }

            $manifest = Get-Content -LiteralPath "$PSScriptRoot/../../project-manifest.json" -Raw | ConvertFrom-Json -AsHashtable
            $config = Get-Content -LiteralPath "$PSScriptRoot/../../governance.config.json" -Raw | ConvertFrom-Json -AsHashtable
            $manifest.standardsConsumption = @{ mode=$Mode; localPath='agents' }
            if ($Mode -eq 'vendored') {
                $manifest.standardsConsumption.sourceRepository = 'ExampleOrg/Vendored-Standards'
                $manifest.standardsConsumption.sourceCommitSha = ('b' * 40)
            }
            $config.requiredDocumentationPaths = @('AGENTS.md')
            $manifest | ConvertTo-Json -Depth 30 | Set-Content -LiteralPath (Join-Path $callerRoot 'project-manifest.json')
            $config | ConvertTo-Json -Depth 30 | Set-Content -LiteralPath (Join-Path $callerRoot 'governance.config.json')

            & pwsh -NoProfile -File "$PSScriptRoot/../../actions/validate-contract/Invoke-ContractValidation.ps1" `
                -Path $callerRoot `
                -ExpectedRepository 'AIAllTheThingz/Engineering-Standards' `
                -ExpectedStandardsRepository 'AIAllTheThingz/Engineering-Standards' `
                -RepositoryOwnerType User `
                -ExpectedGovernanceCommitSha 'f378c4b64d3d79d96cd2874d543696dd52e6283d' `
                -ExpectedWorkflowInterfaceVersion '1.0.0' `
                -ExpectedWorkflowProfile 'standards-maintainer' `
                -ExpectedRequiredCheckName 'Governance / Governance validation'

            $LASTEXITCODE | Should -Be 0
        }
    }
}
