BeforeAll {
    $script:root = (Resolve-Path "$PSScriptRoot/../..").Path
    Import-Module (Join-Path $script:root 'scripts/GovernanceValidation.psm1') -Force
    $script:example = Join-Path $script:root 'examples/bash-project'
    $script:workflowPath = Join-Path $script:root '.github/workflows/bash-ci-reusable.yml'
    $script:workflow = Get-Content -LiteralPath $script:workflowPath -Raw
    $script:entryWorkflow = Get-Content -LiteralPath (Join-Path $script:root '.github/workflows/bash-ci.yml') -Raw
    $script:driver = Get-Content -LiteralPath (Join-Path $script:root 'scripts/bash-project-validation.py') -Raw
    $script:installer = Get-Content -LiteralPath (Join-Path $script:root 'scripts/Install-BashProjectToolchain.py') -Raw
    $script:artifactVerifier = Get-Content -LiteralPath (Join-Path $script:root 'scripts/Test-BashWorkflowEvidenceArtifact.ps1') -Raw
    $script:exampleWrapper = Get-Content -LiteralPath (Join-Path $script:example 'tools/Test-Example.ps1') -Raw
    $script:exampleWorkflow = Get-Content -LiteralPath (Join-Path $script:example '.github/workflows/governance.yml') -Raw
    $script:exampleManifest = Get-Content -LiteralPath (Join-Path $script:example 'project-manifest.json') -Raw | ConvertFrom-Json -AsHashtable
    $script:exampleConfig = Get-Content -LiteralPath (Join-Path $script:example 'governance.config.json') -Raw | ConvertFrom-Json -AsHashtable

function Test-BashExampleWorkflowContract {
    param(
        [Parameter(Mandatory)][string]$Text,
        [Parameter(Mandatory)][hashtable]$Manifest,
        [Parameter(Mandatory)][hashtable]$Config
    )
    $findings = [Collections.Generic.List[string]]::new()
    if ($Manifest.requiredWorkflows -ccontains 'bash') {
        $job = [regex]::Match($Text, '(?ms)^  bash:\s*\r?\n(?<body>.*?)(?=^  [A-Za-z0-9_-]+:\s*(?:\r?\n|$)|\z)')
        if (-not $job.Success) {
            $findings.Add('missing-bash-job')
            return @($findings)
        }
        $body = $job.Groups['body'].Value
        $callerName = [regex]::Match($body, '(?m)^    name:\s*(?<name>\S.*?)\s*$')
        $expectedCheck = 'Bash / Bash validation'
        if (-not $callerName.Success -or $callerName.Groups['name'].Value -cne 'Bash' -or
            $Config.requiredCheckNames -cnotcontains $expectedCheck -or
            $Config.workflowInterface.requiredCheckNames -cnotcontains $expectedCheck) {
            $findings.Add('required-bash-check')
        }
        $uses = [regex]::Match($body, '(?m)^    uses:\s*(?<value>\S+)\s*$')
        if (-not $uses.Success -or $uses.Groups['value'].Value -cnotmatch '^AIAllTheThingz/Engineering-Standards/\.github/workflows/bash-ci-reusable\.yml@[0-9a-f]{40}$') {
            $findings.Add('immutable-bash-reference')
        }
        if ($body -cnotmatch '(?m)^      project-path:\s*\.\s*$') {
            $findings.Add('bash-project-path')
        }
    }
    @($findings)
}

function Initialize-BashExampleWrapperFixture {
    $root = Join-Path $TestDrive ([guid]::NewGuid().ToString('N'))
    $example = Join-Path $root 'examples/bash-project'
    New-Item -ItemType Directory -Path (Join-Path $root 'scripts'),(Join-Path $example 'tools') -Force | Out-Null
    Copy-Item -LiteralPath (Join-Path $script:root 'scripts/Install-BashProjectToolchain.py') -Destination (Join-Path $root 'scripts')
    Copy-Item -LiteralPath (Join-Path $script:root 'scripts/GovernanceValidation.psm1') -Destination (Join-Path $root 'scripts')
    Copy-Item -LiteralPath (Join-Path $script:example 'bash-toolchain.lock.json') -Destination $example
    Copy-Item -LiteralPath (Join-Path $script:example 'tools/Test-Example.ps1') -Destination (Join-Path $example 'tools')
    Copy-Item -LiteralPath (Join-Path $script:example 'evidence') -Destination $example -Recurse
    [pscustomobject]@{ Root=$root; Example=$example; Installer=(Join-Path $root 'scripts/Install-BashProjectToolchain.py') }
}

function Invoke-BashExampleOfflineFixture {
    param([Parameter(Mandatory)][psobject]$Fixture)
    $cache = Join-Path $Fixture.Root 'cache'
    $temporary = Join-Path $Fixture.Root 'temporary'
    New-Item -ItemType Directory -Path $cache,$temporary -Force | Out-Null
    $savedTemporary = $env:TMPDIR
    try {
        $env:TMPDIR = $temporary
        $output = @(& pwsh -NoProfile -File (Join-Path $Fixture.Example 'tools/Test-Example.ps1') -ProjectPath $Fixture.Example -ToolCache $cache -Offline 2>&1)
        $exitCode = $LASTEXITCODE
    }
    finally {
        $env:TMPDIR = $savedTemporary
    }
    [pscustomobject]@{ ExitCode=$exitCode; Output=($output -join "`n"); Temporary=$temporary }
}

function Test-BashWorkflowControls {
    param([Parameter(Mandatory)][string]$Text)
    $failures = [Collections.Generic.List[string]]::new()
    if ($Text -notmatch 'permissions:\s*\r?\n\s+contents:\s*read') { $failures.Add('least-permission') }
    if ($Text -match 'contents:\s*write|write-all|pull_request_target|secrets:\s*inherit|environment:' -or $Text -match '(?m)^\s+(actions|attestations|checks|deployments|discussions|id-token|issues|models|packages|pages|pull-requests|security-events|statuses):\s*(read|write|none)\s*$') { $failures.Add('prohibited-authority') }
    if ($Text -notmatch 'actions/checkout@[0-9a-f]{40}' -or $Text -notmatch 'actions/setup-python@[0-9a-f]{40}' -or $Text -notmatch 'actions/upload-artifact@[0-9a-f]{40}') { $failures.Add('immutable-actions') }
    if ([regex]::Matches($Text, 'persist-credentials:\s*false').Count -ne 2 -or $Text -match 'persist-credentials:\s*true') { $failures.Add('credential-persistence') }
    foreach ($use in [regex]::Matches($Text, '(?m)^\s+(?:-\s*)?uses:\s*(?<value>\S+)\s*$')) {
        if ($use.Groups['value'].Value -notmatch '@[0-9a-f]{40}$') { $failures.Add('immutable-actions'); break }
    }
    if ($Text -notmatch 'job\.workflow_sha' -or $Text -notmatch 'job\.workflow_repository') { $failures.Add('trusted-workflow-identity') }
    if (-not $Text.Contains('ref: ${{ github.event.pull_request.head.sha || github.sha }}') -or
        -not $Text.Contains('Get-Content -LiteralPath $env:GITHUB_EVENT_PATH -Raw') -or
        -not $Text.Contains('$callerCommitSha = [string]$event.pull_request.head.sha') -or
        -not $Text.Contains('$callerRefName = [string]$event.pull_request.head.ref') -or
        -not $Text.Contains('CALLER_COMMIT_SHA=$callerCommitSha') -or
        -not $Text.Contains('CALLER_REF_NAME=$callerRefName') -or
        -not $Text.Contains('-ValidatedCommitSha $env:CALLER_COMMIT_SHA') -or
        -not $Text.Contains('-ExpectedCommitSha $env:CALLER_COMMIT_SHA') -or
        -not $Text.Contains('-ExpectedRepository $env:GITHUB_REPOSITORY') -or
        -not $Text.Contains('-ExpectedRefName $env:CALLER_REF_NAME')) { $failures.Add('caller-source-identity') }
    if ($Text.IndexOf('Upload Bash evidence before enforcement') -lt 0 -or $Text.IndexOf('Upload Bash evidence before enforcement') -gt $Text.IndexOf('Enforce governed Bash validation') -or
        $Text.IndexOf('Upload Bash bootstrap failure evidence before enforcement') -lt 0 -or $Text.IndexOf('Upload Bash bootstrap failure evidence before enforcement') -gt $Text.IndexOf('Enforce governed Bash validation')) { $failures.Add('evidence-order') }
    if ($Text -notmatch "(?ms)- name: Create Bash completion evidence in trusted workspace\s+id: completion\s+if: always\(\) && steps\.bootstrap\.outcome == 'success' && steps\.normalization\.outcome == 'success'" -or
        $Text -notmatch "(?ms)- name: Validate Bash completion evidence\s+id: evidence\s+if: always\(\) && steps\.bootstrap\.outcome == 'success' && steps\.normalization\.outcome == 'success' && steps\.completion\.outcome == 'success'" -or
        $Text -notmatch "(?ms)- name: Upload Bash evidence before enforcement\s+id: upload\s+if: always\(\) && steps\.bootstrap\.outcome == 'success' && steps\.normalization\.outcome == 'success' && steps\.completion\.outcome == 'success' && steps\.evidence\.outcome == 'success'") { $failures.Add('unsafe-evidence-upload') }
    if ($Text -notmatch "(?ms)- name: Upload Bash bootstrap failure evidence before enforcement\s+id: bootstrap_failure_upload\s+if: always\(\) && steps\.bootstrap\.outcome != 'success' && steps\.staging\.outcome == 'success' && steps\.normalization\.outcome == 'success'" -or
        -not $Text.Contains("`$bootstrapFailed = `$outcomes.bootstrap -cne 'success'") -or
        -not $Text.Contains("bootstrapFailureUpload = '`${{ steps.bootstrap_failure_upload.outcome }}'")) { $failures.Add('unsafe-bootstrap-failure-upload') }
    $pythonExport = $Text.IndexOf('"TRUSTED_PYTHON=$trustedPython"')
    $installerInvocation = $Text.IndexOf('& $trustedPython -I standards/scripts/Install-BashProjectToolchain.py')
    if ($pythonExport -lt 0 -or $installerInvocation -lt 0 -or $pythonExport -gt $installerInvocation) { $failures.Add('late-trusted-python-export') }
    if ($Text -notmatch 'Get-Command python.*?Select-Object -First 1') { $failures.Add('ambiguous-trusted-python-path') }
    $preservation = [regex]::Match($Text, '(?ms)\$preservationOutcomes\s*=.*?\$preservationFailures')
    if (-not $preservation.Success -or $preservation.Value -match '\bregression\b') { $failures.Add('unrelated-bootstrap-preservation-gate') }
    if ($Text -match "(?ms)- name: Run governed functional Bash validation\s+id: functional\s+if:.*steps\.boundary\.outcome == 'success'") { $failures.Add('missing-boundary-failure-evidence') }
    if ($Text -match '--(?:bash|shellcheck|shfmt|bats)\s+"?\$CALLER') { $failures.Add('caller-tool-path') }
    @($failures)
}

function Test-BashExampleWrapperControls {
    param([Parameter(Mandatory)][string]$Text)
    $failures = [Collections.Generic.List[string]]::new()
    if (-not $Text.Contains('git -C $project rev-parse --verify HEAD') -or
        -not $Text.Contains('git -C $standardsRoot status --porcelain --untracked-files=all -- .') -or
        -not $Text.Contains('-ValidatedCommitSha $validatedCommitSha')) { $failures.Add('local-commit-identity') }
    if ($Text -notmatch '(?ms)\$artifacts\s*=\s*@\(.*?''evidence/bash-toolchain-bootstrap\.json''.*?\)') { $failures.Add('local-bootstrap-binding') }
    if (-not $Text.Contains("-CommandsNotExecuted @('GitHub-hosted Bash workflow execution')")) { $failures.Add('hosted-notrun-command') }
    @($failures)
}

function Test-BashDriverControls {
    param([Parameter(Mandatory)][string]$Text)
    $failures = [Collections.Generic.List[string]]::new()
    if ($Text -notmatch '--rcfile=/dev/null' -or $Text -notmatch '"externalSources": False') { $failures.Add('caller-shellcheck-config') }
    if ($Text -notmatch 'RLIMIT_FSIZE' -or $Text -notmatch 'EVIDENCE_OUTPUT_CHARS') { $failures.Add('bounded-output') }
    if ($Text -notmatch 'execution_gate' -or $Text -notmatch 'Bats execution was not run because a mandatory non-executing gate') { $failures.Add('execution-gate') }
    if ($Text -notmatch 'source_files\s*=\s*bash_files') { $failures.Add('bats-source-isolation') }
    if ($Text -notmatch 'reject_undeclared_bash_content\(project_root\)') { $failures.Add('precopy-bash-inventory') }
    if ($Text -notmatch '"Blocked"' -or $Text -notmatch 'FileNotFoundError') { $failures.Add('blocked-status') }
    if ($Text -notmatch 'UNSAFE_ENVIRONMENT_VARIABLES' -or $Text -notmatch '"PATH": "/usr/bin:/bin"') { $failures.Add('environment-isolation') }
    @($failures)
}

function Test-BashArtifactVerifierControls {
    param([Parameter(Mandatory)][string]$Text)
    $failures = [Collections.Generic.List[string]]::new()
    if ($Text -notmatch "ExpectedConclusion -eq 'success'.*?'Passed'.*?'Failed'" -or $Text -notmatch 'completion\.status -cne \$expectedStatus') { $failures.Add('expected-completion-status') }
    if ($Text -notmatch 'controlled-failure phase did not fail' -or $Text -notmatch "status -cne 'Failed'") { $failures.Add('expected-failure-phase') }
    if ($Text -notmatch 'artifactMetadata\.id -cne \$ExpectedArtifactId' -or $Text -notmatch 'entry content differs from the extracted file') { $failures.Add('artifact-identity') }
    @($failures)
}

function New-BashArtifactInputs {
    param(
        [Parameter(Mandatory)][string]$ArtifactPath,
        [string]$CommitSha = ('1' * 40),
        [string]$Branch = 'main',
        [string]$RunId = '1',
        [string]$ArtifactId = '2',
        [string]$ArtifactName = 'bash-evidence-1'
    )
    Add-Type -AssemblyName System.IO.Compression.FileSystem
    $stem = [guid]::NewGuid().ToString('N')
    $zipPath = Join-Path $TestDrive "$stem.zip"
    [IO.Compression.ZipFile]::CreateFromDirectory($ArtifactPath, $zipPath)
    $zipSha = (Get-FileHash -LiteralPath $zipPath -Algorithm SHA256).Hash.ToLowerInvariant()
    $metadataPath = Join-Path $TestDrive "$stem-metadata.json"
    [ordered]@{
        id = [int64]$ArtifactId
        name = $ArtifactName
        expired = $false
        digest = "sha256:$zipSha"
        workflow_run = [ordered]@{ id = [int64]$RunId; head_sha = $CommitSha; head_branch = $Branch }
    } | ConvertTo-Json -Depth 6 | Set-Content -LiteralPath $metadataPath -Encoding utf8
    [pscustomobject]@{ ZipPath = $zipPath; MetadataPath = $metadataPath }
}

function New-ValidBashArtifactFixture {
    $workspace = Join-Path $TestDrive ([guid]::NewGuid().ToString('N'))
    $caller = Join-Path $workspace 'caller'
    $artifact = Join-Path $workspace 'evidence'
    New-Item -ItemType Directory -Path $caller,$artifact | Out-Null
    foreach ($name in @(
        'bash-syntax.json','bash-shellcheck.json','bash-formatting.json','bash-tests.json','bash-toolchain.json',
        'bash-toolchain-bootstrap.json','bash-project-sbom.cdx.json','local-test-results.json'
    )) {
        Copy-Item -LiteralPath (Join-Path $script:example "evidence/$name") -Destination (Join-Path $artifact $name)
    }
    $tests = Get-Content -LiteralPath (Join-Path $artifact 'local-test-results.json') -Raw | ConvertFrom-Json
    $hosted = @($tests | Where-Object name -EQ 'GitHub-hosted workflow execution')[0]
    $hosted.status = 'Passed'
    $hosted.requiredValidation = $true
    $hosted.exitCode = 0
    $hosted.summary = 'GitHub-hosted Bash workflow execution passed.'
    $hosted.failureReason = $null
    $hosted.notRunReason = $null
    $hosted.details.sanitizedOutput = 'Hosted execution is active.'
    $tests | ConvertTo-Json -Depth 30 | Set-Content -LiteralPath (Join-Path $artifact 'local-test-results.json') -Encoding utf8

    $saved = @{}
    foreach ($name in @('GITHUB_RUN_ID','GITHUB_RUN_ATTEMPT','GITHUB_WORKFLOW','GITHUB_SHA','GITHUB_REF_NAME','GITHUB_REPOSITORY')) {
        $saved[$name] = [Environment]::GetEnvironmentVariable($name)
    }
    try {
        $env:GITHUB_RUN_ID = '1'; $env:GITHUB_RUN_ATTEMPT = '1'; $env:GITHUB_WORKFLOW = 'Bash example CI'
        $env:GITHUB_SHA = ('1' * 40); $env:GITHUB_REF_NAME = '79/merge'; $env:GITHUB_REPOSITORY = 'example-org/project'
        & (Join-Path $script:root 'scripts/New-CompletionEvidence.ps1') `
            -RepositoryPath $workspace -SourceRepositoryPath $caller -OutputPath 'evidence/completion-result.json' `
            -TestResultPath 'evidence/local-test-results.json' -GovernanceVersion 1.1.0 -RiskClassification High `
            -Summary 'Synthetic hosted Bash artifact verifier fixture.' `
            -CommandsExecuted @('Install-BashProjectToolchain.py','bash-project-validation.py','Normalize-BashFunctionalEvidence.py') `
            -ArtifactPath @('evidence/bash-syntax.json','evidence/bash-shellcheck.json','evidence/bash-formatting.json','evidence/bash-tests.json','evidence/bash-toolchain.json','evidence/bash-toolchain-bootstrap.json','evidence/bash-project-sbom.cdx.json') `
            -ArtifactName 'bash-evidence-1' -Repository 'example-org/project' -Branch main -ValidatedCommitSha ('1' * 40) `
            -StandardsRepository 'AIAllTheThingz/Engineering-Standards' -StandardsWorkflowSha ('2' * 40) `
            -ValidationProfile bash-functional -ChecksExecuted @('BashSyntax','ShellCheck','shfmt','Bats','ToolchainProvenance','SBOM') `
            -EvidenceExecutionContext GitHubActions | Out-Null
        (Get-Content -LiteralPath (Join-Path $artifact 'completion-result.json') -Raw | ConvertFrom-Json).branch |
            Should -BeExactly 'main'
        & (Join-Path $script:root 'actions/validate-evidence/Invoke-EvidenceValidation.ps1') `
            -Path $workspace -EvidencePath 'evidence/completion-result.json' `
            -ExpectedCommitSha ('1' * 40) -ExpectedRepository 'example-org/project' -ExpectedRefName main `
            -OutputJson (Join-Path $artifact 'evidence-validation.json') | Out-Null
        [ordered]@{
            initialize='success'; boundary='success'; python='success'; bootstrap='success'; functional='success'
            regression='success'; staging='success'; normalization='success'; completion='success'; evidence='success'
        } | ConvertTo-Json | Set-Content -LiteralPath (Join-Path $artifact 'step-outcomes.json') -Encoding utf8
    }
    finally {
        foreach ($name in $saved.Keys) { [Environment]::SetEnvironmentVariable($name, $saved[$name]) }
    }
    $inputs = New-BashArtifactInputs -ArtifactPath $artifact
    [pscustomobject]@{ ArtifactPath=$artifact; ZipPath=$inputs.ZipPath; MetadataPath=$inputs.MetadataPath }
}
}

