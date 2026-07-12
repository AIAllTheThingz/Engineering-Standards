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
