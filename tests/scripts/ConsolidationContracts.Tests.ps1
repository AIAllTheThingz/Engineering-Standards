BeforeAll {
    $script:root = (Resolve-Path "$PSScriptRoot/../..").Path
    Import-Module (Join-Path $script:root 'scripts/GovernanceValidation.psm1') -Force
    $script:standardsPath = Join-Path $script:root 'governance/standards-consistency.json'
    $script:standardsSchema = Join-Path $script:root 'schemas/standards-consistency.schema.json'
    $script:compatibilityPath = Join-Path $script:root 'governance/downstream-compatibility.json'
    $script:compatibilitySchema = Join-Path $script:root 'schemas/downstream-compatibility.schema.json'
}

Describe 'Consolidation contract regression coverage' {
    It 'validates both owned records against their current schemas and semantic validator' {
        (Get-Content -LiteralPath $script:standardsPath -Raw | Test-Json -SchemaFile $script:standardsSchema) | Should -BeTrue
        (Get-Content -LiteralPath $script:compatibilityPath -Raw | Test-Json -SchemaFile $script:compatibilitySchema) | Should -BeTrue
        @((Test-GovernanceJsonDocument -Path $script:standardsPath -Kind 'standards-consistency') | Where-Object status -EQ Failed).Count | Should -Be 0
    }

    It 'preserves historical downstream compatibility 1.0.0 records without functional workflow entries' {
        $legacy = Get-Content -LiteralPath $script:compatibilityPath -Raw | ConvertFrom-Json
        $legacy.unreleasedContract.PSObject.Properties.Remove('functionalWorkflows')
        ($legacy | ConvertTo-Json -Depth 30 | Test-Json -SchemaFile $script:compatibilitySchema) | Should -BeTrue
    }

    It 'requires functional workflow authorities in the repository-owned compatibility record' {
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
            $entry[0].supportStatus | Should -BeExactly 'Preview'
            $entry[0].validationStatus | Should -BeExactly 'Passed'
            $entry[0].evidence.Length | Should -BeGreaterThan 20

            $template = Get-Content -LiteralPath (Join-Path $script:root $expected[$language].distributionTemplate) -Raw
            $template | Should -Match ([regex]::Escape("$($expected[$language].workflowPath)@$($expected[$language].immutableSha)"))
        }
    }

    It 'preserves the original standards consistency 1.0.0 release-readiness shape' {
        $legacy = Get-Content -LiteralPath $script:standardsPath -Raw | ConvertFrom-Json
        $legacy.PSObject.Properties.Remove('publishedRelease')
        $legacy.PSObject.Properties.Remove('nextReleaseReadiness')
        $legacy.releaseReadiness = [pscustomobject]@{
            status = 'NotRun'
            proposedVersion = '1.1.0'
            proposedTag = 'v1.1.0'
            targetCommitSha = '2704049d7e826975d956611b194214dd79ea3686'
            releaseCreated = $true
            reason = 'Historical version 1.0.0 record retained for compatibility testing.'
        }
        ($legacy | ConvertTo-Json -Depth 30 | Test-Json -SchemaFile $script:standardsSchema) | Should -BeTrue
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
    }

    It 'requires the split release state in the repository-owned standards record' {
        $matrix = Get-Content -LiteralPath $script:standardsPath -Raw | ConvertFrom-Json
        $matrix.publishedRelease.status | Should -BeExactly 'Passed'
        $matrix.publishedRelease.version | Should -BeExactly '1.1.0'
        $matrix.publishedRelease.tag | Should -BeExactly 'v1.1.0'
        $matrix.nextReleaseReadiness.status | Should -BeExactly 'NotRun'
        $matrix.nextReleaseReadiness.proposedVersion | Should -BeNullOrEmpty
        $matrix.nextReleaseReadiness.proposedTag | Should -BeNullOrEmpty
        $matrix.nextReleaseReadiness.targetCommitSha | Should -BeNullOrEmpty
        $matrix.releaseReadiness.status | Should -BeExactly 'NotApplicable'
    }

    It 'rejects published release values inside a NotRun next-release record' {
        $matrix = Get-Content -LiteralPath $script:standardsPath -Raw | ConvertFrom-Json
        $matrix.nextReleaseReadiness.proposedVersion = '1.1.0'
        $matrix.nextReleaseReadiness.proposedTag = 'v1.1.0'
        $matrix.nextReleaseReadiness.targetCommitSha = '2704049d7e826975d956611b194214dd79ea3686'
        ($matrix | ConvertTo-Json -Depth 30 | Test-Json -SchemaFile $script:standardsSchema) | Should -BeFalse
    }
}
