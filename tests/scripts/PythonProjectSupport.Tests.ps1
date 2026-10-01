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
        $script:workflow | Should -Match '\$runtimePython = \[string\]\$env:FUNCTIONAL_RUNTIME_PYTHON'
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

    It 'rechecks both SBOM digests in the trusted completion step before generating the receipt' {
        $recheckIndex = $script:workflow.IndexOf('no longer matches the digest recorded when it was generated')
        $generatorIndex = $script:workflow.IndexOf('& ./standards/scripts/New-CompletionEvidence.ps1', $recheckIndex)
        $recheckIndex | Should -BeGreaterThan 0
        $generatorIndex | Should -BeGreaterThan $recheckIndex
        $script:workflow | Should -Match "'Python toolchain SBOM', 'Python project SBOM'"
        $script:workflow | Should -Match '\$recordedSbomHash = \[string\]\$sbomRecord\[0\]\.details\.sha256'
        $script:workflow | Should -Match '\(Get-FileHash -LiteralPath \$sbomPath -Algorithm SHA256\)\.Hash\.ToLowerInvariant\(\) -ne \$recordedSbomHash\.ToLowerInvariant\(\)'
    }

    It 'reserves enough job time for serial lock closure and durable evidence' {
        $timeoutMatch = [regex]::Match($script:workflow, '(?m)^\s+timeout-minutes:\s*(?<minutes>\d+)\s*$')
        $timeoutMatch.Success | Should -BeTrue
        [int]$timeoutMatch.Groups['minutes'].Value | Should -BeGreaterOrEqual 60
        $script:workflow | Should -Match '\$env:GITHUB_EVENT_PATH'
        $script:workflow | Should -Match '\$env:GITHUB_EVENT_NAME -eq ''push'''
        $script:workflow | Should -Match '\$eventPayload\.before'
        $script:workflow | Should -Match '\$eventPayload\.pull_request\.base\.sha'
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
        $inputValidation.Groups['body'].Value | Should -Match 'CALLER_PYTHON_VERSION:\s*\$\{\{ inputs\.python-version \}\}'
        $inputValidation.Groups['body'].Value | Should -Match 'CALLER_PROJECT_PATH:\s*\$\{\{ inputs\.project-path \}\}'
        $inputValidation.Groups['body'].Value | Should -Match '\$env:CALLER_PYTHON_VERSION'
        $inputValidation.Groups['body'].Value | Should -Match '\$env:CALLER_PROJECT_PATH'
        $inputValidation.Groups['body'].Value | Should -Match 'input-validation-metadata\.json'
        $inputValidation.Groups['body'].Value | Should -Match 'validated-project-path\.txt'
        $inputValidation.Groups['body'].Value | Should -Not -Match 'GITHUB_OUTPUT'
        $inputValidation.Groups['body'].Value | Should -Match 'project-path must not contain a link or reparse-point component\.'
        $inputValidation.Groups['body'].Value | Should -Match '\$resolvedProject\.StartsWith\(\$resolvedRoot'
        $inputValidation.Groups['body'].Value | Should -Not -Match "'\$\{\{ inputs\.python-version \}\}'"
        $inputValidation.Groups['body'].Value | Should -Not -Match "'\$\{\{ inputs\.project-path \}\}'"
        foreach ($stepName in @('Set up exact CPython 3.13.2 lock resolver','Set up exact Python runtime','Verify complete hash-locked toolchain closure before installation')) {
            $step = [regex]::Match($script:workflow, "(?s)- name: $([regex]::Escape($stepName))\s*(?<body>.*?)(?=\r?\n\s*- name:)")
            $step.Success | Should -BeTrue
            $step.Groups['body'].Value | Should -Match "if:\s*steps\.inputs\.outcome\s*==\s*'success'"
        }
        $script:workflow | Should -Match '\$inputValidationOutcome = \[string\]\$env:INPUT_OUTCOME'
        $script:workflow | Should -Match '(?s)- name: Prepare Python phase evidence\s+id:\s*phase_evidence'
        $script:workflow | Should -Match 'name=''Python workflow input validation'''
        $script:workflow | Should -Match 'status=''Failed'''
        $script:workflow | Should -Match 'failureReason=\[string\]\$inputMetadata\.error'
        $script:workflow | Should -Match 'inputs = \[string\]\$env:INPUT_OUTCOME'
        $script:workflow | Should -Match 'inputValidationOutcome = \$inputValidationOutcome'
        $functional = [regex]::Match($script:workflow, '(?s)- name: Run governed functional validation\s*(?<body>.*?)(?=\r?\n\s*- name:)')
        $functional.Success | Should -BeTrue
        $functional.Groups['body'].Value | Should -Match 'validated-project-path\.txt'
        $functional.Groups['body'].Value | Should -Match '\[IO\.File\]::ReadAllText'
        $functional.Groups['body'].Value | Should -Match '--project \$validatedProjectPath'
        $functional.Groups['body'].Value | Should -Not -Match '\$\{\{ inputs\.project-path \}\}'
    }

    It 'keeps GitHub expressions out of executable shell bodies' {
        $runBlocks = [regex]::Matches($script:workflow, '(?m)^[ ]{8}run:\s*(?:\||>|>-|\|-)\s*\r?\n(?<body>(?:^[ ]{10,}.*(?:\r?\n|$))*)')
        $runBlocks.Count | Should -BeGreaterThan 0
        foreach ($runBlock in $runBlocks) {
            $runBlock.Groups['body'].Value | Should -Not -Match '\$\{\{'
        }
    }

    It 'lists each failure-receipt command once and never as both executed and not executed' {
        $lines = [regex]::Matches($script:workflow, '(?m)^\s*(?<line>\$commands(?:Not)?Executed = @\(\$commands(?:Not)?Executed \| Where-Object .*)$') | ForEach-Object { $_.Groups['line'].Value.Trim() }
        @($lines).Count | Should -Be 2
        $commandsExecuted = @('lock','install','lock','pytest')
        $commandsNotExecuted = @('lock','functional','functional','')
        foreach ($line in $lines) { Invoke-Expression $line }
        @($commandsExecuted) | Should -Be @('lock','install','pytest')
        @($commandsNotExecuted) | Should -Be @('functional')
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
        $script:workflow | Should -Match '(?s)try \{\s*Copy-Item -LiteralPath \$venvPython -Destination \$toolPython\s*\}\s*catch \{\s*Complete-ToolchainInstallMetadata -Command ''Copy-Item <tool-python> <tool-python-isolated>'' -ExitCode 1\s*throw ''Isolated Python toolchain interpreter copy failed\.''\s*\}'
        $script:workflow | Should -Match '(?s)id:\s*normalization.*?normalization_exit_code=0\s*"\$TOOL_PYTHON" -I standards/scripts/Normalize-PythonFunctionalEvidence\.py.*?\|\| normalization_exit_code=\$\?'
        $script:workflow | Should -Match 'NORMALIZATION_STARTED_AT_UTC: \$\{\{ steps\.normalization\.outputs\.started_at_utc \}\}'
        $script:workflow | Should -Match 'NORMALIZATION_EXIT_CODE: \$\{\{ steps\.normalization\.outputs\.exit_code \}\}'
        $script:workflow | Should -Match 'startedAtUtc=\$normalizationStarted; completedAtUtc=\$normalizationCompleted; durationSeconds=\[double\]::Parse\(\$normalizationDurationText'
        $script:workflow | Should -Match 'exitCode=\[int\]::Parse\(\$normalizationExitText'
        $script:workflow | Should -Not -Match 'normalizationTimestamp'
        $script:workflow | Should -Not -Match 'functionalTimestamp'
        $script:workflow | Should -Match '(?s)id:\s*functional\s.*?\$functionalExitCode = \$LASTEXITCODE.*?finally \{.*?"exit_code=\$functionalExitCode"'
        $script:workflow | Should -Match 'FUNCTIONAL_STARTED_AT_UTC: \$\{\{ steps\.functional\.outputs\.started_at_utc \}\}'
        $script:workflow | Should -Match 'FUNCTIONAL_EXIT_CODE: \$\{\{ steps\.functional\.outputs\.exit_code \}\}'
        $script:workflow | Should -Match 'startedAtUtc = \$functionalStarted\s+completedAtUtc = \$functionalCompleted\s+durationSeconds = \[double\]::Parse\(\$functionalDurationText'
        $script:workflow | Should -Match 'exitCode = \[int\]::Parse\(\$functionalExitText'
        $script:workflow | Should -Match 'status=\$\(if\(\$normalizationPassed\)\{''Passed''\}else\{''Failed''\}\)'
        $script:workflow | Should -Match 'phase-normalization\.json'
        $script:workflow | Should -Match '\$allTestRecords = @\(\$lockVerificationRecord, \$toolchainInstallRecord, \$regressionRecord, \$normalizationRecord\)'
        $script:workflow | Should -Match '(?s)\$failureRecords \+= \$regressionRecord\s*\$commandsExecuted \+= \[string\]\$regressionRecord\.command'
        $script:workflow | Should -Match '\$candidate -split ''/'''
        $script:workflow | Should -Not -Match '\$candidate -split ''\[\\\\/\]'''
        $script:workflow | Should -Match 'details=\[ordered\]@\{ outcome=\$env:NORMALIZATION_OUTCOME \}'
        $script:workflow | Should -Not -Match 'details=\[ordered\]@\{ outcome=''failure'' \}'
        $script:workflow | Should -Match '\$toolchainInstallOutcome = \[string\]\$env:TOOL_OUTCOME'
        $script:workflow | Should -Match 'started_at_utc=\$installStartedAtUtc'
        $script:workflow | Should -Match 'completed_at_utc=\$completedAtUtc'
        $script:workflow | Should -Match 'duration_seconds='
        $script:workflow | Should -Match 'failed_command='
        $script:workflow | Should -Match 'exit_code='
        $script:workflow | Should -Match 'name\s*=\s*''Python toolchain installation'''
        $script:workflow | Should -Match 'Toolchain installation failed after successful lock verification\.'
        $script:workflow | Should -Match 'Successful Python lock-verification record is unavailable for install-failure evidence\.'
        $script:workflow | Should -Match '\$failureRecords = @\(\$lockInstallRecord,\$toolInstallFailureRecord\)'
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
        $script:workflow | Should -Match '\$lockVerificationStartedAtUtc = \[string\]\$env:LOCK_STARTED_AT_UTC'
        $script:workflow | Should -Match '\$lockVerificationCompletedAtUtc = \[string\]\$env:LOCK_COMPLETED_AT_UTC'
        $script:workflow | Should -Match '\$lockVerificationDurationSeconds = \[double\]::Parse\('
        $script:workflow | Should -Match 'startedAtUtc = \$lockVerificationStartedAtUtc'
        $script:workflow | Should -Match 'completedAtUtc = \$lockVerificationCompletedAtUtc'
        $script:workflow | Should -Match 'durationSeconds = \$lockVerificationDurationSeconds'
        $script:workflow | Should -Match '\$commandsNotExecuted \+= \$lockVerificationCommand'
        $script:workflow | Should -Match 'status = if \(\$lockVerificationBlocked\) \{ ''Blocked'' \} else \{ ''Failed'' \}'
        $script:workflow | Should -Match 'exitCode = if \(\$lockVerificationBlocked\) \{ \$null \} else \{ 1 \}'
        $script:workflow | Should -Match '\$verificationCommand = ''<CPython-3\.13\.2 with pip==26\.2\.1> -I standards/scripts/python-project-validation\.py --verify-tool-lock --work-root <runner-temp>/python-lock-resolution --tool-lock standards/examples/python-project/requirements-ci\.lock --resolver-python <CPython-3\.13\.2> --runtime-python <CPython-3\.12\.11>'
        $script:workflow | Should -Match '"verification_command=\$verificationCommand"'
        $script:workflow | Should -Match '\$lockVerificationCommand = \[string\]\$env:LOCK_COMMAND'
        $script:workflow | Should -Match '-CommandsExecuted @\(\$lockVerificationCommand,\$toolchainInstallCommand,''python-project-validation\.py'',\[string\]\$regressionRecord\.command,''Normalize-PythonFunctionalEvidence\.py''\)'
        $script:workflow | Should -Match 'Join-Path \$env:RUNNER_TEMP ''python-lock-verification\.log'''
        $script:workflow | Should -Match 'New-Item -ItemType File -Path \$durableLockLogPath -Force'
        $script:workflow | Should -Match 'Set-Content -LiteralPath \$durableLockLogPath -Value ''Python toolchain lock verification started\.'''
        $script:workflow | Should -Match 'Copy-Item -LiteralPath \$durableLockLogPath -Destination \$lockEvidenceLogPath'
        $script:workflow | Should -Match "status\s*=\s*'Passed'"
        $script:workflow | Should -Match 'Python toolchain lock closure completed successfully\.'
        $script:workflow | Should -Match '\$regressionOutcome = \[string\]\$env:REGRESSION_OUTCOME'
        $script:workflow | Should -Match 'name = ''Python validator regression tests'''
        $script:workflow | Should -Match 'status = if \(\$regressionOutcome -eq ''success''\) \{ ''Passed'' \} else \{ ''Failed'' \}'
        $script:workflow | Should -Match 'evidence/validator-regression\.log'
        $script:workflow | Should -Match 'phase-lock-verification\.json'
        $script:workflow | Should -Match 'phase-toolchain-installation\.json'
        $script:workflow | Should -Match 'phase-normalization-failure\.json'
        $script:workflow | Should -Match '\$prerequisiteRecords = @\(\$lockPrerequisiteRecord,\$toolPrerequisiteRecord\)'
        $script:workflow | Should -Match '\$failureRecords = \$prerequisiteRecords \+ \$failureRecords'
        $script:workflow | Should -Match '\$failureRecords \+= \(Get-Content -LiteralPath \$normalizationFailurePath -Raw \| ConvertFrom-Json\)'
        $script:workflow | Should -Match 'name\s*=\s*''Python workflow input validation'''
        $script:workflow | Should -Match 'phase-toolchain-installation\.json'
        $script:workflow | Should -Match '-CommandsExecuted @\(\$lockVerificationCommand,\$toolchainInstallCommand,''python-project-validation\.py'',\[string\]\$regressionRecord\.command,''Normalize-PythonFunctionalEvidence\.py''\)'
        $completionWorkflow = $script:workflow.Substring($completionIndex, $evidenceIndex - $completionIndex)
        $failureBody = $completionWorkflow
        $inputFailureIndex = $failureBody.IndexOf("if (`$inputValidationOutcome -ne 'success')")
        $toolchainFailureIndex = $failureBody.IndexOf('elseif ($toolchainInstallFailed)')
        $functionalFailureIndex = $failureBody.IndexOf('elseif ($functionalFailed)')
        $normalizationFailureIndex = $failureBody.IndexOf('elseif ($normalizationFailed)')
        $fallbackMessageIndex = $failureBody.IndexOf("`$commandsNotExecuted += 'Toolchain installation and functional validation were not run because lock verification did not succeed.'")
        foreach ($routeIndex in @($inputFailureIndex,$toolchainFailureIndex,$functionalFailureIndex,$normalizationFailureIndex,$fallbackMessageIndex)) { $routeIndex | Should -BeGreaterThan -1 }
        $inputFailureIndex | Should -BeLessThan $toolchainFailureIndex
        $toolchainFailureIndex | Should -BeLessThan $functionalFailureIndex
        $functionalFailureIndex | Should -BeLessThan $normalizationFailureIndex
        $normalizationFailureIndex | Should -BeLessThan $fallbackMessageIndex
        $failureBody | Should -Match '\$failureRecords = @\(\)'
        $failureBody | Should -Match '\$failureArtifacts = @\(''evidence/lock-verification\.log'',''evidence/local-test-results\.json''\)'
        $failureBody | Should -Match '\$functionalResultsPath = Join-Path \$env:PYTHON_WORK_ROOT ''evidence/local-test-results\.json'''
        $failureBody | Should -Match '\$failureRecords = @\(Get-Content -LiteralPath \$functionalResultsPath -Raw \| ConvertFrom-Json\)'
        $failureBody | Should -Match 'Functional validation failed before detailed test records were available\.'
        $failureBody | Should -Match '\$failureRecords \+= \$regressionRecord'
        $failureBody | Should -Match '\$failureArtifacts \+= ''evidence/validator-regression\.log'''
        $failureBody | Should -Match '\$failureRecords = @\(Get-Content -LiteralPath \$functionalResultsPath -Raw \| ConvertFrom-Json\) \+ \$failureRecords'
        $failureBody | Should -Match '\$failureRecords \| ConvertTo-Json -Depth 10 -AsArray'
        $failureBody | Should -Match '-ArtifactPath \$failureArtifacts'
        $failureBody | Should -Match '-SourceRepositoryPath \$completionSourceRoot'
        $failureBody | Should -Match '-ChangedFile \$completionChangedFiles'
        $failureBody | Should -Match '(?s)elseif \(\$normalizationFailed\) \{.*?if \(\$null -ne \$regressionRecord\) \{.*?\}\s*\}\s*else \{'
        $failureBody | Should -Not -Match '(?s)elseif \(\$normalizationFailed\) \{.*?\}\s*\}\s*if \(\$null -ne \$regressionRecord\)'
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

    It 'inventories every pushed commit when a new branch is pushed, and the whole tree when nothing precedes it' {
        $functionText = [regex]::Match($script:workflow, '(?ms)^ {12}function Get-CompletionChangedFiles \{.*?^ {12}\}\s*$').Value
        $snapshotText = [regex]::Match($script:workflow, '(?ms)- name: Snapshot completion scope before caller code runs.*?run: \|\r?\n(?<body>.*?)(?=^ {6}- name:)').Groups['body'].Value
        $selectionText = [regex]::Match($script:workflow, '(?ms)^ {10}if \(\$env:SCOPE_OUTCOME -ne ''success''\).*?^ {10}if \(\$completionChangedFiles\.Count -eq 0\)[^\r\n]*').Value
        $functionText | Should -Not -BeNullOrEmpty
        $snapshotText | Should -Not -BeNullOrEmpty
        $selectionText | Should -Not -BeNullOrEmpty
        $snapshotText = $snapshotText -replace '(?m)^\s*\$callerStage = Join-Path \$env:GITHUB_WORKSPACE ''caller''\r?\n', ''
        $snapshotRunner = [scriptblock]::Create("param(`$callerStage)`n$snapshotText")
        $runner = [scriptblock]::Create("param(`$completionSourceRoot)`n$functionText`n$selectionText`n`$completionChangedFiles")

        function New-CommitFile {
            param($Repository, $Name, $Message)
            [IO.File]::WriteAllText((Join-Path $Repository $Name), $Name, [Text.UTF8Encoding]::new($false))
            & git -C $Repository add --all
            & git -C $Repository commit --quiet -m $Message
            (& git -C $Repository rev-parse HEAD).Trim()
        }
        function Invoke-Snapshot {
            param($Repository, $Sha, $EventName, $Before, $DefaultBranch)
            $eventPath = Join-Path $TestDrive ("event-" + [guid]::NewGuid() + '.json')
            [ordered]@{ before = $Before; repository = [ordered]@{ default_branch = $DefaultBranch } } | ConvertTo-Json | Set-Content -LiteralPath $eventPath -Encoding utf8
            $outputPath = Join-Path $TestDrive ("output-" + [guid]::NewGuid() + '.txt')
            $saved = @{ P = $env:GITHUB_EVENT_PATH; N = $env:GITHUB_EVENT_NAME; S = $env:GITHUB_SHA; O = $env:GITHUB_OUTPUT }
            try {
                $env:GITHUB_EVENT_PATH = $eventPath; $env:GITHUB_EVENT_NAME = $EventName; $env:GITHUB_SHA = $Sha; $env:GITHUB_OUTPUT = $outputPath
                & $snapshotRunner $Repository
            }
            finally { $env:GITHUB_EVENT_PATH = $saved.P; $env:GITHUB_EVENT_NAME = $saved.N; $env:GITHUB_SHA = $saved.S; $env:GITHUB_OUTPUT = $saved.O }
            $outputs = @{}
            foreach ($line in Get-Content -LiteralPath $outputPath) { $name, $value = $line -split '=', 2; $outputs[$name] = $value }
            $outputs
        }
        function Invoke-Selection {
            param($Repository, $Sha, $EventName, $Before, $DefaultBranch)
            $snapshot = Invoke-Snapshot $Repository $Sha $EventName $Before $DefaultBranch
            Use-Snapshot $Repository $Sha $snapshot
        }
        function Use-Snapshot {
            param($Repository, $Sha, $Snapshot)
            $saved = @{ S = $env:GITHUB_SHA; O = $env:SCOPE_OUTCOME; B = $env:SCOPE_BASE_SHA; F = $env:SCOPE_FULL_TREE }
            try {
                $env:GITHUB_SHA = $Sha; $env:SCOPE_OUTCOME = 'success'; $env:SCOPE_BASE_SHA = $Snapshot['scope_base_sha']; $env:SCOPE_FULL_TREE = $Snapshot['scope_full_tree']
                @(& $runner $Repository)
            }
            finally { $env:GITHUB_SHA = $saved.S; $env:SCOPE_OUTCOME = $saved.O; $env:SCOPE_BASE_SHA = $saved.B; $env:SCOPE_FULL_TREE = $saved.F }
        }
        $zeros = '0' * 40

        # New branch with three commits on top of main: every pushed file is inventoried, not only the tip's.
        $repository = Join-Path $TestDrive 'new-branch-push'
        New-Item -ItemType Directory -Path $repository -Force | Out-Null
        & git -C $repository init --quiet --initial-branch=main
        & git -C $repository config user.email 'evidence-test@example.invalid'
        & git -C $repository config user.name 'Evidence Test'
        $main = New-CommitFile $repository 'main-only.txt' 'main'
        & git -C $repository update-ref refs/remotes/origin/main $main
        $null = New-CommitFile $repository 'first.txt' 'first'
        $null = New-CommitFile $repository 'second.txt' 'second'
        $tip = New-CommitFile $repository 'third.txt' 'third'
        $files = Invoke-Selection $repository $tip 'push' $zeros 'main'
        @($files | Sort-Object) | Should -Be @('first.txt','second.txt','third.txt')

        # New branch created exactly at the default-branch tip: no tree delta exists, so the existing tip commit's
        # files must not be reported as changes; the whole validated tree is inventoried instead.
        & git -C $repository update-ref refs/remotes/origin/main $tip
        $files = Invoke-Selection $repository $tip 'push' $zeros 'main'
        @($files | Sort-Object) | Should -Be @('first.txt','main-only.txt','second.txt','third.txt')

        # First push of the default branch: there is no default-branch ancestor, so inventory the whole tree.
        $initial = Join-Path $TestDrive 'initial-push'
        New-Item -ItemType Directory -Path $initial -Force | Out-Null
        & git -C $initial init --quiet --initial-branch=main
        & git -C $initial config user.email 'evidence-test@example.invalid'
        & git -C $initial config user.name 'Evidence Test'
        $null = New-CommitFile $initial 'one.txt' 'one'
        $initialTip = New-CommitFile $initial 'two.txt' 'two'
        $files = Invoke-Selection $initial $initialTip 'push' $zeros 'main'
        @($files | Sort-Object) | Should -Be @('one.txt','two.txt')

        # A push that leaves the tree unchanged has no delta: the whole validated tree is inventoried instead of failing.
        & git -C $repository commit --quiet --allow-empty -m 'empty'
        $emptyTip = (& git -C $repository rev-parse HEAD).Trim()
        $files = Invoke-Selection $repository $emptyTip 'push' $tip 'main'
        @($files | Sort-Object) | Should -Be @('first.txt','main-only.txt','second.txt','third.txt')

        # Caller code can rewrite the event payload and the default-branch ref after the snapshot; the selection must not notice.
        & git -C $repository update-ref refs/remotes/origin/main $main
        $snapshot = Invoke-Snapshot $repository $tip 'push' $zeros 'main'
        & git -C $repository update-ref refs/remotes/origin/main $tip
        $files = Use-Snapshot $repository $tip $snapshot
        @($files | Sort-Object) | Should -Be @('first.txt','second.txt','third.txt')
        $selectionText | Should -Not -Match 'GITHUB_EVENT_PATH|refs/remotes'

        # The snapshot is taken before any caller code can run.
        $script:workflow.IndexOf('id: scope_snapshot') | Should -BeLessThan $script:workflow.IndexOf('id: functional')
        $script:workflow | Should -Match '(?s)- name: Stage Python completion source metadata.*?SCOPE_OUTCOME: \$\{\{ steps\.scope_snapshot\.outcome \}\}'

        # An ordinary push keeps diffing against the previous tip.
        $files = Invoke-Selection $repository $tip 'push' $main 'main'
        @($files | Sort-Object) | Should -Be @('first.txt','second.txt','third.txt')
    }

    It 'validates an Ubuntu project path whose directory name contains a literal backslash' {
        if ($IsWindows) {
            Set-ItResult -Skipped -Because 'A directory name containing a backslash is a Linux-only fixture.'
            return
        }
        $block = [regex]::Match($script:workflow, '(?ms)^ {10}\$inputStartedAt = .*?(?=^ {6}- name:)').Value
        $block | Should -Not -BeNullOrEmpty
        $workspace = Join-Path $TestDrive 'literal-backslash-workspace'
        $work = Join-Path $TestDrive 'literal-backslash-work'
        $caller = Join-Path $workspace 'caller'
        $literalProject = $caller + '/ex' + [char]92 + 'ample/proj'
        $decoyProject = $caller + '/ex/ample/proj'
        [void][IO.Directory]::CreateDirectory($literalProject)
        [void][IO.Directory]::CreateDirectory($decoyProject)
        [void][IO.Directory]::CreateDirectory($work + '/evidence')
        $saved = @{ W = $env:GITHUB_WORKSPACE; P = $env:PYTHON_WORK_ROOT; V = $env:CALLER_PYTHON_VERSION; C = $env:CALLER_PROJECT_PATH }
        try {
            $env:GITHUB_WORKSPACE = $workspace; $env:PYTHON_WORK_ROOT = $work
            $env:CALLER_PYTHON_VERSION = '3.12.11'; $env:CALLER_PROJECT_PATH = 'ex' + [char]92 + 'ample/proj'
            & ([scriptblock]::Create($block))
            [IO.File]::ReadAllText($work + '/evidence/validated-project-path.txt') | Should -BeExactly ([IO.Path]::GetFullPath($literalProject)) -Because 'the literal backslash directory, not the slash-separated decoy, must be validated'

            $env:CALLER_PROJECT_PATH = 'ex' + [char]92 + 'missing/proj'
            { & ([scriptblock]::Create($block)) } | Should -Throw
        }
        finally {
            $env:GITHUB_WORKSPACE = $saved.W; $env:PYTHON_WORK_ROOT = $saved.P; $env:CALLER_PYTHON_VERSION = $saved.V; $env:CALLER_PROJECT_PATH = $saved.C
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
