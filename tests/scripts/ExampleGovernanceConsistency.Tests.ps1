BeforeAll {
    $script:root = (Resolve-Path "$PSScriptRoot/../..").Path
    $script:examplesRoot = Join-Path $script:root 'examples'
    $rootManifest = Get-Content -LiteralPath (Join-Path $script:root 'project-manifest.json') -Raw | ConvertFrom-Json
    $script:expectedImplementationSha = [string]$rootManifest.governanceCommitSha
    if ($script:expectedImplementationSha -cnotmatch '^[0-9a-f]{40}$') {
        throw 'The authoritative root governanceCommitSha must be a full lowercase commit SHA.'
    }

    function Get-WorkflowGovernanceBinding {
        <#
        .SYNOPSIS
        Reads the immutable governance version and workflow SHA from an example workflow.
        #>
        [CmdletBinding()]
        param(
            [Parameter(Mandatory)]
            [string]$Path
        )

        if (-not (Test-Path -LiteralPath $Path -PathType Leaf)) {
            throw "Missing required example file '$Path'."
        }

        $content = Get-Content -LiteralPath $Path -Raw
        $usesPattern = '(?m)^\s*uses:\s*AIAllTheThingz/Engineering-Standards/\.github/workflows/governance-ci-reusable\.yml@(?<sha>[0-9a-f]{40})\s*$'
        $versionPattern = '(?m)^\s*governance-version:\s*(?<version>[0-9]+\.[0-9]+\.[0-9]+)\s*$'
        $callerJobNamePattern = '(?m)^\s{4}name:\s*(?<name>Governance)\s*$'
        $usesMatches = [regex]::Matches($content, $usesPattern)
        $versionMatches = [regex]::Matches($content, $versionPattern)
        $callerJobNameMatches = [regex]::Matches($content, $callerJobNamePattern)

        if ($usesMatches.Count -ne 1) {
            throw "Example workflow '$Path' must contain exactly one immutable reusable-workflow reference using a full lowercase 40-character SHA."
        }
        if ($versionMatches.Count -ne 1) {
            throw "Example workflow '$Path' must contain exactly one semantic governance-version input."
        }
        if ($callerJobNameMatches.Count -ne 1) {
            throw "Example workflow '$Path' must set the governance caller job display name to canonical value 'Governance'."
        }

        [pscustomobject]@{
            Sha = $usesMatches[0].Groups['sha'].Value
            GovernanceVersion = $versionMatches[0].Groups['version'].Value
            CallerJobName = $callerJobNameMatches[0].Groups['name'].Value
        }
    }

    function Get-ExampleGovernanceRecord {
        <#
        .SYNOPSIS
        Loads the manifest, governance config, and workflow binding for one example.
        #>
        [CmdletBinding()]
        param(
            [Parameter(Mandatory)]
            [string]$Directory
        )

        $manifestPath = Join-Path $Directory 'project-manifest.json'
        $configPath = Join-Path $Directory 'governance.config.json'
        $workflowPath = Join-Path $Directory '.github/workflows/governance.yml'
        foreach ($requiredPath in @($manifestPath, $configPath, $workflowPath)) {
            if (-not (Test-Path -LiteralPath $requiredPath -PathType Leaf)) {
                throw "Missing required example file '$requiredPath'."
            }
        }

        [pscustomobject]@{
            Name = Split-Path -Leaf $Directory
            Manifest = Get-Content -LiteralPath $manifestPath -Raw | ConvertFrom-Json -AsHashtable
            Config = Get-Content -LiteralPath $configPath -Raw | ConvertFrom-Json -AsHashtable
            Workflow = Get-WorkflowGovernanceBinding -Path $workflowPath
        }
    }

    function Get-ExampleGovernanceConsistencyFinding {
        <#
        .SYNOPSIS
        Returns deterministic cross-file governance version and SHA contradictions.
        #>
        [CmdletBinding()]
        param(
            [Parameter(Mandatory)]
            [hashtable]$Manifest,

            [Parameter(Mandatory)]
            [hashtable]$Config,

            [Parameter(Mandatory)]
            [psobject]$Workflow,

            [Parameter(Mandatory)]
            [string]$ExpectedSha
        )

        $findings = [System.Collections.Generic.List[string]]::new()
        if ($Manifest.governanceVersion -ne $Config.governanceVersion) {
            $findings.Add("Manifest governanceVersion '$($Manifest.governanceVersion)' does not match config governanceVersion '$($Config.governanceVersion)'.")
        }
        if ($Workflow.GovernanceVersion -ne $Manifest.governanceVersion) {
            $findings.Add("Workflow governance-version '$($Workflow.GovernanceVersion)' does not match manifest governanceVersion '$($Manifest.governanceVersion)'.")
        }
        if ($Manifest.governanceCommitSha -ne $ExpectedSha) {
            $findings.Add("Manifest governanceCommitSha '$($Manifest.governanceCommitSha)' does not match expected implementation SHA '$ExpectedSha'.")
        }
        if ($Config.governanceCommitSha -ne $ExpectedSha) {
            $findings.Add("Config governanceCommitSha '$($Config.governanceCommitSha)' does not match expected implementation SHA '$ExpectedSha'.")
        }
        if ($Manifest.standardsConsumption.sourceCommitSha -ne $ExpectedSha) {
            $findings.Add("Manifest standardsConsumption.sourceCommitSha '$($Manifest.standardsConsumption.sourceCommitSha)' does not match expected implementation SHA '$ExpectedSha'.")
        }
        if ($Workflow.Sha -ne $ExpectedSha) {
            $findings.Add("Workflow reusable reference SHA '$($Workflow.Sha)' does not match expected implementation SHA '$ExpectedSha'.")
        }
        $expectedCheckName = "$($Workflow.CallerJobName) / $($Config.workflowInterface.jobName)"
        if ($Config.requiredCheckNames -cnotcontains $expectedCheckName -or $Config.workflowInterface.requiredCheckNames -cnotcontains $expectedCheckName) {
            $findings.Add("Workflow caller/called job names compose check '$expectedCheckName', which is absent from the config required check names.")
        }

        @($findings)
    }
}

