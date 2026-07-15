BeforeAll {
    $script:repoRoot = (Resolve-Path "$PSScriptRoot/../..").Path
    $script:validator = Join-Path $script:repoRoot 'scripts/Invoke-GovernanceValidation.ps1'
    $script:evidenceGenerator = Join-Path $script:repoRoot 'scripts/New-CompletionEvidence.ps1'
    $script:evidenceValidator = Join-Path $script:repoRoot 'actions/validate-evidence/Invoke-EvidenceValidation.ps1'
    $script:tempRoot = Join-Path ([System.IO.Path]::GetTempPath()) ("reusable-governance-tests-" + [guid]::NewGuid())
    New-Item -ItemType Directory -Path $script:tempRoot -Force | Out-Null
    $script:callerSha = '1111111111111111111111111111111111111111'
    $script:standardsSha = (& git -C $script:repoRoot rev-parse HEAD).Trim()
}

AfterAll {
    if (Test-Path -LiteralPath $script:tempRoot) { Remove-Item -LiteralPath $script:tempRoot -Recurse -Force }
}

function script:New-DownstreamFixture {
    param([Parameter(Mandatory)][string]$Name)

    $root = Join-Path $script:tempRoot $Name
    New-Item -ItemType Directory -Path $root -Force | Out-Null
    foreach ($document in @('README.md','SECURITY.md','CONTRIBUTING.md','AGENTS.md')) {
        Set-Content -LiteralPath (Join-Path $root $document) -Value "# $document`n`nSynthetic downstream fixture documentation." -Encoding utf8
    }
    Add-Content -LiteralPath (Join-Path $root 'AGENTS.md') -Value @'

## Applicable Standards

- [Base](agents/AGENTS_Base.md)
- [Integration](agents/AGENTS_Integration.md)
'@ -Encoding utf8
    [ordered]@{
        schemaVersion='1.0.0'; projectName='Downstream Fixture'; repository='ExampleOrg/downstream-fixture'
        description='Synthetic downstream fixture for reusable governance workflow testing.'; projectType='integration'
        technologies=@('integration','github-actions'); governanceVersion='1.1.0'; riskClassification='Moderate'
        dataClassification='Internal'; owners=@('@ExampleOrg/maintainers')
        environments=@([ordered]@{name='local';type='development';production=$false})
        applicableStandards=@('agents/AGENTS_Base.md','agents/AGENTS_Integration.md'); requiredWorkflows=@('governance')
        externalIntegrations=@(); secretsProvider='none-required-for-synthetic-fixture'; productionApprovalRequired=$false
        evidence=[ordered]@{completionEvidencePath='evidence/completion-result.json';testEvidencePath='evidence/test-results.json'}
        exceptions=@()
    } | ConvertTo-Json -Depth 20 | Set-Content -LiteralPath (Join-Path $root 'project-manifest.json') -Encoding utf8
    [ordered]@{
        schemaVersion='1.0.0'; manifestPath='project-manifest.json'; evidencePath='evidence'
        requiredDocumentationPaths=@('README.md','SECURITY.md','CONTRIBUTING.md','AGENTS.md')
        applicableAgentStandards=@('agents/AGENTS_Base.md','agents/AGENTS_Integration.md')
        validationCategories=@('Contract'); additionalForbiddenPatterns=@(); reviewedAllowlist=@()
        controls=[ordered]@{mandatoryControlsDisabled=@()}; exceptions=@()
    } | ConvertTo-Json -Depth 20 | Set-Content -LiteralPath (Join-Path $root 'governance.config.json') -Encoding utf8
    $root
}

function script:New-StructuredDownstreamFixture {
    param(
        [Parameter(Mandatory)][string]$Name,
        [ValidateSet('User','Organization')][string]$DeclaredOwnerType = 'User'
    )

    $root = New-DownstreamFixture -Name $Name
    $manifest = Get-Content -LiteralPath (Join-Path $script:repoRoot 'examples/integration-project/project-manifest.json') -Raw | ConvertFrom-Json -AsHashtable
    $config = Get-Content -LiteralPath (Join-Path $script:repoRoot 'examples/integration-project/governance.config.json') -Raw | ConvertFrom-Json -AsHashtable
    $manifest.repository = 'ExampleOrg/downstream-fixture'
    $manifest.projectName = 'Structured Downstream Fixture'
    $manifest.governanceCommitSha = $script:standardsSha
    $manifest.repositoryOwnerType = $DeclaredOwnerType
    $manifest.standardsConsumption.sourceCommitSha = $script:standardsSha
    if ($DeclaredOwnerType -eq 'Organization') {
        $manifest.owners = @([ordered]@{ type='github-team'; identifier='@ExampleOrg/maintainers'; responsibility='Owns governance review.'; escalation='SECURITY.md' })
    }
    else {
        $manifest.owners = @([ordered]@{ type='github-user'; identifier='@ExampleOrg'; responsibility='Owns governance review.'; escalation='SECURITY.md' })
    }
    $config.governanceCommitSha = $script:standardsSha
    $manifest | ConvertTo-Json -Depth 20 | Set-Content -LiteralPath (Join-Path $root 'project-manifest.json') -Encoding utf8
    $config | ConvertTo-Json -Depth 20 | Set-Content -LiteralPath (Join-Path $root 'governance.config.json') -Encoding utf8
    $root
}

