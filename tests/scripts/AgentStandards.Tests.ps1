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

        It 'fails an infrastructure standard version below the required minimum' {
            $script:tempRoot = New-AgentStandardsFixture
            $path = Join-Path $script:tempRoot 'agents/AGENTS_Infrastructure.md'
            $text = (Get-Content -LiteralPath $path -Raw).Replace('| Version | 1.1.0 |', '| Version | 1.0.0 |')
            Set-Content -LiteralPath $path -Value $text -Encoding utf8
            Invoke-AgentStandardsValidator -Path $script:tempRoot | Should -Not -Be 0
        }

        It 'fails a malformed infrastructure standard semantic version' {
            $script:tempRoot = New-AgentStandardsFixture
            $path = Join-Path $script:tempRoot 'agents/AGENTS_Infrastructure.md'
            $text = (Get-Content -LiteralPath $path -Raw).Replace('| Version | 1.1.0 |', '| Version | current |')
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
'@
            Invoke-AgentStandardsValidator -Path $script:tempRoot | Should -Not -Be 0
        }
    }
}
