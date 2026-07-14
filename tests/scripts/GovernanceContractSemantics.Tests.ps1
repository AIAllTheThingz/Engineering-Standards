BeforeAll {
    Import-Module "$PSScriptRoot/../../scripts/GovernanceValidation.psm1" -Force
    $script:root = (Resolve-Path "$PSScriptRoot/../..").Path
    $script:manifest = Read-JsonFile -Path (Join-Path $script:root 'project-manifest.json')
    $script:config = Read-JsonFile -Path (Join-Path $script:root 'governance.config.json')
    function Copy-ContractObject([object]$Value) {
        $Value | ConvertTo-Json -Depth 30 | ConvertFrom-Json -AsHashtable
    }
    function Invoke-Semantics([hashtable]$Manifest, [hashtable]$Config, [string]$ExpectedRepository = 'AIAllTheThingz/Engineering-Standards', [string]$OwnerType = 'User', [string]$ExpectedSha = '94e975ec30440eada07250cd46d2252cec10d227', [string]$Interface = '1.0.0', [string]$Profile = 'standards-maintainer', [string]$Check = 'Governance / Governance validation', [string]$Root = $script:root) {
        @(Test-GovernanceContractSemantics -Root $Root -Manifest $Manifest -Config $Config -ExpectedRepository $ExpectedRepository -RepositoryOwnerType $OwnerType -ExpectedGovernanceCommitSha $ExpectedSha -ExpectedWorkflowInterfaceVersion $Interface -ExpectedWorkflowProfile $Profile -ExpectedRequiredCheckName $Check -ValidationDateUtc ([datetime]'2026-07-14T00:00:00Z'))
    }
}

Describe 'Governance contract semantic validation' {
    It 'accepts the coherent current repository contract' {
        $results = Invoke-Semantics (Copy-ContractObject $script:manifest) (Copy-ContractObject $script:config)
        @($results | Where-Object status -eq 'Failed').Count | Should -Be 0
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
}