function script:New-ActiveException {
    param(
        [string]$Identifier = 'GOV-2026-ACTIVE',
        [string]$Status = 'Approved',
        [string]$AffectedControl = 'SyntheticControl'
    )

    [ordered]@{
        identifier = $Identifier
        status = $Status
        scope = 'Synthetic aggregate exception scope'
        owner = '@owner'
        approver = '@approver'
        approvalDate = '2026-01-01'
        expiration = '2099-12-31'
        affectedControl = $AffectedControl
        compensatingControls = @('Synthetic compensating validation')
        remediationPlan = 'Remove the synthetic exception after remediation.'
        evidenceReference = 'evidence/exception.json'
    }
}

function script:Invoke-DownstreamValidation {
    param(
        [Parameter(Mandatory)][string]$CallerRoot,
        [string]$ProjectPath='.',
        [string]$EvidenceRoot=(Join-Path $script:tempRoot ("evidence-" + [guid]::NewGuid())),
        [string]$StandardsRepository='AIAllTheThingz/Engineering-Standards',
        [string]$StandardsSha=$script:standardsSha,
        [string]$RepositoryOwnerType='Unknown',
        [string[]]$Category,
        [switch]$ControlledFailure
    )
    $prior = $env:GITHUB_ACTIONS
    $env:GITHUB_ACTIONS = 'true'
    try {
        $arguments = @('-NoProfile', '-File', $script:validator, '-Path', $CallerRoot, '-ProjectPath', $ProjectPath, '-EvidenceRoot', $EvidenceRoot, '-ExpectedGovernanceVersion', '1.1.0', '-CallerRepository', 'ExampleOrg/downstream-fixture', '-CallerCommitSha', $script:callerSha, '-StandardsRepository', $StandardsRepository, '-StandardsWorkflowSha', $StandardsSha, '-RepositoryOwnerType', $RepositoryOwnerType)
        if ($Category) { $arguments += @('-Category') + @($Category) }
        if ($ControlledFailure) { $arguments += '-ControlledFailure' }
        $output = @(& pwsh @arguments 2>&1)
        $joinedOutput = $output -join [Environment]::NewLine
        $joinedOutput = [regex]::Replace($joinedOutput, '\x1B\[[0-9;?]*[ -/]*[@-~]', '')
        $joinedOutput = [regex]::Replace($joinedOutput, '\s+', ' ')
        [pscustomobject]@{ ExitCode=$LASTEXITCODE; Output=$joinedOutput; EvidenceRoot=$EvidenceRoot }
    }
    finally {
        $env:GITHUB_ACTIONS = $prior
    }
}

