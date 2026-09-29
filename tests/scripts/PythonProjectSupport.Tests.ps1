BeforeAll {
    $script:root = (Resolve-Path "$PSScriptRoot/../..").Path
    $script:example = Join-Path $script:root 'examples/python-project'
    $script:workflow = Get-Content -LiteralPath (Join-Path $script:root '.github/workflows/python-ci-reusable.yml') -Raw
    $script:driver = Get-Content -LiteralPath (Join-Path $script:root 'scripts/python-project-validation.py') -Raw
}

Describe 'Governed Python project support' {
    It 'keeps functional execution in the dedicated Python workflow' {
        $aggregate=Get-Content (Join-Path $script:root 'scripts/Test-Examples.ps1') -Raw
        $aggregate | Should -Not -Match 'examples/python-project/tools/Test-Example\.ps1'
        (Get-Content (Join-Path $script:root '.github/workflows/python-ci-reusable.yml') -Raw) | Should -Match 'python-project-validation\.py'
    }

    It 'provides the complete functional example contract' {
        foreach ($path in @('pyproject.toml','requirements-ci.in','requirements-ci.lock','requirements-runtime.lock','project-manifest.json','governance.config.json','src/governed_paths/paths.py','tests/test_paths.py','tools/Test-Example.ps1')) {
            Test-Path -LiteralPath (Join-Path $script:example $path) -PathType Leaf | Should -BeTrue
        }
        (Get-Content -LiteralPath (Join-Path $script:example 'project-manifest.json') -Raw | ConvertFrom-Json).projectType | Should -BeExactly 'python'
    }

    It 'pins every functional requirement and supplies hashes' {
        $lock = Get-Content -LiteralPath (Join-Path $script:example 'requirements-ci.lock') -Raw
        foreach ($package in @('pytest==9.1.1','mypy==2.3.1','pip-audit==2.10.1','build==1.6.1','hatchling==1.32.4','ruff==0.15.22','cyclonedx-bom==7.3.0')) {
            $lock | Should -Match ([regex]::Escape($package))
        }
        $lock | Should -Match '(?m)^\s+--hash=sha256:[0-9a-f]{64}'
        $lock | Should -Not -Match '(?m)^[A-Za-z0-9_.-]+(?:>=|~=|>)'
    }

    It 'keeps every direct input pin synchronized with the generated lock' {
        $lock = Get-Content -LiteralPath (Join-Path $script:example 'requirements-ci.lock') -Raw
        $inputPins = @(Get-Content -LiteralPath (Join-Path $script:example 'requirements-ci.in') |
            Where-Object { $_ -match '^\s*[A-Za-z0-9_.-]+==[^\s#]+' } |
            ForEach-Object { ([regex]::Match($_, '^\s*([A-Za-z0-9_.-]+==[^\s#]+)')).Groups[1].Value })
        $inputPins.Count | Should -BeGreaterThan 0
        foreach ($pin in $inputPins) {
            $lock | Should -Match (([regex]::Escape($pin)) + '\s*\\')
        }
    }

    It 'resolves the complete CPython 3.13.2 toolchain closure before installing the lock' {
        $resolverIndex = $script:workflow.IndexOf('Verify complete hash-locked toolchain closure before installation')
        $installIndex = $script:workflow.IndexOf('Install standards-owned hash-locked toolchain')
        $resolverIndex | Should -BeGreaterThan -1
        $resolverIndex | Should -BeLessThan $installIndex
        $script:workflow | Should -Match 'python-version:\s*3\.13\.2'
        $script:workflow | Should -Match '--verify-tool-lock'
        $script:workflow | Should -Match '--resolver-python'
        $script:driver | Should -Match '"--dry-run"'
        $script:driver | Should -Match '"--ignore-installed"'
        $script:driver | Should -Match '"-c"'
        $script:driver | Should -Match 'cpython 3\.13\.2'
        $script:driver | Should -Match 'validate_resolved_requirements_lock'
    }

    It 'emits validated failure completion evidence when toolchain lock verification does not succeed' {
        $completionIndex = $script:workflow.IndexOf('Create completion evidence in trusted workspace')
        $evidenceIndex = $script:workflow.IndexOf('Validate Python completion evidence')
        $completionIndex | Should -BeGreaterThan -1
        $evidenceIndex | Should -BeGreaterThan $completionIndex
        $script:workflow | Should -Match '(?s)id:\s*completion\s*\r?\n\s*if:\s*always\(\)'
        $script:workflow | Should -Match 'if \(\$lockVerificationOutcome -eq ''success''\)'
        $script:workflow | Should -Match '(?s)id:\s*lock_resolver\s*\r?\n\s*continue-on-error:\s*true'
        $script:workflow | Should -Match 'The exact CPython 3\.13\.2 lock resolver was unavailable; no toolchain was installed\.'
        $readme = Get-Content -LiteralPath (Join-Path $script:example 'README.md') -Raw
        $readme | Should -Match 'Linux, Windows, and macOS'
        $readme | Should -Match 'does not expand the functional workflow'
        $script:workflow | Should -Match 'local-test-results\.json'
        $script:workflow | Should -Match 'The governed Python toolchain lock verification did not complete successfully\.'
        $script:workflow | Should -Match 'evidence/lock-verification\.log'
        $script:workflow | Should -Match 'verifier_started=false'
        $script:workflow | Should -Match 'verifier_started=true'
        $script:workflow | Should -Match '\$lockVerificationStarted'
        $script:workflow | Should -Match '\$commandsNotExecuted \+= \$verificationCommand'
        $script:workflow | Should -Match 'status = if \(\$lockVerificationStarted\) \{ ''Failed'' \} else \{ ''Blocked'' \}'
        $script:workflow | Should -Match '(?s)id:\s*evidence\s*\r?\n\s*if:\s*always\(\) && steps\.completion\.outcome == ''success'''
    }

    It 'validates a lock-failure receipt without installing the rejected toolchain' {
        $workspace = Join-Path $TestDrive 'python-lock-failure-evidence'
        $caller = Join-Path $workspace 'caller'
        $evidence = Join-Path $workspace 'evidence'
        New-Item -ItemType Directory -Path $caller,$evidence -Force | Out-Null
        'The governed lock verifier rejected the supplied toolchain closure.' | Set-Content -LiteralPath (Join-Path $evidence 'lock-verification.log') -Encoding utf8
        $now = (Get-Date).ToUniversalTime().ToString('o')
        $failureRecord = [ordered]@{
            schemaVersion = '1.1.0'
            name = 'Python toolchain lock closure'
            category = 'security'
            status = 'Failed'
            requiredValidation = $true
            evidenceSource = 'Automated'
            command = 'python-project-validation.py --verify-tool-lock'
            workingDirectory = 'trusted-isolated-workspace'
            startedAtUtc = $now
            completedAtUtc = $now
            durationSeconds = 0
            runtime = 'CPython 3.13.2 resolver'
            toolVersion = 'python-project-validation.py'
            exitCode = 1
            summary = 'The required Python toolchain lock verification did not succeed.'
            warnings = @()
            failureReason = 'The governed Python toolchain lock verification did not complete successfully.'
            blockedReason = $null
            notApplicableRationale = $null
            details = [ordered]@{
                outcome = 'failure'
                logPath = 'evidence/lock-verification.log'
            }
        }
        @($failureRecord) | ConvertTo-Json -Depth 10 -AsArray | Set-Content -LiteralPath (Join-Path $evidence 'local-test-results.json') -Encoding utf8
        $saved = @{}
        foreach ($name in @('GITHUB_ACTIONS','GITHUB_RUN_ID','GITHUB_RUN_ATTEMPT','GITHUB_WORKFLOW','GITHUB_SHA','GITHUB_REF_NAME','GITHUB_REPOSITORY')) {
            $saved[$name] = [Environment]::GetEnvironmentVariable($name)
        }
        try {
            $env:GITHUB_ACTIONS = 'true'; $env:GITHUB_RUN_ID = '1'; $env:GITHUB_RUN_ATTEMPT = '1'
            $env:GITHUB_WORKFLOW = 'Python validation'; $env:GITHUB_SHA = ('1' * 40)
            $env:GITHUB_REF_NAME = 'main'; $env:GITHUB_REPOSITORY = 'example-org/project'
            & (Join-Path $script:root 'scripts/New-CompletionEvidence.ps1') `
                -RepositoryPath $workspace -SourceRepositoryPath $caller -OutputPath 'evidence/completion-result.json' `
                -TestResultPath 'evidence/local-test-results.json' -GovernanceVersion 1.1.0 -RiskClassification Moderate `
                -Summary 'Python toolchain lock verification failed before toolchain installation.' `
                -CommandsExecuted @('python-project-validation.py --verify-tool-lock') `
                -CommandsNotExecuted @('Toolchain installation and functional validation were not run because lock verification failed.') `
                -ArtifactPath @('evidence/lock-verification.log','evidence/local-test-results.json') `
                -ArtifactName 'python-evidence-1' -Repository 'example-org/project' -Branch main -ValidatedCommitSha ('1' * 40) `
                -StandardsRepository 'AIAllTheThingz/Engineering-Standards' -StandardsWorkflowSha ('2' * 40) `
                -ValidationProfile 'python-functional' -ChecksExecuted @('PythonToolchainLockClosure') `
                -EvidenceExecutionContext GitHubActions | Out-Null
            $LASTEXITCODE | Should -Be 0
            & (Join-Path $script:root 'actions/validate-evidence/Invoke-EvidenceValidation.ps1') `
                -Path $workspace -EvidencePath 'evidence/completion-result.json' `
                -ExpectedCommitSha ('1' * 40) -ExpectedRepository 'example-org/project' -ExpectedRefName main `
                -OutputJson (Join-Path $evidence 'evidence-validation.json') | Out-Null
            $LASTEXITCODE | Should -Be 0
            $completion = Get-Content -LiteralPath (Join-Path $evidence 'completion-result.json') -Raw | ConvertFrom-Json
            $completion.status | Should -BeExactly 'Failed'
            @($completion.artifacts.path) | Should -Contain 'evidence/lock-verification.log'
            @($completion.artifacts.path) | Should -Contain 'evidence/local-test-results.json'
        }
        finally {
            foreach ($name in $saved.Keys) { [Environment]::SetEnvironmentVariable($name, $saved[$name]) }
        }
    }

    It 'records an unavailable resolver as blocked completion evidence' {
        $workspace = Join-Path $TestDrive 'python-lock-resolver-blocked-evidence'
        $caller = Join-Path $workspace 'caller'
        $evidence = Join-Path $workspace 'evidence'
        New-Item -ItemType Directory -Path $caller,$evidence -Force | Out-Null
        'The exact CPython 3.13.2 lock resolver was unavailable; no toolchain was installed.' | Set-Content -LiteralPath (Join-Path $evidence 'lock-verification.log') -Encoding utf8
        $now = (Get-Date).ToUniversalTime().ToString('o')
        $blockedRecord = [ordered]@{
            schemaVersion = '1.1.0'
            name = 'Python toolchain lock closure'
            category = 'security'
            status = 'Blocked'
            requiredValidation = $true
            evidenceSource = 'Automated'
            command = 'python-project-validation.py --verify-tool-lock'
            workingDirectory = 'trusted-isolated-workspace'
            startedAtUtc = $now
            completedAtUtc = $now
            durationSeconds = 0
            runtime = 'CPython 3.13.2 resolver'
            toolVersion = 'python-project-validation.py'
            exitCode = $null
            summary = 'The required Python toolchain lock verification could not start.'
            warnings = @()
            failureReason = $null
            blockedReason = 'The exact CPython 3.13.2 lock resolver was unavailable, so validation could not start.'
            notApplicableRationale = $null
            details = [ordered]@{
                outcome = 'failure'
                resolverAvailable = $false
                logPath = 'evidence/lock-verification.log'
            }
        }
        @($blockedRecord) | ConvertTo-Json -Depth 10 -AsArray | Set-Content -LiteralPath (Join-Path $evidence 'local-test-results.json') -Encoding utf8
        $saved = @{}
        foreach ($name in @('GITHUB_ACTIONS','GITHUB_RUN_ID','GITHUB_RUN_ATTEMPT','GITHUB_WORKFLOW','GITHUB_SHA','GITHUB_REF_NAME','GITHUB_REPOSITORY')) {
            $saved[$name] = [Environment]::GetEnvironmentVariable($name)
        }
        try {
            $env:GITHUB_ACTIONS = 'true'; $env:GITHUB_RUN_ID = '1'; $env:GITHUB_RUN_ATTEMPT = '1'
            $env:GITHUB_WORKFLOW = 'Python validation'; $env:GITHUB_SHA = ('1' * 40)
            $env:GITHUB_REF_NAME = 'main'; $env:GITHUB_REPOSITORY = 'example-org/project'
            & (Join-Path $script:root 'scripts/New-CompletionEvidence.ps1') `
                -RepositoryPath $workspace -SourceRepositoryPath $caller -OutputPath 'evidence/completion-result.json' `
                -TestResultPath 'evidence/local-test-results.json' -GovernanceVersion 1.1.0 -RiskClassification Moderate `
                -Summary 'Python toolchain lock verification could not start before toolchain installation.' `
                -CommandsExecuted @() `
                -CommandsNotExecuted @('python-project-validation.py --verify-tool-lock','Toolchain installation and functional validation were not run because lock verification did not succeed.') `
                -BlockedReason 'The exact CPython 3.13.2 lock resolver was unavailable, so validation could not start.' `
                -ArtifactPath @('evidence/lock-verification.log','evidence/local-test-results.json') `
                -ArtifactName 'python-evidence-1' -Repository 'example-org/project' -Branch main -ValidatedCommitSha ('1' * 40) `
                -StandardsRepository 'AIAllTheThingz/Engineering-Standards' -StandardsWorkflowSha ('2' * 40) `
                -ValidationProfile 'python-functional' -ChecksExecuted @('PythonToolchainLockClosure') `
                -EvidenceExecutionContext GitHubActions | Out-Null
            $LASTEXITCODE | Should -Be 0
            & (Join-Path $script:root 'actions/validate-evidence/Invoke-EvidenceValidation.ps1') `
                -Path $workspace -EvidencePath 'evidence/completion-result.json' `
                -ExpectedCommitSha ('1' * 40) -ExpectedRepository 'example-org/project' -ExpectedRefName main `
                -OutputJson (Join-Path $evidence 'evidence-validation.json') | Out-Null
            $LASTEXITCODE | Should -Be 0
            $completion = Get-Content -LiteralPath (Join-Path $evidence 'completion-result.json') -Raw | ConvertFrom-Json
            $completion.status | Should -BeExactly 'Blocked'
            $completion.blockedReason | Should -BeExactly 'The exact CPython 3.13.2 lock resolver was unavailable, so validation could not start.'
            @($completion.commandsExecuted) | Should -Not -Contain 'python-project-validation.py --verify-tool-lock'
            @($completion.commandsNotExecuted) | Should -Contain 'python-project-validation.py --verify-tool-lock'
        }
        finally {
            foreach ($name in $saved.Keys) { [Environment]::SetEnvironmentVariable($name, $saved[$name]) }
        }
    }

    It 'keeps functional tools outside the central static validator lock' {
        $central = Get-Content -LiteralPath (Join-Path $script:root '.github/dependencies/validator-dependencies.psd1') -Raw
        $central | Should -Not -Match "(?i)Name\s*=\s*'(pytest|mypy|pip-audit|build|hatchling|cyclonedx-bom)'"
    }

    It 'uses immutable actions, fixed runtime, read-only permission, and evidence-before-enforcement' {
        $script:workflow | Should -Match 'runs-on:\s*ubuntu-24\.04'
        $script:workflow | Should -Match 'default:\s*3\.12\.11'
        $script:workflow | Should -Match 'actions/checkout@[0-9a-f]{40}'
        $script:workflow | Should -Match 'actions/setup-python@[0-9a-f]{40}'
        $script:workflow | Should -Match 'actions/upload-artifact@[0-9a-f]{40}'
        $script:workflow | Should -Match 'permissions:\s*\r?\n\s+contents:\s*read'
        $script:workflow.IndexOf('Upload Python evidence before enforcement') | Should -BeLessThan $script:workflow.IndexOf('Enforce Python validation')
    }

    It 'locks down caller-controlled test and type-check configuration' {
        $script:driver | Should -Match 'PYTEST_DISABLE_PLUGIN_AUTOLOAD'
        $script:driver | Should -Match '(?s)"-c",\s+os\.devnull'
        $script:driver | Should -Match '"--config-file"'
        $script:driver | Should -Match 'python-mypy\.ini|mypy_config'
        $script:driver | Should -Match '"-I"'
        $script:driver | Should -Match '"--no-isolation"'
    }

    It 'fails mutations that remove representative trust controls' -ForEach @(
        @{ Pattern='PYTEST_DISABLE_PLUGIN_AUTOLOAD'; Replacement='PYTEST_PLUGIN_AUTOLOAD' },
        @{ Pattern='--config-file'; Replacement='--caller-config' },
        @{ Pattern='inspect_wheel\(wheel, metadata\)'; Replacement='list()' },
        @{ Pattern='Blocked'; Replacement='Passed' }
    ) {
        $mutant = $script:driver -replace $Pattern, $Replacement
        $mutant | Should -Not -BeExactly $script:driver
        $mutant | Should -Not -Match $Pattern
    }

    It 'rejects rooted and traversal paths in the reusable workflow' {
        $script:workflow | Should -Match 'IsPathRooted'
        $script:workflow | Should -Match '\\\.\\\.'
        $script:workflow | Should -Match 'LinkType|ReparsePoint'
    }

    It 'preserves non-bypassable static-language applicability' {
        $aggregate = Get-Content -LiteralPath (Join-Path $script:root 'scripts/Invoke-GovernanceValidation.ps1') -Raw
        $aggregate | Should -Match 'Get-TrustedSourceFiles -Root \$ProjectRoot -Language Python'
        $aggregate | Should -Match 'Get-TrustedSourceFiles -Root \$ProjectRoot -Language Bash'
        $aggregate | Should -Match 'Downstream caller configuration cannot disable mandatory category'
    }
}
