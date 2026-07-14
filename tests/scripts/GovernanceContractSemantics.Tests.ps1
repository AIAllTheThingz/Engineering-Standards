BeforeAll {
    Import-Module "$PSScriptRoot/../../scripts/GovernanceValidation.psm1" -Force
    $script:root = (Resolve-Path "$PSScriptRoot/../..").Path
    $script:manifest = Read-JsonFile -Path (Join-Path $script:root 'project-manifest.json')
    $script:config = Read-JsonFile -Path (Join-Path $script:root 'governance.config.json')
    function Copy-ContractObject([object]$Value) {
        $Value | ConvertTo-Json -Depth 30 | ConvertFrom-Json -AsHashtable
    }
    function New-TestException([string]$Identifier = 'GOV-2026-ACTIVE', [string]$Status = 'Approved', [string]$AffectedControl = 'SyntheticControl', [string]$ApprovalDate = '2026-01-01', [string]$Expiration = '2026-12-31') {
        @{
            identifier = $Identifier
            status = $Status
            scope = 'Synthetic governance exception scope'
            owner = '@owner'
            approver = '@approver'
            approvalDate = $ApprovalDate
            expiration = $Expiration
            affectedControl = $AffectedControl
            compensatingControls = @('Synthetic compensating validation')
            remediationPlan = 'Remove the synthetic exception after remediation.'
            evidenceReference = 'evidence/exception.json'
        }
    }
    function New-TestOwner([string]$Type, [string]$Identifier) {
        @{
            type = $Type
            identifier = $Identifier
            responsibility = 'Owns the synthetic governance contract tests.'
            escalation = 'SECURITY.md'
        }
    }
    function Invoke-Semantics([hashtable]$Manifest, [hashtable]$Config, [string]$ExpectedRepository = 'AIAllTheThingz/Engineering-Standards', [string]$ExpectedStandardsRepository = 'AIAllTheThingz/Engineering-Standards', [string]$OwnerType = 'User', [string]$ExpectedSha = '02d696c2a39976a290137e1b24ca0eca68060ee3', [string]$Interface = '1.0.0', [string]$Profile = 'standards-maintainer', [string]$Check = 'Governance / Governance validation', [string]$Root = $script:root) {
        @(Test-GovernanceContractSemantics -Root $Root -Manifest $Manifest -Config $Config -ExpectedRepository $ExpectedRepository -ExpectedStandardsRepository $ExpectedStandardsRepository -RepositoryOwnerType $OwnerType -ExpectedGovernanceCommitSha $ExpectedSha -ExpectedWorkflowInterfaceVersion $Interface -ExpectedWorkflowProfile $Profile -ExpectedRequiredCheckName $Check -ValidationDateUtc ([datetime]'2026-07-14T00:00:00Z'))
    }
}