Describe 'Reusable governance workflow trust boundaries' {
    It 'accepts trusted User owner type for schema version 1.2.0' {
        $caller = New-StructuredDownstreamFixture -Name 'structured-user-owner'
        $result = Invoke-DownstreamValidation -CallerRoot $caller -RepositoryOwnerType User
        $result.ExitCode | Should -Be 0 -Because $result.Output
    }

    It 'accepts trusted Organization owner type for schema version 1.2.0' {
        $caller = New-StructuredDownstreamFixture -Name 'structured-organization-owner' -DeclaredOwnerType Organization
        $result = Invoke-DownstreamValidation -CallerRoot $caller -RepositoryOwnerType Organization
        $result.ExitCode | Should -Be 0 -Because $result.Output
    }

    It 'fails closed when trusted owner type is absent for schema version 1.2.0' {
        $caller = New-StructuredDownstreamFixture -Name 'structured-owner-unknown'
        $result = Invoke-DownstreamValidation -CallerRoot $caller
        $result.ExitCode | Should -Not -Be 0
        $result.Output | Should -Match 'Trusted repository owner type is required for schema version 1.2.0'
    }

    It 'rejects an unsupported trusted repository owner type' {
        $caller = New-StructuredDownstreamFixture -Name 'structured-owner-unsupported'
        $result = Invoke-DownstreamValidation -CallerRoot $caller -RepositoryOwnerType Enterprise
        $result.ExitCode | Should -Not -Be 0
        $result.Output | Should -Match 'RepositoryOwnerType must be exactly Unknown, User, or Organization'
    }

    It 'passes trusted repository owner type through aggregate validation to Contract' {
        $caller = New-StructuredDownstreamFixture -Name 'structured-owner-manifest-override'
        $result = Invoke-DownstreamValidation -CallerRoot $caller -RepositoryOwnerType Organization
        $result.ExitCode | Should -Not -Be 0
        $result.Output | Should -Match 'GCS003|GCS004'
    }

    It 'validates a downstream caller without central scripts tests or examples' {
        $caller = New-DownstreamFixture -Name 'valid-downstream'
        $result = Invoke-DownstreamValidation -CallerRoot $caller
        $result.ExitCode | Should -Be 0
        Test-Path -LiteralPath (Join-Path $caller 'scripts') | Should -BeFalse
        Test-Path -LiteralPath (Join-Path $caller 'tests') | Should -BeFalse
        Test-Path -LiteralPath (Join-Path $caller 'examples') | Should -BeFalse
        $report = Get-Content -LiteralPath (Join-Path $result.EvidenceRoot 'governance-validation.json') -Raw | ConvertFrom-Json
        $report.validationProfile | Should -Be 'downstream'
        $report.caller.commitSha | Should -Be $script:callerSha
        $report.standards.workflowSha | Should -Be $script:standardsSha
        @($report.results).Count | Should -Be 1
        $report.results[0].toolPath | Should -Be 'standards/actions/validate-contract/Invoke-ContractValidation.ps1'
        $report.results[0].target | Should -Be 'caller'
    }

    It 'accepts empty downstream scanner configuration arrays' {
        $caller = New-DownstreamFixture -Name 'empty-scanner-configuration'
        $result = Invoke-DownstreamValidation -CallerRoot $caller
        $result.ExitCode | Should -Be 0
    }

    It 'rejects nonempty additionalForbiddenPatterns for downstream validation' {
        $caller = New-DownstreamFixture -Name 'unsupported-additional-patterns'
        $configPath = Join-Path $caller 'governance.config.json'
        $config = Get-Content -LiteralPath $configPath -Raw | ConvertFrom-Json -AsHashtable
        $config.additionalForbiddenPatterns = @('unsafe-synthetic-pattern')
        $config | ConvertTo-Json -Depth 20 | Set-Content -LiteralPath $configPath -Encoding utf8
        $result = Invoke-DownstreamValidation -CallerRoot $caller
        $result.ExitCode | Should -Not -Be 0
        $result.Output | Should -Match 'additionalForbiddenPatterns'
        $result.Output | Should -Match 'Issue #21'
    }

    It 'rejects nonempty reviewedAllowlist for downstream validation' {
        $caller = New-DownstreamFixture -Name 'unsupported-reviewed-allowlist'
        $configPath = Join-Path $caller 'governance.config.json'
        $config = Get-Content -LiteralPath $configPath -Raw | ConvertFrom-Json -AsHashtable
        $config.reviewedAllowlist = @([ordered]@{ patternId='synthetic'; path='README.md'; owner='@test'; reason='synthetic'; expiresOn='2099-01-01' })
        $config | ConvertTo-Json -Depth 20 | Set-Content -LiteralPath $configPath -Encoding utf8
        $result = Invoke-DownstreamValidation -CallerRoot $caller
        $result.ExitCode | Should -Not -Be 0
        $result.Output | Should -Match 'reviewedAllowlist'
        $result.Output | Should -Match 'Issue #21'
    }

    It 'rejects an absolute project path' {
        $caller = New-DownstreamFixture -Name 'absolute-path'
        $result = Invoke-DownstreamValidation -CallerRoot $caller -ProjectPath $caller
        $result.ExitCode | Should -Not -Be 0
        $result.Output | Should -Match 'Absolute paths are not allowed'
        $report = Get-Content -LiteralPath (Join-Path $result.EvidenceRoot 'governance-validation.json') -Raw | ConvertFrom-Json
        $report.caller.projectPath | Should -Be '[invalid]'
    }

    It 'rejects project path traversal outside the caller workspace' {
        $caller = New-DownstreamFixture -Name 'traversal'
        $result = Invoke-DownstreamValidation -CallerRoot $caller -ProjectPath '../outside'
        $result.ExitCode | Should -Not -Be 0
        $result.Output | Should -Match 'Path traversal is not allowed'
    }

    It 'rejects a caller attempt to override the standards repository' {
        $caller = New-DownstreamFixture -Name 'standards-repository-override'
        $result = Invoke-DownstreamValidation -CallerRoot $caller -StandardsRepository 'ExampleOrg/untrusted'
        $result.ExitCode | Should -Not -Be 0
        $result.Output | Should -Match 'Unexpected standards workflow repository'
    }

    It 'rejects a non-immutable standards workflow SHA' {
        $caller = New-DownstreamFixture -Name 'standards-sha-override'
        $result = Invoke-DownstreamValidation -CallerRoot $caller -StandardsSha 'master'
        $result.ExitCode | Should -Not -Be 0
        $result.Output | Should -Match 'full 40-character hexadecimal'
    }

    It 'rejects a full standards SHA that does not match the trusted checkout' {
        $caller = New-DownstreamFixture -Name 'standards-sha-mismatch'
        $result = Invoke-DownstreamValidation -CallerRoot $caller -StandardsSha '3333333333333333333333333333333333333333'
        $result.ExitCode | Should -Not -Be 0
        $result.Output | Should -Match 'Standards checkout HEAD does not match'
    }

    It 'fails when the manifest is missing' {
        $caller = New-DownstreamFixture -Name 'missing-manifest'
        Remove-Item -LiteralPath (Join-Path $caller 'project-manifest.json')
        $result = Invoke-DownstreamValidation -CallerRoot $caller
        $result.ExitCode | Should -Not -Be 0
        $result.Output | Should -Match 'project-manifest.json is missing'
    }

    It 'fails when the manifest contains invalid JSON' {
        $caller = New-DownstreamFixture -Name 'invalid-manifest'
        Set-Content -LiteralPath (Join-Path $caller 'project-manifest.json') -Value '{ invalid' -Encoding utf8
        $result = Invoke-DownstreamValidation -CallerRoot $caller
        $result.ExitCode | Should -Not -Be 0
        $result.Output | Should -Match 'Conversion from JSON failed|Invalid JSON primitive'
    }

    It 'rejects a governance version mismatch' {
        $caller = New-DownstreamFixture -Name 'version-mismatch'
        $manifest = Get-Content -LiteralPath (Join-Path $caller 'project-manifest.json') -Raw | ConvertFrom-Json
        $manifest.governanceVersion = '1.0.0'
        $manifest | ConvertTo-Json -Depth 20 | Set-Content -LiteralPath (Join-Path $caller 'project-manifest.json') -Encoding utf8
        $result = Invoke-DownstreamValidation -CallerRoot $caller
        $result.ExitCode | Should -Not -Be 0
        $result.Output | Should -Match 'Governance version mismatch'
        $report = Get-Content -LiteralPath (Join-Path $result.EvidenceRoot 'governance-validation.json') -Raw | ConvertFrom-Json
        $report.failed | Should -Be 1
        $report.results[0].name | Should -Be 'BootstrapValidation'
        $report.results[0].failureReason | Should -Be "Governance version mismatch: workflow expects '1.1.0' but manifest declares '1.0.0'."
    }

    It 'keeps legacy schema version <SchemaVersion> mandatory-control disablement fail-closed before Contract execution' -ForEach @(
        @{ SchemaVersion = '1.0.0' }
        @{ SchemaVersion = '1.1.0' }
    ) {
        $caller = New-DownstreamFixture -Name 'mandatory-disabled'
        $config = Get-Content -LiteralPath (Join-Path $caller 'governance.config.json') -Raw | ConvertFrom-Json
        $config.schemaVersion = $SchemaVersion
        $config.controls.mandatoryControlsDisabled = @([pscustomobject]@{control='Contract';exceptionReference='GOV-TEST-1'})
        $config | ConvertTo-Json -Depth 20 | Set-Content -LiteralPath (Join-Path $caller 'governance.config.json') -Encoding utf8
        $result = Invoke-DownstreamValidation -CallerRoot $caller
        $result.ExitCode | Should -Not -Be 0
        $result.Output | Should -Match 'attempts to disable one or more mandatory.*controls'
        $report = Get-Content -LiteralPath (Join-Path $result.EvidenceRoot 'governance-validation.json') -Raw | ConvertFrom-Json
        $report.failed | Should -Be 1
        $report.results[0].name | Should -Be 'BootstrapValidation'
        $report.results[0].failureReason | Should -Be 'governance.config.json attempts to disable one or more mandatory controls. Reusable workflow validation requires an independently validated approved exception.'
    }

    It 'accepts a schema version 1.2.0 disabled control with a matching active structured exception' {
        $caller = New-StructuredDownstreamFixture -Name 'structured-active-exception'
        $configPath = Join-Path $caller 'governance.config.json'
        $config = Get-Content -LiteralPath $configPath -Raw | ConvertFrom-Json -AsHashtable
        $config.exceptions = @(New-ActiveException)
        $config.controls.mandatoryControlsDisabled = @([ordered]@{control='SyntheticControl';exceptionReference='GOV-2026-ACTIVE'})
        $config | ConvertTo-Json -Depth 20 | Set-Content -LiteralPath $configPath -Encoding utf8

        $result = Invoke-DownstreamValidation -CallerRoot $caller -RepositoryOwnerType User

        $result.ExitCode | Should -Be 0 -Because $result.Output
        $report = Get-Content -LiteralPath (Join-Path $result.EvidenceRoot 'governance-validation.json') -Raw | ConvertFrom-Json
        $report.results[0].name | Should -Be 'Contract'
        $report.results[0].status | Should -Be 'Passed'
    }

    It 'runs explicitly selected Contract for schema version 1.2.0 structured-exception validation' {
        $caller = New-StructuredDownstreamFixture -Name 'structured-contract-first'
        $configPath = Join-Path $caller 'governance.config.json'
        $config = Get-Content -LiteralPath $configPath -Raw | ConvertFrom-Json -AsHashtable
        $config.exceptions = @(New-ActiveException)
        $config.controls.mandatoryControlsDisabled = @([ordered]@{control='SyntheticControl';exceptionReference='GOV-2026-ACTIVE'})
        $config | ConvertTo-Json -Depth 20 | Set-Content -LiteralPath $configPath -Encoding utf8

        $result = Invoke-DownstreamValidation -CallerRoot $caller -RepositoryOwnerType User -Category Contract

        $result.ExitCode | Should -Be 0 -Because $result.Output
        $report = Get-Content -LiteralPath (Join-Path $result.EvidenceRoot 'governance-validation.json') -Raw | ConvertFrom-Json
        @($report.results).Count | Should -Be 1
        $report.results[0].name | Should -Be 'Contract'
    }

    It 'rejects false <Mode> provenance through the aggregate downstream Contract entry point' -ForEach @(
        @{ Mode='local' },
        @{ Mode='vendored' }
    ) {
        $caller = New-StructuredDownstreamFixture -Name "structured-false-$Mode-provenance"
        New-Item -ItemType Directory -Path (Join-Path $caller 'agents') -Force | Out-Null
        $manifestPath = Join-Path $caller 'project-manifest.json'
        $manifest = Get-Content -LiteralPath $manifestPath -Raw | ConvertFrom-Json -AsHashtable
        $manifest.standardsConsumption = @{ mode=$Mode; localPath='agents' }
        if ($Mode -eq 'vendored') {
            $manifest.standardsConsumption.sourceRepository = 'ExampleOrg/Vendored-Standards'
            $manifest.standardsConsumption.sourceCommitSha = ('b' * 40)
        }
        $manifest | ConvertTo-Json -Depth 20 | Set-Content -LiteralPath $manifestPath -Encoding utf8

        $result = Invoke-DownstreamValidation -CallerRoot $caller -RepositoryOwnerType User -Category Contract

        $result.ExitCode | Should -Not -Be 0
        $result.Output | Should -Match 'GCS004.*regular file.*authoritative'
        $report = Get-Content -LiteralPath (Join-Path $result.EvidenceRoot 'governance-validation.json') -Raw | ConvertFrom-Json
        @($report.results).Count | Should -Be 1
        $report.results[0].name | Should -Be 'Contract'
        $report.results[0].status | Should -Be 'Failed'
    }

    It 'accepts complete <Mode> provenance through the aggregate downstream Contract entry point' -ForEach @(
        @{ Mode='local' },
        @{ Mode='vendored' }
    ) {
        $caller = New-StructuredDownstreamFixture -Name "structured-valid-$Mode-provenance"
        New-Item -ItemType Directory -Path (Join-Path $caller 'agents') -Force | Out-Null
        foreach ($name in @('AGENTS_Base.md','AGENTS_Integration.md')) {
            Copy-Item -LiteralPath (Join-Path $script:repoRoot "agents/$name") -Destination (Join-Path $caller "agents/$name")
        }
        $manifestPath = Join-Path $caller 'project-manifest.json'
        $manifest = Get-Content -LiteralPath $manifestPath -Raw | ConvertFrom-Json -AsHashtable
        $manifest.standardsConsumption = @{ mode=$Mode; localPath='agents' }
        if ($Mode -eq 'vendored') {
            $manifest.standardsConsumption.sourceRepository = 'ExampleOrg/Vendored-Standards'
            $manifest.standardsConsumption.sourceCommitSha = ('b' * 40)
        }
        $manifest | ConvertTo-Json -Depth 20 | Set-Content -LiteralPath $manifestPath -Encoding utf8

        $result = Invoke-DownstreamValidation -CallerRoot $caller -RepositoryOwnerType User -Category Contract

        $result.ExitCode | Should -Be 0 -Because $result.Output
        $report = Get-Content -LiteralPath (Join-Path $result.EvidenceRoot 'governance-validation.json') -Raw | ConvertFrom-Json
        @($report.results).Count | Should -Be 1
        $report.results[0].name | Should -Be 'Contract'
        $report.results[0].status | Should -Be 'Passed'
    }

    It 'rejects an explicit category override that omits Contract before structured-exception execution' {
        $caller = New-StructuredDownstreamFixture -Name 'structured-contract-omitted'
        $configPath = Join-Path $caller 'governance.config.json'
        $config = Get-Content -LiteralPath $configPath -Raw | ConvertFrom-Json -AsHashtable
        $config.exceptions = @(New-ActiveException)
        $config.controls.mandatoryControlsDisabled = @([ordered]@{control='SyntheticControl';exceptionReference='GOV-2026-ACTIVE'})
        $config | ConvertTo-Json -Depth 20 | Set-Content -LiteralPath $configPath -Encoding utf8

        $result = Invoke-DownstreamValidation -CallerRoot $caller -RepositoryOwnerType User -Category ForbiddenPatterns

        $result.ExitCode | Should -Not -Be 0
        $result.Output | Should -Match 'Contract validation is mandatory.*structured-exception validation.*cannot be omitted'
        $report = Get-Content -LiteralPath (Join-Path $result.EvidenceRoot 'governance-validation.json') -Raw | ConvertFrom-Json
        $report.results[0].name | Should -Be 'BootstrapValidation'
        $report.results[0].failureReason | Should -Match 'Contract validation is mandatory'
    }

    It 'reports invalid schema version 1.2.0 structured exceptions through Contract semantics' {
        $caller = New-StructuredDownstreamFixture -Name 'structured-inactive-exception'
        $configPath = Join-Path $caller 'governance.config.json'
        $config = Get-Content -LiteralPath $configPath -Raw | ConvertFrom-Json -AsHashtable
        $config.exceptions = @(New-ActiveException -Status Rejected)
        $config.controls.mandatoryControlsDisabled = @([ordered]@{control='SyntheticControl';exceptionReference='GOV-2026-ACTIVE'})
        $config | ConvertTo-Json -Depth 20 | Set-Content -LiteralPath $configPath -Encoding utf8

        $result = Invoke-DownstreamValidation -CallerRoot $caller -RepositoryOwnerType User

        $result.ExitCode | Should -Not -Be 0
        $result.Output | Should -Match 'GCS010'
        $result.Output | Should -Match 'GCS011'
        $report = Get-Content -LiteralPath (Join-Path $result.EvidenceRoot 'governance-validation.json') -Raw | ConvertFrom-Json
        $report.results[0].name | Should -Be 'Contract'
        $report.results[0].status | Should -Be 'Failed'
    }

    It 'records the missing required documentation path in aggregate evidence' {
        $caller = New-DownstreamFixture -Name 'missing-required-document'
        Remove-Item -LiteralPath (Join-Path $caller 'SECURITY.md')
        $result = Invoke-DownstreamValidation -CallerRoot $caller
        $result.ExitCode | Should -Not -Be 0
        $report = Get-Content -LiteralPath (Join-Path $result.EvidenceRoot 'governance-validation.json') -Raw | ConvertFrom-Json
        $contract = @($report.results | Where-Object name -eq 'Contract')[0]
        $contract.status | Should -Be 'Failed'
        $contract.failureReason | Should -Match 'SECURITY\.md'
        $contract.failureReason | Should -Not -Match 'before the aggregate report could be finalized'
    }

    It 'rejects an evidence path inside the caller workspace' {
        $caller = New-DownstreamFixture -Name 'invalid-evidence-path'
        $result = Invoke-DownstreamValidation -CallerRoot $caller -EvidenceRoot (Join-Path $caller 'evidence')
        $result.ExitCode | Should -Not -Be 0
        $result.Output | Should -Match 'Evidence workspace must be separate'
    }

    It 'records controlled failure after normal validation evidence' {
        $caller = New-DownstreamFixture -Name 'controlled-failure'
        $result = Invoke-DownstreamValidation -CallerRoot $caller -ControlledFailure
        $result.ExitCode | Should -Not -Be 0
        $reportPath = Join-Path $result.EvidenceRoot 'governance-validation.json'
        Test-Path -LiteralPath $reportPath | Should -BeTrue
        $report = Get-Content -LiteralPath $reportPath -Raw | ConvertFrom-Json
        $report.results[0].status | Should -Be 'Passed'
        @($report.results | Where-Object name -eq 'ControlledFailure').Count | Should -Be 1
    }

    It 'records caller and trusted workflow identities in completion evidence' {
        $workspace = Join-Path $script:tempRoot 'completion-evidence-identity'
        $caller = Join-Path $workspace 'caller'
        $evidence = Join-Path $workspace 'evidence'
        New-Item -ItemType Directory -Path $caller,$evidence -Force | Out-Null
        $now = (Get-Date).ToUniversalTime().ToString('o')
        @([ordered]@{
            schemaVersion='1.1.0'; name='Contract'; category='workflow'; status='Passed'; requiredValidation=$true
            evidenceSource='Automated'; command='standards/actions/validate-contract/Invoke-ContractValidation.ps1'
            workingDirectory='caller'; startedAtUtc=$now; completedAtUtc=$now; durationSeconds=0
            runtime='Pester'; toolVersion=$PSVersionTable.PSVersion.ToString(); environment='Local synthetic fixture'
            exitCode=0; summary='Synthetic contract validation passed.'; warnings=@(); failureReason=$null
            blockedReason=$null; notApplicableRationale=$null; manualProcedure=$null
            executionMode=[ordered]@{dryRun=$false;whatIf=$false;planOnly=$false;applied=$true}; details=$null
        },[ordered]@{
            schemaVersion='1.1.0'; name='GitHub-hosted workflow execution'; category='workflow'; status='NotRun'; requiredValidation=$true
            evidenceSource='Automated'; command='Governance CI'; workingDirectory='caller'; startedAtUtc=$now; completedAtUtc=$now
            durationSeconds=0; runtime='Local Pester'; toolVersion=$PSVersionTable.PSVersion.ToString(); environment='Local synthetic fixture'
            exitCode=3; summary='GitHub-hosted workflow was not run in this local fixture.'; warnings=@()
            failureReason='GitHub-hosted workflow execution was not performed in this local fixture.'; blockedReason=$null
            notApplicableRationale=$null; manualProcedure=$null
            executionMode=[ordered]@{dryRun=$false;whatIf=$false;planOnly=$false;applied=$false}; details=$null
        }) | ConvertTo-Json -Depth 20 | Set-Content -LiteralPath (Join-Path $evidence 'tests.json') -Encoding utf8
        Set-Content -LiteralPath (Join-Path $evidence 'environment.json') -Value '{}' -Encoding utf8
        & $script:evidenceGenerator -RepositoryPath $workspace -SourceRepositoryPath $caller -OutputPath 'evidence/completion-result.json' -GovernanceVersion '1.1.0' -RiskClassification Moderate -ExecutionContext Local -Summary 'Synthetic downstream identity evidence.' -TestResultPath 'evidence/tests.json' -ArtifactPath @('evidence/tests.json') -CommandsExecuted @('trusted validation') -CommandsNotExecuted @('GitHub-hosted Governance CI workflow execution') -ValidatedCommitSha $script:callerSha -Repository 'ExampleOrg/downstream-fixture' -Branch 'feature/test' -StandardsRepository 'AIAllTheThingz/Engineering-Standards' -StandardsWorkflowSha $script:standardsSha -ValidationProfile 'downstream' -ChecksExecuted @('Contract')
        $document = Get-Content -LiteralPath (Join-Path $evidence 'completion-result.json') -Raw | ConvertFrom-Json
        $document.repository | Should -Be 'ExampleOrg/downstream-fixture'
        $document.commitSha | Should -Be $script:callerSha
        $document.validatedCommitSha | Should -Be $script:callerSha
        $document.riskClassification | Should -Be 'Moderate'
        $identity = $document.technologyEvidence.infrastructure.governanceWorkflow
        $identity.standardsRepository | Should -Be 'AIAllTheThingz/Engineering-Standards'
        $identity.standardsWorkflowSha | Should -Be $script:standardsSha
        $identity.validationProfile | Should -Be 'downstream'
        $validationOutput = @(& pwsh -NoProfile -File $script:evidenceValidator -Path $workspace -EvidencePath 'evidence/completion-result.json' -ExpectedCommitSha $script:callerSha 2>&1)
        $LASTEXITCODE | Should -Be 0 -Because ($validationOutput -join [Environment]::NewLine)
    }

    It 'rejects a symbolic-link project escape when links are supported' {
        $caller = New-DownstreamFixture -Name 'symlink-caller'
        $outside = New-DownstreamFixture -Name 'symlink-outside'
        $link = Join-Path $caller 'linked-project'
        try {
            New-Item -ItemType SymbolicLink -Path $link -Target $outside -ErrorAction Stop | Out-Null
        }
        catch {
            Set-ItResult -Skipped -Because "Symbolic links are unavailable in this test environment: $($_.Exception.Message)"
            return
        }
        $result = Invoke-DownstreamValidation -CallerRoot $caller -ProjectPath 'linked-project'
        $result.ExitCode | Should -Not -Be 0
        $result.Output | Should -Match 'symbolic link or junction'
    }

    It 'rejects every symbolic link in caller content, including internal targets' {
        $caller = New-DownstreamFixture -Name 'nested-symlink-caller'
        $link = Join-Path $caller 'docs-link'
        try {
            New-Item -ItemType SymbolicLink -Path $link -Target (Join-Path $caller 'README.md') -ErrorAction Stop | Out-Null
        }
        catch {
            Set-ItResult -Skipped -Because "Symbolic links are unavailable in this test environment: $($_.Exception.Message)"
            return
        }
        $result = Invoke-DownstreamValidation -CallerRoot $caller
        $result.ExitCode | Should -Not -Be 0
        $result.Output | Should -Match 'Caller content contains unsupported symbolic link or junction'
    }

    It 'rejects a caller link outside the selected project path' {
        $caller = New-DownstreamFixture -Name 'link-outside-project-path'
        $project = Join-Path $caller 'selected-project'
        New-Item -ItemType Directory -Path $project -Force | Out-Null
        foreach ($name in @('README.md','SECURITY.md','CONTRIBUTING.md','AGENTS.md','project-manifest.json','governance.config.json')) {
            Copy-Item -LiteralPath (Join-Path $caller $name) -Destination (Join-Path $project $name)
        }
        $link = Join-Path $caller 'outside-selected-project-link'
        try {
            New-Item -ItemType SymbolicLink -Path $link -Target (Join-Path $caller 'README.md') -ErrorAction Stop | Out-Null
        }
        catch {
            Set-ItResult -Skipped -Because "Symbolic links are unavailable in this test environment: $($_.Exception.Message)"
            return
        }
        $result = Invoke-DownstreamValidation -CallerRoot $caller -ProjectPath 'selected-project'
        $result.ExitCode | Should -Not -Be 0
        $result.Output | Should -Match 'Caller content contains unsupported symbolic link or junction'
    }

    It 'rejects a symbolic-link evidence root when links are supported' {
        $caller = New-DownstreamFixture -Name 'evidence-symlink-caller'
        $outside = Join-Path $script:tempRoot 'evidence-symlink-target'
        $link = Join-Path $script:tempRoot 'evidence-symlink-link'
        New-Item -ItemType Directory -Path $outside -Force | Out-Null
        try {
            New-Item -ItemType SymbolicLink -Path $link -Target $outside -ErrorAction Stop | Out-Null
        }
        catch {
            Set-ItResult -Skipped -Because "Symbolic links are unavailable in this test environment: $($_.Exception.Message)"
            return
        }
        $result = Invoke-DownstreamValidation -CallerRoot $caller -EvidenceRoot $link
        $result.ExitCode | Should -Not -Be 0
        $result.Output | Should -Match 'Evidence workspace must not be a symbolic link or junction'
    }
}
