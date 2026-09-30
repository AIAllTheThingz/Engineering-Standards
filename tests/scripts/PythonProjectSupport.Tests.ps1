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
        $script:workflow | Should -Match '--bootstrap-lock-parser'
        $script:workflow | Should -Match '\$lockParserPython -I standards/scripts/python-project-validation\.py'
        $script:workflow | Should -Match '--resolver-python'
        $script:workflow | Should -Match '--runtime-python'
        $script:workflow | Should -Match '\$runtimePython = ''\$\{\{ steps\.runtime\.outputs\.python-path \}\}'''
        $script:workflow | Should -Not -Match 'Get-Command python -CommandType Application'
        $script:driver | Should -Match '"--dry-run"'
        $script:driver | Should -Match '"--ignore-installed"'
        $script:driver | Should -Match '"-c"'
        $script:driver | Should -Match '"--platform"'
        $script:driver | Should -Match '"--python-version"'
        $script:driver | Should -Match 'cpython 3\.13\.2'
        $script:driver | Should -Match 'cpython 3\.12\.11'
        $script:driver | Should -Match 'validate_resolved_requirements_lock'
        $script:driver | Should -Match 'require_pinned_lock_metadata_parser'
        $script:driver | Should -Match 'bootstrap_pinned_lock_metadata_parser'
        $script:driver | Should -Match 'TARGET_MARKER_PIP_WRAPPER'
        $script:driver | Should -Match 'markers\.default_environment\s*=\s*target_marker_environment'
        $script:driver | Should -Not -Match 'original_default_environment'
    }

    It 'reserves enough job time for serial lock closure and durable evidence' {
        $timeoutMatch = [regex]::Match($script:workflow, '(?m)^\s+timeout-minutes:\s*(?<minutes>\d+)\s*$')
        $timeoutMatch.Success | Should -BeTrue
        [int]$timeoutMatch.Groups['minutes'].Value | Should -BeGreaterOrEqual 60
    }

    It 'creates durable failure evidence when caller inputs are rejected' {
        $workspaceIndex = $script:workflow.IndexOf('Initialize Python evidence workspace')
        $inputValidationIndex = $script:workflow.IndexOf('Validate fixed runtime and project path')
        $workspaceIndex | Should -BeGreaterThan -1
        $inputValidationIndex | Should -BeGreaterThan -1
        $workspaceIndex | Should -BeLessThan $inputValidationIndex
        $inputValidation = [regex]::Match(
            $script:workflow,
            '(?s)- name: Validate fixed runtime and project path\s*(?<body>.*?)(?=\r?\n\s*- name:)'
        )
        $inputValidation.Success | Should -BeTrue
        $inputValidation.Groups['body'].Value | Should -Match 'id:\s*inputs'
        $inputValidation.Groups['body'].Value | Should -Match 'continue-on-error:\s*true'
        foreach ($stepName in @('Set up exact CPython 3.13.2 lock resolver','Set up exact Python runtime','Verify complete hash-locked toolchain closure before installation')) {
            $step = [regex]::Match($script:workflow, "(?s)- name: $([regex]::Escape($stepName))\s*(?<body>.*?)(?=\r?\n\s*- name:)")
            $step.Success | Should -BeTrue
            $step.Groups['body'].Value | Should -Match "if:\s*steps\.inputs\.outcome\s*==\s*'success'"
        }
        $script:workflow | Should -Match '\$inputValidationOutcome = ''\$\{\{ steps\.inputs\.outcome \}\}'''
        $script:workflow | Should -Match 'The fixed runtime and project path validation did not succeed, so lock validation was not started\.'
        $script:workflow | Should -Match 'inputs = ''\$\{\{ steps\.inputs\.outcome \}\}'''
        $script:workflow | Should -Match 'inputValidationOutcome = \$inputValidationOutcome'
    }

    It 'emits validated failure completion evidence when toolchain lock verification does not succeed' {
        $completionIndex = $script:workflow.IndexOf('Create completion evidence in trusted workspace')
        $evidenceIndex = $script:workflow.IndexOf('Validate Python completion evidence')
        $completionIndex | Should -BeGreaterThan -1
        $evidenceIndex | Should -BeGreaterThan $completionIndex
        $script:workflow | Should -Match '(?s)id:\s*completion\s*\r?\n\s*if:\s*always\(\)'
        $script:workflow | Should -Match '(?s)if \(\s*\$lockVerificationOutcome -eq ''success'' -and\s*\$toolchainInstallOutcome -eq ''success'' -and\s*\$functionalOutcome -eq ''success'' -and\s*\$normalizationOutcome -eq ''success''\s*\)'
        $script:workflow | Should -Match '(?s)- name: Install standards-owned hash-locked toolchain\s*id:\s*toolchain_install\s*if:\s*steps\.lock_verification\.outcome == ''success''\s*continue-on-error:\s*true'
        $script:workflow | Should -Match 'Hash-locked Python toolchain package installation failed\.'
        $script:workflow | Should -Match 'Hash-locked Python toolchain pip check failed\.'
        $script:workflow | Should -Match 'Isolated Python toolchain interpreter assertion failed\.'
        $script:workflow | Should -Match '\$toolchainInstallOutcome = ''\$\{\{ steps\.toolchain_install\.outcome \}\}'''
        $script:workflow | Should -Match 'started_at_utc=\$installStartedAtUtc'
        $script:workflow | Should -Match 'completed_at_utc=\$completedAtUtc'
        $script:workflow | Should -Match 'duration_seconds='
        $script:workflow | Should -Match 'failed_command='
        $script:workflow | Should -Match 'exit_code='
        $script:workflow | Should -Match '\$toolchainInstallStartedAtUtc = ''\$\{\{ steps\.toolchain_install\.outputs\.started_at_utc \}\}'''
        $script:workflow | Should -Match '\$toolchainInstallCompletedAtUtc = ''\$\{\{ steps\.toolchain_install\.outputs\.completed_at_utc \}\}'''
        $script:workflow | Should -Match '\$toolchainInstallDurationText = ''\$\{\{ steps\.toolchain_install\.outputs\.duration_seconds \}\}'''
        $script:workflow | Should -Match '\$toolchainInstallFailedCommand = ''\$\{\{ steps\.toolchain_install\.outputs\.failed_command \}\}'''
        $script:workflow | Should -Match '\$toolchainInstallExitCodeText = ''\$\{\{ steps\.toolchain_install\.outputs\.exit_code \}\}'''
        $script:workflow | Should -Match 'command = \$toolchainInstallFailedCommand'
        $script:workflow | Should -Match 'startedAtUtc = \$toolchainInstallStartedAtUtc'
        $script:workflow | Should -Match 'completedAtUtc = \$toolchainInstallCompletedAtUtc'
        $script:workflow | Should -Match 'durationSeconds = \$toolchainInstallDurationSeconds'
        $script:workflow | Should -Match 'exitCode = \$toolchainInstallExitCode'
        $script:workflow | Should -Match 'name = ''Python toolchain installation'''
        $script:workflow | Should -Match 'Toolchain installation failed after successful lock verification\.'
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
        $script:workflow | Should -Match 'verifier_blocked=true'
        $script:workflow | Should -Match 'verifier_blocked_reason='
        $script:workflow | Should -Match '\$lockVerificationStarted'
        $script:workflow | Should -Match '\$lockVerificationBlocked'
        $script:workflow | Should -Match '\$lockVerificationBlockedReason'
        $script:workflow | Should -Match 'verification_started_at_utc='
        $script:workflow | Should -Match 'verification_completed_at_utc='
        $script:workflow | Should -Match 'verification_duration_seconds='
        $script:workflow | Should -Match '\$lockVerificationStartedAtUtc = ''\$\{\{ steps\.lock_verification\.outputs\.verification_started_at_utc \}\}'''
        $script:workflow | Should -Match '\$lockVerificationCompletedAtUtc = ''\$\{\{ steps\.lock_verification\.outputs\.verification_completed_at_utc \}\}'''
        $script:workflow | Should -Match '\$lockVerificationDurationSeconds = \[double\]::Parse\('
        $script:workflow | Should -Match 'startedAtUtc = \$lockVerificationStartedAtUtc'
        $script:workflow | Should -Match 'completedAtUtc = \$lockVerificationCompletedAtUtc'
        $script:workflow | Should -Match 'durationSeconds = \$lockVerificationDurationSeconds'
        $script:workflow | Should -Match '\$commandsNotExecuted \+= \$lockVerificationCommand'
        $script:workflow | Should -Match 'status = if \(\$lockVerificationBlocked\) \{ ''Blocked'' \} else \{ ''Failed'' \}'
        $script:workflow | Should -Match 'exitCode = if \(\$lockVerificationBlocked\) \{ \$null \} else \{ 1 \}'
        $script:workflow | Should -Match '\$verificationCommand = ''<CPython-3\.13\.2 with pip==26\.2\.1> -I standards/scripts/python-project-validation\.py --verify-tool-lock --work-root <runner-temp>/python-lock-resolution --tool-lock standards/examples/python-project/requirements-ci\.lock --resolver-python <CPython-3\.13\.2> --runtime-python <CPython-3\.12\.11>'
        $script:workflow | Should -Match '"verification_command=\$verificationCommand"'
        $script:workflow | Should -Match '\$lockVerificationCommand = ''\$\{\{ steps\.lock_verification\.outputs\.verification_command \}\}'''
        $script:workflow | Should -Match '-CommandsExecuted @\(\$lockVerificationCommand,''python-project-validation\.py''\)'
        $script:workflow | Should -Match 'Join-Path \$env:RUNNER_TEMP ''python-lock-verification\.log'''
        $script:workflow | Should -Match 'New-Item -ItemType File -Path \$durableLockLogPath -Force'
        $script:workflow | Should -Match 'Set-Content -LiteralPath \$durableLockLogPath -Value ''Python toolchain lock verification started\.'''
        $script:workflow | Should -Match 'Copy-Item -LiteralPath \$durableLockLogPath -Destination \$lockEvidenceLogPath'
        $script:workflow | Should -Match "status = 'Passed'"
        $script:workflow | Should -Match 'Python toolchain lock closure completed successfully\.'
        $script:workflow | Should -Match '\$regressionOutcome = ''\$\{\{ steps\.regression\.outcome \}\}'''
        $script:workflow | Should -Match 'name = ''Python validator regression tests'''
        $script:workflow | Should -Match 'status = if \(\$regressionOutcome -eq ''success''\) \{ ''Passed'' \} else \{ ''Failed'' \}'
        $script:workflow | Should -Match 'evidence/validator-regression\.log'
        $script:workflow | Should -Match '\$allTestRecords = @\(\$lockVerificationRecord, \$toolchainInstallRecord, \$regressionRecord\)'
        $script:workflow | Should -Match 'name = ''Python workflow input validation'''
        $script:workflow | Should -Match 'failureReason = \$inputValidationError'
        $script:workflow | Should -Match '\$toolchainInstallCommand'
        $script:workflow | Should -Match '-CommandsExecuted @\(\$lockVerificationCommand,\$toolchainInstallCommand,''python-project-validation\.py''\)'
        $completionWorkflow = $script:workflow.Substring($completionIndex, $evidenceIndex - $completionIndex)
        $failureEvidence = [regex]::Match(
            $completionWorkflow,
            '(?s)if \(\s*\$lockVerificationOutcome -eq ''success'' -and\s*\$toolchainInstallOutcome -eq ''success'' -and\s*\$functionalOutcome -eq ''success'' -and\s*\$normalizationOutcome -eq ''success''\s*\) \{.*?\r?\n\s*\}\r?\n\s*else \{\s*(?<body>.*?)\r?\n\s*\}\r?\n\s*if \(-not \(Test-Path -LiteralPath \$completionPath'
        )
        $failureEvidence.Success | Should -BeTrue
        $failureBody = $failureEvidence.Groups['body'].Value
        $failureBody | Should -Match '\$failureRecords = @\(\)'
        $failureBody | Should -Match '\$failureArtifacts = @\(''evidence/lock-verification\.log'',''evidence/local-test-results\.json''\)'
        $failureBody | Should -Match '\$functionalResultsPath = Join-Path \$env:PYTHON_WORK_ROOT ''evidence/local-test-results\.json'''
        $failureBody | Should -Match '\$failureRecords = @\(Get-Content -LiteralPath \$functionalResultsPath -Raw \| ConvertFrom-Json\)'
        $failureBody | Should -Match 'Functional validation failed before detailed test records were available\.'
        $failureBody | Should -Match '\$failureRecords \+= \$regressionRecord'
        $failureBody | Should -Match "\$failureArtifacts \+= 'evidence/validator-regression\.log'"
        $failureBody | Should -Match '\$failureRecords = @\(Get-Content -LiteralPath \$functionalResultsPath -Raw \| ConvertFrom-Json\) \+ \$failureRecords'
        $failureBody | Should -Match '\$failureRecords \| ConvertTo-Json -Depth 10 -AsArray'
        $failureBody | Should -Match '-ArtifactPath \$failureArtifacts'
        $failureBody | Should -Match '-SourceRepositoryPath \$completionSourceRoot'
        $failureBody | Should -Match '-ChangedFile \$completionChangedFiles'
        $script:workflow | Should -Match '(?s)- name: Stage Python completion source metadata\s+id:\s*source_metadata'
        $script:workflow | Should -Match '\$completionChangedFiles \| ConvertTo-Json -AsArray'
        $script:workflow | Should -Match '(?s)id:\s*evidence\s*\r?\n\s*if:\s*always\(\) && steps\.completion\.outcome == ''success'''
    }

    It 'preserves Unicode and newline paths when reading a NUL-delimited failure inventory' {
        $repository = Join-Path $TestDrive 'nul-delimited-failure-inventory'
        New-Item -ItemType Directory -Path $repository -Force | Out-Null
        & git -C $repository init --quiet
        $LASTEXITCODE | Should -Be 0
        & git -C $repository config user.email 'evidence-test@example.invalid'
        & git -C $repository config user.name 'Evidence Test'
        [IO.File]::WriteAllText((Join-Path $repository 'baseline.txt'), 'baseline', [Text.UTF8Encoding]::new($false))
        & git -C $repository add --all
        $LASTEXITCODE | Should -Be 0
        & git -C $repository commit --quiet -m 'baseline'
        $LASTEXITCODE | Should -Be 0
        $defaultBranch = (& git -C $repository branch --show-current).Trim()
        & git -C $repository checkout --quiet -b feature
        $LASTEXITCODE | Should -Be 0

        $unicodeName = 'café.txt'
        $newlineName = 'line' + [char]10 + 'feed.txt'
        [IO.File]::WriteAllText((Join-Path $repository $unicodeName), 'unicode', [Text.UTF8Encoding]::new($false))
        & git -C $repository add --all
        $LASTEXITCODE | Should -Be 0
        & git -C $repository commit --quiet -m 'feature path inventory'
        $LASTEXITCODE | Should -Be 0
        & git -C $repository checkout --quiet $defaultBranch
        $LASTEXITCODE | Should -Be 0
        [IO.File]::WriteAllText((Join-Path $repository 'base-only.txt'), 'base', [Text.UTF8Encoding]::new($false))
        & git -C $repository add --all
        $LASTEXITCODE | Should -Be 0
        & git -C $repository commit --quiet -m 'base-only change'
        $LASTEXITCODE | Should -Be 0
        $baseSha = (& git -C $repository rev-parse HEAD).Trim()
        & git -C $repository merge --quiet --no-ff --no-edit feature
        $LASTEXITCODE | Should -Be 0
        $headSha = (& git -C $repository rev-parse HEAD).Trim()

        $gitCommand = @(Get-Command git -CommandType Application -ErrorAction Stop)[0]
        $startInfo = [Diagnostics.ProcessStartInfo]::new($gitCommand.Source)
        $startInfo.UseShellExecute = $false
        $startInfo.RedirectStandardOutput = $true
        $startInfo.RedirectStandardError = $true
        foreach ($argument in @('-C', $repository, 'diff', '--no-ext-diff', '--name-only', '-z', $baseSha, $headSha)) {
            [void]$startInfo.ArgumentList.Add($argument)
        }
        $process = [Diagnostics.Process]::new()
        $process.StartInfo = $startInfo
        $output = [IO.MemoryStream]::new()
        try {
            $started = $process.Start()
            $started | Should -BeTrue
            $process.StandardOutput.BaseStream.CopyTo($output)
            $standardError = $process.StandardError.ReadToEnd()
            $process.WaitForExit()
            $process.ExitCode | Should -Be 0
            $standardError | Should -BeExactly ''
            $paths = [Text.UTF8Encoding]::new($false, $true).GetString($output.ToArray()).Split([char]0, [StringSplitOptions]::RemoveEmptyEntries)
            $paths | Should -Contain $unicodeName
            $paths | Should -Not -Contain 'base-only.txt'
            $newlinePaths = [Text.UTF8Encoding]::new($false, $true).GetString(
                [Text.UTF8Encoding]::new($false).GetBytes($unicodeName + [char]0 + $newlineName + [char]0)
            ).Split([char]0, [StringSplitOptions]::RemoveEmptyEntries)
            $newlinePaths | Should -Contain $newlineName
        }
        finally {
            $output.Dispose()
            $process.Dispose()
        }
    }

    It 'preserves failure evidence when the functional runtime setup is unavailable' {
        $workspaceIndex = $script:workflow.IndexOf('Initialize Python evidence workspace')
        $resolverIndex = $script:workflow.IndexOf('Set up exact CPython 3.13.2 lock resolver')
        $runtimeIndex = $script:workflow.IndexOf('Set up exact Python runtime')
        $workspaceIndex | Should -BeGreaterThan -1
        $workspaceIndex | Should -BeLessThan $resolverIndex
        $workspaceIndex | Should -BeLessThan $runtimeIndex
        $runtimeSetup = [regex]::Match(
            $script:workflow,
            '(?s)- name: Set up exact Python runtime\s*(?<body>.*?)(?=\r?\n\s*- name:)'
        )
        $runtimeSetup.Success | Should -BeTrue
        $runtimeSetup.Groups['body'].Value | Should -Match 'id:\s*runtime'
        $runtimeSetup.Groups['body'].Value | Should -Match 'continue-on-error:\s*true'
        $script:workflow | Should -Match 'The exact CPython 3\.12\.11 functional runtime was unavailable; no toolchain was installed\.'
    }

    It 'validates a lock-failure receipt from metadata staged beneath the evidence root' {
        $workspace = Join-Path $TestDrive 'python-lock-failure-evidence'
        $callerSource = Join-Path $TestDrive 'python-lock-failure-caller-source'
        $caller = Join-Path $workspace 'caller'
        $evidence = Join-Path $workspace 'evidence'
        New-Item -ItemType Directory -Path $callerSource,$evidence -Force | Out-Null
        'CALLER_SOURCE = 1' | Set-Content -LiteralPath (Join-Path $callerSource 'source.py') -NoNewline
        & git -C $callerSource init --quiet
        $LASTEXITCODE | Should -Be 0
        & git -C $callerSource config user.email 'evidence-test@example.invalid'
        & git -C $callerSource config user.name 'Evidence Test'
        & git -C $callerSource add --all
        & git -C $callerSource commit --quiet -m 'caller source'
        $LASTEXITCODE | Should -Be 0
        $callerSha = (& git -C $callerSource rev-parse HEAD).Trim()
        & git -c protocol.file.allow=always clone --no-local --no-checkout --no-tags $callerSource $caller
        $LASTEXITCODE | Should -Be 0
        & git -C $caller cat-file -e "$callerSha^{commit}"
        $LASTEXITCODE | Should -Be 0
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
            $env:GITHUB_WORKFLOW = 'Python validation'; $env:GITHUB_SHA = $callerSha
            $env:GITHUB_REF_NAME = 'main'; $env:GITHUB_REPOSITORY = 'example-org/project'
            & (Join-Path $script:root 'scripts/New-CompletionEvidence.ps1') `
                -RepositoryPath $workspace -SourceRepositoryPath $caller -OutputPath 'evidence/completion-result.json' `
                -TestResultPath 'evidence/local-test-results.json' -GovernanceVersion 1.1.0 -RiskClassification Moderate `
                -Summary 'Python toolchain lock verification failed before toolchain installation.' `
                -CommandsExecuted @('python-project-validation.py --verify-tool-lock') `
                -CommandsNotExecuted @('Toolchain installation and functional validation were not run because lock verification failed.') `
                -ArtifactPath @('evidence/lock-verification.log','evidence/local-test-results.json') `
                -ArtifactName 'python-evidence-1' -Repository 'example-org/project' -Branch main -ValidatedCommitSha $callerSha `
                -StandardsRepository 'AIAllTheThingz/Engineering-Standards' -StandardsWorkflowSha ('2' * 40) `
                -ValidationProfile 'python-functional' -ChecksExecuted @('PythonToolchainLockClosure') `
                -EvidenceExecutionContext GitHubActions | Out-Null
            $LASTEXITCODE | Should -Be 0
            & (Join-Path $script:root 'actions/validate-evidence/Invoke-EvidenceValidation.ps1') `
                -Path $workspace -EvidencePath 'evidence/completion-result.json' `
                -ExpectedCommitSha $callerSha -ExpectedRepository 'example-org/project' -ExpectedRefName main `
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