Describe 'Governed Bash project support' {
    It 'provides the complete functional example contract' {
        foreach ($path in @(
            'README.md','AGENTS.md','project-manifest.json','governance.config.json','bash-toolchain.lock.json',
            '.github/workflows/governance.yml',
            'cmd/governed-path','lib/governed_path.sh','spec/governed_path.bats','tools/Test-Example.ps1'
        )) {
            Test-Path -LiteralPath (Join-Path $script:example $path) -PathType Leaf | Should -BeTrue
        }
        (Get-Content -LiteralPath (Join-Path $script:example 'project-manifest.json') -Raw | ConvertFrom-Json).projectType | Should -BeExactly 'bash'
    }

    It 'binds the required Bash workflow to the expected immutable downstream check' {
        @(Test-BashExampleWorkflowContract -Text $script:exampleWorkflow -Manifest $script:exampleManifest -Config $script:exampleConfig).Count | Should -Be 0
    }

    It 'detects a missing Bash job when the manifest requires Bash' {
        $mutant = [regex]::Replace($script:exampleWorkflow, '(?ms)^  bash:\s*\r?\n.*\z', '')
        @(Test-BashExampleWorkflowContract -Text $mutant -Manifest $script:exampleManifest -Config $script:exampleConfig) |
            Should -Contain 'missing-bash-job'
    }

    It 'detects a Bash caller that cannot produce the required check name' {
        $mutant = $script:exampleWorkflow -replace '(?m)^    name:\s*Bash\s*$', '    name: Shell'
        @(Test-BashExampleWorkflowContract -Text $mutant -Manifest $script:exampleManifest -Config $script:exampleConfig) |
            Should -Contain 'required-bash-check'
    }

    It 'rejects non-immutable Bash reusable workflow reference <Reference>' -ForEach @(
        @{ Reference='main' },
        @{ Reference='v1.1.0' },
        @{ Reference='9872907' },
        @{ Reference='refs/heads/feature/bash' }
    ) {
        $mutant = [regex]::Replace($script:exampleWorkflow, '(?<=bash-ci-reusable\.yml@)[^\r\n]+', $Reference)
        @(Test-BashExampleWorkflowContract -Text $mutant -Manifest $script:exampleManifest -Config $script:exampleConfig) |
            Should -Contain 'immutable-bash-reference'
    }

    It 'rejects an incorrect downstream Bash project path' {
        $mutant = $script:exampleWorkflow -replace '(?m)^      project-path:\s*\.\s*$', '      project-path: examples/bash-project'
        @(Test-BashExampleWorkflowContract -Text $mutant -Manifest $script:exampleManifest -Config $script:exampleConfig) |
            Should -Contain 'bash-project-path'
    }

    It 'preserves truthful Blocked bootstrap evidence for an empty offline cache' -Skip:(-not $IsLinux) {
        $fixture = Initialize-BashExampleWrapperFixture
        $result = Invoke-BashExampleOfflineFixture -Fixture $fixture
        $evidencePath = Join-Path $fixture.Example 'evidence/bash-toolchain-bootstrap.json'
        $result.ExitCode | Should -Not -Be 0
        Test-Path -LiteralPath $evidencePath -PathType Leaf | Should -BeTrue
        $record = Get-Content -LiteralPath $evidencePath -Raw | ConvertFrom-Json
        $record.status | Should -BeExactly 'Blocked'
        $record.blockedReason | Should -Match 'offline cache is missing'
        $record.exitCode | Should -BeNullOrEmpty
        $result.Output | Should -Match 'exit code 2'
        $result.Output | Should -Match ([regex]::Escape($record.blockedReason))
        @(Get-ChildItem -LiteralPath (Join-Path $fixture.Example 'evidence') -File -Filter '*.json').Count | Should -Be 1
        Test-Path -LiteralPath (Join-Path $fixture.Example 'evidence/bash-tests.json') | Should -BeFalse
        Test-Path -LiteralPath (Join-Path $fixture.Example 'evidence/local-completion-result.json') | Should -BeFalse
        @(Get-ChildItem -LiteralPath $result.Temporary -Directory -Filter 'governed-bash-*').Count | Should -Be 0
    }

    It 'binds the local wrapper to a clean commit and records hosted validation as not run' {
        @(Test-BashExampleWrapperControls -Text $script:exampleWrapper).Count | Should -Be 0
    }

    It 'keeps checked-in local completion evidence valid and honestly NotRun' {
        $completionPath = Join-Path $script:example 'evidence/local-completion-result.json'
        @((Test-GovernanceJsonDocument -Path $completionPath -Kind completion-result) | Where-Object status -EQ Failed).Count | Should -Be 0
        $completion = Get-Content -LiteralPath $completionPath -Raw | ConvertFrom-Json
        $completion.commitSha | Should -Match '^[0-9a-f]{40}$'
        $completion.validatedCommitSha | Should -BeExactly $completion.commitSha
        $completion.status | Should -BeExactly 'NotRun'
        @($completion.commandsNotExecuted) | Should -Contain 'GitHub-hosted Bash workflow execution'
        @($completion.artifacts.path) | Should -Contain 'evidence/bash-toolchain-bootstrap.json'
        $changedAfterValidation = @(& git -C $script:root diff --name-only "$($completion.validatedCommitSha)..HEAD" --)
        $LASTEXITCODE | Should -Be 0
        $allowedAfterValidation = @(
            '.github/workflows/bash-ci.yml',
            'workflows/bash-ci.yml',
            'examples/bash-project/.github/workflows/governance.yml'
        )
        @($changedAfterValidation | Where-Object {
            -not $_.StartsWith('examples/bash-project/evidence/', [StringComparison]::Ordinal) -and
            $allowedAfterValidation -cnotcontains $_
        }) | Should -BeNullOrEmpty
    }

    It 'detects local completion identity and NotRun metadata mutations' -ForEach @(
        @{ Pattern='git -C $project rev-parse --verify HEAD'; Expected='local-commit-identity' },
        @{ Pattern='git -C $standardsRoot status --porcelain --untracked-files=all -- .'; Expected='local-commit-identity' },
        @{ Pattern="'evidence/bash-toolchain-bootstrap.json',"; Expected='local-bootstrap-binding' },
        @{ Pattern="-CommandsNotExecuted @('GitHub-hosted Bash workflow execution')"; Expected='hosted-notrun-command' }
    ) {
        $mutant = $script:exampleWrapper.Replace($Pattern, 'CONTROL_REMOVED')
        @(Test-BashExampleWrapperControls -Text $mutant) | Should -Contain $Expected
    }

    It 'fails closed when nonzero bootstrap evidence is <EvidenceMode>' -ForEach @(
        @{ EvidenceMode='missing' },
        @{ EvidenceMode='malformed' },
        @{ EvidenceMode='incomplete' },
        @{ EvidenceMode='wrong-identity' }
    ) -Skip:(-not $IsLinux) {
        $fixture = Initialize-BashExampleWrapperFixture
        $stub = @"
import json
import pathlib
import sys
evidence = pathlib.Path(sys.argv[sys.argv.index('--evidence') + 1])
mode = '$EvidenceMode'
if mode == 'malformed':
    evidence.write_text('{invalid', encoding='utf-8')
elif mode == 'incomplete':
    evidence.write_text(json.dumps({'status': 'Blocked', 'blockedReason': '0123456789'}), encoding='utf-8')
elif mode == 'wrong-identity':
    evidence.write_text(json.dumps({
        'schemaVersion': '1.1.0',
        'name': 'Untrusted bootstrap record',
        'category': 'dependency',
        'status': 'Blocked',
        'requiredValidation': True,
        'evidenceSource': 'Automated',
        'command': 'synthetic installer',
        'workingDirectory': '.',
        'startedAtUtc': '2026-07-22T00:00:00Z',
        'completedAtUtc': '2026-07-22T00:00:01Z',
        'durationSeconds': 1,
        'runtime': 'CPython 3.12.0',
        'toolName': 'bash-toolchain-bootstrap',
        'toolVersion': '1.0.0',
        'exitCode': None,
        'summary': 'Synthetic blocked bootstrap record.',
        'warnings': [],
        'failureReason': None,
        'blockedReason': 'Synthetic bootstrap failure reason.',
        'details': {'sanitizedOutput': 'Synthetic bootstrap failure reason.'}
    }), encoding='utf-8')
print('synthetic offline bootstrap failure', file=sys.stderr)
raise SystemExit(2)
"@
        Set-Content -LiteralPath $fixture.Installer -Value $stub -Encoding utf8
        $result = Invoke-BashExampleOfflineFixture -Fixture $fixture
        $result.ExitCode | Should -Not -Be 0
        Test-Path -LiteralPath (Join-Path $fixture.Example 'evidence/bash-toolchain-bootstrap.json') | Should -BeFalse
        Test-Path -LiteralPath (Join-Path $fixture.Example 'evidence/bash-tests.json') | Should -BeFalse
        Test-Path -LiteralPath (Join-Path $fixture.Example 'evidence/local-completion-result.json') | Should -BeFalse
        @(Get-ChildItem -LiteralPath (Join-Path $fixture.Example 'evidence') -File -Filter '*.json').Count | Should -Be 0
        @(Get-ChildItem -LiteralPath $result.Temporary -Directory -Filter 'governed-bash-*').Count | Should -Be 0
    }

    It 'locks exact functional tools separately and keeps ShellCheck consistent with the central lock' {
        $lock = Get-Content -LiteralPath (Join-Path $script:example 'bash-toolchain.lock.json') -Raw | ConvertFrom-Json
        @($lock.tools.name) | Should -Be @('ShellCheck','shfmt','Bats')
        foreach ($tool in @($lock.tools)) {
            $tool.version | Should -Match '^\d+\.\d+\.\d+$'
            $tool.sourceUrl | Should -Match '^https://'
            $tool.sourceUrl | Should -Not -Match '/latest/?$'
            $tool.sha256 | Should -Match '^[0-9a-f]{64}$'
            $tool.expectedExecutablePath | Should -Not -Match '(^/|\.\.)'
            $tool.licenseSpdx | Should -Not -BeNullOrEmpty
            $tool.purl | Should -Match '^pkg:'
            $tool.runnerArchitecture | Should -BeExactly 'linux-x86_64'
        }
        $central = Import-PowerShellDataFile -LiteralPath (Join-Path $script:root '.github/dependencies/validator-dependencies.psd1')
        $centralShellCheck = @($central.Packages | Where-Object Name -EQ 'ShellCheck')[0]
        $functionalShellCheck = @($lock.tools | Where-Object name -CEQ 'ShellCheck')[0]
        $functionalShellCheck.version | Should -BeExactly $centralShellCheck.Version
        $functionalShellCheck.sha256 | Should -BeExactly $centralShellCheck.Sha256
        $functionalShellCheck.sourceUrl | Should -BeExactly $centralShellCheck.SourceUri
        (Get-Content -LiteralPath (Join-Path $script:root '.github/dependencies/validator-dependencies.psd1') -Raw) | Should -Not -Match "(?i)Name\s*=\s*'(shfmt|Bats)'"
    }

    It 'keeps central static Bash validation non-executing' {
        $static = Get-Content -LiteralPath (Join-Path $script:root 'scripts/Test-BashStaticAnalysis.ps1') -Raw
        $static | Should -Match "'--noprofile','--norc','-n'"
        $static | Should -Not -Match '--external-sources|--check-sourced'
        $static | Should -Match '--rcfile=/dev/null'
        $static | Should -Not -Match 'bash-project-validation\.py|\bbats\b|\bsource\s+\$'
    }

    It 'enforces runtime isolation, fixed tool paths, clean environment, and bounded Bats execution' {
        foreach ($name in @('BASH_ENV','ENV','SHELLOPTS','BASHOPTS','CDPATH','GLOBIGNORE','BATS_LIB_PATH','SHELLCHECK_OPTS')) { $script:driver | Should -Match $name }
        $script:driver | Should -Match 'PATH": "/usr/bin:/bin"'
        $script:driver | Should -Match 'RLIMIT_FSIZE'
        $script:driver | Should -Match 'killpg'
        $script:driver | Should -Match 'project, work root, and evidence root must not overlap'
        $script:driver | Should -Match '--rcfile=/dev/null'
        $script:driver | Should -Match '"externalSources": False'
        $script:driver | Should -Not -Match '"--external-sources"'
        $script:driver | Should -Match '"-ln",\s*"bash"'
        $script:driver | Should -Match 'execution_gate'
    }

    It 'uses immutable least-privilege workflow controls and uploads before enforcement' {
        @(Test-BashWorkflowControls -Text $script:workflow).Count | Should -Be 0
        $script:workflow | Should -Match 'runs-on:\s*ubuntu-24\.04'
        $script:workflow | Should -Match 'python-version:\s*3\.12\.11'
        $script:workflow | Should -Match '--bash /usr/bin/bash'
        $script:workflow | Should -Not -Match 'pull_request_target|secrets\.|secrets:\s*inherit|contents:\s*write'
    }

    It 'triggers Bash CI for shared completion and evidence validation changes' {
        foreach ($path in @(
            'scripts/New-CompletionEvidence.ps1',
            'scripts/GovernanceValidation.psm1',
            'actions/validate-evidence/Invoke-EvidenceValidation.ps1'
        )) {
            $script:entryWorkflow | Should -Match ([regex]::Escape("- '$path'"))
        }
    }

    It 'detects representative workflow-control mutations' -ForEach @(
        @{ Name='permission broadening'; Mutate={ param($text) $text -replace 'contents: read','contents: write' }; Expected='prohibited-authority' },
        @{ Name='one checkout persists credentials'; Mutate={ param($text) [regex]::Replace($text,'persist-credentials: false','persist-credentials: true',1) }; Expected='credential-persistence' },
        @{ Name='mutable action tag'; Mutate={ param($text) $text -replace 'actions/checkout@[0-9a-f]{40}','actions/checkout@v5' }; Expected='immutable-actions' },
        @{ Name='extra mutable action'; Mutate={ param($text) $text + "`n      - uses: example/action@main`n" }; Expected='immutable-actions' },
        @{ Name='OIDC permission added'; Mutate={ param($text) $text -replace 'permissions:\r?\n  contents: read',"permissions:`n  contents: read`n  id-token: write" }; Expected='prohibited-authority' },
        @{ Name='trusted identity removal'; Mutate={ param($text) $text -replace 'job\.workflow_sha','github.sha' }; Expected='trusted-workflow-identity' },
        @{ Name='caller source identity removal'; Mutate={ param($text) $text.Replace('github.event.pull_request.head.sha || github.sha','github.sha') }; Expected='caller-source-identity' },
        @{ Name='caller-selected tool path'; Mutate={ param($text) $text.Replace('--shellcheck "$TRUSTED_SHELLCHECK"','--shellcheck "$CALLER_SHELLCHECK"') }; Expected='caller-tool-path' },
        @{ Name='evidence after enforcement'; Mutate={ param($text) $text.Replace('Upload Bash evidence before enforcement','Late evidence upload').Replace('Enforce governed Bash validation','Upload Bash evidence before enforcement') }; Expected='evidence-order' },
        @{ Name='completion copies unnormalized evidence'; Mutate={ param($text) $text.Replace("if: always() && steps.bootstrap.outcome == 'success' && steps.normalization.outcome == 'success'",'if: always()') }; Expected='unsafe-evidence-upload' },
        @{ Name='upload ignores evidence safety gates'; Mutate={ param($text) $text.Replace("if: always() && steps.bootstrap.outcome == 'success' && steps.normalization.outcome == 'success' && steps.completion.outcome == 'success' && steps.evidence.outcome == 'success'",'if: always()') }; Expected='unsafe-evidence-upload' },
        @{ Name='bootstrap failure upload ignores preservation gates'; Mutate={ param($text) $text.Replace("if: always() && steps.bootstrap.outcome != 'success' && steps.staging.outcome == 'success' && steps.normalization.outcome == 'success'",'if: always()') }; Expected='unsafe-bootstrap-failure-upload' },
        @{ Name='bootstrap failure upload is not enforced'; Mutate={ param($text) $text.Replace("`$bootstrapFailed = `$outcomes.bootstrap -cne 'success'",'$bootstrapFailed = $false') }; Expected='unsafe-bootstrap-failure-upload' },
        @{ Name='boundary failure skips evidence driver'; Mutate={ param($text) $text.Replace("if: always() && steps.python.outcome == 'success' && steps.bootstrap.outcome == 'success'","if: always() && steps.boundary.outcome == 'success' && steps.python.outcome == 'success' && steps.bootstrap.outcome == 'success'") }; Expected='missing-boundary-failure-evidence' },
        @{ Name='trusted Python export delayed until after installer'; Mutate={ param($text) $text.Replace('"TRUSTED_PYTHON=$trustedPython" | Out-File -FilePath $env:GITHUB_ENV -Encoding utf8 -Append','').Replace('"TRUSTED_SHELLCHECK=$($paths.shellcheck)",','"TRUSTED_PYTHON=$trustedPython",`n            "TRUSTED_SHELLCHECK=$($paths.shellcheck)",') }; Expected='late-trusted-python-export' },
        @{ Name='trusted Python path accepts every PATH match'; Mutate={ param($text) $text.Replace(' | Select-Object -First 1','') }; Expected='ambiguous-trusted-python-path' },
        @{ Name='regression gates bootstrap preservation'; Mutate={ param($text) $text.Replace('staging = $outcomes.staging','regression = $outcomes.regression`n              staging = $outcomes.staging') }; Expected='unrelated-bootstrap-preservation-gate' }
    ) {
        $mutant = & $Mutate $script:workflow
        @(Test-BashWorkflowControls -Text $mutant) | Should -Contain $Expected
    }

    It 'detects driver trust-control mutations with independent policy validation' -ForEach @(
        @{ Pattern='--rcfile=/dev/null'; Expected='caller-shellcheck-config' },
        @{ Pattern='"externalSources": False'; Expected='caller-shellcheck-config' },
        @{ Pattern='RLIMIT_FSIZE'; Expected='bounded-output' },
        @{ Pattern='execution_gate'; Expected='execution-gate' },
        @{ Pattern='source_files = bash_files'; Expected='bats-source-isolation' },
        @{ Pattern='reject_undeclared_bash_content(project_root)'; Expected='precopy-bash-inventory' },
        @{ Pattern='"Blocked"'; Expected='blocked-status' },
        @{ Pattern='"PATH": "/usr/bin:/bin"'; Expected='environment-isolation' }
    ) {
        $mutant = $script:driver -replace [regex]::Escape($Pattern), 'CONTROL_REMOVED'
        @(Test-BashDriverControls -Text $mutant) | Should -Contain $Expected
    }

    It 'detects mutation that would report an expected functional failure as success' {
        @(Test-BashArtifactVerifierControls -Text $script:artifactVerifier).Count | Should -Be 0
        $mutant = $script:artifactVerifier.Replace("if (`$completion.status -cne `$expectedStatus)", "if (`$false)")
        @(Test-BashArtifactVerifierControls -Text $mutant) | Should -Contain 'expected-completion-status'
    }

    It 'implements fail-closed archive, offline, tamper, and version controls' {
        $script:installer | Should -Match 'member\.isfile\(\) or member\.isdir\(\)'
        $script:installer | Should -Match 'duplicate or case-colliding'
        $script:installer | Should -Match 'offline cache is missing'
        $script:installer | Should -Match 'SHA-256 mismatch'
        $script:installer | Should -Match 'version does not match'
        $script:installer | Should -Match 'return 2'
    }

    It 'fails artifact verification when evidence is missing' {
        $artifact = Join-Path $TestDrive 'missing-artifact'
        New-Item -ItemType Directory -Path $artifact | Out-Null
        $inputs = New-BashArtifactInputs -ArtifactPath $artifact
        $output = & pwsh -NoProfile -File (Join-Path $script:root 'scripts/Test-BashWorkflowEvidenceArtifact.ps1') `
            -ArtifactPath $artifact `
            -ExpectedRepository 'example-org/project' `
            -ExpectedCommitSha ('1' * 40) `
            -ExpectedBranch main `
            -ExpectedRunId 1 `
            -ExpectedArtifactId 2 `
            -ExpectedArtifactName 'bash-evidence-1' `
            -ArtifactMetadataPath $inputs.MetadataPath `
            -ZipPath $inputs.ZipPath `
            -ExpectedStandardsRepository 'AIAllTheThingz/Engineering-Standards' `
            -ExpectedStandardsWorkflowSha ('2' * 40) `
            -ExpectedConclusion success
        $LASTEXITCODE | Should -Not -Be 0
    }

    It 'accepts a complete identity-bound hosted success artifact' {
        $fixture = New-ValidBashArtifactFixture
        $validationReport = Get-Content -LiteralPath (Join-Path $fixture.ArtifactPath 'evidence-validation.json') -Raw
        $output = & pwsh -NoProfile -File (Join-Path $script:root 'scripts/Test-BashWorkflowEvidenceArtifact.ps1') `
            -ArtifactPath $fixture.ArtifactPath -ExpectedRepository 'example-org/project' -ExpectedCommitSha ('1' * 40) `
            -ExpectedBranch main -ExpectedRunId 1 -ExpectedArtifactId 2 -ExpectedArtifactName 'bash-evidence-1' `
            -ArtifactMetadataPath $fixture.MetadataPath -ZipPath $fixture.ZipPath `
            -ExpectedStandardsRepository 'AIAllTheThingz/Engineering-Standards' -ExpectedStandardsWorkflowSha ('2' * 40) `
            -ExpectedConclusion success 2>&1
        $LASTEXITCODE | Should -Be 0 -Because (($output -join "`n") + "`n" + $validationReport)
    }

    It 'independently scans artifacts for absolute workstation paths' {
        $artifact = Join-Path $TestDrive 'unsafe-artifact'
        New-Item -ItemType Directory -Path $artifact | Out-Null
        Set-Content -LiteralPath (Join-Path $artifact 'unsafe.json') -Value '{"path":"/etc/passwd"}'
        $inputs = New-BashArtifactInputs -ArtifactPath $artifact
        $output = & pwsh -NoProfile -File (Join-Path $script:root 'scripts/Test-BashWorkflowEvidenceArtifact.ps1') `
            -ArtifactPath $artifact `
            -ExpectedRepository 'example-org/project' `
            -ExpectedCommitSha ('1' * 40) `
            -ExpectedBranch main `
            -ExpectedRunId 1 `
            -ExpectedArtifactId 2 `
            -ExpectedArtifactName 'bash-evidence-1' `
            -ArtifactMetadataPath $inputs.MetadataPath `
            -ZipPath $inputs.ZipPath `
            -ExpectedStandardsRepository 'AIAllTheThingz/Engineering-Standards' `
            -ExpectedStandardsWorkflowSha ('2' * 40) `
            -ExpectedConclusion success 2>&1
        $LASTEXITCODE | Should -Not -Be 0
        $output -join "`n" | Should -Match 'Absolute workstation path'
    }

    It 'independently scans artifacts for token-like values' {
        $artifact = Join-Path $TestDrive 'token-artifact'
        New-Item -ItemType Directory -Path $artifact | Out-Null
        $syntheticCredential = [string]::Concat('github', '_pat_', 'abcdefghijklmnopqrstuvwxyz123456')
        Set-Content -LiteralPath (Join-Path $artifact 'unsafe.json') -Value ("{`"value`":`"$syntheticCredential`"}")
        $inputs = New-BashArtifactInputs -ArtifactPath $artifact
        $output = & pwsh -NoProfile -File (Join-Path $script:root 'scripts/Test-BashWorkflowEvidenceArtifact.ps1') `
            -ArtifactPath $artifact -ExpectedRepository 'example-org/project' -ExpectedCommitSha ('1' * 40) `
            -ExpectedBranch main -ExpectedRunId 1 -ExpectedArtifactId 2 -ExpectedArtifactName 'bash-evidence-1' `
            -ArtifactMetadataPath $inputs.MetadataPath -ZipPath $inputs.ZipPath `
            -ExpectedStandardsRepository 'AIAllTheThingz/Engineering-Standards' -ExpectedStandardsWorkflowSha ('2' * 40) `
            -ExpectedConclusion success 2>&1
        $LASTEXITCODE | Should -Not -Be 0
        $output -join "`n" | Should -Match 'Credential-like output'
    }

    It 'binds the expected artifact ID to independent API metadata' {
        $artifact = Join-Path $TestDrive 'identity-artifact'
        New-Item -ItemType Directory -Path $artifact | Out-Null
        Set-Content -LiteralPath (Join-Path $artifact 'record.json') -Value '{}'
        $inputs = New-BashArtifactInputs -ArtifactPath $artifact -ArtifactId 3
        $output = & pwsh -NoProfile -File (Join-Path $script:root 'scripts/Test-BashWorkflowEvidenceArtifact.ps1') `
            -ArtifactPath $artifact -ExpectedRepository 'example-org/project' -ExpectedCommitSha ('1' * 40) `
            -ExpectedBranch main -ExpectedRunId 1 -ExpectedArtifactId 2 -ExpectedArtifactName 'bash-evidence-1' `
            -ArtifactMetadataPath $inputs.MetadataPath -ZipPath $inputs.ZipPath `
            -ExpectedStandardsRepository 'AIAllTheThingz/Engineering-Standards' -ExpectedStandardsWorkflowSha ('2' * 40) `
            -ExpectedConclusion success 2>&1
        $LASTEXITCODE | Should -Not -Be 0
        $output -join "`n" | Should -Match 'Artifact API ID mismatch'
    }

    It 'rejects an extracted directory paired with different ZIP content' {
        $artifact = Join-Path $TestDrive 'zip-binding-artifact'
        New-Item -ItemType Directory -Path $artifact | Out-Null
        Set-Content -LiteralPath (Join-Path $artifact 'record.json') -Value '{"value":"original"}'
        $inputs = New-BashArtifactInputs -ArtifactPath $artifact
        Set-Content -LiteralPath (Join-Path $artifact 'record.json') -Value '{"value":"changed!"}'
        $output = & pwsh -NoProfile -File (Join-Path $script:root 'scripts/Test-BashWorkflowEvidenceArtifact.ps1') `
            -ArtifactPath $artifact -ExpectedRepository 'example-org/project' -ExpectedCommitSha ('1' * 40) `
            -ExpectedBranch main -ExpectedRunId 1 -ExpectedArtifactId 2 -ExpectedArtifactName 'bash-evidence-1' `
            -ArtifactMetadataPath $inputs.MetadataPath -ZipPath $inputs.ZipPath `
            -ExpectedStandardsRepository 'AIAllTheThingz/Engineering-Standards' -ExpectedStandardsWorkflowSha ('2' * 40) `
            -ExpectedConclusion success 2>&1
        $LASTEXITCODE | Should -Not -Be 0
        $output -join "`n" | Should -Match 'ZIP entry (size|content) differs'
    }
}
