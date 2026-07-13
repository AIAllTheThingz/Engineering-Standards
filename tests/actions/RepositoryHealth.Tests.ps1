Describe 'Repository health' {
    BeforeAll {
        $script:actionHarnessRoot = Join-Path ([System.IO.Path]::GetTempPath()) ('repository-health-action-' + [guid]::NewGuid())
        New-Item -ItemType Directory -Path $script:actionHarnessRoot -Force | Out-Null
        $actionText = Get-Content -LiteralPath "$PSScriptRoot/../../actions/repository-health/action.yml" -Raw
        $runText = ($actionText -split '(?m)^      run: \|\r?$')[1]
        $runLines = @($runText -split "`r?`n" | ForEach-Object { $_ -replace '^        ', '' })
        Set-Content -LiteralPath (Join-Path $script:actionHarnessRoot 'action-run.ps1') -Value ($runLines -join "`n")
        @'
param([string]$Path, [string]$OutputJson, [switch]$Advisory, [string]$RepositoryOwnerType)
[ordered]@{ Path=$Path; OutputJson=$OutputJson; Advisory=[bool]$Advisory; RepositoryOwnerType=$RepositoryOwnerType } |
    ConvertTo-Json | Set-Content -LiteralPath $env:CAPTURE_PATH
@{ failed = 0 } | ConvertTo-Json | Set-Content -LiteralPath $OutputJson
exit 0
'@ | Set-Content -LiteralPath (Join-Path $script:actionHarnessRoot 'Invoke-RepositoryHealth.ps1')

        function New-SyntheticRepositoryHealthFixture {
            param(
                [Parameter(Mandatory)][string]$Root,
                [string[]]$RequiredCodeownerPaths,
                [Parameter(Mandatory)][string]$Codeowners,
                [ValidateSet('powershell', 'dotnet', 'governance')][string]$ProjectType = 'governance'
            )

            New-Item -ItemType Directory -Path $Root -Force | Out-Null
            foreach ($directory in @('.github/workflows', 'docs', 'scripts', 'tests')) {
                New-Item -ItemType Directory -Path (Join-Path $Root $directory) -Force | Out-Null
            }
            foreach ($file in @(
                'README.md', 'LICENSE', 'SECURITY.md', 'CONTRIBUTING.md', 'AGENTS.md',
                '.github/dependabot.yml', '.github/workflows/governance-ci.yml', '.github/pull_request_template.md',
                'docs/BRANCH_PROTECTION.md', 'docs/ACTION_SECURITY.md', 'scripts/GovernanceValidation.psm1',
                'scripts/Test-GitHubWorkflowArchitecture.ps1'
            )) {
                Set-Content -LiteralPath (Join-Path $Root $file) -Value 'fixture'
            }
            foreach ($validator in @('scripts/Test-DocumentationCompleteness.ps1', 'scripts/Test-YamlSyntax.ps1', 'scripts/Test-JsonSchemas.ps1')) {
                Set-Content -LiteralPath (Join-Path $Root $validator) -Value 'exit 0'
            }
            Set-Content -LiteralPath (Join-Path $Root 'tests/Fixture.Tests.ps1') -Value "Describe 'fixture' { It 'passes' { `$true | Should -BeTrue } }"
            Set-Content -LiteralPath (Join-Path $Root 'CODEOWNERS') -Value $Codeowners
            $manifest = Get-Content -LiteralPath "$PSScriptRoot/../fixtures/valid/project-manifest.json" -Raw | ConvertFrom-Json -AsHashtable
            $manifest.projectType = $ProjectType
            $manifest.projectName = "Synthetic $ProjectType Repository"
            $manifest.repository = "example-org/synthetic-$ProjectType"
            $manifest | ConvertTo-Json -Depth 20 | Set-Content -LiteralPath (Join-Path $Root 'project-manifest.json')
            $config = Get-Content -LiteralPath "$PSScriptRoot/../fixtures/valid/governance-config.json" -Raw | ConvertFrom-Json -AsHashtable
            if ($PSBoundParameters.ContainsKey('RequiredCodeownerPaths')) {
                $config.ownership = @{ requiredCodeownerPaths = @($RequiredCodeownerPaths) }
            }
            $config | ConvertTo-Json -Depth 20 | Set-Content -LiteralPath (Join-Path $Root 'governance.config.json')
        }
    }

    AfterAll {
        if ($script:actionHarnessRoot -and (Test-Path -LiteralPath $script:actionHarnessRoot)) {
            Remove-Item -LiteralPath $script:actionHarnessRoot -Recurse -Force
        }
    }

    Context 'rebuilt repository' {
        It 'passes repository health validation' {
            & pwsh -NoProfile -File "$PSScriptRoot/../../actions/repository-health/Invoke-RepositoryHealth.ps1" -Path "$PSScriptRoot/../.."
            $LASTEXITCODE | Should -Be 0
        }

        It 'defaults owner type to Unknown without repository-name inference' {
            $scriptText = Get-Content -LiteralPath "$PSScriptRoot/../../actions/repository-health/Invoke-RepositoryHealth.ps1" -Raw
            $scriptText | Should -Match "RepositoryOwnerType = 'Unknown'"
            $scriptText | Should -Not -Match '\^AIAllTheThingz/'
        }

        It 'does not track generated build output directories' {
            $root = Resolve-Path "$PSScriptRoot/../.."
            $tracked = @(& git -C $root ls-files | Where-Object {
                $_ -match '(^|/)(bin|obj|dist)(/|$)' -or $_ -match '^(coverage|TestResults)(/|$)'
            })
            $tracked.Count | Should -Be 0
        }

        It 'exposes and safely forwards repository owner type through action metadata' {
            $action = Get-Content -LiteralPath "$PSScriptRoot/../../actions/repository-health/action.yml" -Raw
            $action | Should -Match '(?m)^  repository-owner-type:'
            $action | Should -Match '(?m)^    default: Unknown$'
            $action | Should -Match '(?ms)^  path:.*?^    default: \.$'
            $action | Should -Match 'RepositoryOwnerType = \$ownerType'
            $action | Should -Match '\$ownerType'
            $action | Should -Match 'inputs\.path'
            $action | Should -Match 'inputs\.output-json'
            $action | Should -Match 'inputs\.advisory'
            $runBlock = ($action -split '(?m)^      run: \|\r?$')[1]
            $runBlock | Should -Not -Match '\$\{\{ inputs\.'
            $runBlock | Should -Match '\$env:INPUT_PATH'
            $runBlock | Should -Match '\$env:INPUT_REPOSITORY_OWNER_TYPE'
            $runBlock | Should -Match '@invokeParameters'
            $action | Should -Not -Match 'Invoke-Expression'
        }

        It 'accepts each exact repository owner type and rejects invalid casing and values' {
            foreach ($ownerType in @('Unknown', 'User', 'Organization')) {
                & pwsh -NoProfile -File "$PSScriptRoot/../../actions/repository-health/Invoke-RepositoryHealth.ps1" -Path "$PSScriptRoot/../.." -RepositoryOwnerType $ownerType | Out-Null
                $LASTEXITCODE | Should -Be 0 -Because $ownerType
            }
            foreach ($ownerType in @('user', 'ORG', 'Repository', ' ', 'arbitrary')) {
                & pwsh -NoProfile -File "$PSScriptRoot/../../actions/repository-health/Invoke-RepositoryHealth.ps1" -Path "$PSScriptRoot/../.." -RepositoryOwnerType $ownerType 2>$null
                $LASTEXITCODE | Should -Not -Be 0 -Because $ownerType
            }
        }

        It 'preserves CODEOWNERS rule and identity diagnostics in repository-health results' {
            $scriptText = Get-Content -LiteralPath "$PSScriptRoot/../../actions/repository-health/Invoke-RepositoryHealth.ps1" -Raw
            $scriptText | Should -Match 'rulePattern = \$finding\.Path'
            $scriptText | Should -Match 'identity = \$finding\.Identity'
            $scriptText | Should -Match '-Data \$findingData'
        }

        It 'enforces this repository explicit high-risk CODEOWNERS configuration' {
            $config = Get-Content -LiteralPath "$PSScriptRoot/../../governance.config.json" -Raw | ConvertFrom-Json
            @($config.ownership.requiredCodeownerPaths).Count | Should -BeGreaterThan 0
            $reportRelativePath = '.tmp/repository-health-central-' + [guid]::NewGuid() + '.json'
            $reportPath = Join-Path "$PSScriptRoot/../.." $reportRelativePath
            try {
                & pwsh -NoProfile -File "$PSScriptRoot/../../actions/repository-health/Invoke-RepositoryHealth.ps1" -Path "$PSScriptRoot/../.." -RepositoryOwnerType User -OutputJson $reportRelativePath | Out-Null
                $LASTEXITCODE | Should -Be 0
                $report = Get-Content -LiteralPath $reportPath -Raw | ConvertFrom-Json
                $requiredPathFindings = @($report.results | Where-Object { $null -ne $_.data -and $_.data.requiredPath })
                $expectedEvaluationPaths = [System.Collections.Generic.List[string]]::new()
                foreach ($configuredPath in $config.ownership.requiredCodeownerPaths) {
                    $fullPath = Join-Path "$PSScriptRoot/../.." $configuredPath.TrimStart('/').TrimEnd('/')
                    if (Test-Path -LiteralPath $fullPath -PathType Container) {
                        $files = @(Get-ChildItem -LiteralPath $fullPath -Recurse -File -Force)
                        if ($files.Count -eq 0) { $expectedEvaluationPaths.Add($configuredPath) }
                        foreach ($file in $files) {
                            $relative = [System.IO.Path]::GetRelativePath((Resolve-Path "$PSScriptRoot/../..").Path, $file.FullName).Replace([char]'\', [char]'/')
                            $expectedEvaluationPaths.Add("/$relative")
                        }
                    }
                    else { $expectedEvaluationPaths.Add($configuredPath) }
                }
                $expectedEvaluationPaths = @($expectedEvaluationPaths | Sort-Object -Unique)
                $requiredPathFindings.Count | Should -Be $expectedEvaluationPaths.Count
                @($requiredPathFindings | Where-Object status -ne 'Passed').Count | Should -Be 0
                @($requiredPathFindings.data.requiredPath | Sort-Object -Unique) | Should -Be $expectedEvaluationPaths
            }
            finally {
                if (Test-Path -LiteralPath $reportPath) { Remove-Item -LiteralPath $reportPath -Force }
            }
        }

        It 'does not require central governance paths in a downstream PowerShell repository' {
            $root = Join-Path $script:actionHarnessRoot 'downstream-powershell'
            New-SyntheticRepositoryHealthFixture -Root $root -ProjectType powershell -Codeowners '* @downstream-owner'
            Test-Path -LiteralPath (Join-Path $root 'governance') | Should -BeFalse
            & pwsh -NoProfile -File "$PSScriptRoot/../../actions/repository-health/Invoke-RepositoryHealth.ps1" -Path $root | Out-Null
            $LASTEXITCODE | Should -Be 0
        }

        It 'does not require central skill paths in a downstream .NET repository' {
            $root = Join-Path $script:actionHarnessRoot 'downstream-dotnet'
            New-SyntheticRepositoryHealthFixture -Root $root -ProjectType dotnet -Codeowners '* @downstream-owner'
            Test-Path -LiteralPath (Join-Path $root '.agents/skills') | Should -BeFalse
            & pwsh -NoProfile -File "$PSScriptRoot/../../actions/repository-health/Invoke-RepositoryHealth.ps1" -Path $root | Out-Null
            $LASTEXITCODE | Should -Be 0
        }

        It 'requires default CODEOWNERS coverage when downstream ownership configuration is omitted' {
            $root = Join-Path $script:actionHarnessRoot 'downstream-missing-default'
            New-SyntheticRepositoryHealthFixture -Root $root -ProjectType powershell -Codeowners '/scripts/ @script-owner'
            $output = & pwsh -NoProfile -File "$PSScriptRoot/../../actions/repository-health/Invoke-RepositoryHealth.ps1" -Path $root 2>&1
            $LASTEXITCODE | Should -Be 1
            $output | Out-String | Should -Match "CODEOWNERS must include default '\*' coverage"
        }

        It 'selects each GitHub-supported CODEOWNERS location and identifies it in diagnostics' -ForEach @(
            @{ Location = '.github/CODEOWNERS'; Fixture = 'codeowners-dot-github' }
            @{ Location = 'CODEOWNERS'; Fixture = 'codeowners-root' }
            @{ Location = 'docs/CODEOWNERS'; Fixture = 'codeowners-docs' }
        ) {
            $root = Join-Path $script:actionHarnessRoot $Fixture
            New-SyntheticRepositoryHealthFixture -Root $root -Codeowners '* @downstream-owner'
            if ($Location -ne 'CODEOWNERS') {
                Move-Item -LiteralPath (Join-Path $root 'CODEOWNERS') -Destination (Join-Path $root $Location)
            }
            & pwsh -NoProfile -File "$PSScriptRoot/../../actions/repository-health/Invoke-RepositoryHealth.ps1" -Path $root -OutputJson 'health.json' | Out-Null
            $LASTEXITCODE | Should -Be 0
            $report = Get-Content -LiteralPath (Join-Path $root 'health.json') -Raw | ConvertFrom-Json
            $selection = @($report.results | Where-Object message -eq 'GitHub-selected CODEOWNERS file exists.')
            $selection.Count | Should -Be 1
            $selection[0].path | Should -Be $Location
            @($report.results | Where-Object { $_.data -and $_.data.rulePattern }).path | Should -Contain $Location
        }

        It 'selects the highest-priority CODEOWNERS file when multiple locations exist' {
            $root = Join-Path $script:actionHarnessRoot 'codeowners-precedence'
            New-SyntheticRepositoryHealthFixture -Root $root -Codeowners '* @root-owner'
            Set-Content -LiteralPath (Join-Path $root 'docs/CODEOWNERS') -Value '* @docs-owner'
            Set-Content -LiteralPath (Join-Path $root '.github/CODEOWNERS') -Value '* @github-owner'
            & pwsh -NoProfile -File "$PSScriptRoot/../../actions/repository-health/Invoke-RepositoryHealth.ps1" -Path $root -OutputJson 'health.json' | Out-Null
            $LASTEXITCODE | Should -Be 0
            $report = Get-Content -LiteralPath (Join-Path $root 'health.json') -Raw | ConvertFrom-Json
            @($report.results | Where-Object message -eq 'GitHub-selected CODEOWNERS file exists.')[0].path | Should -Be '.github/CODEOWNERS'
            $ownerFinding = @($report.results | Where-Object { $_.data -and $_.data.identity })[0]
            $ownerFinding.path | Should -Be '.github/CODEOWNERS'
            $ownerFinding.data.identity | Should -Be '@github-owner'
        }

        It 'does not accept a valid root file when the selected higher-priority file is invalid' {
            $root = Join-Path $script:actionHarnessRoot 'codeowners-invalid-precedence'
            New-SyntheticRepositoryHealthFixture -Root $root -Codeowners '* @root-owner'
            Set-Content -LiteralPath (Join-Path $root '.github/CODEOWNERS') -Value '* owner-without-prefix'
            & pwsh -NoProfile -File "$PSScriptRoot/../../actions/repository-health/Invoke-RepositoryHealth.ps1" -Path $root -OutputJson 'health.json' 2>$null
            $LASTEXITCODE | Should -Be 1
            $report = Get-Content -LiteralPath (Join-Path $root 'health.json') -Raw | ConvertFrom-Json
            @($report.results | Where-Object status -eq 'Failed').path | Should -Contain '.github/CODEOWNERS'
            @($report.results | Where-Object { $_.data -and $_.data.identity -eq '@root-owner' }).Count | Should -Be 0
        }

        It 'does not accept a valid root file when the selected higher-priority file removes required ownership' {
            $root = Join-Path $script:actionHarnessRoot 'codeowners-ownerless-precedence'
            New-SyntheticRepositoryHealthFixture -Root $root -RequiredCodeownerPaths @('/scripts/') -Codeowners '* @root-owner'
            Set-Content -LiteralPath (Join-Path $root '.github/CODEOWNERS') -Value "* @github-owner`n/scripts/"
            & pwsh -NoProfile -File "$PSScriptRoot/../../actions/repository-health/Invoke-RepositoryHealth.ps1" -Path $root -OutputJson 'health.json' 2>$null
            $LASTEXITCODE | Should -Be 1
            $report = Get-Content -LiteralPath (Join-Path $root 'health.json') -Raw | ConvertFrom-Json
            $failure = @($report.results | Where-Object { $_.status -eq 'Failed' -and $_.data.requiredPath })[0]
            $failure.path | Should -Be '.github/CODEOWNERS'
            $failure.message | Should -Match 'has no owners'
        }

        It 'rejects case-variant CODEOWNERS filenames without falling through' -ForEach @(
            @{ Location = '.github/codeowners'; Fixture = 'codeowners-case-dot-github'; Expected = '.github/CODEOWNERS' }
            @{ Location = 'codeowners'; Fixture = 'codeowners-case-root'; Expected = 'CODEOWNERS' }
            @{ Location = 'docs/codeowners'; Fixture = 'codeowners-case-docs'; Expected = 'docs/CODEOWNERS' }
        ) {
            $root = Join-Path $script:actionHarnessRoot $Fixture
            New-SyntheticRepositoryHealthFixture -Root $root -Codeowners '* @root-owner'
            if ($Location -eq 'codeowners') {
                Move-Item -LiteralPath (Join-Path $root 'CODEOWNERS') -Destination (Join-Path $root 'temporary-owner-file')
                Move-Item -LiteralPath (Join-Path $root 'temporary-owner-file') -Destination (Join-Path $root $Location)
            }
            else {
                Set-Content -LiteralPath (Join-Path $root $Location) -Value '* @case-variant-owner'
                if ($Location -eq 'docs/codeowners') {
                    Remove-Item -LiteralPath (Join-Path $root 'CODEOWNERS') -Force
                }
            }
            & pwsh -NoProfile -File "$PSScriptRoot/../../actions/repository-health/Invoke-RepositoryHealth.ps1" -Path $root -OutputJson 'health.json' 2>$null
            $LASTEXITCODE | Should -Be 1
            $report = Get-Content -LiteralPath (Join-Path $root 'health.json') -Raw | ConvertFrom-Json
            $failure = @($report.results | Where-Object { $_.status -eq 'Failed' -and $_.path -eq $Expected })[0]
            $failure.message | Should -Match 'does not match repository path casing'
        }

        It 'rejects a higher-priority symbolic-link CODEOWNERS file without falling through' {
            $root = Join-Path $script:actionHarnessRoot 'codeowners-symbolic-link'
            New-SyntheticRepositoryHealthFixture -Root $root -Codeowners '* @root-owner'
            try {
                New-Item -ItemType SymbolicLink -Path (Join-Path $root '.github/CODEOWNERS') -Target (Join-Path $root 'CODEOWNERS') -ErrorAction Stop | Out-Null
            }
            catch {
                Set-ItResult -Skipped -Because "Symbolic-link creation is unavailable: $($_.Exception.Message)"
                return
            }
            & pwsh -NoProfile -File "$PSScriptRoot/../../actions/repository-health/Invoke-RepositoryHealth.ps1" -Path $root -OutputJson 'health.json' 2>$null
            $LASTEXITCODE | Should -Be 1
            $report = Get-Content -LiteralPath (Join-Path $root 'health.json') -Raw | ConvertFrom-Json
            $failure = @($report.results | Where-Object { $_.status -eq 'Failed' -and $_.path -eq '.github/CODEOWNERS' })[0]
            $failure.message | Should -Match 'must not be a symbolic link, junction, or reparse point'
            @($report.results | Where-Object { $_.data -and $_.data.identity -eq '@root-owner' }).Count | Should -Be 0
        }

        It 'passes configured existing paths with effective ownership and reports the selected rule' {
            $root = Join-Path $script:actionHarnessRoot 'downstream-configured'
            New-SyntheticRepositoryHealthFixture -Root $root -RequiredCodeownerPaths @('/src/') -Codeowners "* @downstream-owner`n/src/ @downstream-owner"
            New-Item -ItemType Directory -Path (Join-Path $root 'src') -Force | Out-Null
            Set-Content -LiteralPath (Join-Path $root 'src/app.ps1') -Value 'Write-Output fixture'
            & pwsh -NoProfile -File "$PSScriptRoot/../../actions/repository-health/Invoke-RepositoryHealth.ps1" -Path $root -OutputJson 'health.json' | Out-Null
            $LASTEXITCODE | Should -Be 0
            $report = Get-Content -LiteralPath (Join-Path $root 'health.json') -Raw | ConvertFrom-Json
            $finding = @($report.results | Where-Object { $null -ne $_.data -and $_.data.requiredPath -eq '/src/app.ps1' })[-1]
            $finding.status | Should -Be 'Passed'
            $finding.data.effectivePattern | Should -Be '/src/'
            @($finding.data.effectiveOwners) | Should -Be @('@downstream-owner')
            $finding.data.ruleIndex | Should -Be 2
            $finding.data.lineNumber | Should -Be 2
        }

        It 'fails a concrete file under a configured directory when a later exact rule removes ownership' {
            $root = Join-Path $script:actionHarnessRoot 'downstream-directory-file-override'
            New-SyntheticRepositoryHealthFixture -Root $root -RequiredCodeownerPaths @('/scripts/') -Codeowners "* @downstream-owner`n/scripts/ @script-owner`n/scripts/build.ps1"
            Set-Content -LiteralPath (Join-Path $root 'scripts/build.ps1') -Value 'Write-Output fixture'
            $output = & pwsh -NoProfile -File "$PSScriptRoot/../../actions/repository-health/Invoke-RepositoryHealth.ps1" -Path $root 2>&1
            $LASTEXITCODE | Should -Be 1
            $output | Out-String | Should -Match "required path '/scripts/build.ps1' has no owners"
        }

        It 'fails closed when a later unsupported embedded double-star pattern could match a concrete file' {
            $root = Join-Path $script:actionHarnessRoot 'downstream-directory-unsupported-override'
            New-SyntheticRepositoryHealthFixture -Root $root -RequiredCodeownerPaths @('/scripts/') -Codeowners "* @downstream-owner`n/scripts/ @script-owner`n/scripts/a*ab**cd"
            Set-Content -LiteralPath (Join-Path $root 'scripts/axabZZcd') -Value 'fixture'
            $output = & pwsh -NoProfile -File "$PSScriptRoot/../../actions/repository-health/Invoke-RepositoryHealth.ps1" -Path $root 2>&1
            $LASTEXITCODE | Should -Be 1
            $output | Out-String | Should -Match "Unsupported CODEOWNERS pattern '/scripts/a\*ab\*\*cd' could affect required path '/scripts/axabZZcd'"
        }

        It 'fails configured existing paths when a later ownerless rule removes ownership' {
            $root = Join-Path $script:actionHarnessRoot 'downstream-ownerless-override'
            New-SyntheticRepositoryHealthFixture -Root $root -RequiredCodeownerPaths @('/src/') -Codeowners "* @downstream-owner`n/src/ @source-owner`n/src/"
            New-Item -ItemType Directory -Path (Join-Path $root 'src') -Force | Out-Null
            $output = & pwsh -NoProfile -File "$PSScriptRoot/../../actions/repository-health/Invoke-RepositoryHealth.ps1" -Path $root 2>&1
            $LASTEXITCODE | Should -Be 1
            $output | Out-String | Should -Match "Effective CODEOWNERS rule '/src/' for required path '/src/' has no owners"
        }

        It 'fails when a configured required CODEOWNERS path does not exist' {
            $root = Join-Path $script:actionHarnessRoot 'downstream-missing-path'
            New-SyntheticRepositoryHealthFixture -Root $root -RequiredCodeownerPaths @('/governance/') -Codeowners "* @downstream-owner`n/governance/ @downstream-owner"
            $output = & pwsh -NoProfile -File "$PSScriptRoot/../../actions/repository-health/Invoke-RepositoryHealth.ps1" -Path $root 2>&1
            $LASTEXITCODE | Should -Be 1
            $output | Out-String | Should -Match "Configured required CODEOWNERS path '/governance/' does not exist"
        }

        It 'enforces configured trailing-slash path kinds' {
            $directoryRoot = Join-Path $script:actionHarnessRoot 'downstream-directory-kind'
            New-SyntheticRepositoryHealthFixture -Root $directoryRoot -RequiredCodeownerPaths @('/scripts') -Codeowners '* @downstream-owner'
            $directoryOutput = & pwsh -NoProfile -File "$PSScriptRoot/../../actions/repository-health/Invoke-RepositoryHealth.ps1" -Path $directoryRoot 2>&1
            $LASTEXITCODE | Should -Be 1
            $directoryOutput | Out-String | Should -Match "does not end with '/' but is a directory"

            $fileRoot = Join-Path $script:actionHarnessRoot 'downstream-file-kind'
            New-SyntheticRepositoryHealthFixture -Root $fileRoot -RequiredCodeownerPaths @('/SECURITY.md/') -Codeowners '* @downstream-owner'
            $fileOutput = & pwsh -NoProfile -File "$PSScriptRoot/../../actions/repository-health/Invoke-RepositoryHealth.ps1" -Path $fileRoot 2>&1
            $LASTEXITCODE | Should -Be 1
            $fileOutput | Out-String | Should -Match "ends with '/' but is not a directory"
        }

        It 'rejects configured repository path casing that differs from GitHub case-sensitive paths' {
            $root = Join-Path $script:actionHarnessRoot 'downstream-path-case'
            New-SyntheticRepositoryHealthFixture -Root $root -RequiredCodeownerPaths @('/SRC/') -Codeowners "* @downstream-owner`n/SRC/ @source-owner"
            New-Item -ItemType Directory -Path (Join-Path $root 'src') -Force | Out-Null
            $output = & pwsh -NoProfile -File "$PSScriptRoot/../../actions/repository-health/Invoke-RepositoryHealth.ps1" -Path $root 2>&1
            $LASTEXITCODE | Should -Be 1
            $output | Out-String | Should -Match "does not (exist|match repository path casing)"
        }

        It 'behaviorally forwards action inputs and preserves outputs through the argument array' {
            foreach ($ownerType in @('Unknown', 'User', 'Organization')) {
                $capture = Join-Path $script:actionHarnessRoot "capture-$ownerType.json"
                $report = Join-Path $script:actionHarnessRoot "report-$ownerType.json"
                $githubOutput = Join-Path $script:actionHarnessRoot "output-$ownerType.txt"
                $prior = @($env:INPUT_PATH, $env:INPUT_OUTPUT_JSON, $env:INPUT_ADVISORY, $env:INPUT_REPOSITORY_OWNER_TYPE, $env:REPOSITORY_HEALTH_ACTION_PATH, $env:CAPTURE_PATH, $env:GITHUB_OUTPUT, $env:RUNNER_TEMP)
                try {
                    $env:INPUT_PATH = '.'
                    $env:INPUT_OUTPUT_JSON = $report
                    $env:INPUT_ADVISORY = 'true'
                    $env:INPUT_REPOSITORY_OWNER_TYPE = $ownerType
                    $env:REPOSITORY_HEALTH_ACTION_PATH = $script:actionHarnessRoot
                    $env:CAPTURE_PATH = $capture
                    $env:GITHUB_OUTPUT = $githubOutput
                    $env:RUNNER_TEMP = $script:actionHarnessRoot
                    & pwsh -NoProfile -File (Join-Path $script:actionHarnessRoot 'action-run.ps1')
                    $LASTEXITCODE | Should -Be 0 -Because $ownerType
                    $actual = Get-Content -LiteralPath $capture -Raw | ConvertFrom-Json
                    $actual.Path | Should -Be '.'
                    $actual.OutputJson | Should -Be $report
                    $actual.Advisory | Should -BeTrue
                    $actual.RepositoryOwnerType | Should -Be $ownerType
                    Get-Content -LiteralPath $githubOutput -Raw | Should -Match 'failed-count=0'
                }
                finally {
                    $env:INPUT_PATH, $env:INPUT_OUTPUT_JSON, $env:INPUT_ADVISORY, $env:INPUT_REPOSITORY_OWNER_TYPE, $env:REPOSITORY_HEALTH_ACTION_PATH, $env:CAPTURE_PATH, $env:GITHUB_OUTPUT, $env:RUNNER_TEMP = $prior
                }
            }
        }

        It 'rejects invalid action input before invoking the entry point' {
            $capture = Join-Path $script:actionHarnessRoot 'invalid-capture.json'
            $prior = @($env:INPUT_PATH, $env:INPUT_OUTPUT_JSON, $env:INPUT_ADVISORY, $env:INPUT_REPOSITORY_OWNER_TYPE, $env:REPOSITORY_HEALTH_ACTION_PATH, $env:CAPTURE_PATH, $env:GITHUB_OUTPUT, $env:RUNNER_TEMP)
            try {
                $env:INPUT_PATH = '.'
                $env:INPUT_OUTPUT_JSON = (Join-Path $script:actionHarnessRoot 'invalid-report.json')
                $env:INPUT_ADVISORY = 'false'
                $env:INPUT_REPOSITORY_OWNER_TYPE = 'user'
                $env:REPOSITORY_HEALTH_ACTION_PATH = $script:actionHarnessRoot
                $env:CAPTURE_PATH = $capture
                $env:GITHUB_OUTPUT = (Join-Path $script:actionHarnessRoot 'invalid-output.txt')
                $env:RUNNER_TEMP = $script:actionHarnessRoot
                & pwsh -NoProfile -File (Join-Path $script:actionHarnessRoot 'action-run.ps1') 2>$null
                $LASTEXITCODE | Should -Not -Be 0
                Test-Path -LiteralPath $capture | Should -BeFalse
            }
            finally {
                $env:INPUT_PATH, $env:INPUT_OUTPUT_JSON, $env:INPUT_ADVISORY, $env:INPUT_REPOSITORY_OWNER_TYPE, $env:REPOSITORY_HEALTH_ACTION_PATH, $env:CAPTURE_PATH, $env:GITHUB_OUTPUT, $env:RUNNER_TEMP = $prior
            }
        }
    }

    Context 'invalid repository' {
        BeforeAll {
            $script:tempRoot = Join-Path ([System.IO.Path]::GetTempPath()) ("repo-health-tests-" + [guid]::NewGuid())
            New-Item -ItemType Directory -Path $script:tempRoot -Force | Out-Null
            Set-Content -LiteralPath (Join-Path $script:tempRoot 'README.md') -Value '# Incomplete'
        }

        AfterAll {
            if ($script:tempRoot -and (Test-Path -LiteralPath $script:tempRoot)) {
                Remove-Item -LiteralPath $script:tempRoot -Recurse -Force
            }
        }

        It 'fails when required governance files are absent' {
            & pwsh -NoProfile -File "$PSScriptRoot/../../actions/repository-health/Invoke-RepositoryHealth.ps1" -Path $script:tempRoot
            $LASTEXITCODE | Should -Not -Be 0
        }
    }
}
