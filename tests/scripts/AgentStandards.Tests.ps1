Describe 'Agent standards validation' {
    BeforeAll {
        $script:repoRoot = (Resolve-Path -LiteralPath "$PSScriptRoot/../..").Path

        function New-AgentStandardsFixture {
            $tempRoot = Join-Path ([System.IO.Path]::GetTempPath()) ("agent-standards-" + [guid]::NewGuid())
            New-Item -ItemType Directory -Path $tempRoot -Force | Out-Null
            New-Item -ItemType Directory -Path (Join-Path $tempRoot 'agents') -Force | Out-Null
            New-Item -ItemType Directory -Path (Join-Path $tempRoot 'governance') -Force | Out-Null
            New-Item -ItemType Directory -Path (Join-Path $tempRoot 'docs') -Force | Out-Null

            Copy-Item -LiteralPath (Join-Path $script:repoRoot 'AGENTS.md') -Destination (Join-Path $tempRoot 'AGENTS.md')
            Copy-Item -LiteralPath (Join-Path $script:repoRoot 'CHANGELOG.md') -Destination (Join-Path $tempRoot 'CHANGELOG.md')
            Copy-Item -Path (Join-Path $script:repoRoot 'agents/AGENTS_*.md') -Destination (Join-Path $tempRoot 'agents')
            Copy-Item -Path (Join-Path $script:repoRoot 'governance/*.md') -Destination (Join-Path $tempRoot 'governance')
            foreach ($doc in @('GOVERNANCE_ARCHITECTURE.md','MAINTAINER_GUIDE.md','ADOPTION_GUIDE.md','RELEASE_PROCESS.md')) {
                Copy-Item -LiteralPath (Join-Path $script:repoRoot "docs/$doc") -Destination (Join-Path $tempRoot 'docs')
            }
            $tempRoot
        }

        function Invoke-AgentStandardsValidator {
            param([string]$Path)
            & pwsh -NoProfile -File (Join-Path $script:repoRoot 'scripts/Test-AgentStandards.ps1') -Path $Path | Out-Null
            $LASTEXITCODE
        }
    }

    Context 'valid documents' {
        It 'passes for the repository documents' {
            Invoke-AgentStandardsValidator -Path $script:repoRoot | Should -Be 0
        }
    }

    Context 'invalid documents' {
        AfterEach {
            if ($script:tempRoot -and (Test-Path -LiteralPath $script:tempRoot)) {
                Remove-Item -LiteralPath $script:tempRoot -Recurse -Force
                $script:tempRoot = $null
            }
        }

        It 'fails Python mutation: <Name>' -ForEach @(
            @{ Name='runtime compatibility removed'; Old='Each repository MUST declare a supported CPython version matrix'; New='Runtime compatibility may be inferred' },
            @{ Name='reproducible dependencies weakened'; Old='Dependency resolution MUST be reproducible'; New='Dependency resolution SHOULD be reproducible' },
            @{ Name='safe subprocess arguments weakened'; Old='External commands MUST prefer argument arrays'; New='External commands MAY prefer argument arrays' },
            @{ Name='shell true allowed for untrusted input'; Old='`shell=True` MUST NOT be used with untrusted or concatenated input'; New='`shell=True` MAY be used with untrusted or concatenated input' },
            @{ Name='unsafe deserialization prohibition removed'; Old='Untrusted data MUST NOT be loaded with unsafe pickle, marshal'; New='Untrusted data may be loaded with pickle or marshal' },
            @{ Name='network timeouts removed'; Old='use explicit connection and operation timeouts'; New='use default timeout behavior' },
            @{ Name='secret protection weakened'; Old='Secrets MUST NOT be committed, embedded in artifacts, placed in URLs, exposed in logs or exceptions'; New='Secrets SHOULD NOT usually be logged' },
            @{ Name='negative testing made optional'; Old='Tests MUST include positive, negative, boundary, failure-path, and security cases'; New='Tests MAY include positive and negative cases' },
            @{ Name='missing tools changed to invented success'; Old='Missing tools or environments MUST be reported as `NotRun` or `Blocked`'; New='Missing tools or environments may be reported as `AssumedPassed`' },
            @{ Name='base inheritance removed'; Old='This standard inherits [AGENTS_Base.md](AGENTS_Base.md).'; New='This standard is independent of the base standard.' }
        ) {
            $script:tempRoot = New-AgentStandardsFixture
            $path = Join-Path $script:tempRoot 'agents/AGENTS_Python.md'
            $text = (Get-Content -LiteralPath $path -Raw).Replace($Old, $New)
            Set-Content -LiteralPath $path -Value $text -Encoding utf8
            Invoke-AgentStandardsValidator -Path $script:tempRoot | Should -Not -Be 0
        }

        It 'fails Bash mutation: <Name>' -ForEach @(
            @{ Name='Bash versus POSIX declaration removed'; Old='declare whether it requires Bash or portable POSIX `sh`'; New='declare a generic shell' },
            @{ Name='quoting requirement weakened'; Old='Variable expansions MUST be quoted'; New='Variable expansions MAY be quoted' },
            @{ Name='unsafe destructive targets allowed'; Old='reject empty, root, home, wildcard, traversal, or unbounded destructive targets'; New='accept empty or root destructive targets' },
            @{ Name='unsafe eval permitted'; Old='Unsafe `eval` is prohibited'; New='Unsafe `eval` is permitted' },
            @{ Name='temporary-file safety weakened'; Old='Temporary files and directories MUST use `mktemp`'; New='Temporary files and directories MAY use predictable paths' },
            @{ Name='unverified download execution permitted'; Old='Piping unverified `curl` or `wget` output directly into `bash`, `sh`, or another interpreter is prohibited'; New='Piping unverified downloads into an interpreter is permitted' },
            @{ Name='secret tracing controls removed'; Old='Secrets MUST NOT be exposed through `set -x`'; New='Secrets MAY be exposed through tracing' },
            @{ Name='failure propagation weakened'; Old='Scripts MUST preserve command and pipeline failure exit codes'; New='Scripts MAY ignore command and pipeline failures' },
            @{ Name='negative testing made optional'; Old='Tests MUST cover syntax, positive, negative, boundary, destructive-target, quoting, signal, cleanup, pipeline, command-failure, and failure-path behavior'; New='Tests MAY cover positive behavior' },
            @{ Name='functional execution boundary weakened'; Old='Functional validation MUST run only declared test entry points'; New='Functional validation MAY run arbitrary project entry points' },
            @{ Name='base inheritance removed'; Old='This standard inherits [AGENTS_Base.md](AGENTS_Base.md).'; New='This standard is independent of the base standard.' }
        ) {
            $script:tempRoot = New-AgentStandardsFixture
            $path = Join-Path $script:tempRoot 'agents/AGENTS_Bash.md'
            $text = (Get-Content -LiteralPath $path -Raw).Replace($Old, $New)
            Set-Content -LiteralPath $path -Value $text -Encoding utf8
            Invoke-AgentStandardsValidator -Path $script:tempRoot | Should -Not -Be 0
        }

        It 'fails self-inheritance in the base standard' {
            $script:tempRoot = New-AgentStandardsFixture
            Add-Content -LiteralPath (Join-Path $script:tempRoot 'agents/AGENTS_Base.md') -Value "`nThis file inherits AGENTS_Base.md."
            Invoke-AgentStandardsValidator -Path $script:tempRoot | Should -Not -Be 0
        }

        It 'fails a missing hierarchy' {
            $script:tempRoot = New-AgentStandardsFixture
            $path = Join-Path $script:tempRoot 'agents/AGENTS_Base.md'
            $text = (Get-Content -LiteralPath $path -Raw) -replace '(?i)Organization governance documents', 'Organization policy files'
            Set-Content -LiteralPath $path -Value $text -Encoding utf8
            Invoke-AgentStandardsValidator -Path $script:tempRoot | Should -Not -Be 0
        }

        It 'fails a missing work phase' {
            $script:tempRoot = New-AgentStandardsFixture
            $path = Join-Path $script:tempRoot 'agents/AGENTS_Base.md'
            $text = (Get-Content -LiteralPath $path -Raw).Replace('Phase 5 - Validation', 'Phase 5 - Checks')
            Set-Content -LiteralPath $path -Value $text -Encoding utf8
            Invoke-AgentStandardsValidator -Path $script:tempRoot | Should -Not -Be 0
        }

        It 'fails the wrong default branch' {
            $script:tempRoot = New-AgentStandardsFixture
            $path = Join-Path $script:tempRoot 'AGENTS.md'
            $text = (Get-Content -LiteralPath $path -Raw).Replace('`master`', '`main`')
            Set-Content -LiteralPath $path -Value $text -Encoding utf8
            Invoke-AgentStandardsValidator -Path $script:tempRoot | Should -Not -Be 0
        }

        It 'fails a missing base reference' {
            $script:tempRoot = New-AgentStandardsFixture
            $path = Join-Path $script:tempRoot 'AGENTS.md'
            $text = (Get-Content -LiteralPath $path -Raw).Replace('[agents/AGENTS_Base.md](agents/AGENTS_Base.md)', 'the central base standard')
            Set-Content -LiteralPath $path -Value $text -Encoding utf8
            Invoke-AgentStandardsValidator -Path $script:tempRoot | Should -Not -Be 0
        }

        It 'fails a missing completion status' {
            $script:tempRoot = New-AgentStandardsFixture
            $path = Join-Path $script:tempRoot 'agents/AGENTS_Base.md'
            $text = (Get-Content -LiteralPath $path -Raw).Replace('`Blocked`', '`Waiting`')
            Set-Content -LiteralPath $path -Value $text -Encoding utf8
            Invoke-AgentStandardsValidator -Path $script:tempRoot | Should -Not -Be 0
        }

        It 'fails placeholder text' {
            $script:tempRoot = New-AgentStandardsFixture
            Add-Content -LiteralPath (Join-Path $script:tempRoot 'AGENTS.md') -Value "`nTODO: fill this in."
            Invoke-AgentStandardsValidator -Path $script:tempRoot | Should -Not -Be 0
        }

        It 'fails a missing validation command' {
            $script:tempRoot = New-AgentStandardsFixture
            $path = Join-Path $script:tempRoot 'AGENTS.md'
            $text = (Get-Content -LiteralPath $path -Raw).Replace('git diff --check', 'git diff --stat')
            Set-Content -LiteralPath $path -Value $text -Encoding utf8
            Invoke-AgentStandardsValidator -Path $script:tempRoot | Should -Not -Be 0
        }

        It 'fails when the agent-standard validation command is missing' {
            $script:tempRoot = New-AgentStandardsFixture
            $path = Join-Path $script:tempRoot 'AGENTS.md'
            $text = (Get-Content -LiteralPath $path -Raw).Replace(
                'pwsh -NoProfile -File scripts/Test-AgentStandards.ps1 -Path .',
                'pwsh -NoProfile -File scripts/Test-AgentStandards.ps1 -Path agents'
            )
            Set-Content -LiteralPath $path -Value $text -Encoding utf8
            Invoke-AgentStandardsValidator -Path $script:tempRoot | Should -Not -Be 0
        }

        It 'fails when the repository-health owner type is omitted' {
            $script:tempRoot = New-AgentStandardsFixture
            $path = Join-Path $script:tempRoot 'AGENTS.md'
            $text = (Get-Content -LiteralPath $path -Raw).Replace(' -RepositoryOwnerType User', '')
            Set-Content -LiteralPath $path -Value $text -Encoding utf8
            Invoke-AgentStandardsValidator -Path $script:tempRoot | Should -Not -Be 0
        }

        It 'fails an incorrectly cased repository-health owner type' {
            $script:tempRoot = New-AgentStandardsFixture
            $path = Join-Path $script:tempRoot 'AGENTS.md'
            $text = (Get-Content -LiteralPath $path -Raw).Replace('-RepositoryOwnerType User', '-RepositoryOwnerType user')
            Set-Content -LiteralPath $path -Value $text -Encoding utf8
            Invoke-AgentStandardsValidator -Path $script:tempRoot | Should -Not -Be 0
        }

        It 'fails an invalid repository-health owner type' -ForEach @('Unknown', 'Organization') {
            $script:tempRoot = New-AgentStandardsFixture
            $path = Join-Path $script:tempRoot 'AGENTS.md'
            $text = (Get-Content -LiteralPath $path -Raw).Replace('-RepositoryOwnerType User', "-RepositoryOwnerType $_")
            Set-Content -LiteralPath $path -Value $text -Encoding utf8
            Invoke-AgentStandardsValidator -Path $script:tempRoot | Should -Not -Be 0
        }

        It 'fails duplicate or conflicting repository-health owner type arguments' -ForEach @('User', 'Organization') {
            $script:tempRoot = New-AgentStandardsFixture
            $path = Join-Path $script:tempRoot 'AGENTS.md'
            $text = (Get-Content -LiteralPath $path -Raw).Replace('-RepositoryOwnerType User', "-RepositoryOwnerType User -RepositoryOwnerType $_")
            Set-Content -LiteralPath $path -Value $text -Encoding utf8
            Invoke-AgentStandardsValidator -Path $script:tempRoot | Should -Not -Be 0
        }

        It 'does not accept the command only in an unrelated section' {
            $script:tempRoot = New-AgentStandardsFixture
            $path = Join-Path $script:tempRoot 'AGENTS.md'
            $command = 'pwsh -NoProfile -File actions/repository-health/Invoke-RepositoryHealth.ps1 -Path . -RepositoryOwnerType User'
            $text = (Get-Content -LiteralPath $path -Raw).Replace($command, 'pwsh -NoProfile -File actions/repository-health/Invoke-RepositoryHealth.ps1 -Path .')
            $text += "`n## Historical Note`n`n``````powershell`n$command`n```````n"
            Set-Content -LiteralPath $path -Value $text -Encoding utf8
            Invoke-AgentStandardsValidator -Path $script:tempRoot | Should -Not -Be 0
        }

        It 'fails an unsafe PowerShell path-boundary example' {
            $script:tempRoot = New-AgentStandardsFixture
            $path = Join-Path $script:tempRoot 'agents/AGENTS_PowerShell.md'
            $text = (Get-Content -LiteralPath $path -Raw).
                Replace('$candidate.StartsWith($rootBoundary, [System.StringComparison]::OrdinalIgnoreCase)', '$candidate.StartsWith($resolvedRoot, [System.StringComparison]::OrdinalIgnoreCase)').
                Replace('Prefix matching without a directory boundary is unsafe', 'Prefix matching is usually fine')
            Set-Content -LiteralPath $path -Value $text -Encoding utf8
            Invoke-AgentStandardsValidator -Path $script:tempRoot | Should -Not -Be 0
        }

        It 'fails missing PowerShell README parameter documentation requirements' {
            $script:tempRoot = New-AgentStandardsFixture
            $path = Join-Path $script:tempRoot 'agents/AGENTS_PowerShell.md'
            $text = (Get-Content -LiteralPath $path -Raw).Replace(
                'README documentation MUST include every public entry-point parameter and switch',
                'README documentation SHOULD describe common parameters'
            )
            Set-Content -LiteralPath $path -Value $text -Encoding utf8
            Invoke-AgentStandardsValidator -Path $script:tempRoot | Should -Not -Be 0
        }

        It 'fails a PowerShell signing example that silently selects the first certificate' {
            $script:tempRoot = New-AgentStandardsFixture
            $path = Join-Path $script:tempRoot 'agents/AGENTS_PowerShell.md'
            $text = (Get-Content -LiteralPath $path -Raw).
                Replace('$certificates.Count -gt 1', '$certificates.Count -lt 0').
                Replace('$certificate = $certificates[0]', '$certificate = $certificates | Select-Object -First 1')
            Set-Content -LiteralPath $path -Value $text -Encoding utf8
            Invoke-AgentStandardsValidator -Path $script:tempRoot | Should -Not -Be 0
        }

        It 'fails missing .NET runtime and SDK policy requirements' {
            $script:tempRoot = New-AgentStandardsFixture
            $path = Join-Path $script:tempRoot 'agents/AGENTS_DotNet.md'
            $text = (Get-Content -LiteralPath $path -Raw).
                Replace('Target framework monikers', 'Framework names').
                Replace('rollForward', 'roll ahead').
                Replace('global.json', 'SDK selection file')
            Set-Content -LiteralPath $path -Value $text -Encoding utf8
            Invoke-AgentStandardsValidator -Path $script:tempRoot | Should -Not -Be 0
        }

        It 'fails a .NET standard version below the corrected minimum' {
            $script:tempRoot = New-AgentStandardsFixture
            $path = Join-Path $script:tempRoot 'agents/AGENTS_DotNet.md'
            $text = (Get-Content -LiteralPath $path -Raw).Replace('| Version | 1.1.1 |', '| Version | 1.1.0 |')
            Set-Content -LiteralPath $path -Value $text -Encoding utf8
            Invoke-AgentStandardsValidator -Path $script:tempRoot | Should -Not -Be 0
        }

        It 'fails a malformed .NET standard semantic version' {
            $script:tempRoot = New-AgentStandardsFixture
            $path = Join-Path $script:tempRoot 'agents/AGENTS_DotNet.md'
            $text = (Get-Content -LiteralPath $path -Raw).Replace('| Version | 1.1.1 |', '| Version | next |')
            Set-Content -LiteralPath $path -Value $text -Encoding utf8
            Invoke-AgentStandardsValidator -Path $script:tempRoot | Should -Not -Be 0
        }

        It 'fails when .NET deny-by-default authorization is weakened to SHOULD' {
            $script:tempRoot = New-AgentStandardsFixture
            $path = Join-Path $script:tempRoot 'agents/AGENTS_DotNet.md'
            $text = (Get-Content -LiteralPath $path -Raw).Replace('Protected resources MUST be deny-by-default', 'Protected resources SHOULD be deny-by-default')
            Set-Content -LiteralPath $path -Value $text -Encoding utf8
            Invoke-AgentStandardsValidator -Path $script:tempRoot | Should -Not -Be 0
        }

        It 'fails missing .NET foundational modern coding requirements' {
            $script:tempRoot = New-AgentStandardsFixture
            $path = Join-Path $script:tempRoot 'agents/AGENTS_DotNet.md'
            $text = (Get-Content -LiteralPath $path -Raw).
                Replace('New or materially changed configuration contracts MUST use strongly typed options', 'New or materially changed configuration contracts SHOULD use strongly typed options').
                Replace('Managed outbound HTTP clients MUST use `IHttpClientFactory`', 'Managed outbound HTTP clients SHOULD use `IHttpClientFactory`').
                Replace('New .NET projects MUST enable nullable reference types unless a documented compatibility constraint exists', 'New .NET projects SHOULD enable nullable reference types')
            Set-Content -LiteralPath $path -Value $text -Encoding utf8
            Invoke-AgentStandardsValidator -Path $script:tempRoot | Should -Not -Be 0
        }

        It 'fails missing .NET JWT negative-test requirements' {
            $script:tempRoot = New-AgentStandardsFixture
            $path = Join-Path $script:tempRoot 'agents/AGENTS_DotNet.md'
            $text = (Get-Content -LiteralPath $path -Raw).Replace(
                'invalid signature, issuer, audience, expiration',
                'invalid token inputs'
            )
            Set-Content -LiteralPath $path -Value $text -Encoding utf8
            Invoke-AgentStandardsValidator -Path $script:tempRoot | Should -Not -Be 0
        }

        It 'fails missing .NET outbound request and SSRF controls' {
            $script:tempRoot = New-AgentStandardsFixture
            $path = Join-Path $script:tempRoot 'agents/AGENTS_DotNet.md'
            $text = (Get-Content -LiteralPath $path -Raw).
                Replace('## Outbound Request And SSRF Safety', '## Outbound Request Safety').
                Replace('cloud metadata', 'cloud service').
                Replace('validate every redirect target', 'validate redirects')
            Set-Content -LiteralPath $path -Value $text -Encoding utf8
            Invoke-AgentStandardsValidator -Path $script:tempRoot | Should -Not -Be 0
        }

        It 'fails missing .NET deserialization safety controls' {
            $script:tempRoot = New-AgentStandardsFixture
            $path = Join-Path $script:tempRoot 'agents/AGENTS_DotNet.md'
            $text = (Get-Content -LiteralPath $path -Raw).
                Replace('## Serialization And Deserialization Safety', '## Serialization Safety').
                Replace('BinaryFormatter', 'legacy binary serializer').
                Replace('XML parsers MUST disable external entity resolution', 'XML parsers should be configured safely')
            Set-Content -LiteralPath $path -Value $text -Encoding utf8
            Invoke-AgentStandardsValidator -Path $script:tempRoot | Should -Not -Be 0
        }

        It 'fails missing .NET native process execution controls' {
            $script:tempRoot = New-AgentStandardsFixture
            $path = Join-Path $script:tempRoot 'agents/AGENTS_DotNet.md'
            $text = (Get-Content -LiteralPath $path -Raw).
                Replace('## Native Process And Command Execution', '## Process Execution').
                Replace('ProcessStartInfo.ArgumentList', 'process arguments').
                Replace('secrets MUST NOT be passed in visible command-line arguments', 'secrets should not be passed in visible arguments')
            Set-Content -LiteralPath $path -Value $text -Encoding utf8
            Invoke-AgentStandardsValidator -Path $script:tempRoot | Should -Not -Be 0
        }

        It 'fails .NET weakening language for unsafe security exceptions' {
            $script:tempRoot = New-AgentStandardsFixture
            Add-Content -LiteralPath (Join-Path $script:tempRoot 'agents/AGENTS_DotNet.md') -Value "`nBinaryFormatter is allowed for untrusted input."
            Invoke-AgentStandardsValidator -Path $script:tempRoot | Should -Not -Be 0
        }

        It 'fails missing .NET deployment and evidence honesty requirements' {
            $script:tempRoot = New-AgentStandardsFixture
            $path = Join-Path $script:tempRoot 'agents/AGENTS_DotNet.md'
            $text = (Get-Content -LiteralPath $path -Raw).
                Replace('IIS-hosted', 'server-hosted').
                Replace('dotnet --info', 'SDK details command').
                Replace('Permitted statuses are `Passed`, `Failed`, `Blocked`, `NotRun`, and `NotApplicable`', 'Use repository evidence statuses')
            Set-Content -LiteralPath $path -Value $text -Encoding utf8
            Invoke-AgentStandardsValidator -Path $script:tempRoot | Should -Not -Be 0
        }

        It 'fails a Web Frontend standard version below the required minimum' {
            $script:tempRoot = New-AgentStandardsFixture
            $path = Join-Path $script:tempRoot 'agents/AGENTS_WebFrontend.md'
            $text = (Get-Content -LiteralPath $path -Raw).Replace('| Version | 1.1.1 |', '| Version | 1.1.0 |')
            Set-Content -LiteralPath $path -Value $text -Encoding utf8
            Invoke-AgentStandardsValidator -Path $script:tempRoot | Should -Not -Be 0
        }

        It 'fails a malformed Web Frontend semantic version' {
            $script:tempRoot = New-AgentStandardsFixture
            $path = Join-Path $script:tempRoot 'agents/AGENTS_WebFrontend.md'
            $text = (Get-Content -LiteralPath $path -Raw).Replace('| Version | 1.1.1 |', '| Version | current |')
            Set-Content -LiteralPath $path -Value $text -Encoding utf8
            Invoke-AgentStandardsValidator -Path $script:tempRoot | Should -Not -Be 0
        }

        It 'fails missing Web Frontend cross-standard handoffs' {
            $script:tempRoot = New-AgentStandardsFixture
            $path = Join-Path $script:tempRoot 'agents/AGENTS_WebFrontend.md'
            $text = (Get-Content -LiteralPath $path -Raw).
                Replace('ASP.NET Core hosting, authentication, authorization, cookies, antiforgery, APIs, Data Protection, Identity, JWT validation, IIS, server configuration, and backend security MUST also apply [AGENTS_DotNet.md](AGENTS_DotNet.md)', 'Backend hosting should be reviewed separately').
                Replace('REST, GraphQL, gRPC-web, WebSocket, SignalR, webhook-related UI, vendor API behavior, retry, rate limiting, and external service contracts MUST also apply [AGENTS_Integration.md](AGENTS_Integration.md)', 'API behavior should be reviewed separately').
                Replace('CDN, reverse proxy, load balancer, TLS termination, DNS, CSP headers, HSTS, hosting, static asset delivery, cache headers, containers, Kubernetes, and infrastructure deployment MUST also apply [AGENTS_Infrastructure.md](AGENTS_Infrastructure.md)', 'Hosting should be reviewed separately').
                Replace('Job submission, job status, script catalog, cancellation, replay, report links, worker state, and background-processing UI MUST also apply [AGENTS_WorkerService.md](AGENTS_WorkerService.md)', 'Background-processing UI should be reviewed separately').
                Replace('Database details MUST NOT be exposed directly to the browser', 'Database details should not usually appear in the browser').
                Replace('PowerShell-generated frontend assets, deployment scripts, packaging, IIS automation, and test orchestration MUST also apply [AGENTS_PowerShell.md](AGENTS_PowerShell.md)', 'PowerShell-generated assets should be reviewed separately')
            Set-Content -LiteralPath $path -Value $text -Encoding utf8
            Invoke-AgentStandardsValidator -Path $script:tempRoot | Should -Not -Be 0
        }

        It 'fails missing Web Frontend required discovery and rendering controls' {
            $script:tempRoot = New-AgentStandardsFixture
            $path = Join-Path $script:tempRoot 'agents/AGENTS_WebFrontend.md'
            $text = (Get-Content -LiteralPath $path -Raw).
                Replace('Before editing frontend code, agents MUST identify and record the relevant subset of runtime and exact version', 'Before editing frontend code, agents should identify useful context').
                Replace('Rendering model discovery MUST explicitly identify CSR, SSR, SSG, ISR, hybrid, MPA, or PWA behavior', 'Rendering model discovery should identify the application type').
                Replace('Browser code is untrusted from the server''s perspective', 'Browser code should be treated carefully')
            Set-Content -LiteralPath $path -Value $text -Encoding utf8
            Invoke-AgentStandardsValidator -Path $script:tempRoot | Should -Not -Be 0
        }

        It 'fails missing Web Frontend lockfile and reproducibility controls' {
            $script:tempRoot = New-AgentStandardsFixture
            $path = Join-Path $script:tempRoot 'agents/AGENTS_WebFrontend.md'
            $text = (Get-Content -LiteralPath $path -Raw).
                Replace('Every frontend repository MUST define one approved package manager', 'Every frontend repository should define a package manager').
                Replace('frozen or immutable lockfile install in CI', 'lockfile install in CI').
                Replace('No mixed lockfiles are allowed', 'Mixed lockfiles should be avoided').
                Replace('No production build may use an unlocked dependency graph', 'Production builds should avoid unlocked dependencies')
            Set-Content -LiteralPath $path -Value $text -Encoding utf8
            Invoke-AgentStandardsValidator -Path $script:tempRoot | Should -Not -Be 0
        }

        It 'fails missing Web Frontend dependency and supply-chain controls' {
            $script:tempRoot = New-AgentStandardsFixture
            $path = Join-Path $script:tempRoot 'agents/AGENTS_WebFrontend.md'
            $text = (Get-Content -LiteralPath $path -Raw).
                Replace('New or changed dependencies MUST be reviewed for package source, publisher, maintainer health, license, vulnerability status', 'New dependencies should be reviewed').
                Replace('`npm audit fix --force` or equivalent MUST NOT be run automatically', 'npm audit force fixes can be automated')
            Set-Content -LiteralPath $path -Value $text -Encoding utf8
            Invoke-AgentStandardsValidator -Path $script:tempRoot | Should -Not -Be 0
        }

        It 'fails missing Web Frontend environment-variable and secret controls' {
            $script:tempRoot = New-AgentStandardsFixture
            $path = Join-Path $script:tempRoot 'agents/AGENTS_WebFrontend.md'
            $text = (Get-Content -LiteralPath $path -Raw).
                Replace('Every value embedded in a browser bundle MUST be treated as public', 'Browser bundle values should be reviewed').
                Replace('Prefixes such as `NEXT_PUBLIC_`, `VITE_`, or framework equivalents do not make values secret', 'Public prefixes can identify public configuration').
                Replace('Browser code MUST NOT contain private keys, database credentials, client secrets, server API keys, signing keys, privileged tokens', 'Browser code should not contain secrets')
            Set-Content -LiteralPath $path -Value $text -Encoding utf8
            Invoke-AgentStandardsValidator -Path $script:tempRoot | Should -Not -Be 0
        }

        It 'fails missing Web Frontend server-side auth and authz requirements' {
            $script:tempRoot = New-AgentStandardsFixture
            $path = Join-Path $script:tempRoot 'agents/AGENTS_WebFrontend.md'
            $text = (Get-Content -LiteralPath $path -Raw).
                Replace('Authentication MUST be enforced server-side', 'Authentication should be enforced server-side').
                Replace('Frontend route guards are UX controls only', 'Frontend route guards protect routes').
                Replace('Hiding a button is not authorization', 'Hidden buttons can enforce authorization').
                Replace('Disabling a control is not authorization', 'Disabled controls can enforce authorization').
                Replace('Admin routes MUST be server-protected and direct navigation to admin routes MUST receive server denial when unauthorized', 'Admin routes should be protected')
            Set-Content -LiteralPath $path -Value $text -Encoding utf8
            Invoke-AgentStandardsValidator -Path $script:tempRoot | Should -Not -Be 0
        }

        It 'fails missing Web Frontend token and storage controls' {
            $script:tempRoot = New-AgentStandardsFixture
            $path = Join-Path $script:tempRoot 'agents/AGENTS_WebFrontend.md'
            $text = (Get-Content -LiteralPath $path -Raw).
                Replace('Sensitive session tokens SHOULD use Secure, HttpOnly cookies where architecture supports it', 'Sensitive session tokens can use cookies').
                Replace('Privileged or long-lived tokens MUST NOT be stored in localStorage or sessionStorage unless an approved threat model and exception require it', 'Privileged tokens may be stored in browser storage').
                Replace('Tenant-safe cache keys are mandatory', 'Cache keys should be scoped').
                Replace('Logout MUST clear protected caches', 'Logout should clear protected caches')
            Set-Content -LiteralPath $path -Value $text -Encoding utf8
            Invoke-AgentStandardsValidator -Path $script:tempRoot | Should -Not -Be 0
        }

        It 'fails missing Web Frontend XSS, DOM, and URL controls' {
            $script:tempRoot = New-AgentStandardsFixture
            $path = Join-Path $script:tempRoot 'agents/AGENTS_WebFrontend.md'
            $text = (Get-Content -LiteralPath $path -Raw).
                Replace('Untrusted HTML MUST NOT be inserted directly', 'Untrusted HTML should be sanitized').
                Replace('dangerouslySetInnerHTML`, Angular sanitizer bypasses, direct `innerHTML`, `outerHTML`, `insertAdjacentHTML`, document writes, unsafe template compilation, unsafe markdown rendering, DOM clobbering, and script URL injection require security review and tests', 'dangerous HTML APIs should be reviewed').
                Replace('URL construction MUST use safe parsers and protocol allowlists', 'URL construction should be safe').
                Replace('Open redirects are prohibited unless targets are allowlisted and validated', 'Open redirects should be avoided')
            Set-Content -LiteralPath $path -Value $text -Encoding utf8
            Invoke-AgentStandardsValidator -Path $script:tempRoot | Should -Not -Be 0
        }

        It 'fails missing Web Frontend Trusted Types, CSP, CSRF, and CORS controls' {
            $script:tempRoot = New-AgentStandardsFixture
            $path = Join-Path $script:tempRoot 'agents/AGENTS_WebFrontend.md'
            $text = (Get-Content -LiteralPath $path -Raw).
                Replace('Trusted Types SHOULD be used for applications with material DOM injection risk', 'Trusted Types can be considered').
                Replace('CSP MUST be governed as a security control', 'CSP should be governed').
                Replace('CSP MUST NOT be disabled for convenience', 'CSP should not be disabled').
                Replace('Cookie-authenticated state-changing requests MUST have CSRF protection enforced by the server', 'Cookie-authenticated requests should consider CSRF').
                Replace('CORS MUST NOT be treated as authorization', 'CORS should not be treated as authorization')
            Set-Content -LiteralPath $path -Value $text -Encoding utf8
            Invoke-AgentStandardsValidator -Path $script:tempRoot | Should -Not -Be 0
        }

        It 'fails missing Web Frontend redirect, opener, form, upload, and download controls' {
            $script:tempRoot = New-AgentStandardsFixture
            $path = Join-Path $script:tempRoot 'agents/AGENTS_WebFrontend.md'
            $text = (Get-Content -LiteralPath $path -Raw).
                Replace('target="_blank"` MUST use safe opener protection', 'target blank links should use opener protection').
                Replace('Forms MUST be accessible, labeled, keyboard operable, error-associated', 'Forms should be accessible').
                Replace('Empty scope, empty target, empty filter, or missing file input MUST NOT mean all targets', 'Empty input should not usually mean all targets').
                Replace('Browser file validation is insufficient by itself', 'Browser file validation can be enough').
                Replace('Protected downloads and report links MUST require server-side access-time authorization', 'Protected downloads should be authorized')
            Set-Content -LiteralPath $path -Value $text -Encoding utf8
            Invoke-AgentStandardsValidator -Path $script:tempRoot | Should -Not -Be 0
        }

        It 'fails missing Web Frontend API, cache, route, and service-worker controls' {
            $script:tempRoot = New-AgentStandardsFixture
            $path = Join-Path $script:tempRoot 'agents/AGENTS_WebFrontend.md'
            $text = (Get-Content -LiteralPath $path -Raw).
                Replace('API clients MUST define API origin, contract source, generated-client ownership, schema version, timeout, cancellation, retry', 'API clients should define request behavior').
                Replace('Service workers MUST NOT cache protected API data by default', 'Service workers may cache protected API data').
                Replace('Critical journeys require direct-navigation and refresh tests', 'Critical journeys should have browser tests')
            Set-Content -LiteralPath $path -Value $text -Encoding utf8
            Invoke-AgentStandardsValidator -Path $script:tempRoot | Should -Not -Be 0
        }

        It 'fails missing Web Frontend third-party privacy and SRI controls' {
            $script:tempRoot = New-AgentStandardsFixture
            $path = Join-Path $script:tempRoot 'agents/AGENTS_WebFrontend.md'
            $text = (Get-Content -LiteralPath $path -Raw).
                Replace('Third-party scripts need privacy review before use', 'Third-party scripts should be reviewed').
                Replace('External assets for protected production paths MUST use pinned versions and Subresource Integrity where supported', 'External assets should use integrity where practical')
            Set-Content -LiteralPath $path -Value $text -Encoding utf8
            Invoke-AgentStandardsValidator -Path $script:tempRoot | Should -Not -Be 0
        }

        It 'fails missing Web Frontend accessibility, performance, reliability, telemetry, and source-map controls' {
            $script:tempRoot = New-AgentStandardsFixture
            $path = Join-Path $script:tempRoot 'agents/AGENTS_WebFrontend.md'
            $text = (Get-Content -LiteralPath $path -Raw).
                Replace('Frontend work MUST target WCAG 2.2 AA', 'Frontend work should target accessibility').
                Replace('keyboard navigation, visible focus, logical focus order', 'keyboard behavior').
                Replace('performance budgets for bundle size, route chunks, image size, font loading, hydration', 'performance budgets').
                Replace('User workflows MUST define loading, empty, error, partial success, retry, cancellation', 'User workflows should define states').
                Replace('Client telemetry MUST define events, owner, purpose, sampling, consent, redaction', 'Client telemetry should define events').
                Replace('Production source maps MUST NOT be public without review and approval', 'Production source maps may be public')
            Set-Content -LiteralPath $path -Value $text -Encoding utf8
            Invoke-AgentStandardsValidator -Path $script:tempRoot | Should -Not -Be 0
        }

        It 'fails missing Web Frontend validation, browser/E2E, and evidence honesty controls' {
            $script:tempRoot = New-AgentStandardsFixture
            $path = Join-Path $script:tempRoot 'agents/AGENTS_WebFrontend.md'
            $text = (Get-Content -LiteralPath $path -Raw).
                Replace('Browser automation MUST define approved tool such as Playwright, Selenium, Cypress, WebdriverIO', 'Browser automation should define a tool').
                Replace('Validation Commands', 'Validation Guidance').
                Replace('npm ci', 'npm install').
                Replace('pnpm install --frozen-lockfile', 'pnpm install').
                Replace('yarn install --immutable', 'yarn install').
                Replace('Build success does not prove browser behavior', 'Build success proves browser behavior').
                Replace('Permitted statuses are `Passed`, `Failed`, `Blocked`, `NotRun`, and `NotApplicable`', 'Use completion statuses').
                Replace('Unexecuted browser, accessibility, performance, security-policy, deployment, or production validation MUST NOT be labeled `Passed`', 'Unexecuted frontend validation should be documented')
            Set-Content -LiteralPath $path -Value $text -Encoding utf8
            Invoke-AgentStandardsValidator -Path $script:tempRoot | Should -Not -Be 0
        }

        It 'fails unsafe Web Frontend weakening phrases' {
            $script:tempRoot = New-AgentStandardsFixture
            Add-Content -LiteralPath (Join-Path $script:tempRoot 'agents/AGENTS_WebFrontend.md') -Value @'

Browser code may contain server secrets.
Client-side route guards are sufficient authorization.
Hidden buttons enforce authorization.
Privileged tokens should be stored in localStorage.
Untrusted HTML may be inserted directly.
dangerouslySetInnerHTML requires no review.
javascript URLs are acceptable.
CSP may be disabled for convenience.
Cookie-authenticated POST requests need no CSRF protection.
CORS proves authorization.
Open redirects are acceptable.
target blank needs no opener protection.
Empty input means all targets.
Browser file validation is sufficient.
Public report URLs are acceptable for protected data.
Cache keys need no tenant scope.
Logout does not need to clear caches.
Service workers may cache protected API data by default.
Third-party scripts need no privacy review.
Accessibility is optional.
Build success proves browser behavior.
Production source maps should always be public.
Production may be used when test environments are unavailable.
npm audit fix force may be run automatically.
Missing frontend validation may be marked Passed.
Browser OAuth clients may use implicit flow.
PKCE is optional for public browser clients.
OAuth state or OIDC nonce needs no validation.
Wildcard redirect URIs are acceptable.
Tokens may appear in URLs.
Refresh-token reuse may be ignored.
Static CSP nonces are acceptable.
CSP report-only may remain permanent.
GET requests may change state.
CSRF failures may be retried automatically.
Login/logout CSRF does not matter.
Dynamic CORS origins may be reflected blindly.
Development origins may remain in production.
WebSocket origins need no validation.
Public CORS proxies are acceptable.
User filenames may be server paths.
HTML/SVG downloads are always passive.
Spreadsheet formula injection does not matter.
Content type may be inferred only from extension.
HTTP 200 always means business success.
Unknown enums may map to administrator.
Schema mismatches may be ignored.
Non-idempotent requests may be retried blindly.
Polling may run without delay.
Cancellation/completion may display before server confirmation.
Stale poll responses may overwrite current state.
Service workers may use broad scope by default or bypass CSP.
Opaque responses may always be cached.
Cache poisoning needs no review.
Telemetry failures may break the UI.
Production console logs may contain tokens.
Production debug logging may remain enabled.
Source maps need not match the deployed release or be secret-scanned.
Missing Web Frontend 1.1.1 validation may be marked Passed.
'@
            Invoke-AgentStandardsValidator -Path $script:tempRoot | Should -Not -Be 0
        }

        It 'fails missing Web Frontend OAuth PKCE, state, nonce, and redirect controls' {
            $script:tempRoot = New-AgentStandardsFixture
            $path = Join-Path $script:tempRoot 'agents/AGENTS_WebFrontend.md'
            $text = (Get-Content -LiteralPath $path -Raw).
                Replace('Every OAuth/OIDC browser flow MUST define identity provider and client type', 'OAuth browser flows should define identity provider details').
                Replace('Public browser clients MUST use Authorization Code flow with PKCE', 'Public browser clients should use PKCE where convenient').
                Replace('Implicit flow MUST NOT be used for new browser applications', 'Implicit flow should be avoided for new browser applications').
                Replace('OAuth state MUST be high entropy, transaction-bound, validated on return, and consumed once', 'OAuth state should be validated').
                Replace('OIDC nonce MUST be generated, transaction-bound, validated, and consumed once', 'OIDC nonce should be validated').
                Replace('Redirect URIs MUST be exact, allowlisted, environment-specific, and registered', 'Redirect URIs should be allowlisted').
                Replace('Tokens MUST NOT appear in query strings, fragments, browser history, referrers, analytics, or logs', 'Tokens should not appear in URLs').
                Replace('Refresh tokens require provider support, rotation, reuse detection where available, bounded lifetime, revocation, and approved storage', 'Refresh tokens should rotate').
                Replace('Session fixation MUST be prevented by rotating or replacing session state at login and privilege elevation', 'Session fixation should be prevented').
                Replace('Account or tenant switching MUST clear prior identity, cache, and authorization state', 'Account switching should clear state')
            Set-Content -LiteralPath $path -Value $text -Encoding utf8
            Invoke-AgentStandardsValidator -Path $script:tempRoot | Should -Not -Be 0
        }

        It 'fails missing Web Frontend CSP directive and nonce lifecycle controls' {
            $script:tempRoot = New-AgentStandardsFixture
            $path = Join-Path $script:tempRoot 'agents/AGENTS_WebFrontend.md'
            $text = (Get-Content -LiteralPath $path -Raw).
                Replace('Every CSP MUST define, where applicable, delivery mechanism, `default-src`, `script-src`, `script-src-elem`, `script-src-attr`', 'CSP should define directives').
                Replace('`default-src` MUST be explicit for protected applications', 'default-src should be explicit').
                Replace('`object-src ''none''` SHOULD be used unless a reviewed requirement exists', 'object-src should be reviewed').
                Replace('`base-uri` MUST restrict base URL manipulation', 'base-uri should be restricted').
                Replace('`form-action` MUST restrict submission destinations', 'form-action should be restricted').
                Replace('`frame-ancestors` MUST define clickjacking protection', 'frame-ancestors should be defined').
                Replace('`connect-src` MUST explicitly cover approved API, WebSocket, telemetry, and worker destinations', 'connect-src should cover destinations').
                Replace('Nonces MUST be unpredictable and request-scoped', 'Nonces should be unique').
                Replace('Static or reusable nonces are prohibited', 'Static nonces should be avoided').
                Replace('Report-only mode MUST have an owner, review period, remediation process, and enforcement target date', 'Report-only mode should have an owner')
            Set-Content -LiteralPath $path -Value $text -Encoding utf8
            Invoke-AgentStandardsValidator -Path $script:tempRoot | Should -Not -Be 0
        }

        It 'fails missing Web Frontend CSRF lifecycle and no-retry controls' {
            $script:tempRoot = New-AgentStandardsFixture
            $path = Join-Path $script:tempRoot 'agents/AGENTS_WebFrontend.md'
            $text = (Get-Content -LiteralPath $path -Raw).
                Replace('GET, HEAD, OPTIONS, and other safe methods MUST NOT perform state-changing business actions', 'Safe methods should avoid state changes').
                Replace('Login endpoints MUST address login CSRF and account-confusion risks', 'Login endpoints should consider CSRF').
                Replace('Logout endpoints MUST address logout CSRF according to the threat model', 'Logout endpoints should consider CSRF').
                Replace('Failed CSRF validation MUST fail closed', 'Failed CSRF validation should fail safely').
                Replace('Failed CSRF validation MUST NOT automatically retry the mutation', 'Failed CSRF validation may retry').
                Replace('Retry loops after antiforgery-related 400, 401, or 403 responses are prohibited', 'Antiforgery retry loops should be limited')
            Set-Content -LiteralPath $path -Value $text -Encoding utf8
            Invoke-AgentStandardsValidator -Path $script:tempRoot | Should -Not -Be 0
        }

        It 'fails missing Web Frontend strict CORS and WebSocket controls' {
            $script:tempRoot = New-AgentStandardsFixture
            $path = Join-Path $script:tempRoot 'agents/AGENTS_WebFrontend.md'
            $text = (Get-Content -LiteralPath $path -Raw).
                Replace('Dynamic origin reflection MUST use a strict allowlist', 'Dynamic origin reflection should use a list').
                Replace('Blind Origin reflection is prohibited', 'Blind Origin reflection should be avoided').
                Replace('Suffix matching without a hostname boundary is prohibited', 'Suffix matching should be careful').
                Replace('Production allowlists MUST NOT silently include localhost, loopback, development domains, wildcard ports, preview domains, or test origins', 'Production allowlists should avoid development origins').
                Replace('WebSocket and SignalR endpoints MUST validate Origin', 'WebSocket endpoints should validate Origin').
                Replace('Unsafe public CORS proxies or ad hoc relay services are prohibited', 'Public CORS proxies should be avoided').
                Replace('Credential mode MUST match the approved server contract', 'Credential mode should match the server')
            Set-Content -LiteralPath $path -Value $text -Encoding utf8
            Invoke-AgentStandardsValidator -Path $script:tempRoot | Should -Not -Be 0
        }

        It 'fails missing Web Frontend active-content and integrity upload/download controls' {
            $script:tempRoot = New-AgentStandardsFixture
            $path = Join-Path $script:tempRoot 'agents/AGENTS_WebFrontend.md'
            $text = (Get-Content -LiteralPath $path -Raw).
                Replace('User filenames MUST NOT become server filesystem paths', 'User filenames should not become paths').
                Replace('Uploaded HTML or SVG MUST NOT render inline in a privileged application origin', 'Uploaded HTML or SVG should be isolated').
                Replace('CSV exports MUST address spreadsheet formula injection', 'CSV exports should address spreadsheet safety').
                Replace('Downloads MUST define server-authoritative Content-Type, Content-Disposition, safe filename, `X-Content-Type-Options: nosniff`', 'Downloads should define content metadata').
                Replace('Safety MUST NOT be inferred from extension alone', 'Extensions help infer safety').
                Replace('Hash mismatch MUST fail closed where hashes are provided', 'Hash mismatch should be reviewed').
                Replace('Expired, revoked, wrong-tenant, wrong-attempt, wrong-version, or mismatched artifacts MUST fail safely', 'Invalid artifacts should fail safely')
            Set-Content -LiteralPath $path -Value $text -Encoding utf8
            Invoke-AgentStandardsValidator -Path $script:tempRoot | Should -Not -Be 0
        }

        It 'fails missing Web Frontend API outcome, schema, and idempotency controls' {
            $script:tempRoot = New-AgentStandardsFixture
            $path = Join-Path $script:tempRoot 'agents/AGENTS_WebFrontend.md'
            $text = (Get-Content -LiteralPath $path -Raw).
                Replace('API contracts MUST define HTTP status and business outcome', 'API contracts should define outcomes').
                Replace('HTTP 2xx MUST NOT automatically mean full business success', 'HTTP 2xx means success').
                Replace('Partial success MUST remain explicit', 'Partial success should be visible').
                Replace('Unknown enums MUST fail safely and MUST NOT map to privileged defaults', 'Unknown enums may use defaults').
                Replace('Missing required fields and schema-version mismatches MUST fail safely', 'Schema mismatches should be handled').
                Replace('Nullability mismatches MUST NOT be silently coerced when meaning changes', 'Nullability can be coerced').
                Replace('Date/time formats MUST be explicit and unambiguous', 'Date formats should be clear').
                Replace('Pagination MUST define maximum size, stable ordering, continuation behavior', 'Pagination should define size').
                Replace('Continuation tokens are opaque', 'Continuation tokens may be parsed').
                Replace('Idempotency keys MUST be unique, scoped, retained, and interpreted according to the server contract', 'Idempotency keys should be unique').
                Replace('Blind retry of non-idempotent requests is prohibited', 'Non-idempotent retries should be careful')
            Set-Content -LiteralPath $path -Value $text -Encoding utf8
            Invoke-AgentStandardsValidator -Path $script:tempRoot | Should -Not -Be 0
        }

        It 'fails missing Web Frontend bounded polling and server-confirmed terminal-state controls' {
            $script:tempRoot = New-AgentStandardsFixture
            $path = Join-Path $script:tempRoot 'agents/AGENTS_WebFrontend.md'
            $text = (Get-Content -LiteralPath $path -Raw).
                Replace('Job polling MUST define initial, normal, and maximum intervals, backoff and jitter', 'Job polling should define intervals').
                Replace('Poll intervals MUST be bounded', 'Poll intervals should be bounded').
                Replace('Tight or zero-delay loops are prohibited', 'Tight loops should be avoided').
                Replace('Polling MUST stop on terminal states', 'Polling should stop on terminal states').
                Replace('Polling MUST cancel on navigation, logout, account switch, component disposal, or lost authorization', 'Polling should cancel on lifecycle changes').
                Replace('Visibility changes MUST NOT create duplicate loops', 'Visibility changes should avoid duplicate loops').
                Replace('A cancellation request MUST NOT be displayed as completed until the server confirms terminal cancellation', 'Cancellation can display after request').
                Replace('A job MUST NOT be shown completed until the server reports terminal completion', 'Jobs can display complete optimistically').
                Replace('Stale responses from prior attempts MUST NOT overwrite current state', 'Stale responses should not overwrite state').
                Replace('Out-of-order responses MUST NOT regress terminal state', 'Out-of-order responses should be handled')
            Set-Content -LiteralPath $path -Value $text -Encoding utf8
            Invoke-AgentStandardsValidator -Path $script:tempRoot | Should -Not -Be 0
        }

        It 'fails missing Web Frontend service-worker scope, cache-poisoning, and integrity controls' {
            $script:tempRoot = New-AgentStandardsFixture
            $path = Join-Path $script:tempRoot 'agents/AGENTS_WebFrontend.md'
            $text = (Get-Content -LiteralPath $path -Raw).
                Replace('Service-worker work MUST define script identity, scope, registration path, allowed scope', 'Service-worker work should define identity').
                Replace('Scope MUST be no broader than required', 'Scope should be narrow').
                Replace('Workers MUST NOT bypass auth, authorization, CSP, Trusted Types, or server controls', 'Workers should not bypass controls').
                Replace('Cached executable assets MUST match the approved release identity', 'Cached executable assets should match release').
                Replace('Opaque cross-origin responses require review before caching', 'Opaque responses can be cached').
                Replace('Cache poisoning through URLs, query strings, redirects, headers, or compromised upstream content MUST be considered', 'Cache poisoning should be considered').
                Replace('Authentication pages, logout responses, antiforgery responses, token endpoints, and protected API responses MUST NOT be cached without an approved design', 'Protected endpoints should not be cached').
                Replace('Faulty active workers require documented recovery', 'Faulty workers should recover').
                Replace('Update failures MUST be observable', 'Update failures should be observable')
            Set-Content -LiteralPath $path -Value $text -Encoding utf8
            Invoke-AgentStandardsValidator -Path $script:tempRoot | Should -Not -Be 0
        }

        It 'fails missing Web Frontend telemetry and source-map release-integrity controls' {
            $script:tempRoot = New-AgentStandardsFixture
            $path = Join-Path $script:tempRoot 'agents/AGENTS_WebFrontend.md'
            $text = (Get-Content -LiteralPath $path -Raw).
                Replace('Telemetry failure MUST NOT break core UI', 'Telemetry failure should not break UI').
                Replace('Console logs MUST NOT contain secrets, tokens, passwords, authorization headers, private keys', 'Console logs should avoid secrets').
                Replace('Debug logging MUST be disabled in protected production builds unless approved', 'Debug logging should be disabled').
                Replace('Correlation IDs MUST be opaque, safe, and non-secret', 'Correlation IDs should be safe').
                Replace('Events MUST identify frontend release and environment', 'Events should identify release').
                Replace('Every production source map MUST associate with the exact source revision, release identifier, bundle filename, and content hash', 'Production source maps should have release association').
                Replace('Maps and bundles MUST be secret-scanned before publication or upload', 'Maps should be scanned').
                Replace('Upload success MUST be verified independently from deployment success', 'Upload success should be verified').
                Replace('Provider upload MUST NOT make maps publicly reachable', 'Provider upload should protect maps').
                Replace('Mismatched maps MUST fail deployment verification or be reported as a defect', 'Mismatched maps should be reported')
            Set-Content -LiteralPath $path -Value $text -Encoding utf8
            Invoke-AgentStandardsValidator -Path $script:tempRoot | Should -Not -Be 0
        }

        It 'fails a database standard version below the required minimum' {
            $script:tempRoot = New-AgentStandardsFixture
            $path = Join-Path $script:tempRoot 'agents/AGENTS_Database.md'
            $text = (Get-Content -LiteralPath $path -Raw).Replace('| Version | 1.1.1 |', '| Version | 1.1.0 |')
            Set-Content -LiteralPath $path -Value $text -Encoding utf8
            Invoke-AgentStandardsValidator -Path $script:tempRoot | Should -Not -Be 0
        }

        It 'fails a malformed database standard semantic version' {
            $script:tempRoot = New-AgentStandardsFixture
            $path = Join-Path $script:tempRoot 'agents/AGENTS_Database.md'
            $text = (Get-Content -LiteralPath $path -Raw).Replace('| Version | 1.1.1 |', '| Version | current |')
            Set-Content -LiteralPath $path -Value $text -Encoding utf8
            Invoke-AgentStandardsValidator -Path $script:tempRoot | Should -Not -Be 0
        }

        It 'fails missing database engine and development-model requirements' {
            $script:tempRoot = New-AgentStandardsFixture
            $path = Join-Path $script:tempRoot 'agents/AGENTS_Database.md'
            $text = (Get-Content -LiteralPath $path -Raw).
                Replace('SQL Server, Azure SQL Database, Azure SQL Managed Instance, PostgreSQL, MySQL, MariaDB, Oracle Database, SQLite', 'common database engines').
                Replace('authoritative schema model', 'main schema approach').
                Replace('already-applied immutable migrations', 'old migrations')
            Set-Content -LiteralPath $path -Value $text -Encoding utf8
            Invoke-AgentStandardsValidator -Path $script:tempRoot | Should -Not -Be 0
        }

        It 'fails missing database rollout and destructive-operation controls' {
            $script:tempRoot = New-AgentStandardsFixture
            $path = Join-Path $script:tempRoot 'agents/AGENTS_Database.md'
            $text = (Get-Content -LiteralPath $path -Raw).
                Replace('## Expand-And-Contract And Rolling Deployment Compatibility', '## Rolling Deployment Compatibility').
                Replace('Automatic production migration-on-startup is prohibited', 'Automatic production migrations are discouraged').
                Replace('Empty input MUST NOT mean all rows', 'Empty input should not mean all rows').
                Replace('maximum affected-row threshold', 'affected-row limit')
            Set-Content -LiteralPath $path -Value $text -Encoding utf8
            Invoke-AgentStandardsValidator -Path $script:tempRoot | Should -Not -Be 0
        }

        It 'fails missing database SQL safety and performance controls' {
            $script:tempRoot = New-AgentStandardsFixture
            $path = Join-Path $script:tempRoot 'agents/AGENTS_Database.md'
            $text = (Get-Content -LiteralPath $path -Raw).
                Replace('parameterized queries, bound parameters', 'safe queries').
                Replace('identifier allowlists', 'identifier checks').
                Replace('`SELECT *` MUST NOT be introduced into stable production contracts', 'SELECT star should be avoided').
                Replace('`NOLOCK` MUST NOT be used as a generic performance fix', 'NOLOCK needs care').
                Replace('Accidental cross joins are prohibited', 'Cross joins need care').
                Replace('Cursor, loop, and row-by-row processing MUST be justified', 'Cursor processing should be explained').
                Replace('Recursive queries MUST define termination condition, maximum depth', 'Recursive queries should terminate')
            Set-Content -LiteralPath $path -Value $text -Encoding utf8
            Invoke-AgentStandardsValidator -Path $script:tempRoot | Should -Not -Be 0
        }

        It 'fails missing database MERGE and upsert controls' {
            $script:tempRoot = New-AgentStandardsFixture
            $path = Join-Path $script:tempRoot 'agents/AGENTS_Database.md'
            $text = (Get-Content -LiteralPath $path -Raw).
                Replace('`MERGE` and equivalent upsert constructs MUST receive engine- and version-specific correctness and concurrency review', 'Upserts should be reviewed').
                Replace('duplicate source-row behavior, concurrent writer behavior', 'duplicate behavior').
                Replace('Upsert tests MUST cover concurrent insert attempts, concurrent update attempts, duplicate source rows, retry after partial failure', 'Upsert tests should cover normal behavior')
            Set-Content -LiteralPath $path -Value $text -Encoding utf8
            Invoke-AgentStandardsValidator -Path $script:tempRoot | Should -Not -Be 0
        }

        It 'fails missing database transaction uncertainty controls' {
            $script:tempRoot = New-AgentStandardsFixture
            $path = Join-Path $script:tempRoot 'agents/AGENTS_Database.md'
            $text = (Get-Content -LiteralPath $path -Raw).
                Replace('Transactions MUST use the smallest practical scope', 'Transactions should be scoped').
                Replace('Remote API, SMTP, file-transfer, queue, or other external calls MUST NOT occur inside a database transaction unless explicitly justified and protected by an approved pattern', 'External calls inside transactions should be reviewed').
                Replace('When commit outcome is uncertain, callers MUST NOT blindly retry non-idempotent operations', 'Commit uncertainty should be considered').
                Replace('Transactional DDL support MUST be verified for the declared engine before rollback claims are made', 'Transactional DDL should be checked')
            Set-Content -LiteralPath $path -Value $text -Encoding utf8
            Invoke-AgentStandardsValidator -Path $script:tempRoot | Should -Not -Be 0
        }

        It 'fails missing database routine-specific controls' {
            $script:tempRoot = New-AgentStandardsFixture
            $path = Join-Path $script:tempRoot 'agents/AGENTS_Database.md'
            $text = (Get-Content -LiteralPath $path -Raw).
                Replace('Stored procedures MUST define explicit parameter names, explicit parameter types, explicit string or binary lengths', 'Stored procedures should define parameters').
                Replace('stable result-set contracts', 'result behavior').
                Replace('Functions MUST document determinism assumptions', 'Functions should document behavior').
                Replace('Scalar function performance impact MUST be reviewed', 'Scalar functions should be reviewed').
                Replace('Views MUST use explicit column lists and MUST avoid `SELECT *`', 'Views should avoid broad columns')
            Set-Content -LiteralPath $path -Value $text -Encoding utf8
            Invoke-AgentStandardsValidator -Path $script:tempRoot | Should -Not -Be 0
        }

        It 'fails missing database security, backup, and HA controls' {
            $script:tempRoot = New-AgentStandardsFixture
            $path = Join-Path $script:tempRoot 'agents/AGENTS_Database.md'
            $text = (Get-Content -LiteralPath $path -Raw).
                Replace('Application accounts MUST NOT use `sysadmin`, `dbo`-equivalent, `superuser`', 'Application accounts should avoid broad permissions').
                Replace('TLS where supported and required. Certificate validation MUST NOT be bypassed', 'TLS should be considered').
                Replace('Before destructive production work, agents MUST verify backup status through an authoritative mechanism', 'Backups should be checked before destructive work').
                Replace('## Replication, High Availability, And Disaster Recovery', '## Availability')
            Set-Content -LiteralPath $path -Value $text -Encoding utf8
            Invoke-AgentStandardsValidator -Path $script:tempRoot | Should -Not -Be 0
        }

        It 'fails missing database validation command and evidence honesty requirements' {
            $script:tempRoot = New-AgentStandardsFixture
            $path = Join-Path $script:tempRoot 'agents/AGENTS_Database.md'
            $text = (Get-Content -LiteralPath $path -Raw).
                Replace('sqlcmd -S "<server>" -d "<database>" -E -b -i', 'sqlcmd example').
                Replace('Secret-bearing connection strings MUST NOT be placed directly in process arguments', 'Connection strings should be handled carefully').
                Replace('integrated authentication, managed identity, workload identity, certificate authentication', 'approved authentication').
                Replace('dotnet ef migrations list', 'ef migration command').
                Replace('CI MUST NOT use fake commands that only print success', 'CI should avoid fake commands').
                Replace('Permitted statuses are `Passed`, `Failed`, `Blocked`, `NotRun`, and `NotApplicable`', 'Use evidence statuses')
            Set-Content -LiteralPath $path -Value $text -Encoding utf8
            Invoke-AgentStandardsValidator -Path $script:tempRoot | Should -Not -Be 0
        }

        It 'fails database weakening language for unsafe exceptions' {
            $script:tempRoot = New-AgentStandardsFixture
            Add-Content -LiteralPath (Join-Path $script:tempRoot 'agents/AGENTS_Database.md') -Value @'

Missing database validation may be marked Passed.
MERGE is always safe.
Upserts require no concurrency testing.
Remote calls inside transactions are acceptable by default.
A lost connection during commit means the transaction definitely failed.
Blind retry after uncertain commit is safe.
Procedure parameters may omit lengths.
Functions need no performance review.
Views may use SELECT * by default.
Cross joins require no review.
Cursors are preferred for bulk processing.
Recursive queries need no depth limit.
Plaintext connection strings may be passed to sqlpackage.
Command-line secrets are acceptable in CI.
Transactional DDL support may be assumed.
'@
            Invoke-AgentStandardsValidator -Path $script:tempRoot | Should -Not -Be 0
        }

        It 'fails a worker standard version below the required minimum' {
            $script:tempRoot = New-AgentStandardsFixture
            $path = Join-Path $script:tempRoot 'agents/AGENTS_WorkerService.md'
            $text = (Get-Content -LiteralPath $path -Raw).Replace('| Version | 1.1.1 |', '| Version | 1.1.0 |')
            Set-Content -LiteralPath $path -Value $text -Encoding utf8
            Invoke-AgentStandardsValidator -Path $script:tempRoot | Should -Not -Be 0
        }

        It 'fails a malformed worker standard semantic version' {
            $script:tempRoot = New-AgentStandardsFixture
            $path = Join-Path $script:tempRoot 'agents/AGENTS_WorkerService.md'
            $text = (Get-Content -LiteralPath $path -Raw).Replace('| Version | 1.1.1 |', '| Version | current |')
            Set-Content -LiteralPath $path -Value $text -Encoding utf8
            Invoke-AgentStandardsValidator -Path $script:tempRoot | Should -Not -Be 0
        }

        It 'fails missing worker state-machine requirements' {
            $script:tempRoot = New-AgentStandardsFixture
            $path = Join-Path $script:tempRoot 'agents/AGENTS_WorkerService.md'
            $text = (Get-Content -LiteralPath $path -Raw).
                Replace('Every durable worker MUST define a documented state machine', 'Workers should describe states').
                Replace('State transitions MUST be validated', 'State transitions should be checked').
                Replace('Every progress, heartbeat, completion, failure, retry scheduling, cancellation, timeout, dead-letter, skip, and partial-success transition MUST verify', 'Progress and completion transitions should verify').
                Replace('State transitions MUST use compare-and-swap, optimistic concurrency, an atomic predicate, queue-native ownership semantics, or an equivalent protected mechanism', 'State transitions should use a protected mechanism').
                Replace('A worker that has lost ownership MUST NOT update progress, mark success, mark failure, schedule retry, complete or acknowledge the message, publish final artifacts, dead-letter the work, or mutate terminal state', 'A worker that has lost ownership should avoid terminal mutation').
                Replace('Zero rows affected by an ownership-protected update MUST be treated as ownership loss or stale state, not success', 'Zero rows affected may indicate stale state')
            Set-Content -LiteralPath $path -Value $text -Encoding utf8
            Invoke-AgentStandardsValidator -Path $script:tempRoot | Should -Not -Be 0
        }

        It 'fails missing worker atomic claim requirements' {
            $script:tempRoot = New-AgentStandardsFixture
            $path = Join-Path $script:tempRoot 'agents/AGENTS_WorkerService.md'
            $text = (Get-Content -LiteralPath $path -Raw).
                Replace('For SQL-polled workers, claiming MUST be atomic', 'SQL-polled workers should claim carefully').
                Replace('claim or lease owner, claim timestamp, lease expiration', 'claim timestamp').
                Replace('Queue completion or acknowledgement MUST verify that the current receiver still owns the lock, lease, receipt handle', 'Queue completion should verify ownership').
                Replace('Reclaimed work MUST generate a new ownership context or attempt identity', 'Reclaimed work should generate a new attempt')
            Set-Content -LiteralPath $path -Value $text -Encoding utf8
            Invoke-AgentStandardsValidator -Path $script:tempRoot | Should -Not -Be 0
        }

        It 'fails missing worker lease-loss behavior' {
            $script:tempRoot = New-AgentStandardsFixture
            $path = Join-Path $script:tempRoot 'agents/AGENTS_WorkerService.md'
            $text = (Get-Content -LiteralPath $path -Raw).
                Replace('A worker MUST stop or fail safely if it loses ownership', 'A worker should notice ownership changes').
                Replace('Leases MUST NOT be overwritten by another worker while an active owner is valid', 'Leases should avoid overlap')
            Set-Content -LiteralPath $path -Value $text -Encoding utf8
            Invoke-AgentStandardsValidator -Path $script:tempRoot | Should -Not -Be 0
        }

        It 'fails missing worker delivery and idempotency controls' {
            $script:tempRoot = New-AgentStandardsFixture
            $path = Join-Path $script:tempRoot 'agents/AGENTS_WorkerService.md'
            $text = (Get-Content -LiteralPath $path -Raw).
                Replace('At-least-once delivery MUST assume duplicate messages', 'At-least-once delivery should consider duplicates').
                Replace('Exactly-once delivery is prohibited as a claim unless proven end-to-end', 'Exactly-once delivery should be justified').
                Replace('durable idempotency key', 'idempotency key').
                Replace('Empty input MUST NOT mean all jobs', 'Empty input should not mean all jobs')
            Set-Content -LiteralPath $path -Value $text -Encoding utf8
            Invoke-AgentStandardsValidator -Path $script:tempRoot | Should -Not -Be 0
        }

        It 'fails weakened worker concurrency and polling controls' {
            $script:tempRoot = New-AgentStandardsFixture
            $path = Join-Path $script:tempRoot 'agents/AGENTS_WorkerService.md'
            $text = (Get-Content -LiteralPath $path -Raw).
                Replace('Unbounded concurrency is prohibited', 'Unbounded concurrency should be avoided').
                Replace('Empty polls MUST delay', 'Empty polls should delay').
                Replace('Failure loops MUST back off', 'Failure loops should slow down')
            Set-Content -LiteralPath $path -Value $text -Encoding utf8
            Invoke-AgentStandardsValidator -Path $script:tempRoot | Should -Not -Be 0
        }

        It 'fails missing worker retry and dead-letter controls' {
            $script:tempRoot = New-AgentStandardsFixture
            $path = Join-Path $script:tempRoot 'agents/AGENTS_WorkerService.md'
            $text = (Get-Content -LiteralPath $path -Raw).
                Replace('retryable and nonretryable categories', 'failure categories').
                Replace('maximum attempt count', 'attempt count').
                Replace('exponential backoff and jitter', 'delays').
                Replace('Dead-letter storage MUST be durable', 'Dead-letter storage should persist')
            Set-Content -LiteralPath $path -Value $text -Encoding utf8
            Invoke-AgentStandardsValidator -Path $script:tempRoot | Should -Not -Be 0
        }

        It 'fails missing worker cancellation and timeout controls' {
            $script:tempRoot = New-AgentStandardsFixture
            $path = Join-Path $script:tempRoot 'agents/AGENTS_WorkerService.md'
            $text = (Get-Content -LiteralPath $path -Raw).
                Replace('Cancellation tokens or equivalent cancellation signals MUST propagate', 'Cancellation should be propagated').
                Replace('Graceful shutdown MUST define drain behavior', 'Graceful shutdown should drain').
                Replace('Child processes MUST have timeouts', 'Child processes should have timeouts')
            Set-Content -LiteralPath $path -Value $text -Encoding utf8
            Invoke-AgentStandardsValidator -Path $script:tempRoot | Should -Not -Be 0
        }

        It 'fails missing worker script-runner safeguards' {
            $script:tempRoot = New-AgentStandardsFixture
            $path = Join-Path $script:tempRoot 'agents/AGENTS_WorkerService.md'
            $text = (Get-Content -LiteralPath $path -Raw).
                Replace('Script-runner workers MUST use an approved script or job catalog', 'Script-runner workers should use a catalog').
                Replace('The approved catalog MUST define and verify an immutable executable identity before execution', 'The approved catalog should identify executables').
                Replace('The worker MUST verify the executable, script, module, package, hash, signature, signer, or container digest immediately before execution', 'The worker should verify executable identity').
                Replace('A valid signature from an unapproved signer is insufficient', 'Any valid signature is usually enough').
                Replace('Arbitrary scripts, paths, commands, shell snippets, or user command text MUST NOT be executed', 'Arbitrary commands should be restricted').
                Replace('Secrets MUST NOT be passed in visible command-line arguments', 'Secrets should not be passed on command lines').
                Replace('Accepted exit codes MUST be explicit', 'Exit codes should be checked').
                Replace('The worker MUST intentionally capture the success/output stream, error stream, warning stream, verbose stream, debug stream, and information stream', 'The worker should capture common streams').
                Replace('The worker MUST distinguish terminating and nonterminating errors', 'The worker should inspect errors').
                Replace('Process exit code alone MUST NOT be treated as complete proof of PowerShell success', 'Process exit code usually proves PowerShell success').
                Replace('A stable structured result contract MUST be preferred for governed scripts', 'Script text output is usually enough')
            Set-Content -LiteralPath $path -Value $text -Encoding utf8
            Invoke-AgentStandardsValidator -Path $script:tempRoot | Should -Not -Be 0
        }

        It 'fails missing worker immutable input controls' {
            $script:tempRoot = New-AgentStandardsFixture
            $path = Join-Path $script:tempRoot 'agents/AGENTS_WorkerService.md'
            $text = (Get-Content -LiteralPath $path -Raw).
                Replace('Job input MUST become immutable, versioned, or content-addressed after durable submission', 'Job input should be retained after submission').
                Replace('immutable payload snapshot or immutable object reference, content hash', 'payload reference').
                Replace('The worker MUST verify content hash before execution', 'The worker should inspect input before execution').
                Replace('Uploaded CSV or input files MUST NOT be replaceable after approval', 'Uploaded files should not usually be replaced')
            Set-Content -LiteralPath $path -Value $text -Encoding utf8
            Invoke-AgentStandardsValidator -Path $script:tempRoot | Should -Not -Be 0
        }

        It 'fails missing worker artifact integrity controls' {
            $script:tempRoot = New-AgentStandardsFixture
            $path = Join-Path $script:tempRoot 'agents/AGENTS_WorkerService.md'
            $text = (Get-Content -LiteralPath $path -Raw).
                Replace('Worker artifacts and reports MUST be associated with job ID, attempt number, correlation ID', 'Worker artifacts should include job metadata').
                Replace('content hash, classification, retention, and authorization boundary', 'classification and retention').
                Replace('Artifact publication MUST use an atomic publish model', 'Artifact publication should be orderly').
                Replace('Partial artifacts MUST NOT be presented as final', 'Partial artifacts should not be final').
                Replace('A job MUST NOT be marked fully successful when a required artifact failed to publish', 'Required artifact failure should be reviewed')
            Set-Content -LiteralPath $path -Value $text -Encoding utf8
            Invoke-AgentStandardsValidator -Path $script:tempRoot | Should -Not -Be 0
        }

        It 'fails missing worker durable handoff and safe container validation controls' {
            $script:tempRoot = New-AgentStandardsFixture
            $path = Join-Path $script:tempRoot 'agents/AGENTS_WorkerService.md'
            $text = (Get-Content -LiteralPath $path -Raw).
                Replace('When database state and external side effects must remain coordinated, workers MUST use outbox, inbox, durable queue handoff, idempotent reconciliation, saga or orchestration state, or another approved durable pattern', 'When database state and external side effects must remain coordinated, workers SHOULD use a durable pattern').
                Replace('Queue acknowledgement MUST NOT occur before the approved durable completion point', 'Queue acknowledgement should occur after completion').
                Replace('Normal worker execution MUST NOT be launched merely as a smoke test', 'Normal worker execution may be launched as a smoke test').
                Replace('Production credentials MUST NOT be mounted', 'Production credentials may be mounted for convenience').
                Replace('--validate-configuration', '--run-worker')
            Set-Content -LiteralPath $path -Value $text -Encoding utf8
            Invoke-AgentStandardsValidator -Path $script:tempRoot | Should -Not -Be 0
        }

        It 'fails missing worker security and redaction controls' {
            $script:tempRoot = New-AgentStandardsFixture
            $path = Join-Path $script:tempRoot 'agents/AGENTS_WorkerService.md'
            $text = (Get-Content -LiteralPath $path -Raw).
                Replace('Workers MUST run with least privilege', 'Workers should use limited privilege').
                Replace('Secrets MUST come from approved secret stores', 'Secrets should come from secret stores').
                Replace('Logs MUST NOT include secrets', 'Logs should not include secrets')
            Set-Content -LiteralPath $path -Value $text -Encoding utf8
            Invoke-AgentStandardsValidator -Path $script:tempRoot | Should -Not -Be 0
        }

        It 'fails missing worker readiness, backpressure, and rolling compatibility controls' {
            $script:tempRoot = New-AgentStandardsFixture
            $path = Join-Path $script:tempRoot 'agents/AGENTS_WorkerService.md'
            $text = (Get-Content -LiteralPath $path -Raw).
                Replace('A worker MUST NOT claim jobs before startup validation completes', 'Workers should validate startup before work').
                Replace('backpressure', 'pressure handling').
                Replace('old/new worker compatibility', 'worker compatibility')
            Set-Content -LiteralPath $path -Value $text -Encoding utf8
            Invoke-AgentStandardsValidator -Path $script:tempRoot | Should -Not -Be 0
        }

        It 'fails unsafe worker weakening phrases' {
            $script:tempRoot = New-AgentStandardsFixture
            Add-Content -LiteralPath (Join-Path $script:tempRoot 'agents/AGENTS_WorkerService.md') -Value @'

Exactly-once delivery is automatic.
Empty input means all jobs.
Any script path may be executed.
User command text may be passed to a shell.
Queue messages may be acknowledged before durable completion.
Leases may be overwritten by another worker.
Lost lease may be ignored.
Infinite retries are acceptable.
Poison jobs may be discarded.
Dead-letter replay needs no approval.
Cancellation may be ignored.
Process launch means success.
Secrets may be passed on command lines.
Busy polling is acceptable.
Unlimited concurrency is preferred.
Local time schedules need no DST handling.
Missing worker validation may be marked Passed.
A stale worker may complete the job.
Lease ownership only matters during claim.
Zero rows affected may still be treated as success.
Script version strings are sufficient integrity.
Script hashes do not need verification.
Any valid signer is acceptable.
PowerShell exit code zero always means success.
Nonterminating PowerShell errors may be ignored.
Job input files may be replaced after approval.
File paths are sufficient input identity.
Partial reports may be published as final.
Artifacts may be overwritten during retry.
Artifact hashes are optional.
Outbox or durable handoff is optional for coordinated side effects.
A worker may acknowledge before durable completion.
Normal worker startup is a safe container smoke test.
Production credentials may be used for container validation.
Missing Worker Service validation may be marked Passed.
'@
            Invoke-AgentStandardsValidator -Path $script:tempRoot | Should -Not -Be 0
        }

        It 'fails an Integration standard version below the required minimum' {
            $script:tempRoot = New-AgentStandardsFixture
            $path = Join-Path $script:tempRoot 'agents/AGENTS_Integration.md'
            $text = (Get-Content -LiteralPath $path -Raw).Replace('| Version | 1.1.0 |', '| Version | 1.0.0 |')
            Set-Content -LiteralPath $path -Value $text -Encoding utf8
            Invoke-AgentStandardsValidator -Path $script:tempRoot | Should -Not -Be 0
        }

        It 'fails a malformed Integration standard semantic version' {
            $script:tempRoot = New-AgentStandardsFixture
            $path = Join-Path $script:tempRoot 'agents/AGENTS_Integration.md'
            $text = (Get-Content -LiteralPath $path -Raw).Replace('| Version | 1.1.0 |', '| Version | current |')
            Set-Content -LiteralPath $path -Value $text -Encoding utf8
            Invoke-AgentStandardsValidator -Path $script:tempRoot | Should -Not -Be 0
        }

        It 'accepts a future compatible Integration patch version' {
            $script:tempRoot = New-AgentStandardsFixture
            $path = Join-Path $script:tempRoot 'agents/AGENTS_Integration.md'
            $text = (Get-Content -LiteralPath $path -Raw).Replace('| Version | 1.1.0 |', '| Version | 1.1.9 |')
            Set-Content -LiteralPath $path -Value $text -Encoding utf8
            Invoke-AgentStandardsValidator -Path $script:tempRoot | Should -Be 0
        }

        It 'fails missing Integration contract, retry, and idempotency controls' {
            $script:tempRoot = New-AgentStandardsFixture
            $path = Join-Path $script:tempRoot 'agents/AGENTS_Integration.md'
            $text = (Get-Content -LiteralPath $path -Raw).
                Replace('Every governed integration MUST define explicit API versions, schema versions, message versions, event versions, file layout versions, or vendor SDK versions', 'Integrations should document useful versions').
                Replace('Retries MUST classify retryable and nonretryable failures', 'Retries should classify failures').
                Replace('Retries MUST be bounded, use exponential backoff and jitter, respect `Retry-After`', 'Retries should use backoff').
                Replace('Non-idempotent operations MUST use idempotency keys, deduplication, outbox/inbox, durable coordination', 'Non-idempotent operations should be reviewed before retry')
            Set-Content -LiteralPath $path -Value $text -Encoding utf8
            Invoke-AgentStandardsValidator -Path $script:tempRoot | Should -Not -Be 0
        }

        It 'fails missing Integration webhook and queue controls' {
            $script:tempRoot = New-AgentStandardsFixture
            $path = Join-Path $script:tempRoot 'agents/AGENTS_Integration.md'
            $text = (Get-Content -LiteralPath $path -Raw).
                Replace('Webhook handlers MUST validate signatures or event authenticity', 'Webhook handlers should validate authenticity').
                Replace('Timestamp, nonce, event ID, delivery ID, digest, or equivalent replay protection MUST be enforced', 'Replay protection should be considered').
                Replace('Queue, topic, stream, and broker integrations MUST define delivery semantics', 'Queue integrations should define delivery behavior').
                Replace('Poison messages MUST have dead-letter handling or an approved equivalent remediation path', 'Poison messages should have remediation')
            Set-Content -LiteralPath $path -Value $text -Encoding utf8
            Invoke-AgentStandardsValidator -Path $script:tempRoot | Should -Not -Be 0
        }

        It 'fails missing Integration file-transfer and schema-validation controls' {
            $script:tempRoot = New-AgentStandardsFixture
            $path = Join-Path $script:tempRoot 'agents/AGENTS_Integration.md'
            $text = (Get-Content -LiteralPath $path -Raw).
                Replace('SFTP and managed-file-transfer integrations MUST validate host keys', 'SFTP integrations should validate host keys').
                Replace('File hashes are required where a provider supplies them', 'File hashes are useful where available').
                Replace('Publication MUST use an atomic rename, manifest marker, immutable object version, or equivalent completion signal', 'Publication should use a completion signal').
                Replace('Payloads MUST be validated against schemas before trusted processing', 'Payloads should be validated')
            Set-Content -LiteralPath $path -Value $text -Encoding utf8
            Invoke-AgentStandardsValidator -Path $script:tempRoot | Should -Not -Be 0
        }

        It 'fails missing Integration evidence honesty controls' {
            $script:tempRoot = New-AgentStandardsFixture
            $path = Join-Path $script:tempRoot 'agents/AGENTS_Integration.md'
            $text = (Get-Content -LiteralPath $path -Raw).
                Replace('sandbox, provider endpoint, credential, broker, certificate authority, file-transfer endpoint, or network route is unavailable, record `NotRun` or `Blocked`', 'Unavailable endpoints should be explained').
                Replace('Production MUST NOT be used merely because nonproduction is unavailable', 'Production should not usually be used as fallback').
                Replace('Unexecuted integration validation, unavailable sandboxes, missing credentials, unavailable brokers, missing certificates, missing provider access, or missing external endpoints MUST NOT be labeled `Passed`', 'Unexecuted integration validation should not be labeled passed').
                Replace('Agents MUST NOT fabricate commands, exit codes, workflow runs, provider responses, webhook deliveries, queue messages, file hashes, approvals', 'Agents should not fabricate integration evidence')
            Set-Content -LiteralPath $path -Value $text -Encoding utf8
            Invoke-AgentStandardsValidator -Path $script:tempRoot | Should -Not -Be 0
        }

        It 'fails unsafe Integration weakening phrases' {
            $script:tempRoot = New-AgentStandardsFixture
            Add-Content -LiteralPath (Join-Path $script:tempRoot 'agents/AGENTS_Integration.md') -Value @'

Webhook signatures may be ignored.
Retries may be unbounded.
Every error is retryable.
Retry loops need no jitter.
Continuation tokens may be modified.
HTTP success always means business success.
Client secrets may be committed.
Certificate validation may be disabled.
Queue delivery is exactly once automatically.
Duplicate events may be ignored.
Dead letters are optional for poison messages.
External calls may occur inside database transactions by default.
Partial success may be displayed as full success.
SFTP host keys need no validation.
File hashes are unnecessary.
Untrusted payloads may bypass schema validation.
Production may be used when sandbox access is unavailable.
Missing Integration validation may be marked Passed.
'@
            Invoke-AgentStandardsValidator -Path $script:tempRoot | Should -Not -Be 0
        }

        It 'fails an infrastructure standard version below the required minimum' {
            $script:tempRoot = New-AgentStandardsFixture
            $path = Join-Path $script:tempRoot 'agents/AGENTS_Infrastructure.md'
            $text = (Get-Content -LiteralPath $path -Raw).Replace('| Version | 1.1.1 |', '| Version | 1.1.0 |')
            Set-Content -LiteralPath $path -Value $text -Encoding utf8
            Invoke-AgentStandardsValidator -Path $script:tempRoot | Should -Not -Be 0
        }

        It 'fails a malformed infrastructure standard semantic version' {
            $script:tempRoot = New-AgentStandardsFixture
            $path = Join-Path $script:tempRoot 'agents/AGENTS_Infrastructure.md'
            $text = (Get-Content -LiteralPath $path -Raw).Replace('| Version | 1.1.1 |', '| Version | current |')
            Set-Content -LiteralPath $path -Value $text -Encoding utf8
            Invoke-AgentStandardsValidator -Path $script:tempRoot | Should -Not -Be 0
        }

        It 'fails missing infrastructure environment targeting controls' {
            $script:tempRoot = New-AgentStandardsFixture
            $path = Join-Path $script:tempRoot 'agents/AGENTS_Infrastructure.md'
            $text = (Get-Content -LiteralPath $path -Raw).
                Replace('Every mutating command MUST make the following explicit', 'Mutating commands should identify useful context').
                Replace('Empty target MUST NOT mean all environments or all resources', 'Empty target should not broaden scope').
                Replace('Cached CLI context alone is insufficient for production mutation', 'Cached CLI context should be reviewed for production').
                Replace('Guessing target environment from directory name, current CLI context, shell profile, default subscription, default region, default kubeconfig context, or cached credentials is prohibited', 'Guessing target environment should be avoided')
            Set-Content -LiteralPath $path -Value $text -Encoding utf8
            Invoke-AgentStandardsValidator -Path $script:tempRoot | Should -Not -Be 0
        }

        It 'fails missing infrastructure plan-before-apply controls' {
            $script:tempRoot = New-AgentStandardsFixture
            $path = Join-Path $script:tempRoot 'agents/AGENTS_Infrastructure.md'
            $text = (Get-Content -LiteralPath $path -Raw).
                Replace('Infrastructure changes MUST use plan-before-apply, preview, what-if, diff, or equivalent review output', 'Infrastructure changes should use previews').
                Replace('Apply MUST use the reviewed saved plan artifact where the tool supports saved plans', 'Apply should use reviewed plans where convenient').
                Replace('A plan generated from one commit, variable set, state, provider set, credential, policy set, or environment MUST NOT authorize a different apply', 'Plans should generally match apply inputs')
            Set-Content -LiteralPath $path -Value $text -Encoding utf8
            Invoke-AgentStandardsValidator -Path $script:tempRoot | Should -Not -Be 0
        }

        It 'fails missing infrastructure approved plan binding and production approval controls' {
            $script:tempRoot = New-AgentStandardsFixture
            $path = Join-Path $script:tempRoot 'agents/AGENTS_Infrastructure.md'
            $text = (Get-Content -LiteralPath $path -Raw).
                Replace('Production environment protections MUST be used where available', 'Production environment protections should be used').
                Replace('Critical changes MUST NOT be self-approved unless an approved emergency process applies', 'Critical changes should avoid self-approval')
            Set-Content -LiteralPath $path -Value $text -Encoding utf8
            Invoke-AgentStandardsValidator -Path $script:tempRoot | Should -Not -Be 0
        }

        It 'fails missing infrastructure state locking controls' {
            $script:tempRoot = New-AgentStandardsFixture
            $path = Join-Path $script:tempRoot 'agents/AGENTS_Infrastructure.md'
            $text = (Get-Content -LiteralPath $path -Raw).
                Replace('Shared or production state MUST use a remote protected backend where supported', 'Shared or production state should use a backend').
                Replace('State files MUST NOT be committed', 'State files should not be committed').
                Replace('State backend outage is `Blocked` for apply, not a reason to bypass locking', 'State backend outage may require alternate locking').
                Replace('Force-unlock requires proof that no active operation owns the lock', 'Force-unlock should be used carefully')
            Set-Content -LiteralPath $path -Value $text -Encoding utf8
            Invoke-AgentStandardsValidator -Path $script:tempRoot | Should -Not -Be 0
        }

        It 'fails missing infrastructure state migration controls' {
            $script:tempRoot = New-AgentStandardsFixture
            $path = Join-Path $script:tempRoot 'agents/AGENTS_Infrastructure.md'
            $text = (Get-Content -LiteralPath $path -Raw).
                Replace('State import, move, migration, backend migration, repair, `state rm`, `state mv`, moved blocks, and manual state surgery require phased controls', 'State operations should be phased').
                Replace('Manual state editing is prohibited unless an approved emergency procedure requires it', 'Manual state editing should be rare')
            Set-Content -LiteralPath $path -Value $text -Encoding utf8
            Invoke-AgentStandardsValidator -Path $script:tempRoot | Should -Not -Be 0
        }

        It 'fails missing infrastructure pinning and supply-chain controls' {
            $script:tempRoot = New-AgentStandardsFixture
            $path = Join-Path $script:tempRoot 'agents/AGENTS_Infrastructure.md'
            $text = (Get-Content -LiteralPath $path -Raw).
                Replace('Infrastructure CLI versions MUST be pinned or constrained', 'Infrastructure CLI versions should be known').
                Replace('GitHub Actions MUST be pinned to immutable commit SHAs', 'GitHub Actions may use version tags').
                Replace('Production dependencies MUST NOT use floating `latest`, `main`, `master`, mutable branch names, mutable tags, or unbounded version ranges', 'Production dependencies should avoid floating versions').
                Replace('Dynamically downloaded scripts MUST NOT be immediately executed without integrity controls', 'Downloaded scripts should be reviewed')
            Set-Content -LiteralPath $path -Value $text -Encoding utf8
            Invoke-AgentStandardsValidator -Path $script:tempRoot | Should -Not -Be 0
        }

        It 'fails missing infrastructure destructive-change controls' {
            $script:tempRoot = New-AgentStandardsFixture
            $path = Join-Path $script:tempRoot 'agents/AGENTS_Infrastructure.md'
            $text = (Get-Content -LiteralPath $path -Raw).
                Replace('Destroy, replacement, deletion, purge, resource rename, recreation, force replacement, broad refactoring, and lifecycle changes', 'Destroy and replacement changes').
                Replace('Agents MUST NOT apply, deploy, destroy, import, move, force-unlock, rotate, revoke, purge, or mutate state unless explicitly requested and authorized', 'Agents should avoid mutation unless requested')
            Set-Content -LiteralPath $path -Value $text -Encoding utf8
            Invoke-AgentStandardsValidator -Path $script:tempRoot | Should -Not -Be 0
        }

        It 'fails missing infrastructure persistent-data controls' {
            $script:tempRoot = New-AgentStandardsFixture
            $path = Join-Path $script:tempRoot 'agents/AGENTS_Infrastructure.md'
            $text = (Get-Content -LiteralPath $path -Raw).
                Replace('Snapshot existence does not prove restore capability', 'Snapshots may prove restore capability').
                Replace('Backup configured does not prove restore tested', 'Backup configured is enough restore evidence')
            Set-Content -LiteralPath $path -Value $text -Encoding utf8
            Invoke-AgentStandardsValidator -Path $script:tempRoot | Should -Not -Be 0
        }

        It 'fails missing infrastructure network exposure controls' {
            $script:tempRoot = New-AgentStandardsFixture
            $path = Join-Path $script:tempRoot 'agents/AGENTS_Infrastructure.md'
            $text = (Get-Content -LiteralPath $path -Raw).
                Replace('Networking MUST be private by default and deny by default', 'Networking should be private where practical').
                Replace('Broad ingress, wildcard source ranges, unrestricted egress', 'Broad network rules').
                Replace('DNS rollback MUST account for TTL and caches', 'DNS rollback should account for propagation')
            Set-Content -LiteralPath $path -Value $text -Encoding utf8
            Invoke-AgentStandardsValidator -Path $script:tempRoot | Should -Not -Be 0
        }

        It 'fails missing infrastructure IAM and RBAC controls' {
            $script:tempRoot = New-AgentStandardsFixture
            $path = Join-Path $script:tempRoot 'agents/AGENTS_Infrastructure.md'
            $text = (Get-Content -LiteralPath $path -Raw).
                Replace('Infrastructure identity MUST follow least privilege', 'Infrastructure identity should follow least privilege').
                Replace('Wildcard IAM, broad administrator access, cluster-admin', 'Privileged access')
            Set-Content -LiteralPath $path -Value $text -Encoding utf8
            Invoke-AgentStandardsValidator -Path $script:tempRoot | Should -Not -Be 0
        }

        It 'fails missing infrastructure secrets and PKI controls' {
            $script:tempRoot = New-AgentStandardsFixture
            $path = Join-Path $script:tempRoot 'agents/AGENTS_Infrastructure.md'
            $text = (Get-Content -LiteralPath $path -Raw).
                Replace('Secrets, private keys, certificates, kubeconfigs, SSH keys, tokens, service-principal secrets, signing keys, and state containing sensitive values MUST be stored in approved secret stores', 'Secrets should be stored in safe places').
                Replace('Certificate validation MUST NOT be bypassed', 'Certificate validation should usually remain enabled').
                Replace('Certificate and PKI changes MUST define subject, SANs, issuer, chain, trust store', 'Certificate changes should document PKI details')
            Set-Content -LiteralPath $path -Value $text -Encoding utf8
            Invoke-AgentStandardsValidator -Path $script:tempRoot | Should -Not -Be 0
        }

        It 'fails missing infrastructure Kubernetes controls' {
            $script:tempRoot = New-AgentStandardsFixture
            $path = Join-Path $script:tempRoot 'agents/AGENTS_Infrastructure.md'
            $text = (Get-Content -LiteralPath $path -Raw).
                Replace('Container and Kubernetes work MUST define image source, tag, digest', 'Container work should define image source').
                Replace('Kubernetes workloads MUST run non-root where feasible', 'Kubernetes workloads should avoid root').
                Replace('Privileged containers, hostPath mounts, host networking, host PID, added Linux capabilities, cluster-admin', 'Privileged container settings')
            Set-Content -LiteralPath $path -Value $text -Encoding utf8
            Invoke-AgentStandardsValidator -Path $script:tempRoot | Should -Not -Be 0
        }

        It 'fails missing infrastructure backup, restore, RPO, and RTO controls' {
            $script:tempRoot = New-AgentStandardsFixture
            $path = Join-Path $script:tempRoot 'agents/AGENTS_Infrastructure.md'
            $text = (Get-Content -LiteralPath $path -Raw).
                Replace('Backup and disaster-recovery configuration MUST identify protected resources, schedule, retention, encryption, storage location, immutability or soft-delete controls, access controls, restore owner, restore procedure, restore-test status, RPO, RTO', 'Backup and disaster-recovery configuration should identify recovery details')
            Set-Content -LiteralPath $path -Value $text -Encoding utf8
            Invoke-AgentStandardsValidator -Path $script:tempRoot | Should -Not -Be 0
        }

        It 'fails missing infrastructure drift, policy, and cost controls' {
            $script:tempRoot = New-AgentStandardsFixture
            $path = Join-Path $script:tempRoot 'agents/AGENTS_Infrastructure.md'
            $text = (Get-Content -LiteralPath $path -Raw).
                Replace('Drift MUST be detected and reviewed before applying changes to managed resources', 'Drift should be reviewed').
                Replace('Policy failures MUST NOT be ignored, suppressed, or converted to success', 'Policy failures should not be ignored').
                Replace('Unbounded autoscaling is prohibited', 'Unbounded autoscaling should be avoided')
            Set-Content -LiteralPath $path -Value $text -Encoding utf8
            Invoke-AgentStandardsValidator -Path $script:tempRoot | Should -Not -Be 0
        }

        It 'fails missing infrastructure CI/CD controls' {
            $script:tempRoot = New-AgentStandardsFixture
            $path = Join-Path $script:tempRoot 'agents/AGENTS_Infrastructure.md'
            $text = (Get-Content -LiteralPath $path -Raw).
                Replace('Infrastructure CI/CD MUST use least-privilege workflow permissions', 'Infrastructure CI/CD should use limited permissions').
                Replace('Production mutation MUST NOT run from untrusted pull requests', 'Production mutation should avoid untrusted pull requests')
            Set-Content -LiteralPath $path -Value $text -Encoding utf8
            Invoke-AgentStandardsValidator -Path $script:tempRoot | Should -Not -Be 0
        }

        It 'fails missing infrastructure validation and evidence honesty controls' {
            $script:tempRoot = New-AgentStandardsFixture
            $path = Join-Path $script:tempRoot 'agents/AGENTS_Infrastructure.md'
            $text = (Get-Content -LiteralPath $path -Raw).
                Replace('terraform fmt -check -recursive', 'terraform fmt command').
                Replace('az deployment group what-if', 'azure deployment preview').
                Replace('aws cloudformation validate-template', 'cloudformation validation').
                Replace('kubectl apply --dry-run=server', 'kubectl dry run').
                Replace('helm template', 'helm render').
                Replace('Permitted statuses are `Passed`, `Failed`, `Blocked`, `NotRun`, and `NotApplicable`', 'Use evidence statuses').
                Replace('Unexecuted plan, apply, deployment, destroy, restore, failover, DNS, firewall, certificate, cluster, service, or production validation MUST NOT be labeled `Passed`', 'Unexecuted validation should be recorded honestly')
            Set-Content -LiteralPath $path -Value $text -Encoding utf8
            Invoke-AgentStandardsValidator -Path $script:tempRoot | Should -Not -Be 0
        }

        It 'fails missing infrastructure IIS binding, app-pool, and filesystem controls' {
            $script:tempRoot = New-AgentStandardsFixture
            $path = Join-Path $script:tempRoot 'agents/AGENTS_Infrastructure.md'
            $text = (Get-Content -LiteralPath $path -Raw).
                Replace('Every IIS infrastructure change MUST define site name, application name where applicable, application pool name, application pool identity', 'IIS changes should define site and pool information').
                Replace('IIS sites and applications MUST NOT use broad filesystem permissions such as Everyone, Users, Authenticated Users', 'IIS sites should avoid broad filesystem permissions').
                Replace('Application pool identities MUST receive only the minimum path, certificate, registry, network, and service permissions required', 'Application pool identities should be limited').
                Replace('Production bindings MUST explicitly identify hostname, port, protocol, SNI, and certificate', 'Production bindings should identify relevant TLS details').
                Replace('Wildcard bindings require High or Critical review', 'Wildcard bindings should be reviewed').
                Replace('`web.config` and deployment logs MUST NOT contain plaintext secrets', 'web config and logs should not contain secrets').
                Replace('Successful file copy or site start MUST NOT be treated as application readiness', 'Site start should be checked').
                Replace('Hosting bundle/runtime compatibility MUST be validated for hosted .NET applications under [AGENTS_DotNet.md](AGENTS_DotNet.md)', 'Hosted runtime compatibility should be reviewed')
            Set-Content -LiteralPath $path -Value $text -Encoding utf8
            Invoke-AgentStandardsValidator -Path $script:tempRoot | Should -Not -Be 0
        }

        It 'fails missing infrastructure Windows Service quoting, directory, and ACL controls' {
            $script:tempRoot = New-AgentStandardsFixture
            $path = Join-Path $script:tempRoot 'agents/AGENTS_Infrastructure.md'
            $text = (Get-Content -LiteralPath $path -Raw).
                Replace('Every Windows Service infrastructure change MUST define service name, display name, description, binary path, binary arguments, quoted path behavior', 'Windows Service changes should define service metadata').
                Replace('Service binary paths containing spaces MUST be safely quoted', 'Service binary paths should be checked').
                Replace('Unquoted service paths are prohibited', 'Unquoted service paths should be avoided').
                Replace('Service executable, configuration, and working directories MUST NOT be writable by untrusted or ordinary users', 'Service directories should be protected').
                Replace('Service Control Manager ACLs MUST prevent unauthorized reconfiguration, start, stop, delete, or binary-path changes', 'Service ACLs should be reviewed').
                Replace('Secrets MUST NOT be embedded in ImagePath, command-line arguments, registry values, or logs', 'Secrets should not be embedded in service configuration').
                Replace('A service being in Running state MUST NOT be treated as full application readiness', 'Running services should be checked')
            Set-Content -LiteralPath $path -Value $text -Encoding utf8
            Invoke-AgentStandardsValidator -Path $script:tempRoot | Should -Not -Be 0
        }

        It 'fails missing infrastructure systemd user, capability, and filesystem controls' {
            $script:tempRoot = New-AgentStandardsFixture
            $path = Join-Path $script:tempRoot 'agents/AGENTS_Infrastructure.md'
            $text = (Get-Content -LiteralPath $path -Raw).
                Replace('Every systemd service change MUST define unit name, description, User, Group', 'systemd changes should define unit metadata').
                Replace('User and Group MUST be explicit', 'User and Group should be documented').
                Replace('Root execution requires High or Critical review', 'Root execution should be reviewed').
                Replace('NoNewPrivileges SHOULD be enabled where supported', 'NoNewPrivileges can be considered').
                Replace('CapabilityBoundingSet and AmbientCapabilities MUST be minimized', 'Capabilities should be reviewed').
                Replace('ProtectSystem, ProtectHome, PrivateTmp, PrivateDevices, ProtectKernelTunables, ProtectKernelModules, ProtectControlGroups, RestrictAddressFamilies, RestrictNamespaces, LockPersonality, MemoryDenyWriteExecute, and SystemCallFilter MUST be reviewed where supported', 'systemd protections should be reviewed').
                Replace('EnvironmentFile and secret files MUST not be world-readable', 'Environment files should be protected').
                Replace('Active state MUST NOT be treated as full application readiness', 'Active services should be checked')
            Set-Content -LiteralPath $path -Value $text -Encoding utf8
            Invoke-AgentStandardsValidator -Path $script:tempRoot | Should -Not -Be 0
        }

        It 'fails missing infrastructure DNS record, PTR, split-horizon, DNSSEC, SAN, and TTL controls' {
            $script:tempRoot = New-AgentStandardsFixture
            $path = Join-Path $script:tempRoot 'agents/AGENTS_Infrastructure.md'
            $text = (Get-Content -LiteralPath $path -Raw).
                Replace('Every DNS or IPAM change MUST define environment, DNS server or provider, zone, view or split-horizon scope, record name, record type, existing value', 'DNS changes should define useful record metadata').
                Replace('Existing records MUST be read and recorded before replacement or deletion', 'Existing records should be checked').
                Replace('Forward and reverse or PTR records MUST be considered together where reverse DNS is relevant', 'Reverse records should be considered').
                Replace('Split-horizon DNS views MUST be explicit', 'Split-horizon DNS should be documented').
                Replace('DNSSEC changes MUST define key, signer, chain-of-trust, rollover, and rollback review', 'DNSSEC changes should be reviewed').
                Replace('Certificate SANs and service hostnames MUST align before traffic cutover', 'Certificate names should align').
                Replace('TTL reduction for planned cutover MUST occur early enough to become effective before the change window', 'TTL should be reduced before cutover').
                Replace('Validation SHOULD query multiple authoritative or recursive resolvers appropriate to the environment', 'Validation can query resolvers').
                Replace('Rollback MUST identify the exact prior record values', 'Rollback should identify prior values')
            Set-Content -LiteralPath $path -Value $text -Encoding utf8
            Invoke-AgentStandardsValidator -Path $script:tempRoot | Should -Not -Be 0
        }

        It 'fails weakened infrastructure production image digest requirement' {
            $script:tempRoot = New-AgentStandardsFixture
            $path = Join-Path $script:tempRoot 'agents/AGENTS_Infrastructure.md'
            $text = (Get-Content -LiteralPath $path -Raw).
                Replace('Protected production container and Kubernetes deployment paths MUST pin images by immutable digest', 'Protected production images should use stable tags').
                Replace('Tags MAY remain as human-readable metadata but MUST NOT be the only production identity', 'Tags may be the production identity').
                Replace('Rollback MUST identify the exact prior digest', 'Rollback should identify prior image details').
                Replace('Image policy MUST reject unapproved digest substitution', 'Image policy should check substitutions')
            Set-Content -LiteralPath $path -Value $text -Encoding utf8
            Invoke-AgentStandardsValidator -Path $script:tempRoot | Should -Not -Be 0
        }

        It 'fails missing infrastructure temporary firewall lifecycle controls' {
            $script:tempRoot = New-AgentStandardsFixture
            $path = Join-Path $script:tempRoot 'agents/AGENTS_Infrastructure.md'
            $text = (Get-Content -LiteralPath $path -Raw).
                Replace('Every temporary network or firewall rule MUST define rule ID or name, owner, requestor, business reason, source, destination, protocol, port, environment, creation time, expiration time, change or ticket reference, monitoring, cleanup owner, and removal verification', 'Temporary network rules should define ownership').
                Replace('Temporary rules MUST have an explicit expiration', 'Temporary rules should have an expiration').
                Replace('Temporary rules MUST be removed automatically where the platform supports it, or have a documented manual removal task and owner', 'Temporary rules should be cleaned up').
                Replace('Expired rules MUST NOT remain active silently', 'Expired rules should be reviewed').
                Replace('Removal MUST be verified', 'Removal should be checked').
                Replace('Administrative interfaces such as SSH, RDP, WinRM, vCenter, hypervisor management, Kubernetes API, database administration, storage administration, and PKI administration MUST NOT be exposed publicly without Critical approval and compensating controls', 'Administrative interfaces should not be public').
                Replace('Emergency access requires break-glass controls, short expiration, audit, and removal verification', 'Emergency access should be controlled')
            Set-Content -LiteralPath $path -Value $text -Encoding utf8
            Invoke-AgentStandardsValidator -Path $script:tempRoot | Should -Not -Be 0
        }

        It 'fails missing infrastructure service account workload identity, rotation, and login controls' {
            $script:tempRoot = New-AgentStandardsFixture
            $path = Join-Path $script:tempRoot 'agents/AGENTS_Infrastructure.md'
            $text = (Get-Content -LiteralPath $path -Raw).
                Replace('Every service or workload identity MUST define identity type, owner, purpose, environment, scope, permissions, trust relationship, authentication mechanism, credential source, rotation, expiration', 'Service identities should define ownership and scope').
                Replace('Managed identity, workload identity, federated identity, gMSA, virtual account, or equivalent short-lived mechanism MUST be preferred where supported', 'Managed identities can be used').
                Replace('Long-lived static credentials MUST NOT be used where a supported workload identity can meet the requirement', 'Long-lived credentials should be avoided').
                Replace('Interactive login MUST be disabled for service accounts unless explicitly required and approved', 'Interactive login should be disabled').
                Replace('Credentials MUST have defined rotation and expiration', 'Credentials should rotate').
                Replace('Kubernetes service accounts MUST define token mounting, audience, expiration, projected-token behavior, and RBAC', 'Kubernetes service accounts should define token behavior').
                Replace('IAM policy simulation, access review, or equivalent negative-permission testing SHOULD be used where supported', 'Access review can be used').
                Replace('Removing access requires administrator and workload lockout analysis', 'Removing access should consider lockout').
                Replace('Privilege escalation paths through pass-role, impersonation, assume-role, token creation, group nesting, or delegated administration MUST be reviewed', 'Privilege escalation paths should be reviewed')
            Set-Content -LiteralPath $path -Value $text -Encoding utf8
            Invoke-AgentStandardsValidator -Path $script:tempRoot | Should -Not -Be 0
        }

        It 'fails when Terraform backendless validation is treated as authoritative' {
            $script:tempRoot = New-AgentStandardsFixture
            $path = Join-Path $script:tempRoot 'agents/AGENTS_Infrastructure.md'
            $text = (Get-Content -LiteralPath $path -Raw).
                Replace('`terraform init -backend=false` is suitable only for static initialization or validation where supported', 'terraform init backend false may be used for planning').
                Replace('A plan generated without the authoritative backend or state MUST NOT be treated as authoritative production plan evidence', 'Backendless plans may be production evidence').
                Replace('Backendless validation MUST NOT be used to claim drift detection, replacement accuracy, destroy accuracy, or no-change status', 'Backendless validation may claim no changes').
                Replace('Production plan evidence requires the approved backend, workspace, variables, credentials, state, and target context', 'Production plan evidence should include useful context')
            Set-Content -LiteralPath $path -Value $text -Encoding utf8
            Invoke-AgentStandardsValidator -Path $script:tempRoot | Should -Not -Be 0
        }

        It 'fails when CloudFormation change-set creation is treated as ordinary static validation' {
            $script:tempRoot = New-AgentStandardsFixture
            $path = Join-Path $script:tempRoot 'agents/AGENTS_Infrastructure.md'
            $text = (Get-Content -LiteralPath $path -Raw).
                Replace('`aws cloudformation create-change-set` is a credentialed API mutation', 'CloudFormation change-set creation is static validation').
                Replace('It MUST NOT be presented as ordinary offline static validation', 'It may be presented as ordinary static validation').
                Replace('Unused change sets MUST be deleted or expired according to policy', 'Unused change sets should be reviewed later').
                Replace('Creation success does not prove execution success or stack readiness', 'Creation success proves stack readiness')
            Set-Content -LiteralPath $path -Value $text -Encoding utf8
            Invoke-AgentStandardsValidator -Path $script:tempRoot | Should -Not -Be 0
        }

        It 'fails unsafe infrastructure weakening phrases' {
            $script:tempRoot = New-AgentStandardsFixture
            Add-Content -LiteralPath (Join-Path $script:tempRoot 'agents/AGENTS_Infrastructure.md') -Value @'

Apply may run without a plan.
Cached CLI context is sufficient for production.
Empty target means all resources.
State locking may be bypassed.
State files may be committed.
Force-unlock is always safe.
Manual state editing is acceptable by default.
Floating latest tags are preferred.
GitHub Actions may use mutable tags.
Destroy requires no approval.
Public ingress from anywhere is safe.
Wildcard IAM is acceptable.
Plaintext secrets may be stored in tfvars.
Certificate validation may be disabled.
Snapshots prove restore capability.
Production may be used when test environments are unavailable.
Cluster-admin is the default.
Privileged containers are preferred.
Unbounded autoscaling is acceptable.
Policy failures may be ignored.
Apply success proves readiness.
Missing infrastructure validation may be marked Passed.
Everyone may have write access to IIS content.
Wildcard IIS bindings require no review.
IIS site started means application ready.
Unquoted Windows Service paths are acceptable.
Service executable directories may be user writable.
Service accounts may log on interactively by default.
Windows Service Running state proves readiness.
systemd services should run as root by default.
NoNewPrivileges is unnecessary.
World-readable environment files may contain secrets.
systemd active state proves readiness.
PTR records never matter.
Split-horizon DNS does not need review.
DNSSEC changes require no rollover plan.
DNS TTL may be lowered at cutover time with immediate effect.
Certificate SANs do not need to match DNS.
Production image tags are sufficient without digests.
Latest tags are acceptable for production.
Temporary firewall rules need no expiration.
Public administrative interfaces are acceptable.
Emergency firewall access may remain indefinitely.
Long-lived service-account credentials are preferred.
Interactive login may remain enabled for service accounts.
Kubernetes service-account tokens need no review.
Backendless Terraform plans are authoritative production evidence.
CloudFormation change-set creation is offline static validation.
Missing Infrastructure 1.1.1 validation may be marked Passed.
'@
            Invoke-AgentStandardsValidator -Path $script:tempRoot | Should -Not -Be 0
        }
    }
}
