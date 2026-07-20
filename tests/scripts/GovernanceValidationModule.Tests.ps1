BeforeAll {
    Import-Module "$PSScriptRoot/../../scripts/GovernanceValidation.psm1" -Force
    $script:tempRoot = Join-Path ([System.IO.Path]::GetTempPath()) ("governance-module-tests-" + [guid]::NewGuid())
    New-Item -ItemType Directory -Path $script:tempRoot -Force | Out-Null
}

AfterAll {
    if ($script:tempRoot -and (Test-Path -LiteralPath $script:tempRoot)) {
        Remove-Item -LiteralPath $script:tempRoot -Recurse -Force
    }
}

Describe 'GovernanceValidation module' {
    Context 'authoritative validation registry and profiles' {
        It 'defines unique ordered categories with valid trusted runner paths' {
            $repoRoot = (Resolve-Path "$PSScriptRoot/../..").Path
            $registry = @(Get-GovernanceValidationCategoryRegistry)

            $registry.Count | Should -Be 17
            @($registry.Name | Sort-Object -Unique).Count | Should -Be $registry.Count
            @($registry.Order | Sort-Object -Unique).Count | Should -Be $registry.Count
            ($registry.Name -join ',') | Should -BeExactly 'Contract,AgentStandards,CodexSkills,JsonSchemas,YamlSyntax,WorkflowArchitecture,MarkdownLinks,DocumentationCompleteness,ForbiddenPatterns,RepositoryHealth,Evidence,PowerShellParser,PythonStaticAnalysis,BashStaticAnalysis,Pester,PSScriptAnalyzer,Examples'
            foreach ($entry in $registry | Where-Object Runner -eq 'Script') {
                Test-Path -LiteralPath (Join-Path $repoRoot $entry.Path) -PathType Leaf | Should -BeTrue -Because $entry.Name
            }
        }

        It 'declares the complete Examples validation prerequisites' {
            $examples = Get-GovernanceValidationCategoryRegistry | Where-Object Name -eq 'Examples'

            @($examples.RequiredCommands) | Should -Contain 'python'
            @($examples.RequiredPythonModules) | Should -Contain 'yaml'
        }

        It 'keeps the aggregate Category parameter synchronized with the registry' {
            $repoRoot = (Resolve-Path "$PSScriptRoot/../..").Path
            $scriptCommand = Get-Command -Name (Join-Path $repoRoot 'scripts/Invoke-GovernanceValidation.ps1')
            $validateSet = @($scriptCommand.Parameters.Category.Attributes | Where-Object { $_ -is [System.Management.Automation.ValidateSetAttribute] })
            $validateSet | Should -HaveCount 1
            ($validateSet[0].ValidValues -join ',') | Should -BeExactly ((Get-GovernanceValidationCategoryRegistry).Name -join ',')
        }

        It 'adds every maintainer mandatory category to an explicit narrow selection' {
            $profile = Get-GovernanceValidationProfile -Name 'standards-maintainer'
            $plan = @(Resolve-GovernanceValidationPlan -Profile 'standards-maintainer' -ConfiguredCategory @('Contract') -RequestedCategory @('JsonSchemas'))

            ($plan.Name -join ',') | Should -BeExactly ($profile.mandatoryCategories -join ',')
            @($plan | Where-Object mandatory).Count | Should -Be $profile.mandatoryCategories.Count
        }

        It 'adds downstream Contract while allowing explicit optional category selection' {
            $plan = @(Resolve-GovernanceValidationPlan -Profile downstream -ConfiguredCategory @('Contract','ForbiddenPatterns') -RequestedCategory @('MarkdownLinks'))

            ($plan.Name -join ',') | Should -BeExactly 'Contract,MarkdownLinks,PythonStaticAnalysis,BashStaticAnalysis'
            ($plan | Where-Object Name -eq 'Contract').selectedBy | Should -BeExactly 'ProfileMandatory'
            { Resolve-GovernanceValidationPlan -Profile downstream -ConfiguredCategory @('Contract') -RequestedCategory @('Pester') } | Should -Throw '*not applicable*'
        }

        It 'keeps an actively excepted mandatory category visible in the plan' {
            $plan = @(Resolve-GovernanceValidationPlan -Profile 'standards-maintainer' -ConfiguredCategory @('Contract') -RequestedCategory @('JsonSchemas') -ApprovedDisabledControl @('Pester'))

            ($plan | Where-Object Name -eq 'Pester').excepted | Should -BeTrue
            { Resolve-GovernanceValidationPlan -Profile 'standards-maintainer' -ConfiguredCategory @('Contract') -ApprovedDisabledControl @('Contract') } | Should -Throw '*cannot be disabled*'
        }

        It 'aggregates mandatory child statuses using canonical completion semantics' {
            Get-GovernanceAggregateStatus -Results @([pscustomobject]@{status='Passed';requiredValidation=$true}) | Should -BeExactly 'Passed'
            Get-GovernanceAggregateStatus -Results @([pscustomobject]@{status='NotRun';requiredValidation=$true}) | Should -BeExactly 'NotRun'
            Get-GovernanceAggregateStatus -Results @([pscustomobject]@{status='Blocked';requiredValidation=$true}) | Should -BeExactly 'Blocked'
            Get-GovernanceAggregateStatus -Results @([pscustomobject]@{status='Failed';requiredValidation=$true}) | Should -BeExactly 'Failed'
            Get-GovernanceAggregateStatus -Results @([pscustomobject]@{status='NotApplicable';requiredValidation=$true}) | Should -BeExactly 'NotApplicable'
            Get-GovernanceAggregateStatus -Results @(
                [pscustomobject]@{status='Passed';requiredValidation=$true},
                [pscustomobject]@{status='Failed';requiredValidation=$false}
            ) | Should -BeExactly 'Passed'
        }

        It 'reports missing validation tooling instead of silently skipping it' {
            $entry = [ordered]@{
                requiredCommands = @('governance-validator-command-that-does-not-exist')
                requiredPythonModules = @()
            }

            $missing = @(Get-GovernanceMissingValidationPrerequisite -PlanEntry $entry)
            $missing | Should -HaveCount 1
            $missing[0] | Should -BeExactly "command 'governance-validator-command-that-does-not-exist'"
        }
    }

    Context 'workflow output sanitization' {
        It 'neutralizes every embedded workflow command physical line' {
            $inputText = "ordinary text`r`n::warning::warn`n  ::error::error`r::add-mask::secret`n::stop-commands::token`n::set-output name=x::value"
            $lines = @(ConvertTo-SanitizedWorkflowOutputLine -InputObject $inputText -WorkspaceRoot 'C:\workspace' -TemporaryRoot 'C:\temp')
            $lines.Count | Should -Be 6
            $lines[0] | Should -Be 'ordinary text'
            foreach ($line in $lines[1..5]) {
                $line | Should -Match '^\[validator-output\] '
                $line | Should -Not -Match '^\s*::'
            }
            ($lines -join "`n") | Should -Match '\[validator-output\] ::warning::warn'
            ($lines -join "`n") | Should -Match '\[validator-output\] ::add-mask::secret'
            ($lines -join "`n") | Should -Match '\[validator-output\] ::stop-commands::token'
            ($lines -join "`n") | Should -Match '\[validator-output\] ::set-output name=x::value'
        }

        It 'removes unsafe controls before redacting each physical line' {
            $lines = @(ConvertTo-SanitizedWorkflowOutputLine -InputObject "C:\work$([char]7)space\one`nC:\temp\two$([char]7)" -WorkspaceRoot 'C:\workspace' -TemporaryRoot 'C:\temp')
            $lines | Should -Be @('[workspace]\one','[temp]\two')
        }

        It 'sanitizes and bounds failure messages for downloadable evidence' {
            $pat = 'ghp_' + ('a' * 30)
            $credentialKey = 'to' + 'ken'
            $inputText = "C:\workspace\repo`r`n  ::error::bad$([char]7)`nAuthorization: Bearer bearer-value`n$credentialKey=token-value-12345`nhttps://user:password@example.invalid/path`n$pat"
            $message = ConvertTo-SanitizedWorkflowFailureMessage -InputObject $inputText -WorkspaceRoot 'C:\workspace' -TemporaryRoot 'C:\temp' -MaximumLength 512
            $message | Should -Match '\[workspace\]\\repo'
            $message | Should -Match '\[validator-output\]\s+::error::bad'
            $message | Should -Match 'Authorization: \[redacted\]'
            $message | Should -Match ($credentialKey + '=\[redacted\]')
            $message | Should -Match 'https://\[redacted\]@example.invalid/path'
            $message | Should -Not -Match 'bearer-value|token-value|password|ghp_'
            $message | Should -Not -Match "`r|`n|$([char]7)"
            $message.Length | Should -BeLessOrEqual 512
        }

        It 'uses a generic reason only when no safe specific message exists and never clobbers evidence' {
            $evidence = Join-Path $script:tempRoot 'bootstrap-evidence'
            New-Item -ItemType Directory -Path $evidence -Force | Out-Null
            Write-GovernanceBootstrapFailureReport -EvidenceRoot $evidence -FailureMessage 'Governance version mismatch: expected 1.1.0.' -CallerRepository 'ExampleOrg/repo' -CallerCommitSha ('1' * 40) -StandardsWorkflowSha ('2' * 40) -GovernanceVersion '1.1.0' | Out-Null
            Write-GovernanceBootstrapFailureReport -EvidenceRoot $evidence -FailureMessage '' -GenericFallbackMessage 'generic fallback' -CallerRepository 'ExampleOrg/repo' -CallerCommitSha ('1' * 40) -StandardsWorkflowSha ('2' * 40) -GovernanceVersion '1.1.0' | Out-Null
            $report = Get-Content -LiteralPath (Join-Path $evidence 'governance-validation.json') -Raw | ConvertFrom-Json
            $report.results[0].name | Should -Be 'BootstrapValidation'
            $report.results[0].failureReason | Should -Be 'Governance version mismatch: expected 1.1.0.'
            $report.failed | Should -Be 1
        }
    }

    Context 'safe path resolution' {
        It 'resolves a child path inside the root' {
            $file = Join-Path $script:tempRoot 'inside.txt'
            Set-Content -LiteralPath $file -Value 'ok'
            Resolve-SafePath -Root $script:tempRoot -ChildPath 'inside.txt' | Should -Be $file
        }

        It 'rejects traversal outside the root' {
            { Resolve-SafePath -Root $script:tempRoot -ChildPath '../outside.txt' } | Should -Throw
        }
    }

    Context 'test evidence semantics' {
        It 'accepts NotRun evidence with policy exit code 3' {
            $doc = [ordered]@{
                schemaVersion = '1.0.0'
                name = 'Analyzer validation'
                category = 'lint'
                status = 'NotRun'
                command = 'Invoke-ScriptAnalyzer -Path .'
                workingDirectory = '.'
                startedAtUtc = '2026-06-19T00:00:00Z'
                completedAtUtc = '2026-06-19T00:00:00Z'
                durationSeconds = 0
                runtime = 'PowerShell 7'
                toolVersion = 'local'
                exitCode = 3
                summary = 'Analyzer did not run because the module is unavailable.'
                warnings = @()
                failureReason = 'PSScriptAnalyzer module is unavailable.'
            }
            $path = Join-Path $script:tempRoot 'bad-test-evidence.json'
            $doc | ConvertTo-Json -Depth 20 | Set-Content -LiteralPath $path
            $results = Test-GovernanceJsonDocument -Path $path -Kind 'test-evidence'
            @($results | Where-Object status -eq 'Failed').Count | Should -Be 0
        }

        It 'rejects NotRun evidence without a reason' {
            $doc = [ordered]@{
                schemaVersion = '1.1.0'
                name = 'Analyzer validation'
                category = 'lint'
                status = 'NotRun'
                requiredValidation = $true
                evidenceSource = 'local-execution'
                environment = 'developer-workstation'
                command = 'Invoke-ScriptAnalyzer -Path .'
                workingDirectory = '.'
                startedAtUtc = '2026-06-19T00:00:00Z'
                completedAtUtc = '2026-06-19T00:00:00Z'
                durationSeconds = 0
                runtime = 'PowerShell 7'
                toolVersion = 'local'
                exitCode = 3
                summary = 'Analyzer did not run because the module is unavailable.'
                warnings = @()
                failureReason = $null
            }
            $path = Join-Path $script:tempRoot 'missing-notrun-reason.json'
            $doc | ConvertTo-Json -Depth 20 | Set-Content -LiteralPath $path
            $results = Test-GovernanceJsonDocument -Path $path -Kind 'test-evidence'
            @($results | Where-Object { $_.message -match 'meaningful failure reason' }).Count | Should -BeGreaterThan 0
        }

        It 'accepts valid Passed test evidence' {
            $path = "$PSScriptRoot/../fixtures/valid/test-evidence.json"
            $results = Test-GovernanceJsonDocument -Path $path -Kind 'test-evidence'
            @($results | Where-Object status -eq 'Failed').Count | Should -Be 0
        }
    }

    Context 'completion evidence semantics' {
        It 'rejects approval-required Passed evidence without approvals' {
            $doc = Get-Content "$PSScriptRoot/../fixtures/valid/completion-result-1.1.0.json" -Raw | ConvertFrom-Json -AsHashtable
            $doc.approvalRequired = $true
            $doc.executionContext = 'GitHubActions'
            $doc.status = 'Passed'
            $doc.notRunReason = $null
            $doc.commandsNotExecuted = @()
            $doc.githubRunId = '123456789'
            $doc.githubRunAttempt = '1'
            $doc.githubWorkflow = 'Governance CI'
            $doc.githubJob = 'Governance CI'
            $doc.tests[1].status = 'Passed'
            $doc.tests[1].failureReason = $null
            $doc.tests[1].exitCode = 0
            $doc.approvals = @()
            $path = Join-Path $script:tempRoot 'approval-missing.json'
            $doc | ConvertTo-Json -Depth 30 | Set-Content -LiteralPath $path
            $results = Test-GovernanceJsonDocument -Path $path -Kind 'completion-result'
            @($results | Where-Object { $_.message -match 'approval' }).Count | Should -BeGreaterThan 0
        }

        It 'rejects Blocked completion evidence without a blocked reason' {
            $doc = Get-Content "$PSScriptRoot/../fixtures/valid/completion-result-1.1.0.json" -Raw | ConvertFrom-Json -AsHashtable
            $doc.status = 'Blocked'
            $doc.blockedReason = $null
            $path = Join-Path $script:tempRoot 'blocked-missing-reason.json'
            $doc | ConvertTo-Json -Depth 30 | Set-Content -LiteralPath $path
            $results = Test-GovernanceJsonDocument -Path $path -Kind 'completion-result'
            @($results | Where-Object { $_.message -match 'Blocked' -or $_.message -match 'blockedReason' }).Count | Should -BeGreaterThan 0
        }

        It 'rejects unsupported future major schema versions' {
            $doc = Get-Content "$PSScriptRoot/../fixtures/valid/completion-result-1.1.0.json" -Raw | ConvertFrom-Json -AsHashtable
            $doc.schemaVersion = '2.0.0'
            $path = Join-Path $script:tempRoot 'future-major.json'
            $doc | ConvertTo-Json -Depth 30 | Set-Content -LiteralPath $path
            $results = Test-GovernanceJsonDocument -Path $path -Kind 'completion-result'
            @($results | Where-Object status -eq 'Failed').Count | Should -BeGreaterThan 0
        }

        It 'rejects completion schema 1.2.0 through the evidence validation entry point' {
            $repoRoot = Resolve-Path "$PSScriptRoot/../.."
            $evidenceRoot = Join-Path $script:tempRoot 'unsupported-completion-version'
            New-Item -ItemType Directory -Path $evidenceRoot -Force | Out-Null
            $doc = Get-Content "$PSScriptRoot/../fixtures/valid/completion-result-1.1.0.json" -Raw | ConvertFrom-Json -AsHashtable
            $doc.schemaVersion = '1.2.0'
            $doc | ConvertTo-Json -Depth 30 | Set-Content -LiteralPath (Join-Path $evidenceRoot 'completion-result.json')

            $output = @(& pwsh -NoProfile -File "$repoRoot/actions/validate-evidence/Invoke-EvidenceValidation.ps1" -Path $evidenceRoot -EvidencePath 'completion-result.json' 2>&1)
            $LASTEXITCODE | Should -Be 1
            $output -join "`n" | Should -Match "Unsupported schemaVersion '1\.2\.0' for governance document kind 'completion-result'"
        }
    }

    Context 'document-specific schema versions' {
        BeforeAll {
            $script:documentVersionCases = @(
                @{ Kind = 'completion-result'; Fixtures = @{ '1.0.0' = 'tests/fixtures/valid/completion-result.json'; '1.1.0' = 'tests/fixtures/valid/completion-result-1.1.0.json' } },
                @{ Kind = 'test-evidence'; Fixtures = @{ '1.0.0' = 'tests/fixtures/valid/test-evidence.json'; '1.1.0' = 'tests/fixtures/valid/test-evidence-1.1.0.json' } },
                @{ Kind = 'artifact-record'; Fixtures = @{ '1.0.0' = 'tests/fixtures/valid/artifact-record.json'; '1.1.0' = 'tests/fixtures/valid/artifact-record.json' } },
                @{ Kind = 'project-manifest'; Fixtures = @{ '1.0.0' = 'tests/fixtures/valid/project-manifest.json'; '1.1.0' = 'tests/fixtures/compatibility/project-manifest-1.1.0.json'; '1.2.0' = 'tests/fixtures/valid/project-manifest-1.2.0-user.json' } },
                @{ Kind = 'governance-config'; Fixtures = @{ '1.0.0' = 'tests/fixtures/valid/governance-config.json'; '1.1.0' = 'tests/fixtures/valid/governance-config.json'; '1.2.0' = 'tests/fixtures/valid/governance-config-1.2.0.json' } },
                @{ Kind = 'verified-run'; Fixtures = @{ '1.0.0' = 'tests/fixtures/valid/verified-run.json' } },
                @{ Kind = 'standards-consistency'; Fixtures = @{ '1.0.0' = 'governance/standards-consistency.json' } }
            )
        }

        It 'accepts every schema-declared version in the module mapping' {
            $repoRoot = Resolve-Path "$PSScriptRoot/../.."
            foreach ($case in $script:documentVersionCases) {
                foreach ($version in $case.Fixtures.Keys) {
                    $doc = Get-Content (Join-Path $repoRoot $case.Fixtures[$version]) -Raw | ConvertFrom-Json -AsHashtable
                    $doc.schemaVersion = $version
                    $path = Join-Path $script:tempRoot "$($case.Kind)-declared-$version.json"
                    $doc | ConvertTo-Json -Depth 100 | Set-Content -LiteralPath $path
                    $results = Test-GovernanceJsonDocument -Path $path -Kind $case.Kind
                    @($results | Where-Object { $_.message -match '^Unsupported schemaVersion' }).Count | Should -Be 0 -Because "$($case.Kind) schemaVersion $version is declared by its schema"
                }
            }
        }

        It 'matches the exact version declarations in every governance schema' {
            $repoRoot = Resolve-Path "$PSScriptRoot/../.."
            InModuleScope GovernanceValidation -Parameters @{ Cases = $script:documentVersionCases; Root = $repoRoot } {
                param($Cases, $Root)
                foreach ($case in $Cases) {
                    $schema = Get-Content (Join-Path $Root "schemas/$($case.Kind).schema.json") -Raw | ConvertFrom-Json
                    $declaration = $schema.properties.schemaVersion
                    $declaredVersions = if ($declaration.PSObject.Properties.Name -contains 'enum') {
                        @($declaration.enum)
                    }
                    elseif ($declaration.PSObject.Properties.Name -contains 'const') {
                        @($declaration.const)
                    }
                    elseif (($declaration.PSObject.Properties.Name -contains 'pattern') -and $declaration.pattern -match '^\^([0-9]+)\\\.([0-9]+)\\\.([0-9]+)\$$') {
                        @("$($Matches[1]).$($Matches[2]).$($Matches[3])")
                    }
                    else {
                        throw "schemaVersion for '$($case.Kind)' is not an enum, const, or exact anchored semantic version pattern."
                    }

                    @($script:GovernanceSchemaVersionsByKind[$case.Kind]) | Should -BeExactly $declaredVersions -Because "$($case.Kind) must have one authoritative schema version contract"
                }
            }
        }

        It 'accepts schema 1.2.0 for the manifest and configuration kinds' {
            foreach ($case in @(
                @{ Kind = 'project-manifest'; Fixture = 'project-manifest-1.2.0-user.json' },
                @{ Kind = 'governance-config'; Fixture = 'governance-config-1.2.0.json' }
            )) {
                $results = Test-GovernanceJsonDocument -Path "$PSScriptRoot/../fixtures/valid/$($case.Fixture)" -Kind $case.Kind
                @($results | Where-Object { $_.message -match '^Unsupported schemaVersion' }).Count | Should -Be 0
            }
        }

        It 'rejects scalar values for every required 1.2.0 <Kind> collection field <Field>' -ForEach @(
            @{ Kind='project-manifest'; Fixture='project-manifest-1.2.0-user.json'; Field='technologies' },
            @{ Kind='project-manifest'; Fixture='project-manifest-1.2.0-user.json'; Field='owners' },
            @{ Kind='project-manifest'; Fixture='project-manifest-1.2.0-user.json'; Field='environments' },
            @{ Kind='project-manifest'; Fixture='project-manifest-1.2.0-user.json'; Field='applicableStandards' },
            @{ Kind='project-manifest'; Fixture='project-manifest-1.2.0-user.json'; Field='requiredWorkflows' },
            @{ Kind='project-manifest'; Fixture='project-manifest-1.2.0-user.json'; Field='externalIntegrations' },
            @{ Kind='project-manifest'; Fixture='project-manifest-1.2.0-user.json'; Field='exceptions' },
            @{ Kind='governance-config'; Fixture='governance-config-1.2.0.json'; Field='requiredDocumentationPaths' },
            @{ Kind='governance-config'; Fixture='governance-config-1.2.0.json'; Field='applicableAgentStandards' },
            @{ Kind='governance-config'; Fixture='governance-config-1.2.0.json'; Field='validationCategories' },
            @{ Kind='governance-config'; Fixture='governance-config-1.2.0.json'; Field='additionalForbiddenPatterns' },
            @{ Kind='governance-config'; Fixture='governance-config-1.2.0.json'; Field='reviewedAllowlist' },
            @{ Kind='governance-config'; Fixture='governance-config-1.2.0.json'; Field='exceptions' }
        ) {
            $document = Get-Content "$PSScriptRoot/../fixtures/valid/$Fixture" -Raw | ConvertFrom-Json -AsHashtable
            $document[$Field] = 'scalar-value'
            $path = Join-Path $script:tempRoot "$Kind-scalar-$Field.json"
            $document | ConvertTo-Json -Depth 100 | Set-Content -LiteralPath $path

            $results = Test-GovernanceJsonDocument -Path $path -Kind $Kind
            @($results | Where-Object { $_.message -eq "$Field must be declared as an array." }) | Should -HaveCount 1
        }

        It 'rejects empty values for every nonempty 1.2.0 <Kind> collection field <Field>' -ForEach @(
            @{ Kind='project-manifest'; Fixture='project-manifest-1.2.0-user.json'; Field='technologies' },
            @{ Kind='project-manifest'; Fixture='project-manifest-1.2.0-user.json'; Field='owners' },
            @{ Kind='project-manifest'; Fixture='project-manifest-1.2.0-user.json'; Field='applicableStandards' },
            @{ Kind='governance-config'; Fixture='governance-config-1.2.0.json'; Field='requiredDocumentationPaths' },
            @{ Kind='governance-config'; Fixture='governance-config-1.2.0.json'; Field='applicableAgentStandards' },
            @{ Kind='governance-config'; Fixture='governance-config-1.2.0.json'; Field='validationCategories' }
        ) {
            $document = Get-Content "$PSScriptRoot/../fixtures/valid/$Fixture" -Raw | ConvertFrom-Json -AsHashtable
            $document[$Field] = @()
            $path = Join-Path $script:tempRoot "$Kind-empty-$Field.json"
            $document | ConvertTo-Json -Depth 100 | Set-Content -LiteralPath $path

            $results = Test-GovernanceJsonDocument -Path $path -Kind $Kind
            @($results | Where-Object { $_.message -eq "$Field must be declared as a nonempty array." }) | Should -HaveCount 1
        }

        It 'rejects a scalar mandatory-controls collection in a 1.2.0 governance config' {
            $document = Get-Content "$PSScriptRoot/../fixtures/valid/governance-config-1.2.0.json" -Raw | ConvertFrom-Json -AsHashtable
            $document.controls.mandatoryControlsDisabled = 'scalar-value'
            $path = Join-Path $script:tempRoot 'governance-config-scalar-mandatory-controls.json'
            $document | ConvertTo-Json -Depth 100 | Set-Content -LiteralPath $path

            $results = Test-GovernanceJsonDocument -Path $path -Kind 'governance-config'
            @($results | Where-Object { $_.message -eq 'controls.mandatoryControlsDisabled must be declared as an array.' }) | Should -HaveCount 1
        }

        It 'rejects schema 1.2.0 for completion, test evidence, and artifact kinds' {
            foreach ($case in @(
                @{ Kind = 'completion-result'; Fixture = 'completion-result-1.1.0.json' },
                @{ Kind = 'test-evidence'; Fixture = 'test-evidence-1.1.0.json' },
                @{ Kind = 'artifact-record'; Fixture = 'artifact-record.json' }
            )) {
                $doc = Get-Content "$PSScriptRoot/../fixtures/valid/$($case.Fixture)" -Raw | ConvertFrom-Json -AsHashtable
                $doc.schemaVersion = '1.2.0'
                $path = Join-Path $script:tempRoot "$($case.Kind)-unsupported-1.2.0.json"
                $doc | ConvertTo-Json -Depth 30 | Set-Content -LiteralPath $path
                $results = Test-GovernanceJsonDocument -Path $path -Kind $case.Kind
                @($results | Where-Object { $_.message -eq "Unsupported schemaVersion '1.2.0' for governance document kind '$($case.Kind)'. Supported versions: 1.0.0, 1.1.0." }).Count | Should -Be 1
            }
        }

        It 'rejects unsupported versions for exact-version document kinds' {
            $repoRoot = Resolve-Path "$PSScriptRoot/../.."
            foreach ($case in @(
                @{ Kind = 'verified-run'; Fixture = 'tests/fixtures/valid/verified-run.json' },
                @{ Kind = 'standards-consistency'; Fixture = 'governance/standards-consistency.json' }
            )) {
                foreach ($version in @('1.1.0', '1.0.0-rc', 'v1.0.0')) {
                    $doc = Get-Content (Join-Path $repoRoot $case.Fixture) -Raw | ConvertFrom-Json -AsHashtable
                    $doc.schemaVersion = $version
                    $path = Join-Path $script:tempRoot "$($case.Kind)-unsupported-$($version.Replace('.', '-')).json"
                    $doc | ConvertTo-Json -Depth 100 | Set-Content -LiteralPath $path
                    $results = Test-GovernanceJsonDocument -Path $path -Kind $case.Kind
                    @($results | Where-Object { $_.message -match '^Unsupported schemaVersion' }).Count | Should -Be 1 -Because "$($case.Kind) supports exactly schemaVersion 1.0.0"
                }
            }
        }
    }

    Context 'aggregate governance evidence' {
        It 'wires the trusted repository owner type into repository-health arguments' {
            $repoRoot = Resolve-Path "$PSScriptRoot/../.."
            $aggregateText = Get-Content -LiteralPath (Join-Path $repoRoot 'scripts/Invoke-GovernanceValidation.ps1') -Raw

            $aggregateText | Should -Match "RepositoryHealth\s*=\s*@\('-Path',\`$projectRoot,'-RepositoryOwnerType',\`$RepositoryOwnerType\)"
        }

        It 'rejects invalid and case-variant repository owner types at the aggregate entry point' {
            $repoRoot = Resolve-Path "$PSScriptRoot/../.."
            foreach ($ownerType in @('user', 'Enterprise', '')) {
                $output = @(& pwsh -NoProfile -File "$repoRoot/scripts/Invoke-GovernanceValidation.ps1" -Path $repoRoot -Category JsonSchemas -RepositoryOwnerType $ownerType 2>&1)
                $LASTEXITCODE | Should -Not -Be 0
                $output -join "`n" | Should -Match 'RepositoryOwnerType must be exactly Unknown, User, or Organization'
            }
        }

        It 'rejects candidate maintainer mode outside trusted GitHub repository context' {
            $repoRoot = (Resolve-Path "$PSScriptRoot/../..").Path
            $head = (& git -C $repoRoot rev-parse HEAD).Trim()
            $evidence = Join-Path $script:tempRoot 'candidate-context-evidence'
            $priorGitHubActions = $env:GITHUB_ACTIONS
            $priorGitHubRepository = $env:GITHUB_REPOSITORY
            $priorGitHubSha = $env:GITHUB_SHA
            try {
                $env:GITHUB_ACTIONS = 'true'
                $env:GITHUB_REPOSITORY = 'ExampleOrg/untrusted'
                $env:GITHUB_SHA = $head
                $output = @(& pwsh -NoProfile -File (Join-Path $repoRoot 'scripts/Invoke-GovernanceValidation.ps1') -Path $repoRoot -EvidenceRoot $evidence -CallerRepository 'AIAllTheThingz/Engineering-Standards' -CallerCommitSha $head -RepositoryOwnerType User -ExpectedReusableWorkflowSha ('a' * 40) -CandidateMaintainerValidation 2>&1)
                $LASTEXITCODE | Should -Not -Be 0
                $output -join "`n" | Should -Match '(?s)requires trusted GitHub repository and.*candidate SHA context'
            }
            finally {
                if ($null -eq $priorGitHubActions) { Remove-Item Env:GITHUB_ACTIONS -ErrorAction SilentlyContinue } else { $env:GITHUB_ACTIONS = $priorGitHubActions }
                if ($null -eq $priorGitHubRepository) { Remove-Item Env:GITHUB_REPOSITORY -ErrorAction SilentlyContinue } else { $env:GITHUB_REPOSITORY = $priorGitHubRepository }
                if ($null -eq $priorGitHubSha) { Remove-Item Env:GITHUB_SHA -ErrorAction SilentlyContinue } else { $env:GITHUB_SHA = $priorGitHubSha }
            }
        }

        It 'resolves repository-relative validator script paths from the registry' {
            $repoRoot = Resolve-Path "$PSScriptRoot/../.."
            $entry = Get-GovernanceValidationCategoryRegistry | Where-Object Name -eq 'JsonSchemas'
            $entry.Path | Should -BeExactly 'scripts/Test-JsonSchemas.ps1'
            Resolve-SafePath -Root $repoRoot -ChildPath $entry.Path | Should -BeExactly (Join-Path $repoRoot 'scripts/Test-JsonSchemas.ps1')
        }

        It 'passes a verified repository owner type in every documented aggregate command' {
            $repoRoot = Resolve-Path "$PSScriptRoot/../.."
            $commandDocuments = @(
                Get-Item -LiteralPath (Join-Path $repoRoot 'README.md')
                Get-ChildItem -LiteralPath (Join-Path $repoRoot 'docs') -Filter '*.md' -File -Recurse
                Get-Item -LiteralPath (Join-Path $repoRoot 'scripts/Invoke-GovernanceValidation.ps1')
            )

            foreach ($document in $commandDocuments) {
                $lineNumber = 0
                foreach ($line in Get-Content -LiteralPath $document.FullName) {
                    $lineNumber++
                    if ($line -match '(?i)pwsh\b.*Invoke-GovernanceValidation\.ps1') {
                        $relativePath = [System.IO.Path]::GetRelativePath($repoRoot, $document.FullName).Replace('\\', '/')
                        $line | Should -Match '(?i)(?:^|\s)-RepositoryOwnerType(?:\s|$)' -Because "${relativePath}:$lineNumber must not rely on the unsafe Unknown default"
                    }
                }
            }
        }
    }

    Context 'manifest semantics' {
        It 'requires production approval for High risk manifests' {
            $manifest = Get-Content "$PSScriptRoot/../fixtures/valid/project-manifest.json" -Raw | ConvertFrom-Json -AsHashtable
            $manifest.productionApprovalRequired = $false
            $path = Join-Path $script:tempRoot 'bad-manifest.json'
            $manifest | ConvertTo-Json -Depth 20 | Set-Content -LiteralPath $path
            $results = Test-GovernanceJsonDocument -Path $path -Kind 'project-manifest'
            @($results | Where-Object { $_.message -match 'production approval' }).Count | Should -Be 1
        }

        It 'rejects placeholder email local parts case-insensitively' {
            foreach ($fixture in Get-ChildItem "$PSScriptRoot/../fixtures/invalid" -Filter 'project-manifest*placeholder-email*.json') {
                $results = Test-GovernanceJsonDocument -Path $fixture.FullName -Kind 'project-manifest'
                @($results | Where-Object { $_.status -eq 'Failed' -and $_.message -match 'placeholder' }).Count | Should -Be 1 -Because $fixture.Name
            }
        }

        It 'accepts similar legitimate email local parts' {
            $results = Test-GovernanceJsonDocument -Path "$PSScriptRoot/../fixtures/valid/project-manifest-similar-email-owner.json" -Kind 'project-manifest'
            @($results | Where-Object status -eq 'Failed').Count | Should -Be 0
        }

        It 'accepts a one-character GitHub user and rejects a bare at sign' {
            $validResults = Test-GovernanceJsonDocument -Path "$PSScriptRoot/../fixtures/valid/project-manifest-one-character-user-owner.json" -Kind 'project-manifest'
            @($validResults | Where-Object status -eq 'Failed').Count | Should -Be 0

            $invalidResults = Test-GovernanceJsonDocument -Path "$PSScriptRoot/../fixtures/invalid/project-manifest-bare-user-owner.json" -Kind 'project-manifest'
            @($invalidResults | Where-Object { $_.status -eq 'Failed' -and $_.message -match 'GitHub user handle' }).Count | Should -Be 1
        }

        It 'applies structured owner type and identifier validation without JSON Schema execution' {
            $manifest = Get-Content "$PSScriptRoot/../../project-manifest.json" -Raw | ConvertFrom-Json -AsHashtable
            $manifest.owners = @(@{
                type = 'github-organization'
                identifier = '@example-org'
                responsibility = 'Owns the synthetic governance contract tests.'
                escalation = 'SECURITY.md'
            })
            $path = Join-Path $script:tempRoot 'invalid-structured-owner.json'
            $manifest | ConvertTo-Json -Depth 30 | Set-Content -LiteralPath $path
            $results = Test-GovernanceJsonDocument -Path $path -Kind 'project-manifest'
            @($results | Where-Object { $_.status -eq 'Failed' -and $_.message -match 'unsupported owner type' }) | Should -HaveCount 1

            $manifest.owners[0].type = 'github-user'
            $manifest.owners[0].identifier = '@user-'
            $manifest | ConvertTo-Json -Depth 30 | Set-Content -LiteralPath $path
            $results = Test-GovernanceJsonDocument -Path $path -Kind 'project-manifest'
            @($results | Where-Object { $_.status -eq 'Failed' -and $_.message -match 'malformed.*github-user' }) | Should -HaveCount 1
        }
    }

    Context 'governance configuration ownership semantics' {
        It 'accepts an omitted ownership configuration for backward compatibility' {
            $results = Test-GovernanceJsonDocument -Path "$PSScriptRoot/../fixtures/valid/governance-config.json" -Kind 'governance-config'
            @($results | Where-Object status -eq 'Failed').Count | Should -Be 0
        }

        It 'accepts PowerShellParser as a declared validation category' {
            $document = Get-Content "$PSScriptRoot/../fixtures/valid/governance-config-1.2.0.json" -Raw | ConvertFrom-Json -AsHashtable
            $document.validationCategories = @('Contract', 'PowerShellParser')
            $path = Join-Path $script:tempRoot 'powershell-parser-governance-config.json'
            $document | ConvertTo-Json -Depth 20 | Set-Content -LiteralPath $path
            $results = Test-GovernanceJsonDocument -Path $path -Kind 'governance-config'
            @($results | Where-Object status -eq 'Failed').Count | Should -Be 0
        }

        It 'accepts unique rooted literal required CODEOWNERS paths' {
            $results = Test-GovernanceJsonDocument -Path "$PSScriptRoot/../fixtures/valid/governance-config-required-codeowner-paths.json" -Kind 'governance-config'
            @($results | Where-Object status -eq 'Failed').Count | Should -Be 0
        }

        It 'treats case-distinct required CODEOWNERS paths as unique' {
            $document = Get-Content "$PSScriptRoot/../fixtures/valid/governance-config-required-codeowner-paths.json" -Raw | ConvertFrom-Json -AsHashtable
            $document.ownership.requiredCodeownerPaths = @('/src/', '/SRC/')
            $path = Join-Path $script:tempRoot 'case-distinct-governance-config.json'
            $document | ConvertTo-Json -Depth 20 | Set-Content -LiteralPath $path
            $results = Test-GovernanceJsonDocument -Path $path -Kind 'governance-config'
            @($results | Where-Object status -eq 'Failed').Count | Should -Be 0
        }

        It 'rejects unsafe, duplicate, empty, wildcard, and placeholder required CODEOWNERS paths' {
            foreach ($fixture in Get-ChildItem "$PSScriptRoot/../fixtures/invalid" -Filter 'governance-config-codeowner-*.json') {
                $results = Test-GovernanceJsonDocument -Path $fixture.FullName -Kind 'governance-config'
                @($results | Where-Object status -eq 'Failed').Count | Should -BeGreaterThan 0 -Because $fixture.Name
            }
        }
    }
}
