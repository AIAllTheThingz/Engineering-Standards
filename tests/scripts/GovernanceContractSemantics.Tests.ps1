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
    function Invoke-Semantics([hashtable]$Manifest, [hashtable]$Config, [string]$ExpectedRepository = 'AIAllTheThingz/Engineering-Standards', [string]$ExpectedStandardsRepository = 'AIAllTheThingz/Engineering-Standards', [string]$OwnerType = 'User', [string]$ExpectedSha = '6df785074523a9b59566ac80410891552fe5eb4d', [string]$Interface = '1.0.0', [string]$Profile = 'standards-maintainer', [string]$Check = 'Governance / Governance validation', [string]$Root = $script:root) {
        @(Test-GovernanceContractSemantics -Root $Root -Manifest $Manifest -Config $Config -ExpectedRepository $ExpectedRepository -ExpectedStandardsRepository $ExpectedStandardsRepository -RepositoryOwnerType $OwnerType -ExpectedGovernanceCommitSha $ExpectedSha -ExpectedWorkflowInterfaceVersion $Interface -ExpectedWorkflowProfile $Profile -ExpectedRequiredCheckName $Check -ValidationDateUtc ([datetime]'2026-07-14T00:00:00Z'))
    }
    function New-IsolatedStandardsRoot([string[]]$Standards = @('agents/AGENTS_Base.md','agents/AGENTS_PowerShell.md','agents/AGENTS_Integration.md','agents/AGENTS_Infrastructure.md')) {
        $root = Join-Path ([System.IO.Path]::GetTempPath()) ('governance-provenance-' + [guid]::NewGuid())
        New-Item -ItemType Directory -Path (Join-Path $root 'agents') -Force | Out-Null
        Copy-Item -LiteralPath (Join-Path $script:root 'AGENTS.md') -Destination (Join-Path $root 'AGENTS.md')
        foreach ($standard in $Standards) {
            $target = Join-Path $root $standard
            New-Item -ItemType Directory -Path (Split-Path -Parent $target) -Force | Out-Null
            Set-Content -LiteralPath $target -Value "# Synthetic $standard"
        }
        $root
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

    It 'rejects schema-invalid structured email contacts during Contract-only validation' -ForEach @(
        'a@b.c', 'ops!@example.com', 'ops@example.1', 'ops@example'
    ) {
        $manifest = Copy-ContractObject $script:manifest
        $config = Copy-ContractObject $script:config
        $manifest.owners = @(
            (New-TestOwner -Type 'github-user' -Identifier '@AIAllTheThingz'),
            (New-TestOwner -Type 'email-contact' -Identifier $_)
        )
        $results = Invoke-Semantics $manifest $config
        ($results.message -join "`n") | Should -Match 'GCS003.*malformed.*email-contact'
    }

    It 'accepts structured email contacts that match the project-manifest schema' -ForEach @(
        'governance@example.com', 'governance.ops+alerts@example.co.uk'
    ) {
        $manifest = Copy-ContractObject $script:manifest
        $config = Copy-ContractObject $script:config
        $manifest.owners = @(
            (New-TestOwner -Type 'github-user' -Identifier '@AIAllTheThingz'),
            (New-TestOwner -Type 'email-contact' -Identifier $_)
        )
        $results = Invoke-Semantics $manifest $config
        @($results | Where-Object { $_.message -match 'GCS003' }) | Should -HaveCount 0
    }

    It 'rejects noncanonical repository owner type casing' -ForEach @(
        @{ Declared='user'; Trusted='User'; OwnerType='github-user'; Identifier='@AIAllTheThingz' },
        @{ Declared='organization'; Trusted='Organization'; OwnerType='github-team'; Identifier='@example-org/platform' }
    ) {
        $manifest = Copy-ContractObject $script:manifest
        $config = Copy-ContractObject $script:config
        $manifest.repositoryOwnerType = $Declared
        $manifest.owners = @(New-TestOwner -Type $OwnerType -Identifier $Identifier)
        $results = Invoke-Semantics $manifest $config -OwnerType $Trusted
        ($results.message -join "`n") | Should -Match 'GCS003.*repositoryOwnerType.*unsupported or noncanonical'
    }

    It 'rejects mixed manifest and configuration schema versions when either opts into 1.2.0' -ForEach @(
        @{ ManifestVersion='1.2.0'; ConfigVersion='1.1.0' },
        @{ ManifestVersion='1.1.0'; ConfigVersion='1.2.0' }
    ) {
        $manifest = Copy-ContractObject $script:manifest
        $config = Copy-ContractObject $script:config
        $manifest.schemaVersion = $ManifestVersion
        $config.schemaVersion = $ConfigVersion
        $results = Invoke-Semantics $manifest $config
        ($results.message -join "`n") | Should -Match 'GCS002.*schema versions must both be 1\.2\.0'
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

    It 'rejects noncanonical workflow profile casing' -ForEach @('Downstream', 'Standards-Maintainer') {
        $manifest = Copy-ContractObject $script:manifest
        $config = Copy-ContractObject $script:config
        $config.workflowProfile = $_
        $results = Invoke-Semantics $manifest $config -Profile 'downstream' -Check ''
        ($results.message -join "`n") | Should -Match 'GCS007.*Workflow profile.*unsupported or noncanonical'
    }

    It 'rejects noncanonical workflow interface constants' -ForEach @(
        @{ Name='path'; Mutate={ param($i) $i.path='.github/workflows/Governance-ci-reusable.yml' } },
        @{ Name='job id'; Mutate={ param($i) $i.jobId='Governance' } },
        @{ Name='job name'; Mutate={ param($i) $i.jobName='governance validation' } },
        @{ Name='artifact pattern'; Mutate={ param($i) $i.artifactNamePattern='Governance-evidence-${run_id}' } }
    ) {
        $manifest = Copy-ContractObject $script:manifest
        $config = Copy-ContractObject $script:config
        & $Mutate $config.workflowInterface
        $results = Invoke-Semantics $manifest $config
        ($results.message -join "`n") | Should -Match 'GCS007.*Workflow interface declaration conflicts' -Because $Name
    }

    It 'rejects noncanonical project type casing' {
        $manifest = Copy-ContractObject $script:manifest
        $config = Copy-ContractObject $script:config
        $manifest.projectType = 'Governance'
        $results = Invoke-Semantics $manifest $config
        ($results.message -join "`n") | Should -Match 'GCS005.*Project type.*unsupported or noncanonical'
    }

    It 'rejects noncanonical hosted-evidence constants' -ForEach @(
        @{ Name='workspace'; Mutate={ param($h) $h.workspace='Evidence' } },
        @{ Name='completion'; Mutate={ param($h) $h.completion='Completion-result.json' } },
        @{ Name='tests'; Mutate={ param($h) $h.tests='CI-test-results.json' } },
        @{ Name='artifact pattern'; Mutate={ param($h) $h.artifactNamePattern='Governance-evidence-${run_id}' } }
    ) {
        $manifest = Copy-ContractObject $script:manifest
        $config = Copy-ContractObject $script:config
        & $Mutate $manifest.evidence.hosted
        $results = Invoke-Semantics $manifest $config
        ($results.message -join "`n") | Should -Match 'GCS009.*Hosted evidence declaration conflicts' -Because $Name
    }

    It 'rejects schema-invalid local evidence paths during Contract-only validation' -ForEach @(
        'C:\\evidence.json', '\\server\\share.json', '/etc/evidence.json',
        'evidence/../completion-result.json', 'evidence/completion-result.JSON', 'evidence/completion-result.txt'
    ) {
        $manifest = Copy-ContractObject $script:manifest
        $config = Copy-ContractObject $script:config
        $manifest.evidence.local.completion = $_
        $results = Invoke-Semantics $manifest $config
        ($results.message -join "`n") | Should -Match 'GCS009.*schema-valid repository-relative JSON path'
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

    It 'rejects an empty downstream validation category declaration' {
        $manifest = Copy-ContractObject $script:manifest
        $config = Copy-ContractObject $script:config
        $config.workflowProfile = 'downstream'
        $config.validationCategories = @()
        $results = Invoke-Semantics $manifest $config -Profile 'downstream' -Check ''

        ($results.message -join "`n") |
            Should -Match "(?m)^GCS008 Downstream profile validationCategories declaration must be nonempty and include mandatory category 'Contract'\.$"
    }

    It 'rejects a downstream optional-only declaration that omits Contract' {
        $manifest = Copy-ContractObject $script:manifest
        $config = Copy-ContractObject $script:config
        $config.workflowProfile = 'downstream'
        $config.validationCategories = @('MarkdownLinks')
        $results = Invoke-Semantics $manifest $config -Profile 'downstream' -Check ''

        ($results.message -join "`n") |
            Should -Match "(?m)^GCS008 Downstream profile validationCategories declaration must include mandatory category 'Contract'\.$"
    }

    It 'rejects noncanonical downstream validation category casing' -ForEach @(
        @{ Categories=@('contract'); Noncanonical='contract'; RequiresContract=$true },
        @{ Categories=@('Contract', 'markdownlinks'); Noncanonical='markdownlinks'; RequiresContract=$false }
    ) {
        $manifest = Copy-ContractObject $script:manifest
        $config = Copy-ContractObject $script:config
        $config.workflowProfile = 'downstream'
        $config.validationCategories = @($Categories)
        $results = Invoke-Semantics $manifest $config -Profile 'downstream' -Check ''
        $messages = $results.message -join "`n"

        $messages |
            Should -Match "(?m)^GCS008 Unsupported validation category '$Noncanonical'\.$"
        if ($RequiresContract) {
            $messages |
                Should -Match "(?m)^GCS008 Downstream profile validationCategories declaration must include mandatory category 'Contract'\.$"
        }
    }

    It 'accepts a downstream declaration that includes Contract' -ForEach @(
        @{ Categories = @('Contract') },
        @{ Categories = @('Contract', 'MarkdownLinks') }
    ) {
        $manifest = Copy-ContractObject $script:manifest
        $config = Copy-ContractObject $script:config
        $config.workflowProfile = 'downstream'
        $config.validationCategories = @($Categories)
        $results = Invoke-Semantics $manifest $config -Profile 'downstream' -Check ''

        ($results.message -join "`n") | Should -Not -Match '(?m)^GCS008\s'
    }

    It 'proves the anchored GCS008 selector rejects a finding-free downstream result' {
        $manifest = Copy-ContractObject $script:manifest
        $config = Copy-ContractObject $script:config
        $config.workflowProfile = 'downstream'
        $config.validationCategories = @('Contract')
        $results = Invoke-Semantics $manifest $config -Profile 'downstream' -Check ''

        { ($results.message -join "`n") | Should -Match '(?m)^GCS008\s' } |
            Should -Throw
    }

    It 'preserves standards-maintainer category completeness enforcement' {
        $manifest = Copy-ContractObject $script:manifest
        $config = Copy-ContractObject $script:config
        $config.validationCategories = @($config.validationCategories | Where-Object { $_ -ne 'PowerShellParser' })
        $results = Invoke-Semantics $manifest $config

        ($results.message -join "`n") |
            Should -Match "(?m)^GCS008 Maintainer profile omits executed category 'PowerShellParser'\.$"
    }

    It 'binds central-reference repository and commit identity to trusted workflow context' -ForEach @(
        @{ Name='repository mismatch'; SourceRepository='Untrusted/Standards'; SourceSha='6df785074523a9b59566ac80410891552fe5eb4d'; GovernanceSha='6df785074523a9b59566ac80410891552fe5eb4d'; Pattern='trusted standards repository' },
        @{ Name='trusted SHA mismatch'; SourceRepository='AIAllTheThingz/Engineering-Standards'; SourceSha=('b' * 40); GovernanceSha=('b' * 40); Pattern='trusted workflow standards SHA' },
        @{ Name='governance SHA disagreement'; SourceRepository='AIAllTheThingz/Engineering-Standards'; SourceSha=('b' * 40); GovernanceSha='6df785074523a9b59566ac80410891552fe5eb4d'; Pattern='declared governance commit SHA' }
    ) {
        $manifest = Copy-ContractObject $script:manifest
        $config = Copy-ContractObject $script:config
        $manifest.standardsConsumption = @{ mode='central-reference'; sourceRepository=$SourceRepository; sourceCommitSha=$SourceSha }
        $manifest.governanceCommitSha = $GovernanceSha
        $config.governanceCommitSha = $GovernanceSha
        $expectedSha = if ($Name -eq 'trusted SHA mismatch') { '6df785074523a9b59566ac80410891552fe5eb4d' } else { $SourceSha }
        $results = Invoke-Semantics $manifest $config -ExpectedSha $expectedSha
        ($results.message -join "`n") | Should -Match "GCS004.*$Pattern" -Because $Name
    }

    It 'enforces the central-reference standards-consumption field contract without schema validation' -ForEach @(
        @{ Name='missing source repository'; Mutate={ param($s) $s.Remove('sourceRepository') }; Pattern='sourceRepository.*required' },
        @{ Name='blank source repository'; Mutate={ param($s) $s.sourceRepository=' ' }; Pattern='sourceRepository.*owner/repository' },
        @{ Name='malformed source repository'; Mutate={ param($s) $s.sourceRepository='owner/repository/extra' }; Pattern='sourceRepository.*owner/repository' },
        @{ Name='missing source commit'; Mutate={ param($s) $s.Remove('sourceCommitSha') }; Pattern='sourceCommitSha.*40 hexadecimal' },
        @{ Name='short source commit'; Mutate={ param($s) $s.sourceCommitSha='abc123' }; Pattern='sourceCommitSha.*40 hexadecimal' },
        @{ Name='forbidden local path'; Mutate={ param($s) $s.localPath='agents' }; Pattern='central-reference.*localPath' },
        @{ Name='unknown field'; Mutate={ param($s) $s.unexpected='value' }; Pattern='unsupported field.*unexpected' }
    ) {
        $manifest = Copy-ContractObject $script:manifest
        $config = Copy-ContractObject $script:config
        $manifest.standardsConsumption = @{
            mode = 'central-reference'
            sourceRepository = 'AIAllTheThingz/Engineering-Standards'
            sourceCommitSha = '6df785074523a9b59566ac80410891552fe5eb4d'
        }
        & $Mutate $manifest.standardsConsumption
        $results = Invoke-Semantics $manifest $config
        ($results.message -join "`n") | Should -Match "GCS004.*$Pattern" -Because $Name
    }

    It 'accepts a complete central-reference standards-consumption contract' {
        $manifest = Copy-ContractObject $script:manifest
        $config = Copy-ContractObject $script:config
        $manifest.standardsConsumption = @{
            mode = 'central-reference'
            sourceRepository = 'AIAllTheThingz/Engineering-Standards'
            sourceCommitSha = '6df785074523a9b59566ac80410891552fe5eb4d'
        }
        $results = Invoke-Semantics $manifest $config
        @($results | Where-Object { $_.message -match 'GCS004' }) | Should -HaveCount 0
    }

    It 'accepts complete vendored source identity without binding it to trusted checkout identity' {
        $isolatedRoot = New-IsolatedStandardsRoot
        try {
        $manifest = Copy-ContractObject $script:manifest
        $config = Copy-ContractObject $script:config
        $manifest.standardsConsumption = @{
            mode = 'vendored'
            sourceRepository = 'ExampleOrg/Vendored-Standards'
            sourceCommitSha = ('b' * 40)
            localPath = 'agents'
        }
        $results = Invoke-Semantics $manifest $config -Root $isolatedRoot
        @($results | Where-Object { $_.message -match 'GCS004' }) | Should -HaveCount 0
        }
        finally { Remove-Item -LiteralPath $isolatedRoot -Recurse -Force }
    }

    It 'accepts a complete isolated local standards tree without central identity fields' {
        $isolatedRoot = New-IsolatedStandardsRoot
        try {
            $manifest = Copy-ContractObject $script:manifest
            $config = Copy-ContractObject $script:config
            $manifest.standardsConsumption = @{ mode='local'; localPath='agents' }
            $results = Invoke-Semantics $manifest $config -Root $isolatedRoot
            @($results | Where-Object { $_.message -match 'GCS004' }) | Should -HaveCount 0
        }
        finally { Remove-Item -LiteralPath $isolatedRoot -Recurse -Force }
    }

    It 'rejects incomplete authoritative local and vendored standards trees' -ForEach @(
        @{ Name='empty local tree'; Mode='local'; Present=@() },
        @{ Name='empty vendored tree'; Mode='vendored'; Present=@() },
        @{ Name='partial local tree'; Mode='local'; Present=@('agents/AGENTS_Base.md') },
        @{ Name='partial vendored tree'; Mode='vendored'; Present=@('agents/AGENTS_Base.md') },
        @{ Name='local missing base'; Mode='local'; Present=@('agents/AGENTS_PowerShell.md','agents/AGENTS_Integration.md','agents/AGENTS_Infrastructure.md') },
        @{ Name='vendored missing technology standard'; Mode='vendored'; Present=@('agents/AGENTS_Base.md','agents/AGENTS_Integration.md','agents/AGENTS_Infrastructure.md') }
    ) {
        $isolatedRoot = New-IsolatedStandardsRoot -Standards $Present
        try {
            $manifest = Copy-ContractObject $script:manifest
            $config = Copy-ContractObject $script:config
            $manifest.standardsConsumption = @{ mode=$Mode; localPath='agents' }
            if ($Mode -eq 'vendored') {
                $manifest.standardsConsumption.sourceRepository = 'ExampleOrg/Vendored-Standards'
                $manifest.standardsConsumption.sourceCommitSha = ('b' * 40)
            }
            $results = Invoke-Semantics $manifest $config -Root $isolatedRoot
            ($results.message -join "`n") | Should -Match 'GCS004.*regular file.*authoritative' -Because $Name
        }
        finally { Remove-Item -LiteralPath $isolatedRoot -Recurse -Force }
    }

    It 'rejects malformed applicable-standard declarations during Contract-only semantics' -ForEach @(
        @{ Name='blank'; Value=@('agents/AGENTS_Base.md',' ') },
        @{ Name='null'; Value=@('agents/AGENTS_Base.md',$null) },
        @{ Name='non-string'; Value=@('agents/AGENTS_Base.md',42) },
        @{ Name='duplicate'; Value=@('agents/AGENTS_Base.md','agents/AGENTS_Base.md') },
        @{ Name='absolute'; Value=@('agents/AGENTS_Base.md',[System.IO.Path]::GetFullPath('agents/AGENTS_PowerShell.md')) },
        @{ Name='traversal'; Value=@('agents/AGENTS_Base.md','agents/../AGENTS.md') },
        @{ Name='outside authoritative root'; Value=@('agents/AGENTS_Base.md','AGENTS.md') }
    ) {
        $isolatedRoot = New-IsolatedStandardsRoot
        try {
            $manifest = Copy-ContractObject $script:manifest
            $config = Copy-ContractObject $script:config
            $manifest.standardsConsumption = @{ mode='local'; localPath='agents' }
            $manifest.applicableStandards = $Value
            $config.applicableAgentStandards = $Value
            $results = Invoke-Semantics $manifest $config -Root $isolatedRoot
            ($results.message -join "`n") | Should -Match 'GCS004' -Because $Name
        }
        finally { Remove-Item -LiteralPath $isolatedRoot -Recurse -Force }
    }

    It 'rejects invalid <Document> standards collection shape <Case>' -ForEach @(
        @{ Document='manifest'; Case='missing'; Value='__missing__' },
        @{ Document='manifest'; Case='null'; Value=$null },
        @{ Document='manifest'; Case='empty'; Value=@() },
        @{ Document='manifest'; Case='scalar string'; Value='agents/AGENTS_Base.md' },
        @{ Document='manifest'; Case='object'; Value=@{path='agents/AGENTS_Base.md'} },
        @{ Document='config'; Case='missing'; Value='__missing__' },
        @{ Document='config'; Case='null'; Value=$null },
        @{ Document='config'; Case='empty'; Value=@() },
        @{ Document='config'; Case='scalar string'; Value='agents/AGENTS_Base.md' },
        @{ Document='config'; Case='object'; Value=@{path='agents/AGENTS_Base.md'} }
    ) {
        $isolatedRoot = New-IsolatedStandardsRoot
        try {
            $manifest = Copy-ContractObject $script:manifest
            $config = Copy-ContractObject $script:config
            $manifest.standardsConsumption = @{ mode='local'; localPath='agents' }
            $target = if ($Document -eq 'manifest') { $manifest } else { $config }
            $member = if ($Document -eq 'manifest') { 'applicableStandards' } else { 'applicableAgentStandards' }
            if ($Value -eq '__missing__') { $target.Remove($member) }
            else { $target[$member] = $Value }
            $results = Invoke-Semantics $manifest $config -Root $isolatedRoot
            ($results.message -join "`n") | Should -Match 'GCS004.*nonempty array' -Because "$Document $Case"
        }
        finally { Remove-Item -LiteralPath $isolatedRoot -Recurse -Force }
    }

    It 'rejects a regular file used as the authoritative localPath' {
        $isolatedRoot = New-IsolatedStandardsRoot
        try {
            Set-Content -LiteralPath (Join-Path $isolatedRoot 'standards-file') -Value 'not a directory'
            $manifest = Copy-ContractObject $script:manifest
            $config = Copy-ContractObject $script:config
            $manifest.standardsConsumption = @{ mode='local'; localPath='standards-file' }
            $results = Invoke-Semantics $manifest $config -Root $isolatedRoot
            ($results.message -join "`n") | Should -Match 'GCS004.*authoritative.*directory'
        }
        finally { Remove-Item -LiteralPath $isolatedRoot -Recurse -Force }
    }

    It 'rejects a <Mode> applicable standard target that is a directory' -ForEach @(
        @{ Mode='local' },
        @{ Mode='vendored' }
    ) {
        $isolatedRoot = New-IsolatedStandardsRoot
        try {
            Remove-Item -LiteralPath (Join-Path $isolatedRoot 'agents/AGENTS_Base.md') -Force
            New-Item -ItemType Directory -Path (Join-Path $isolatedRoot 'agents/AGENTS_Base.md') | Out-Null
            $manifest = Copy-ContractObject $script:manifest
            $config = Copy-ContractObject $script:config
            $manifest.standardsConsumption = @{ mode=$Mode; localPath='agents' }
            if ($Mode -eq 'vendored') {
                $manifest.standardsConsumption.sourceRepository = 'ExampleOrg/Vendored-Standards'
                $manifest.standardsConsumption.sourceCommitSha = ('b' * 40)
            }
            $results = Invoke-Semantics $manifest $config -Root $isolatedRoot
            ($results.message -join "`n") | Should -Match 'GCS004.*regular file'
        }
        finally { Remove-Item -LiteralPath $isolatedRoot -Recurse -Force }
    }

    It 'rejects a <Mode> applicable standard target that traverses a symbolic link or reparse point' -ForEach @(
        @{ Mode='local' },
        @{ Mode='vendored' }
    ) {
        $isolatedRoot = New-IsolatedStandardsRoot
        $outsideFile = Join-Path ([System.IO.Path]::GetTempPath()) ('outside-standard-' + [guid]::NewGuid() + '.md')
        try {
            Set-Content -LiteralPath $outsideFile -Value '# Outside authority boundary'
            $linkPath = Join-Path $isolatedRoot 'agents/AGENTS_Base.md'
            Remove-Item -LiteralPath $linkPath -Force
            try { New-Item -ItemType SymbolicLink -Path $linkPath -Target $outsideFile -ErrorAction Stop | Out-Null }
            catch { Set-ItResult -Skipped -Because "Symbolic-link creation is unavailable: $($_.Exception.Message)"; return }

            $manifest = Copy-ContractObject $script:manifest
            $config = Copy-ContractObject $script:config
            $manifest.standardsConsumption = @{ mode=$Mode; localPath='agents' }
            if ($Mode -eq 'vendored') {
                $manifest.standardsConsumption.sourceRepository = 'ExampleOrg/Vendored-Standards'
                $manifest.standardsConsumption.sourceCommitSha = ('b' * 40)
            }
            $results = Invoke-Semantics $manifest $config -Root $isolatedRoot
            ($results.message -join "`n") | Should -Match 'GCS004.*symbolic link|GCS004.*reparse|GCS004.*regular file'
        }
        finally {
            if (Test-Path -LiteralPath $isolatedRoot) { Remove-Item -LiteralPath $isolatedRoot -Recurse -Force }
            if (Test-Path -LiteralPath $outsideFile) { Remove-Item -LiteralPath $outsideFile -Force }
        }
    }

    It 'enforces the vendored standards-consumption field and bounded-path contract without schema validation' -ForEach @(
        @{ Name='missing repository'; Mutate={ param($s) $s.Remove('sourceRepository') }; Pattern='sourceRepository.*required' },
        @{ Name='malformed repository'; Mutate={ param($s) $s.sourceRepository='/repository' }; Pattern='sourceRepository.*owner/repository' },
        @{ Name='missing commit'; Mutate={ param($s) $s.Remove('sourceCommitSha') }; Pattern='sourceCommitSha.*40 hexadecimal' },
        @{ Name='missing local path'; Mutate={ param($s) $s.Remove('localPath') }; Pattern='localPath.*required' },
        @{ Name='rooted local path'; Mutate={ param($s) $s.localPath=(Resolve-Path $script:root).Path }; Pattern='repository-relative' },
        @{ Name='traversal local path'; Mutate={ param($s) $s.localPath='../outside' }; Pattern='repository-relative' },
        @{ Name='missing local source'; Mutate={ param($s) $s.localPath='does-not-exist' }; Pattern='does not exist' }
    ) {
        $manifest = Copy-ContractObject $script:manifest
        $config = Copy-ContractObject $script:config
        $manifest.standardsConsumption = @{
            mode = 'vendored'
            sourceRepository = 'ExampleOrg/Vendored-Standards'
            sourceCommitSha = ('b' * 40)
            localPath = 'agents'
        }
        & $Mutate $manifest.standardsConsumption
        $results = Invoke-Semantics $manifest $config
        ($results.message -join "`n") | Should -Match "GCS004.*$Pattern" -Because $Name
    }

    It 'enforces the local standards-consumption field and bounded-path contract without schema validation' -ForEach @(
        @{ Name='missing local path'; Mutate={ param($s) $s.Remove('localPath') }; Pattern='localPath.*required' },
        @{ Name='blank local path'; Mutate={ param($s) $s.localPath=' ' }; Pattern='localPath.*required' },
        @{ Name='source repository forbidden'; Mutate={ param($s) $s.sourceRepository='ExampleOrg/Standards' }; Pattern='local.*sourceRepository' },
        @{ Name='source commit forbidden'; Mutate={ param($s) $s.sourceCommitSha=('b' * 40) }; Pattern='local.*sourceCommitSha' },
        @{ Name='traversal local path'; Mutate={ param($s) $s.localPath='agents/../../outside' }; Pattern='repository-relative' },
        @{ Name='missing local source'; Mutate={ param($s) $s.localPath='does-not-exist' }; Pattern='does not exist' }
    ) {
        $manifest = Copy-ContractObject $script:manifest
        $config = Copy-ContractObject $script:config
        $manifest.standardsConsumption = @{ mode='local'; localPath='agents' }
        & $Mutate $manifest.standardsConsumption
        $results = Invoke-Semantics $manifest $config
        ($results.message -join "`n") | Should -Match "GCS004.*$Pattern" -Because $Name
    }

    It 'rejects a missing or unknown standards-consumption mode without schema validation' -ForEach @(
        @{ Name='missing'; Mutate={ param($s) $s.Remove('mode') } },
        @{ Name='blank'; Mutate={ param($s) $s.mode=' ' } },
        @{ Name='unknown'; Mutate={ param($s) $s.mode='remote' } }
    ) {
        $manifest = Copy-ContractObject $script:manifest
        $config = Copy-ContractObject $script:config
        & $Mutate $manifest.standardsConsumption
        $results = Invoke-Semantics $manifest $config
        ($results.message -join "`n") | Should -Match 'GCS004.*mode.*unsupported' -Because $Name
    }

    It 'rejects a missing standards-consumption object without schema validation' {
        $manifest = Copy-ContractObject $script:manifest
        $config = Copy-ContractObject $script:config
        $manifest.Remove('standardsConsumption')
        $results = Invoke-Semantics $manifest $config
        ($results.message -join "`n") | Should -Match 'GCS004.*standardsConsumption.*object'
    }

    It 'rejects a local standards path that traverses a reparse point without schema validation' {
        $tempRoot = Join-Path ([System.IO.Path]::GetTempPath()) ('governance-standards-reparse-' + [guid]::NewGuid())
        $physicalPath = Join-Path $tempRoot 'physical-standards'
        $linkPath = Join-Path $tempRoot 'linked-standards'
        try {
            New-Item -ItemType Directory -Path $physicalPath -Force | Out-Null
            if ($IsWindows) {
                New-Item -ItemType Junction -Path $linkPath -Target $physicalPath | Out-Null
            }
            else {
                New-Item -ItemType SymbolicLink -Path $linkPath -Target $physicalPath | Out-Null
            }
            $manifest = Copy-ContractObject $script:manifest
            $config = Copy-ContractObject $script:config
            $manifest.standardsConsumption = @{ mode='local'; localPath='linked-standards' }
            $results = Invoke-Semantics $manifest $config -Root $tempRoot
            ($results.message -join "`n") | Should -Match 'GCS004.*symbolic link or junction'
        }
        finally {
            if (Test-Path -LiteralPath $linkPath) { Remove-Item -LiteralPath $linkPath -Force }
            if (Test-Path -LiteralPath $tempRoot) { Remove-Item -LiteralPath $tempRoot -Recurse -Force }
        }
    }

    It 'rejects invalid downstream required-check arrays without schema validation' -ForEach @(
        @{ Name='both empty'; Required=@(); Interface=@(); Pattern='nonempty array' },
        @{ Name='branch-protection empty'; Required=@(); Interface=@('Valid check'); Pattern='Config.requiredCheckNames.*nonempty array' },
        @{ Name='workflow-interface empty'; Required=@('Valid check'); Interface=@(); Pattern='Config.workflowInterface.requiredCheckNames.*nonempty array' },
        @{ Name='null member'; Required=@($null, 'Valid check'); Interface=@($null, 'Valid check'); Pattern='non-null string' },
        @{ Name='non-string member'; Required=@(42, 'Valid check'); Interface=@(42, 'Valid check'); Pattern='non-null string' },
        @{ Name='whitespace member'; Required=@('   ', 'Valid check'); Interface=@('   ', 'Valid check'); Pattern='must not be blank' },
        @{ Name='too short'; Required=@('ab'); Interface=@('ab'); Pattern='between 3 and 160' },
        @{ Name='too long'; Required=@(('x' * 161)); Interface=@(('x' * 161)); Pattern='between 3 and 160' },
        @{ Name='duplicate'; Required=@('Valid check', 'Valid check'); Interface=@('Valid check', 'Valid check'); Pattern='must be unique' },
        @{ Name='case mismatch'; Required=@('Valid Check'); Interface=@('valid Check'); Pattern='case-sensitive set' },
        @{ Name='value mismatch'; Required=@('Valid check'); Interface=@('Different check'); Pattern='case-sensitive set' }
    ) {
        $manifest = Copy-ContractObject $script:manifest
        $config = Copy-ContractObject $script:config
        $config.workflowProfile = 'downstream'
        $config.validationCategories = @('Contract', 'MarkdownLinks', 'DocumentationCompleteness', 'ForbiddenPatterns', 'CodexSkills')
        if ($null -eq $Required) { $config.requiredCheckNames = @() }
        else { $config.requiredCheckNames = @($Required) }
        if ($null -eq $Interface) { $config.workflowInterface.requiredCheckNames = @() }
        else { $config.workflowInterface.requiredCheckNames = @($Interface) }
        $results = Invoke-Semantics $manifest $config -Profile 'downstream' -Check ''
        ($results.message -join "`n") | Should -Match "GCS012.*$Pattern" -Because $Name
    }

    It 'rejects missing or scalar downstream required-check arrays without schema validation' -ForEach @(
        @{ Name='missing branch-protection array'; Mutate={ param($c) $c.Remove('requiredCheckNames') } },
        @{ Name='missing interface array'; Mutate={ param($c) $c.workflowInterface.Remove('requiredCheckNames') } },
        @{ Name='scalar branch-protection value'; Mutate={ param($c) $c.requiredCheckNames='Valid check' } },
        @{ Name='scalar interface value'; Mutate={ param($c) $c.workflowInterface.requiredCheckNames='Valid check' } }
    ) {
        $manifest = Copy-ContractObject $script:manifest
        $config = Copy-ContractObject $script:config
        $config.workflowProfile = 'downstream'
        $config.validationCategories = @('Contract', 'MarkdownLinks', 'DocumentationCompleteness', 'ForbiddenPatterns', 'CodexSkills')
        $config.requiredCheckNames = @('Valid check')
        $config.workflowInterface.requiredCheckNames = @('Valid check')
        & $Mutate $config
        $results = Invoke-Semantics $manifest $config -Profile 'downstream' -Check ''
        ($results.message -join "`n") | Should -Match 'GCS012.*nonempty array' -Because $Name
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

    It 'rejects noncanonical exception status casing' {
        $manifest = Copy-ContractObject $script:manifest
        $config = Copy-ContractObject $script:config
        $manifest.exceptions = @(New-TestException -Status 'approved')
        $results = Invoke-Semantics $manifest $config
        ($results.message -join "`n") | Should -Match 'GCS010.*status.*unsupported or noncanonical'
    }

    It 'rejects platform-independent rooted exception evidence paths' -ForEach @(
        'C:\\waiver.md', '\\server\\share', '/etc/waiver.md'
    ) {
        $manifest = Copy-ContractObject $script:manifest
        $config = Copy-ContractObject $script:config
        $exception = New-TestException
        $exception.evidenceReference = $_
        $config.exceptions = @($exception)
        $config.controls.mandatoryControlsDisabled = @(@{control='SyntheticControl';exceptionReference='GOV-2026-ACTIVE'})
        $results = Invoke-Semantics $manifest $config
        ($results.message -join "`n") | Should -Match 'GCS010.*malformed'
        ($results.message -join "`n") | Should -Match 'GCS011.*lacks an applicable active exception'
    }

    It 'rejects schema-invalid exception field types and unsupported fields' -ForEach @(
        @{ Name='numeric scope'; Mutate={ param($e) $e.scope=1234567890 } },
        @{ Name='numeric owner'; Mutate={ param($e) $e.owner=123 } },
        @{ Name='numeric approver'; Mutate={ param($e) $e.approver=123 } },
        @{ Name='numeric affected control'; Mutate={ param($e) $e.affectedControl=1234567890 } },
        @{ Name='numeric evidence reference'; Mutate={ param($e) $e.evidenceReference=123 } },
        @{ Name='scalar compensating controls'; Mutate={ param($e) $e.compensatingControls='Synthetic compensating validation' } },
        @{ Name='non-string compensating control'; Mutate={ param($e) $e.compensatingControls=@(1234567890) } },
        @{ Name='duplicate compensating controls'; Mutate={ param($e) $e.compensatingControls=@('Synthetic compensating validation','Synthetic compensating validation') } },
        @{ Name='unsupported field'; Mutate={ param($e) $e.unexpected='not allowed' } }
    ) {
        $manifest = Copy-ContractObject $script:manifest
        $config = Copy-ContractObject $script:config
        $exception = New-TestException
        & $Mutate $exception
        $config.exceptions = @($exception)
        $config.controls.mandatoryControlsDisabled = @(@{control='SyntheticControl';exceptionReference='GOV-2026-ACTIVE'})
        $results = Invoke-Semantics $manifest $config
        ($results.message -join "`n") | Should -Match 'GCS010.*malformed' -Because $Name
        ($results.message -join "`n") | Should -Match 'GCS011.*lacks an applicable active exception' -Because $Name
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

    It 'compares canonical applicable standards paths case-sensitively' {
        $manifest = Copy-ContractObject $script:manifest
        $config = Copy-ContractObject $script:config
        $manifest.applicableStandards[0] = 'agents/AGENTS_base.md'
        $results = Invoke-Semantics $manifest $config
        ($results.message -join "`n") | Should -Match 'GCS006.*applicable standards disagree'
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

        ($results.message -join "`n") |
            Should -Not -Match '(?m)^GCS(?:002|007)\s'
    }

    It 'detects an anchored legacy finding identifier in validation messages' {
        $manifest = Read-JsonFile -Path (Join-Path $script:root 'tests/fixtures/valid/project-manifest.json')
        $config = Read-JsonFile -Path (Join-Path $script:root 'tests/fixtures/valid/governance-config.json')
        $manifest.governanceCommitSha = ('a' * 40)
        $config.governanceCommitSha = ('b' * 40)
        $results = @(Test-GovernanceContractSemantics `
            -Root $script:root `
            -Manifest $manifest `
            -Config $config `
            -ExpectedRepository 'example-org/fixture' `
            -ExpectedGovernanceCommitSha ('a' * 40) `
            -ExpectedWorkflowInterfaceVersion '1.0.0' `
            -ExpectedWorkflowProfile 'downstream' `
            -ValidationDateUtc ([datetime]'2026-07-14T00:00:00Z'))

        ($results.message -join "`n") |
            Should -Match '(?m)^GCS(?:002|007)\s'
    }
}