Describe 'Governance contract semantic validation' {
    It 'accepts the coherent current repository contract' {
        $results = Invoke-Semantics (Copy-ContractObject $script:manifest) (Copy-ContractObject $script:config)
        @($results | Where-Object status -eq 'Failed').Count | Should -Be 0
        $script:config.validationCategories | Should -Contain 'PowerShellParser'
    }

    It 'rejects malformed GitHub user identifiers without counting them as enforceable owners' -ForEach @(
        'not-a-handle', 'user', '@', '@-user', '@user-', '@user/team', '@user name'
    ) {
        $manifest = Copy-ContractObject $script:manifest
        $config = Copy-ContractObject $script:config
        $manifest.owners = @(New-TestOwner -Type 'github-user' -Identifier $_)
        $results = Invoke-Semantics $manifest $config
        ($results.message -join "`n") | Should -Match 'GCS003.*malformed.*github-user'
        ($results.message -join "`n") | Should -Match 'GCS003.*At least one GitHub user or team owner is required'
    }

    It 'rejects malformed GitHub team identifiers without counting them as enforceable owners' -ForEach @(
        '@organization', 'organization/team', '@organization/', '@organization/-team', '@organization/team-', '@organization/team name'
    ) {
        $manifest = Copy-ContractObject $script:manifest
        $config = Copy-ContractObject $script:config
        $manifest.repositoryOwnerType = 'Organization'
        $manifest.owners = @(New-TestOwner -Type 'github-team' -Identifier $_)
        $results = Invoke-Semantics $manifest $config -OwnerType 'Organization'
        ($results.message -join "`n") | Should -Match 'GCS003.*malformed.*github-team'
        ($results.message -join "`n") | Should -Match 'GCS003.*At least one GitHub user or team owner is required'
    }

    It 'rejects unknown structured owner types without counting them as enforceable owners' {
        $manifest = Copy-ContractObject $script:manifest
        $config = Copy-ContractObject $script:config
        $manifest.owners = @(New-TestOwner -Type 'github-organization' -Identifier '@example-org')
        $results = Invoke-Semantics $manifest $config
        ($results.message -join "`n") | Should -Match 'GCS003.*unsupported owner type'
        ($results.message -join "`n") | Should -Match 'GCS003.*At least one GitHub user or team owner is required'
    }

    It 'accepts valid structured GitHub owner identifiers' -ForEach @(
        @{ Type='github-user'; Identifier='@a'; RepositoryOwnerType='User' },
        @{ Type='github-user'; Identifier='@AIAllTheThingz'; RepositoryOwnerType='User' },
        @{ Type='github-user'; Identifier='@user-name'; RepositoryOwnerType='User' },
        @{ Type='github-team'; Identifier='@example-org/platform'; RepositoryOwnerType='Organization' },
        @{ Type='github-team'; Identifier='@example-org/security-review'; RepositoryOwnerType='Organization' }
    ) {
        $manifest = Copy-ContractObject $script:manifest
        $config = Copy-ContractObject $script:config
        $manifest.repositoryOwnerType = $RepositoryOwnerType
        $manifest.owners = @(New-TestOwner -Type $Type -Identifier $Identifier)
        $results = Invoke-Semantics $manifest $config -OwnerType $RepositoryOwnerType
        @($results | Where-Object { $_.message -match 'GCS003' }) | Should -HaveCount 0
    }

    It 'rejects a valid GitHub team owner for a user-owned repository' {
        $manifest = Copy-ContractObject $script:manifest
        $config = Copy-ContractObject $script:config
        $manifest.repositoryOwnerType = 'User'
        $manifest.owners = @(New-TestOwner -Type 'github-team' -Identifier '@example-org/platform')
        $results = Invoke-Semantics $manifest $config -OwnerType 'User'
        ($results.message -join "`n") | Should -Match 'GCS003.*team ownership is invalid for a user-owned repository'
    }

    It 'rejects workflow interface input and output mismatches without schema validation' -ForEach @(
        @{ Name='missing controlled-failure-test'; Mutate={ param($i) $i.inputs=@('project-path','governance-version','artifact-retention-days') } },
        @{ Name='renamed input'; Mutate={ param($i) $i.inputs=@('project-root','governance-version','artifact-retention-days','controlled-failure-test') } },
        @{ Name='extra input'; Mutate={ param($i) $i.inputs=@($i.inputs)+@('unexpected-input') } },
        @{ Name='duplicate input'; Mutate={ param($i) $i.inputs=@($i.inputs)+@('project-path') } },
        @{ Name='wrong-case input'; Mutate={ param($i) $i.inputs[0]='Project-Path' } },
        @{ Name='empty input'; Mutate={ param($i) $i.inputs[0]='' } },
        @{ Name='missing artifact-name'; Mutate={ param($i) $i.outputs=@('evidence-path') } },
        @{ Name='renamed output'; Mutate={ param($i) $i.outputs=@('evidence-path','artifact-id') } },
        @{ Name='extra output'; Mutate={ param($i) $i.outputs=@($i.outputs)+@('unexpected-output') } },
        @{ Name='duplicate output'; Mutate={ param($i) $i.outputs=@($i.outputs)+@('artifact-name') } },
        @{ Name='wrong-case output'; Mutate={ param($i) $i.outputs[0]='Evidence-Path' } },
        @{ Name='empty output'; Mutate={ param($i) $i.outputs[0]='' } }
    ) {
        $manifest = Copy-ContractObject $script:manifest
        $config = Copy-ContractObject $script:config
        & $Mutate $config.workflowInterface
        $results = Invoke-Semantics $manifest $config
        ($results.message -join "`n") | Should -Match 'GCS007.*do not exactly match' -Because $Name
    }

    It 'accepts exactly the supported workflow input and output sets' {
        $manifest = Copy-ContractObject $script:manifest
        $config = Copy-ContractObject $script:config
        $config.workflowInterface.inputs = @('controlled-failure-test','project-path','artifact-retention-days','governance-version')
        $config.workflowInterface.outputs = @('artifact-name','evidence-path')
        $results = Invoke-Semantics $manifest $config
        @($results | Where-Object { $_.message -match 'GCS007' }) | Should -HaveCount 0
    }

    It 'accepts both canonical maintainer checks in both arrays and preserves matching extras' {
        $manifest = Copy-ContractObject $script:manifest
        $config = Copy-ContractObject $script:config
        $checks = @(
            'Candidate implementation validation / Candidate implementation validation'
            'Additional trusted check / Validation'
            'Governance / Governance validation'
        )
        $config.requiredCheckNames = @($checks)
        $config.workflowInterface.requiredCheckNames = @($checks[2], $checks[0], $checks[1])
        $results = Invoke-Semantics $manifest $config
        @($results | Where-Object { $_.message -match 'GCS012' }) | Should -HaveCount 0
    }

    It 'rejects a canonical maintainer check omitted from both arrays' -ForEach @(
        @{ Name='Candidate'; Check='Candidate implementation validation / Candidate implementation validation' },
        @{ Name='Governance'; Check='Governance / Governance validation' }
    ) {
        $manifest = Copy-ContractObject $script:manifest
        $config = Copy-ContractObject $script:config
        $config.requiredCheckNames = @($config.requiredCheckNames | Where-Object { $_ -cne $Check })
        $config.workflowInterface.requiredCheckNames = @($config.workflowInterface.requiredCheckNames | Where-Object { $_ -cne $Check })
        $results = Invoke-Semantics $manifest $config -Check ''
        ($results.message -join "`n") | Should -Match "GCS012.*canonical check.*$([regex]::Escape($Check))" -Because $Name
    }

    It 'rejects a renamed Candidate maintainer check in both arrays' {
        $manifest = Copy-ContractObject $script:manifest
        $config = Copy-ContractObject $script:config
        $renamedCheck = 'Candidate implementation / Candidate implementation validation'
        $config.requiredCheckNames[1] = $renamedCheck
        $config.workflowInterface.requiredCheckNames[1] = $renamedCheck
        $results = Invoke-Semantics $manifest $config
        ($results.message -join "`n") | Should -Match 'GCS012.*canonical check.*Candidate implementation validation'
    }

    It 'rejects wrong case for the Governance maintainer check in both arrays' {
        $manifest = Copy-ContractObject $script:manifest
        $config = Copy-ContractObject $script:config
        $wrongCaseCheck = 'governance / Governance validation'
        $config.requiredCheckNames[0] = $wrongCaseCheck
        $config.workflowInterface.requiredCheckNames[0] = $wrongCaseCheck
        $results = Invoke-Semantics $manifest $config -Check ''
        ($results.message -join "`n") | Should -Match 'GCS012.*canonical check.*Governance / Governance validation'
    }

    It 'rejects required-check arrays that disagree as case-sensitive sets' {
        $manifest = Copy-ContractObject $script:manifest
        $config = Copy-ContractObject $script:config
        $config.workflowInterface.requiredCheckNames[1] = 'Renamed candidate check'
        $results = Invoke-Semantics $manifest $config
        ($results.message -join "`n") | Should -Match 'GCS012.*agree exactly as a case-sensitive set'
    }

    It 'rejects duplicate required checks even when both arrays contain the same duplicate' {
        $manifest = Copy-ContractObject $script:manifest
        $config = Copy-ContractObject $script:config
        $config.requiredCheckNames += 'Governance / Governance validation'
        $config.workflowInterface.requiredCheckNames += 'Governance / Governance validation'
        $results = Invoke-Semantics $manifest $config
        ($results.message -join "`n") | Should -Match 'GCS012.*must be unique'
    }

    It 'does not impose maintainer-only check names on the downstream profile' {
        $manifest = Copy-ContractObject $script:manifest
        $config = Copy-ContractObject $script:config
        $config.workflowProfile = 'downstream'
        $config.validationCategories = @('Contract', 'MarkdownLinks', 'DocumentationCompleteness', 'ForbiddenPatterns', 'CodexSkills')
        $config.requiredCheckNames = @('Downstream governance / Governance validation')
        $config.workflowInterface.requiredCheckNames = @('Downstream governance / Governance validation')
        $results = Invoke-Semantics $manifest $config -Profile 'downstream' -Check 'Downstream governance / Governance validation'
        @($results | Where-Object { $_.message -match 'GCS012' }) | Should -HaveCount 0
    }

    It 'preserves singular ExpectedRequiredCheckName compatibility for additional trusted checks' {
        $manifest = Copy-ContractObject $script:manifest
        $config = Copy-ContractObject $script:config
        $additionalCheck = 'Additional trusted check / Validation'
        $config.requiredCheckNames += $additionalCheck
        $config.workflowInterface.requiredCheckNames += $additionalCheck

        $presentResults = Invoke-Semantics $manifest $config -Check $additionalCheck
        @($presentResults | Where-Object { $_.message -match 'GCS012' }) | Should -HaveCount 0

        $missingResults = Invoke-Semantics $manifest $config -Check 'Missing trusted check / Validation'
        ($missingResults.message -join "`n") | Should -Match 'GCS012.*Missing trusted check / Validation.*absent'
    }

    It 'rejects every maintainer-only category for the downstream profile' -ForEach @(
        'JsonSchemas', 'YamlSyntax', 'WorkflowArchitecture', 'RepositoryHealth', 'Evidence', 'Examples', 'Pester', 'PSScriptAnalyzer', 'PowerShellParser'
    ) {
        $manifest = Copy-ContractObject $script:manifest
        $config = Copy-ContractObject $script:config
        $config.workflowProfile = 'downstream'
        $config.validationCategories = @('Contract', $_)
        $results = Invoke-Semantics $manifest $config -Profile 'downstream' -Check ''
        ($results.message -join "`n") | Should -Match "GCS008.*$_"
    }

    It 'binds central-reference repository and commit identity to trusted workflow context' -ForEach @(
        @{ Name='repository mismatch'; SourceRepository='Untrusted/Standards'; SourceSha='02d696c2a39976a290137e1b24ca0eca68060ee3'; GovernanceSha='02d696c2a39976a290137e1b24ca0eca68060ee3'; Pattern='trusted standards repository' },
        @{ Name='trusted SHA mismatch'; SourceRepository='AIAllTheThingz/Engineering-Standards'; SourceSha=('b' * 40); GovernanceSha=('b' * 40); Pattern='trusted workflow standards SHA' },
        @{ Name='governance SHA disagreement'; SourceRepository='AIAllTheThingz/Engineering-Standards'; SourceSha=('b' * 40); GovernanceSha='02d696c2a39976a290137e1b24ca0eca68060ee3'; Pattern='declared governance commit SHA' }
    ) {
        $manifest = Copy-ContractObject $script:manifest
        $config = Copy-ContractObject $script:config
        $manifest.standardsConsumption = @{ mode='central-reference'; sourceRepository=$SourceRepository; sourceCommitSha=$SourceSha }
        $manifest.governanceCommitSha = $GovernanceSha
        $config.governanceCommitSha = $GovernanceSha
        $expectedSha = if ($Name -eq 'trusted SHA mismatch') { '02d696c2a39976a290137e1b24ca0eca68060ee3' } else { $SourceSha }
        $results = Invoke-Semantics $manifest $config -ExpectedSha $expectedSha
        ($results.message -join "`n") | Should -Match "GCS004.*$Pattern" -Because $Name
    }

    It 'evaluates active manifest exceptions when authorizing a disabled configuration control' {
        $manifest = Copy-ContractObject $script:manifest
        $config = Copy-ContractObject $script:config
        $manifest.exceptions = @(New-TestException)
        $config.controls.mandatoryControlsDisabled = @(@{control='SyntheticControl';exceptionReference='GOV-2026-ACTIVE'})
        $results = Invoke-Semantics $manifest $config
        @($results | Where-Object { $_.message -match 'GCS01[01]' }) | Should -HaveCount 0
    }

    It 'rejects inactive manifest exception records' -ForEach @(
        @{ Name='expired'; Status='Approved'; Approval='2026-01-01'; Expiration='2026-07-01' },
        @{ Name='rejected'; Status='Rejected'; Approval='2026-01-01'; Expiration='2026-12-31' },
        @{ Name='revoked'; Status='Revoked'; Approval='2026-01-01'; Expiration='2026-12-31' },
        @{ Name='future approval'; Status='Approved'; Approval='2026-08-01'; Expiration='2026-12-31' }
    ) {
        $manifest = Copy-ContractObject $script:manifest
        $config = Copy-ContractObject $script:config
        $manifest.exceptions = @(New-TestException -Status $Status -ApprovalDate $Approval -Expiration $Expiration)
        $results = Invoke-Semantics $manifest $config
        ($results.message -join "`n") | Should -Match 'GCS010.*not an active' -Because $Name
    }

    It 'rejects malformed, legacy, and cross-document duplicate version 1.2.0 exceptions' -ForEach @(
        @{ Name='malformed'; Apply={ param($m,$c) $m.exceptions=@(@{identifier='bad'}) }; Pattern='GCS010.*malformed' },
        @{ Name='legacy string'; Apply={ param($m,$c) $m.exceptions=@('GOV-2026-LEGACY') }; Pattern='GCS010.*Legacy exception' },
        @{ Name='duplicate'; Apply={ param($m,$c) $m.exceptions=@(New-TestException); $c.exceptions=@(New-TestException) }; Pattern='GCS010.*Duplicate exception' }
    ) {
        $manifest = Copy-ContractObject $script:manifest
        $config = Copy-ContractObject $script:config
        & $Apply $manifest $config
        $results = Invoke-Semantics $manifest $config
        ($results.message -join "`n") | Should -Match $Pattern -Because $Name
    }

    It 'requires a disabled mandatory control to reference an active exception for the exact control' {
        $manifest = Copy-ContractObject $script:manifest
        $config = Copy-ContractObject $script:config
        $config.exceptions = @(New-TestException -AffectedControl 'DifferentControl')
        $config.controls.mandatoryControlsDisabled = @(@{control='SyntheticControl';exceptionReference='GOV-2026-ACTIVE'})
        $results = Invoke-Semantics $manifest $config
        ($results.message -join "`n") | Should -Match 'GCS011.*lacks an applicable active exception'
    }

    It 'reports stable finding IDs for cross-document contradictions' -ForEach @(
        @{ Id='GCS001'; Mutate={ param($m,$c) $m.repository='Other/repository' } },
        @{ Id='GCS002'; Mutate={ param($m,$c) $m.governanceCommitSha=('a' * 40) } },
        @{ Id='GCS003'; Mutate={ param($m,$c) $m.owners[0].type='github-team'; $m.owners[0].identifier='@ExampleOrg/team' } },
        @{ Id='GCS004'; Mutate={ param($m,$c) $m.standardsConsumption.mode='central-reference'; $m.standardsConsumption.Remove('localPath') } },
        @{ Id='GCS005'; Mutate={ param($m,$c) $m.applicableStandards=@($m.applicableStandards | Where-Object { $_ -ne 'agents/AGENTS_PowerShell.md' }); $c.applicableAgentStandards=$m.applicableStandards } },
        @{ Id='GCS006'; Mutate={ param($m,$c) $c.applicableAgentStandards=@('agents/AGENTS_Base.md') } },
        @{ Id='GCS007'; Mutate={ param($m,$c) $m.workflowInterfaceVersion='2.0.0' } },
        @{ Id='GCS008'; Mutate={ param($m,$c) $c.validationCategories=@('Contract') } },
        @{ Id='GCS009'; Mutate={ param($m,$c) $m.evidence.hosted.artifactNamePattern='wrong-${run_id}' } },
        @{ Id='GCS010'; Mutate={ param($m,$c) $c.exceptions=@(@{identifier='GOV-2026-EXPIRED';status='Approved';scope='Synthetic expired exception';owner='@owner';approver='@approver';approvalDate='2026-01-01';expiration='2026-07-01';affectedControl='SyntheticControl';compensatingControls=@('Synthetic compensating validation');remediationPlan='Remove the synthetic exception after remediation.';evidenceReference='evidence/exception.json'}) } },
        @{ Id='GCS011'; Mutate={ param($m,$c) $c.controls.mandatoryControlsDisabled=@(@{control='SyntheticControl';exceptionReference='GOV-2026-MISSING'}) } },
        @{ Id='GCS012'; Mutate={ param($m,$c) $c.requiredCheckNames=@('Other check') } }
    ) {
        $manifest = Copy-ContractObject $script:manifest
        $config = Copy-ContractObject $script:config
        & $Mutate $manifest $config
        $results = Invoke-Semantics $manifest $config
        ($results.message -join "`n") | Should -Match $Id
    }

    It 'reports GCS013 for an uncontrolled schema identifier' {
        $temp = Join-Path ([System.IO.Path]::GetTempPath()) ('schema-namespace-' + [guid]::NewGuid())
        try {
            New-Item -ItemType Directory -Path (Join-Path $temp 'schemas') -Force | Out-Null
            Set-Content -LiteralPath (Join-Path $temp 'AGENTS.md') -Value (Get-Content -Raw (Join-Path $script:root 'AGENTS.md'))
            Set-Content -LiteralPath (Join-Path $temp 'schemas/bad.schema.json') -Value '{"$id":"https://schemas.example/bad"}'
            $results = Invoke-Semantics (Copy-ContractObject $script:manifest) (Copy-ContractObject $script:config) -Root $temp
            ($results.message -join "`n") | Should -Match 'GCS013'
        }
        finally {
            if (Test-Path -LiteralPath $temp) { Remove-Item -LiteralPath $temp -Recurse -Force }
        }
    }

    It 'rejects named semantic compatibility fixtures' {
        $fixtureRoot = Join-Path $script:root 'tests/fixtures/contract-semantics/invalid'
        foreach ($fixturePath in Get-ChildItem -LiteralPath $fixtureRoot -Filter '*.json' | Sort-Object Name) {
            $fixture = Read-JsonFile -Path $fixturePath.FullName
            $manifest = Copy-ContractObject $script:manifest
            $config = Copy-ContractObject $script:config
            switch ($fixture.mutation) {
                'mismatched-standards' {
                    $config.applicableAgentStandards = @('agents/AGENTS_Base.md')
                }
                'expired-exception' {
                    $config.exceptions = @(@{
                        identifier = 'GOV-2026-EXPIRED'
                        status = 'Approved'
                        scope = 'Synthetic expired exception fixture'
                        owner = '@owner'
                        approver = '@approver'
                        approvalDate = '2026-01-01'
                        expiration = '2026-07-01'
                        affectedControl = 'SyntheticControl'
                        compensatingControls = @('Synthetic compensating validation')
                        remediationPlan = 'Remove the synthetic exception after remediation.'
                        evidenceReference = 'evidence/exception.json'
                    })
                }
                'hosted-evidence-path-mismatch' {
                    $manifest.evidence.hosted.artifactNamePattern = 'wrong-${run_id}'
                }
                default {
                    throw "Unknown semantic fixture mutation '$($fixture.mutation)' in $($fixturePath.Name)."
                }
            }
            $results = Invoke-Semantics $manifest $config
            ($results.message -join "`n") | Should -Match $fixture.expectedFinding -Because $fixture.name
        }
    }

    It 'accepts legacy 1.0.0 and 1.1.0 manifests' {
        foreach ($fixture in @('tests/fixtures/valid/project-manifest.json','tests/fixtures/compatibility/project-manifest-1.1.0.json')) {
            $results = Test-GovernanceJsonDocument -Path (Join-Path $script:root $fixture) -Kind project-manifest
            @($results | Where-Object status -eq 'Failed').Count | Should -Be 0 -Because $fixture
        }
    }

    It 'does not require 1.2-only fields from a legacy contract when trusted workflow context is supplied' {
        $manifest = Read-JsonFile -Path (Join-Path $script:root 'tests/fixtures/valid/project-manifest.json')
        $config = Read-JsonFile -Path (Join-Path $script:root 'tests/fixtures/valid/governance-config.json')
        $results = @(Test-GovernanceContractSemantics `
            -Root $script:root `
            -Manifest $manifest `
            -Config $config `
            -ExpectedRepository 'example-org/fixture' `
            -ExpectedGovernanceCommitSha ('a' * 40) `
            -ExpectedWorkflowInterfaceVersion '1.0.0' `
            -ExpectedWorkflowProfile 'downstream' `
            -ValidationDateUtc ([datetime]'2026-07-14T00:00:00Z'))

        @($results | Where-Object id -In @('GCS002', 'GCS007')) | Should -HaveCount 0
    }
}
