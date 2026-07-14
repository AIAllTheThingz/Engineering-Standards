BeforeAll {
    $script:root = (Resolve-Path "$PSScriptRoot/../..").Path
    $script:examplesRoot = Join-Path $script:root 'examples'
    $script:expectedImplementationSha = '6f9eda81c352b316302867ba45a273e54b3644f2'

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
        $usesMatches = [regex]::Matches($content, $usesPattern)
        $versionMatches = [regex]::Matches($content, $versionPattern)

        if ($usesMatches.Count -ne 1) {
            throw "Example workflow '$Path' must contain exactly one immutable reusable-workflow reference using a full lowercase 40-character SHA."
        }
        if ($versionMatches.Count -ne 1) {
            throw "Example workflow '$Path' must contain exactly one semantic governance-version input."
        }

        [pscustomobject]@{
            Sha = $usesMatches[0].Groups['sha'].Value
            GovernanceVersion = $versionMatches[0].Groups['version'].Value
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

        @($findings)
    }
}

Describe 'Example governance version and trusted implementation consistency' {
    It 'validates every governed example as one complete matrix' {
        $expectedExamples = @(
            'combined-script-runner-project',
            'database-project',
            'dotnet-project',
            'infrastructure-project',
            'integration-project',
            'powershell-project',
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
        foreach ($exampleName in $expectedExamples) {
            $record = Get-ExampleGovernanceRecord -Directory (Join-Path $script:examplesRoot $exampleName)
            $findings = @(
                Get-ExampleGovernanceConsistencyFinding -Manifest $record.Manifest -Config $record.Config -Workflow $record.Workflow -ExpectedSha $script:expectedImplementationSha
            )
            $findings | Should -HaveCount 0 -Because "$exampleName must keep its manifest, config, and workflow identities synchronized"
            $record.Manifest.schemaVersion | Should -BeExactly '1.2.0'
            $record.Config.schemaVersion | Should -BeExactly '1.2.0'
            $record.Manifest.governanceVersion | Should -BeExactly '1.1.0'
        }
    }

    It 'detects controlled <Name>' -ForEach @(
        @{
            Name = 'workflow governance-version mismatch'
            ManifestVersion = '1.1.0'
            ConfigVersion = '1.1.0'
            WorkflowVersion = '1.0.0'
            ManifestSha = '6f9eda81c352b316302867ba45a273e54b3644f2'
            ConfigSha = '6f9eda81c352b316302867ba45a273e54b3644f2'
            SourceSha = '6f9eda81c352b316302867ba45a273e54b3644f2'
            WorkflowSha = '6f9eda81c352b316302867ba45a273e54b3644f2'
            Pattern = '^Workflow governance-version'
        },
        @{
            Name = 'workflow trusted-SHA mismatch'
            ManifestVersion = '1.1.0'
            ConfigVersion = '1.1.0'
            WorkflowVersion = '1.1.0'
            ManifestSha = '6f9eda81c352b316302867ba45a273e54b3644f2'
            ConfigSha = '6f9eda81c352b316302867ba45a273e54b3644f2'
            SourceSha = '6f9eda81c352b316302867ba45a273e54b3644f2'
            WorkflowSha = 'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa'
            Pattern = '^Workflow reusable reference SHA'
        },
        @{
            Name = 'config trusted-SHA mismatch'
            ManifestVersion = '1.1.0'
            ConfigVersion = '1.1.0'
            WorkflowVersion = '1.1.0'
            ManifestSha = '6f9eda81c352b316302867ba45a273e54b3644f2'
            ConfigSha = 'bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb'
            SourceSha = '6f9eda81c352b316302867ba45a273e54b3644f2'
            WorkflowSha = '6f9eda81c352b316302867ba45a273e54b3644f2'
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
        }
        $workflow = [pscustomobject]@{
            GovernanceVersion = $WorkflowVersion
            Sha = $WorkflowSha
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
    uses: AIAllTheThingz/Engineering-Standards/.github/workflows/governance-ci-reusable.yml@<pinned-commit-sha>
    with:
      governance-version: 1.1.0
'@ | Set-Content -LiteralPath $workflowPath -Encoding utf8

        { Get-WorkflowGovernanceBinding -Path $workflowPath } |
            Should -Throw '*must contain exactly one immutable reusable-workflow reference*'
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