Describe 'Example governance version and trusted implementation consistency' {
    It 'validates every governed example as one complete matrix' {
        $expectedExamples = @(
            'bash-review-home-lab',
            'build-pester-tests-home-lab',
            'combined-script-runner-project',
            'completion-evidence-home-lab',
            'database-project',
            'dotnet-project',
            'frameworks-home-lab',
            'governance-validation-home-lab',
            'infrastructure-automation-design-home-lab',
            'infrastructure-project',
            'integration-project',
            'networking-home-lab',
            'operating-systems-home-lab',
            'platforms-home-lab',
            'powershell-project',
            'powershell-review-home-lab',
            'python-review-home-lab',
            'safe-automation-home-lab',
            'terraform-review-home-lab',
            'vendor-documentation-analysis-home-lab',
            'virtualization-home-lab',
            'web-project',
            'worker-service-project'
        )
        $actualExamples = @(
            Get-ChildItem -LiteralPath $script:examplesRoot -Directory |
                Where-Object { Test-Path -LiteralPath (Join-Path $_.FullName 'project-manifest.json') -PathType Leaf } |
                Select-Object -ExpandProperty Name |
                Sort-Object
        )

        $actualExamples | Should -HaveCount $expectedExamples.Count
        ($actualExamples -join "`n") |
            Should -BeExactly (@($expectedExamples | Sort-Object) -join "`n")
        $catalogPath = Join-Path $script:examplesRoot 'README.md'
        Test-Path -LiteralPath $catalogPath -PathType Leaf | Should -BeTrue
        $catalogText = Get-Content -LiteralPath $catalogPath -Raw
        foreach ($exampleName in $expectedExamples) {
            $catalogText | Should -Match ([regex]::Escape("$exampleName/README.md")) -Because "$exampleName must be discoverable from the examples catalog"
            $record = Get-ExampleGovernanceRecord -Directory (Join-Path $script:examplesRoot $exampleName)
            $expectedSha = if ($exampleName -in @('python-review-home-lab', 'bash-review-home-lab')) {
                $record.Workflow.Sha
            }
            else {
                $script:expectedImplementationSha
            }
            $findings = @(
                Get-ExampleGovernanceConsistencyFinding -Manifest $record.Manifest -Config $record.Config -Workflow $record.Workflow -ExpectedSha $expectedSha
            )
            $findings | Should -HaveCount 0 -Because "$exampleName must keep its manifest, config, and workflow identities synchronized"
            $record.Manifest.schemaVersion | Should -BeExactly '1.2.0'
            $record.Config.schemaVersion | Should -BeExactly '1.2.0'
            $record.Manifest.governanceVersion | Should -BeExactly '1.1.0'
        }
    }

    It 'keeps Python and Bash review labs pinned to revisions containing their declared standards' -ForEach @(
        @{ ExampleName='python-review-home-lab'; RequiredStandard='agents/AGENTS_Python.md' },
        @{ ExampleName='bash-review-home-lab'; RequiredStandard='agents/AGENTS_Bash.md' }
    ) {
        $record = Get-ExampleGovernanceRecord -Directory (Join-Path $script:examplesRoot $ExampleName)
        $authoritySha = $record.Workflow.Sha

        $authoritySha | Should -Match '^[0-9a-f]{40}$'
        $record.Manifest.governanceCommitSha | Should -BeExactly $authoritySha
        $record.Manifest.standardsConsumption.sourceCommitSha | Should -BeExactly $authoritySha
        $record.Config.governanceCommitSha | Should -BeExactly $authoritySha
        @($record.Manifest.applicableStandards | Sort-Object) |
            Should -BeExactly @($record.Config.applicableAgentStandards | Sort-Object)
        $record.Manifest.applicableStandards | Should -Contain $RequiredStandard

        & git -C $script:root cat-file -e "$authoritySha^{commit}" 2>$null
        if ($LASTEXITCODE -eq 0) {
            foreach ($standard in @($record.Manifest.applicableStandards)) {
                & git -C $script:root cat-file -e "${authoritySha}:$standard" 2>$null
                $LASTEXITCODE | Should -Be 0 -Because "declared central standard '$standard' must exist at pinned authority '$authoritySha'"
            }
        }
    }

    It 'detects controlled <Name>' -ForEach @(
        @{
            Name = 'workflow governance-version mismatch'
            ManifestVersion = '1.1.0'
            ConfigVersion = '1.1.0'
            WorkflowVersion = '1.0.0'
            ManifestSha = '28bb17a5d361f46a456e97ce8de3151e8b5acbf5'
            ConfigSha = '28bb17a5d361f46a456e97ce8de3151e8b5acbf5'
            SourceSha = '28bb17a5d361f46a456e97ce8de3151e8b5acbf5'
            WorkflowSha = '28bb17a5d361f46a456e97ce8de3151e8b5acbf5'
            Pattern = '^Workflow governance-version'
        },
        @{
            Name = 'workflow trusted-SHA mismatch'
            ManifestVersion = '1.1.0'
            ConfigVersion = '1.1.0'
            WorkflowVersion = '1.1.0'
            ManifestSha = '28bb17a5d361f46a456e97ce8de3151e8b5acbf5'
            ConfigSha = '28bb17a5d361f46a456e97ce8de3151e8b5acbf5'
            SourceSha = '28bb17a5d361f46a456e97ce8de3151e8b5acbf5'
            WorkflowSha = 'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa'
            Pattern = '^Workflow reusable reference SHA'
        },
        @{
            Name = 'config trusted-SHA mismatch'
            ManifestVersion = '1.1.0'
            ConfigVersion = '1.1.0'
            WorkflowVersion = '1.1.0'
            ManifestSha = '28bb17a5d361f46a456e97ce8de3151e8b5acbf5'
            ConfigSha = 'bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb'
            SourceSha = '28bb17a5d361f46a456e97ce8de3151e8b5acbf5'
            WorkflowSha = '28bb17a5d361f46a456e97ce8de3151e8b5acbf5'
            Pattern = '^Config governanceCommitSha'
        }
    ) {
        $manifest = @{
            governanceVersion = $ManifestVersion
            governanceCommitSha = $ManifestSha
            standardsConsumption = @{ sourceCommitSha = $SourceSha }
        }
        $config = @{
            governanceVersion = $ConfigVersion
            governanceCommitSha = $ConfigSha
            workflowInterface = @{ jobName='Governance validation'; requiredCheckNames=@('Governance / Governance validation') }
            requiredCheckNames = @('Governance / Governance validation')
        }
        $workflow = [pscustomobject]@{
            GovernanceVersion = $WorkflowVersion
            Sha = $WorkflowSha
            CallerJobName = 'Governance'
        }

        $findings = @(
            Get-ExampleGovernanceConsistencyFinding -Manifest $manifest -Config $config -Workflow $workflow -ExpectedSha $script:expectedImplementationSha
        )
        ($findings -join "`n") | Should -Match $Pattern
    }

    It 'rejects a placeholder reusable-workflow reference' {
        $workflowPath = Join-Path $TestDrive 'placeholder.yml'
        @'
jobs:
  governance:
    name: Governance
    uses: AIAllTheThingz/Engineering-Standards/.github/workflows/governance-ci-reusable.yml@<pinned-commit-sha>
    with:
      governance-version: 1.1.0
'@ | Set-Content -LiteralPath $workflowPath -Encoding utf8

        { Get-WorkflowGovernanceBinding -Path $workflowPath } |
            Should -Throw '*must contain exactly one immutable reusable-workflow reference*'
    }

    It 'rejects a noncanonical caller job display name' {
        $workflowPath = Join-Path $TestDrive 'caller-name.yml'
        @'
jobs:
  governance:
    name: governance
    uses: AIAllTheThingz/Engineering-Standards/.github/workflows/governance-ci-reusable.yml@bf54167e26fb2aa41eccb653ad25b85d77bb584f
    with:
      governance-version: 1.1.0
'@ | Set-Content -LiteralPath $workflowPath -Encoding utf8

        { Get-WorkflowGovernanceBinding -Path $workflowPath } |
            Should -Throw "*caller job display name*'Governance'*"
    }

    It 'fails closed when an example workflow is missing' {
        $exampleRoot = Join-Path $TestDrive 'missing-workflow'
        New-Item -ItemType Directory -Path $exampleRoot -Force | Out-Null
        Copy-Item -LiteralPath (Join-Path $script:examplesRoot 'database-project/project-manifest.json') -Destination $exampleRoot
        Copy-Item -LiteralPath (Join-Path $script:examplesRoot 'database-project/governance.config.json') -Destination $exampleRoot

        { Get-ExampleGovernanceRecord -Directory $exampleRoot } |
            Should -Throw '*Missing required example file*governance.yml*'
    }

    It 'keeps repository templates on the final trusted implementation' {
        $manifest = Get-Content -LiteralPath (Join-Path $script:root 'templates/repository/project-manifest.template.json') -Raw |
            ConvertFrom-Json -AsHashtable
        $config = Get-Content -LiteralPath (Join-Path $script:root 'templates/repository/governance.config.template.json') -Raw |
            ConvertFrom-Json -AsHashtable

        $manifest.schemaVersion | Should -BeExactly '1.2.0'
        $config.schemaVersion | Should -BeExactly '1.2.0'
        $manifest.governanceVersion | Should -BeExactly '1.1.0'
        $config.governanceVersion | Should -BeExactly '1.1.0'
        $manifest.governanceCommitSha | Should -BeExactly $script:expectedImplementationSha
        $manifest.standardsConsumption.sourceCommitSha | Should -BeExactly $script:expectedImplementationSha
        $config.governanceCommitSha | Should -BeExactly $script:expectedImplementationSha
    }
}
