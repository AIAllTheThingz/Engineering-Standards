BeforeAll {
    $script:root = (Resolve-Path "$PSScriptRoot/../..").Path
    $script:example = Join-Path $script:root 'examples/bash-project'
    $script:workflowPath = Join-Path $script:root '.github/workflows/bash-ci-reusable.yml'
    $script:workflow = Get-Content -LiteralPath $script:workflowPath -Raw
    $script:driver = Get-Content -LiteralPath (Join-Path $script:root 'scripts/bash-project-validation.py') -Raw
    $script:installer = Get-Content -LiteralPath (Join-Path $script:root 'scripts/Install-BashProjectToolchain.py') -Raw
    $script:artifactVerifier = Get-Content -LiteralPath (Join-Path $script:root 'scripts/Test-BashWorkflowEvidenceArtifact.ps1') -Raw

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
        -not $Text.Contains('-ValidatedCommitSha $env:CALLER_COMMIT_SHA')) { $failures.Add('caller-source-identity') }
    if ($Text.IndexOf('Upload Bash evidence before enforcement') -lt 0 -or $Text.IndexOf('Upload Bash evidence before enforcement') -gt $Text.IndexOf('Enforce governed Bash validation')) { $failures.Add('evidence-order') }
    if ($Text -match '--(?:bash|shellcheck|shfmt|bats)\s+"?\$CALLER') { $failures.Add('caller-tool-path') }
    @($failures)
}

function Test-BashDriverControls {
    param([Parameter(Mandatory)][string]$Text)
    $failures = [Collections.Generic.List[string]]::new()
    if ($Text -notmatch '--rcfile=/dev/null' -or $Text -notmatch '"externalSources": False') { $failures.Add('caller-shellcheck-config') }
    if ($Text -notmatch 'RLIMIT_FSIZE' -or $Text -notmatch 'EVIDENCE_OUTPUT_CHARS') { $failures.Add('bounded-output') }
    if ($Text -notmatch 'execution_gate' -or $Text -notmatch 'Bats execution was not run because a mandatory non-executing gate') { $failures.Add('execution-gate') }
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
    $hosted.notRunReason = $null
    $hosted.details.sanitizedOutput = 'Hosted execution is active.'
    $tests | ConvertTo-Json -Depth 30 | Set-Content -LiteralPath (Join-Path $artifact 'local-test-results.json') -Encoding utf8

    $saved = @{}
    foreach ($name in @('GITHUB_RUN_ID','GITHUB_RUN_ATTEMPT','GITHUB_WORKFLOW','GITHUB_SHA','GITHUB_REF_NAME','GITHUB_REPOSITORY')) {
        $saved[$name] = [Environment]::GetEnvironmentVariable($name)
    }
    try {
        $env:GITHUB_RUN_ID = '1'; $env:GITHUB_RUN_ATTEMPT = '1'; $env:GITHUB_WORKFLOW = 'Bash example CI'
        $env:GITHUB_SHA = ('1' * 40); $env:GITHUB_REF_NAME = 'main'; $env:GITHUB_REPOSITORY = 'example-org/project'
        & (Join-Path $script:root 'scripts/New-CompletionEvidence.ps1') `
            -RepositoryPath $workspace -SourceRepositoryPath $caller -OutputPath 'evidence/completion-result.json' `
            -TestResultPath 'evidence/local-test-results.json' -GovernanceVersion 1.1.0 -RiskClassification High `
            -Summary 'Synthetic hosted Bash artifact verifier fixture.' `
            -CommandsExecuted @('Install-BashProjectToolchain.py','bash-project-validation.py','Normalize-BashFunctionalEvidence.py') `
            -ArtifactPath @('evidence/bash-syntax.json','evidence/bash-shellcheck.json','evidence/bash-formatting.json','evidence/bash-tests.json','evidence/bash-toolchain.json','evidence/bash-project-sbom.cdx.json') `
            -ArtifactName 'bash-evidence-1' -Repository 'example-org/project' -Branch main -ValidatedCommitSha ('1' * 40) `
            -StandardsRepository 'AIAllTheThingz/Engineering-Standards' -StandardsWorkflowSha ('2' * 40) `
            -ValidationProfile bash-functional -ChecksExecuted @('BashSyntax','ShellCheck','shfmt','Bats','ToolchainProvenance','SBOM') `
            -EvidenceExecutionContext GitHubActions | Out-Null
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
            'bin/governed-path','lib/governed_path.sh','spec/governed_path.bats','tools/Test-Example.ps1'
        )) {
            Test-Path -LiteralPath (Join-Path $script:example $path) -PathType Leaf | Should -BeTrue
        }
        (Get-Content -LiteralPath (Join-Path $script:example 'project-manifest.json') -Raw | ConvertFrom-Json).projectType | Should -BeExactly 'bash'
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

    It 'detects representative workflow-control mutations' -ForEach @(
        @{ Name='permission broadening'; Mutate={ param($text) $text -replace 'contents: read','contents: write' }; Expected='prohibited-authority' },
        @{ Name='one checkout persists credentials'; Mutate={ param($text) [regex]::Replace($text,'persist-credentials: false','persist-credentials: true',1) }; Expected='credential-persistence' },
        @{ Name='mutable action tag'; Mutate={ param($text) $text -replace 'actions/checkout@[0-9a-f]{40}','actions/checkout@v5' }; Expected='immutable-actions' },
        @{ Name='extra mutable action'; Mutate={ param($text) $text + "`n      - uses: example/action@main`n" }; Expected='immutable-actions' },
        @{ Name='OIDC permission added'; Mutate={ param($text) $text -replace 'permissions:\r?\n  contents: read',"permissions:`n  contents: read`n  id-token: write" }; Expected='prohibited-authority' },
        @{ Name='trusted identity removal'; Mutate={ param($text) $text -replace 'job\.workflow_sha','github.sha' }; Expected='trusted-workflow-identity' },
        @{ Name='caller source identity removal'; Mutate={ param($text) $text.Replace('github.event.pull_request.head.sha || github.sha','github.sha') }; Expected='caller-source-identity' },
        @{ Name='caller-selected tool path'; Mutate={ param($text) $text.Replace('--shellcheck "$TRUSTED_SHELLCHECK"','--shellcheck "$CALLER_SHELLCHECK"') }; Expected='caller-tool-path' },
        @{ Name='evidence after enforcement'; Mutate={ param($text) $text.Replace('Upload Bash evidence before enforcement','Late evidence upload').Replace('Enforce governed Bash validation','Upload Bash evidence before enforcement') }; Expected='evidence-order' }
    ) {
        $mutant = & $Mutate $script:workflow
        @(Test-BashWorkflowControls -Text $mutant) | Should -Contain $Expected
    }

    It 'detects driver trust-control mutations with independent policy validation' -ForEach @(
        @{ Pattern='--rcfile=/dev/null'; Expected='caller-shellcheck-config' },
        @{ Pattern='"externalSources": False'; Expected='caller-shellcheck-config' },
        @{ Pattern='RLIMIT_FSIZE'; Expected='bounded-output' },
        @{ Pattern='execution_gate'; Expected='execution-gate' },
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
