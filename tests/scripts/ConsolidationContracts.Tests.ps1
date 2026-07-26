BeforeAll {
    $script:root = (Resolve-Path "$PSScriptRoot/../..").Path
    $script:standardsPath = Join-Path $script:root 'governance/standards-consistency.json'
    $script:standardsSchema = Join-Path $script:root 'schemas/standards-consistency.schema.json'
    $script:compatibilityPath = Join-Path $script:root 'governance/downstream-compatibility.json'
    $script:compatibilitySchema = Join-Path $script:root 'schemas/downstream-compatibility.schema.json'
}

Describe 'Consolidation contract regression coverage' {
    It 'validates both owned records against their current schemas' {
        (Get-Content -LiteralPath $script:standardsPath -Raw | Test-Json -SchemaFile $script:standardsSchema) | Should -BeTrue
        (Get-Content -LiteralPath $script:compatibilityPath -Raw | Test-Json -SchemaFile $script:compatibilitySchema) | Should -BeTrue
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

    It 'rejects a compatibility record that omits functional workflow authorities' {
        $matrix = Get-Content -LiteralPath $script:compatibilityPath -Raw | ConvertFrom-Json
        $matrix.unreleasedContract.PSObject.Properties.Remove('functionalWorkflows')
        ($matrix | ConvertTo-Json -Depth 30 | Test-Json -SchemaFile $script:compatibilitySchema) | Should -BeFalse
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

    It 'separates the published release from unselected next-release readiness' {
        $matrix = Get-Content -LiteralPath $script:standardsPath -Raw | ConvertFrom-Json
        $matrix.PSObject.Properties.Name | Should -Contain 'publishedRelease'
        $matrix.PSObject.Properties.Name | Should -Contain 'nextReleaseReadiness'
        $matrix.PSObject.Properties.Name | Should -Not -Contain 'releaseReadiness'

        $matrix.publishedRelease.status | Should -BeExactly 'Passed'
        $matrix.publishedRelease.version | Should -BeExactly '1.1.0'
        $matrix.publishedRelease.tag | Should -BeExactly 'v1.1.0'
        $matrix.publishedRelease.targetCommitSha | Should -BeExactly '2704049d7e826975d956611b194214dd79ea3686'
        $matrix.publishedRelease.releaseCreated | Should -BeTrue

        $matrix.nextReleaseReadiness.status | Should -BeExactly 'NotRun'
        $matrix.nextReleaseReadiness.proposedVersion | Should -BeNullOrEmpty
        $matrix.nextReleaseReadiness.proposedTag | Should -BeNullOrEmpty
        $matrix.nextReleaseReadiness.targetCommitSha | Should -BeNullOrEmpty
        $matrix.nextReleaseReadiness.reason | Should -Match 'no next semantic version'
    }

    It 'rejects published release values inside a NotRun next-release record' {
        $matrix = Get-Content -LiteralPath $script:standardsPath -Raw | ConvertFrom-Json
        $matrix.nextReleaseReadiness.proposedVersion = '1.1.0'
        $matrix.nextReleaseReadiness.proposedTag = 'v1.1.0'
        $matrix.nextReleaseReadiness.targetCommitSha = '2704049d7e826975d956611b194214dd79ea3686'
        ($matrix | ConvertTo-Json -Depth 30 | Test-Json -SchemaFile $script:standardsSchema) | Should -BeFalse
    }
}
