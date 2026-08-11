BeforeAll {
    $script:root = (Resolve-Path "$PSScriptRoot/../..").Path
    Import-Module (Join-Path $script:root 'scripts/GovernanceValidation.psm1') -Force
    $script:standardsPath = Join-Path $script:root 'governance/standards-consistency.json'
    $script:standardsSchema = Join-Path $script:root 'schemas/standards-consistency.schema.json'
    $script:compatibilityPath = Join-Path $script:root 'governance/downstream-compatibility.json'
    $script:compatibilitySchema = Join-Path $script:root 'schemas/downstream-compatibility.schema.json'
}

Describe 'Consolidation contract regression coverage' {
    It 'validates both owned version 1.1.0 records against their current schemas and semantics' {
        $standards = Get-Content -LiteralPath $script:standardsPath -Raw | ConvertFrom-Json
        $compatibility = Get-Content -LiteralPath $script:compatibilityPath -Raw | ConvertFrom-Json
        $standards.schemaVersion | Should -BeExactly '1.1.0'
        $compatibility.schemaVersion | Should -BeExactly '1.1.0'
        (Get-Content -LiteralPath $script:standardsPath -Raw | Test-Json -SchemaFile $script:standardsSchema) | Should -BeTrue
        (Get-Content -LiteralPath $script:compatibilityPath -Raw | Test-Json -SchemaFile $script:compatibilitySchema) | Should -BeTrue
        @((Test-GovernanceJsonDocument -Path $script:standardsPath -Kind standards-consistency) | Where-Object status -EQ Failed).Count | Should -Be 0
    }

    It 'preserves downstream compatibility schema 1.0.0 without functional workflows' {
        $matrix = Get-Content -LiteralPath $script:compatibilityPath -Raw | ConvertFrom-Json
        $matrix.schemaVersion = '1.0.0'
        $matrix.unreleasedContract.PSObject.Properties.Remove('functionalWorkflows')
        ($matrix | ConvertTo-Json -Depth 30 | Test-Json -SchemaFile $script:compatibilitySchema) | Should -BeTrue
    }

    It 'rejects unversioned functional workflow additions under compatibility schema 1.0.0' {
        $matrix = Get-Content -LiteralPath $script:compatibilityPath -Raw | ConvertFrom-Json
        $matrix.schemaVersion = '1.0.0'
        ($matrix | ConvertTo-Json -Depth 30 | Test-Json -SchemaFile $script:compatibilitySchema) | Should -BeFalse
    }

    It 'requires functional workflow authorities only for compatibility schema 1.1.0' {
        $matrix = Get-Content -LiteralPath $script:compatibilityPath -Raw | ConvertFrom-Json
        $matrix.unreleasedContract.PSObject.Properties.Remove('functionalWorkflows')
        ($matrix | ConvertTo-Json -Depth 30 | Test-Json -SchemaFile $script:compatibilitySchema) | Should -BeFalse
    }

    It 'records immutable Python and Bash functional workflow authorities' {
        $matrix = Get-Content -LiteralPath $script:compatibilityPath -Raw | ConvertFrom-Json
        $workflows = @($matrix.unreleasedContract.functionalWorkflows)
        $workflows.Count | Should -Be 2

        $expected = [ordered]@{
            python = [ordered]@{
                workflowPath = '.github/workflows/python-ci-reusable.yml'
                distributionTemplate = 'workflows/python-ci.yml'
                interfaceVersion = '1.0.0'
                immutableSha = 'e066df32a0deaee38fed4a4cd477d1f4b4b549ed'
            }
            bash = [ordered]@{
                workflowPath = '.github/workflows/bash-ci-reusable.yml'
                distributionTemplate = 'workflows/bash-ci.yml'
                interfaceVersion = '1.0.0'
                immutableSha = 'd55bb8e6778030f5490e900ba52ba99ac6403827'
            }
        }

        foreach ($language in $expected.Keys) {
            $entry = @($workflows | Where-Object language -CEQ $language)
            $entry.Count | Should -Be 1
            $entry[0].workflowPath | Should -BeExactly $expected[$language].workflowPath
            $entry[0].interfaceVersion | Should -BeExactly $expected[$language].interfaceVersion
            $entry[0].immutableSha | Should -BeExactly $expected[$language].immutableSha
            $entry[0].immutableSha | Should -Match '^[0-9a-f]{40}$'
            $entry[0].supportStatus | Should -BeExactly 'Preview'
            $entry[0].validationStatus | Should -BeExactly 'Passed'
            $entry[0].evidence.Length | Should -BeGreaterThan 20

            $template = Get-Content -LiteralPath (Join-Path $script:root $expected[$language].distributionTemplate) -Raw
            $template | Should -Match ([regex]::Escape("$($expected[$language].workflowPath)@$($expected[$language].immutableSha)"))
        }
    }

    It 'preserves mandatory cross-standard handoffs from the technology standards' {
        $matrix = Get-Content -LiteralPath $script:standardsPath -Raw | ConvertFrom-Json
        $expected = [ordered]@{
            'agents/AGENTS_PowerShell.md' = @('agents/AGENTS_DotNet.md','agents/AGENTS_Database.md','agents/AGENTS_Infrastructure.md','agents/AGENTS_Python.md','agents/AGENTS_Bash.md')
            'agents/AGENTS_DotNet.md' = @('agents/AGENTS_Python.md','agents/AGENTS_Bash.md','agents/AGENTS_Database.md','agents/AGENTS_WorkerService.md','agents/AGENTS_Integration.md','agents/AGENTS_WebFrontend.md')
            'agents/AGENTS_Database.md' = @('agents/AGENTS_DotNet.md','agents/AGENTS_PowerShell.md','agents/AGENTS_WorkerService.md','agents/AGENTS_Integration.md','agents/AGENTS_Infrastructure.md','agents/AGENTS_Python.md','agents/AGENTS_Bash.md')
            'agents/AGENTS_WorkerService.md' = @('agents/AGENTS_DotNet.md','agents/AGENTS_Database.md','agents/AGENTS_PowerShell.md','agents/AGENTS_Integration.md','agents/AGENTS_Infrastructure.md','agents/AGENTS_Python.md','agents/AGENTS_Bash.md')
            'agents/AGENTS_Integration.md' = @('agents/AGENTS_DotNet.md','agents/AGENTS_PowerShell.md','agents/AGENTS_Database.md','agents/AGENTS_WorkerService.md','agents/AGENTS_Infrastructure.md','agents/AGENTS_WebFrontend.md','agents/AGENTS_Python.md','agents/AGENTS_Bash.md')
            'agents/AGENTS_Infrastructure.md' = @('agents/AGENTS_PowerShell.md','agents/AGENTS_DotNet.md','agents/AGENTS_Database.md','agents/AGENTS_WorkerService.md','agents/AGENTS_Integration.md','agents/AGENTS_WebFrontend.md','agents/AGENTS_Python.md','agents/AGENTS_Bash.md')
            'agents/AGENTS_WebFrontend.md' = @('agents/AGENTS_DotNet.md','agents/AGENTS_Integration.md','agents/AGENTS_Infrastructure.md','agents/AGENTS_WorkerService.md','agents/AGENTS_Database.md','agents/AGENTS_PowerShell.md','agents/AGENTS_Python.md','agents/AGENTS_Bash.md')
            'agents/AGENTS_Python.md' = @('agents/AGENTS_WebFrontend.md','agents/AGENTS_Database.md','agents/AGENTS_WorkerService.md','agents/AGENTS_Integration.md','agents/AGENTS_Infrastructure.md','agents/AGENTS_PowerShell.md','agents/AGENTS_DotNet.md')
            'agents/AGENTS_Bash.md' = @('agents/AGENTS_Infrastructure.md','agents/AGENTS_Integration.md','agents/AGENTS_WorkerService.md','agents/AGENTS_Database.md','agents/AGENTS_PowerShell.md','agents/AGENTS_WebFrontend.md','agents/AGENTS_DotNet.md','agents/AGENTS_Python.md')
        }

        foreach ($path in $expected.Keys) {
            $entry = @($matrix.documents | Where-Object path -CEQ $path)
            $entry.Count | Should -Be 1
            @($entry[0].childOrHandoffStandards) | Should -BeExactly $expected[$path]
        }

        $integration = @($matrix.documents | Where-Object path -CEQ 'agents/AGENTS_Integration.md')[0]
        @($integration.parentDocuments) | Should -BeExactly @(
            'agents/AGENTS_Base.md',
            'governance/ORGANIZATION_CONTRACT.md',
            'governance/COMPLETION_EVIDENCE.md',
            'governance/RISK_CLASSIFICATION.md',
            'governance/EXCEPTION_PROCESS.md',
            'governance/AI_GENERATED_CODE_POLICY.md'
        )
    }

    It 'preserves the original standards-consistency 1.0.0 release-readiness shape' {
        $matrix = Get-Content -LiteralPath $script:standardsPath -Raw | ConvertFrom-Json
        $matrix.schemaVersion = '1.0.0'
        $matrix.PSObject.Properties.Remove('publishedRelease')
        $matrix.PSObject.Properties.Remove('nextReleaseReadiness')
        $matrix.releaseReadiness = [pscustomobject]@{
            status = 'NotRun'
            proposedVersion = '1.1.0'
            proposedTag = 'v1.1.0'
            targetCommitSha = '2704049d7e826975d956611b194214dd79ea3686'
            releaseCreated = $true
            reason = 'Synthetic legacy fixture retains the original schema 1.0.0 release-readiness object.'
        }
        $legacyPath = Join-Path $TestDrive 'standards-consistency-v1.0.json'
        $matrix | ConvertTo-Json -Depth 30 | Set-Content -LiteralPath $legacyPath -Encoding utf8
        (Get-Content -LiteralPath $legacyPath -Raw | Test-Json -SchemaFile $script:standardsSchema) | Should -BeTrue
        @((Test-GovernanceJsonDocument -Path $legacyPath -Kind standards-consistency) | Where-Object status -EQ Failed).Count | Should -Be 0
    }

    It 'rejects split release states when mislabeled as standards-consistency 1.0.0' {
        $matrix = Get-Content -LiteralPath $script:standardsPath -Raw | ConvertFrom-Json
        $matrix.schemaVersion = '1.0.0'
        ($matrix | ConvertTo-Json -Depth 30 | Test-Json -SchemaFile $script:standardsSchema) | Should -BeFalse
        $hybridPath = Join-Path $TestDrive 'standards-consistency-hybrid.json'
        $matrix | ConvertTo-Json -Depth 30 | Set-Content -LiteralPath $hybridPath -Encoding utf8
        $messages = @((Test-GovernanceJsonDocument -Path $hybridPath -Kind standards-consistency) | Where-Object status -EQ Failed | ForEach-Object message)
        $messages -join "`n" | Should -Match 'schema 1\.0\.0 must not contain'
    }

    It 'requires authoritative release states for standards-consistency 1.1.0 semantics' {
        $matrix = Get-Content -LiteralPath $script:standardsPath -Raw | ConvertFrom-Json
        $matrix.PSObject.Properties.Remove('publishedRelease')
        $matrix.PSObject.Properties.Remove('nextReleaseReadiness')
        $missingPath = Join-Path $TestDrive 'standards-consistency-v1.1-missing-release-states.json'
        $matrix | ConvertTo-Json -Depth 30 | Set-Content -LiteralPath $missingPath -Encoding utf8
        (Get-Content -LiteralPath $missingPath -Raw | Test-Json -SchemaFile $script:standardsSchema) | Should -BeFalse
        $messages = @((Test-GovernanceJsonDocument -Path $missingPath -Kind standards-consistency) | Where-Object status -EQ Failed | ForEach-Object message)
        $messages | Should -Contain "Standards-consistency schema 1.1.0 is missing required member 'publishedRelease'."
        $messages | Should -Contain "Standards-consistency schema 1.1.0 is missing required member 'nextReleaseReadiness'."
    }

    It 'separates the published release from prepared but not yet candidate-bound next-release readiness' {
        $matrix = Get-Content -LiteralPath $script:standardsPath -Raw | ConvertFrom-Json
        $repositoryVersion = (Get-Content -LiteralPath (Join-Path $script:root 'VERSION') -Raw).Trim()
        $matrix.repositoryVersion | Should -BeExactly $repositoryVersion
        $repositoryVersion | Should -BeExactly '1.2.0'
        $matrix.publishedRelease.status | Should -BeExactly 'Passed'
        $matrix.publishedRelease.version | Should -BeExactly '1.1.0'
        $matrix.publishedRelease.tag | Should -BeExactly 'v1.1.0'
        $matrix.publishedRelease.targetCommitSha | Should -BeExactly '2704049d7e826975d956611b194214dd79ea3686'
        $matrix.publishedRelease.releaseCreated | Should -BeTrue

        $matrix.nextReleaseReadiness.status | Should -BeExactly 'NotRun'
        $matrix.nextReleaseReadiness.proposedVersion | Should -BeNullOrEmpty
        $matrix.nextReleaseReadiness.proposedTag | Should -BeNullOrEmpty
        $matrix.nextReleaseReadiness.targetCommitSha | Should -BeNullOrEmpty
        $matrix.nextReleaseReadiness.reason | Should -Match 'Version 1\.2\.0 is selected.*readiness record remains NotRun'

        $matrix.releaseReadiness.status | Should -BeExactly 'NotApplicable'
        @($matrix.releaseReadiness.PSObject.Properties.Name) | Should -Be @('status','reason')
    }

    It 'rejects published release values inside a NotRun next-release record' {
        $matrix = Get-Content -LiteralPath $script:standardsPath -Raw | ConvertFrom-Json
        $matrix.nextReleaseReadiness.proposedVersion = '1.1.0'
        $matrix.nextReleaseReadiness.proposedTag = 'v1.1.0'
        $matrix.nextReleaseReadiness.targetCommitSha = '2704049d7e826975d956611b194214dd79ea3686'
        ($matrix | ConvertTo-Json -Depth 30 | Test-Json -SchemaFile $script:standardsSchema) | Should -BeFalse
    }

    It 'rejects release candidate fields on the deprecated compatibility alias' {
        $matrix = Get-Content -LiteralPath $script:standardsPath -Raw | ConvertFrom-Json
        $matrix.releaseReadiness | Add-Member -NotePropertyName proposedVersion -NotePropertyValue '1.1.0'
        ($matrix | ConvertTo-Json -Depth 30 | Test-Json -SchemaFile $script:standardsSchema) | Should -BeFalse
        $aliasPath = Join-Path $TestDrive 'standards-consistency-alias-mutation.json'
        $matrix | ConvertTo-Json -Depth 30 | Set-Content -LiteralPath $aliasPath -Encoding utf8
        $messages = @((Test-GovernanceJsonDocument -Path $aliasPath -Kind standards-consistency) | Where-Object status -EQ Failed | ForEach-Object message)
        $messages -join "`n" | Should -Match "alias must not contain 'proposedVersion'"
    }
}
