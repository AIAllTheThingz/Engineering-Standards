# AGENTS Worker Service Standard

| Field | Value |
| --- | --- |
| Status | Active |
| Version | 1.1.0 |
| Owner role | Engineering Standards Maintainers |
| Last reviewed | 2026-06-20 |
| Changelog | See [../CHANGELOG.md](../CHANGELOG.md). |

## Purpose

This document defines enforceable enterprise requirements for AI agents creating, reviewing, or modifying worker services, background jobs, queue consumers, schedulers, daemons, script runners, batch processors, ETL and ELT workers, report generators, notification workers, file watchers, reconciliation jobs, dead-letter reprocessors, retry processors, and multi-step orchestration workers.

It inherits [AGENTS_Base.md](AGENTS_Base.md), the repository-root [../AGENTS.md](../AGENTS.md), and the governance documents. It does not replace application, database, PowerShell, integration, or infrastructure standards. It adds worker-specific controls for durable execution, state, ownership, delivery semantics, idempotency, retry, replay, cancellation, side effects, observability, capacity, deployment, and completion evidence.

When this standard says a control is required, agents MUST implement it, prove it already exists, record a valid `NotApplicable`, `NotRun`, or `Blocked` status with reason, or reference an approved active exception.

## Applicability And Inheritance

This standard applies to:

- .NET Worker Services, `BackgroundService`, and `IHostedService` implementations.
- Windows Services, Linux daemons, containers, Kubernetes workers, serverless workers, scheduled tasks, cron jobs, and long-running service loops.
- SQL-polled workers, queue consumers, message processors, event handlers, topic/subscription processors, file watchers, and webhook handoff processors.
- Batch processors, ETL and ELT workers, report generators, notification workers, reconciliation workers, maintenance jobs, retry/replay processors, dead-letter reprocessors, and orchestration workers.
- Script-runner workers and child-process executors that run approved scripts or operations from a catalog.
- Producer/consumer contracts where a web application authenticates users, presents approved jobs, validates form or CSV input, creates SQL job records, workers atomically claim work, output and errors are captured safely, audit data is persisted, reports are stored under approved paths, and authorized users view status and report links.

Cross-standard handoffs are mandatory:

- .NET `BackgroundService`, `IHostedService`, dependency injection, cancellation, `HttpClient`, process execution, Data Protection, configuration, and hosting MUST also apply [AGENTS_DotNet.md](AGENTS_DotNet.md).
- SQL job tables, atomic claims, leases, state persistence, migrations, indexes, transactions, backfills, and stored routines MUST also apply [AGENTS_Database.md](AGENTS_Database.md).
- PowerShell scripts, modules, configuration, credentials, remoting, reporting, Authenticode, `WhatIf`, `DryRun`, and scheduled automation MUST also apply [AGENTS_PowerShell.md](AGENTS_PowerShell.md).
- Vendor APIs, webhooks, queues, message brokers, SMTP, SFTP, and cross-system workflows MUST also apply [AGENTS_Integration.md](AGENTS_Integration.md).
- Windows Services, containers, Kubernetes, service accounts, secrets infrastructure, networking, storage, schedulers, and deployment infrastructure MUST also apply [AGENTS_Infrastructure.md](AGENTS_Infrastructure.md).

Local instructions MAY strengthen this standard. They MUST NOT weaken root, base, security, review, evidence, validation, or exception controls.

## Normative Terminology

`MUST` and `MUST NOT` are mandatory. `SHOULD` and `SHOULD NOT` are expected controls that require recorded rationale when omitted. `MAY` is optional.

`Worker` means unattended code that accepts, finds, schedules, claims, processes, or finalizes work outside the immediate authenticated user request. `Job` and `message` are used broadly for durable work items. `Lease` means time-limited ownership of work. `Heartbeat` means periodic evidence that the current owner is still active. `Poison work` means work that cannot complete after policy-defined attempts or cannot be processed safely. `Dead-letter` means durable isolation of poison work for review or governed replay.

`NotRun` means validation did not execute. `Blocked` means validation could not complete because a queue, scheduler, database, service host, credential, script runner, provider, container runtime, deployment target, or approval was unavailable. Agents MUST NOT convert unavailable worker validation into `Passed`.

## Required Discovery

Before editing worker behavior, agents MUST inspect and record the relevant subset of:

- Worker language, runtime, framework, version, hosting model, deployment model, and service identity.
- Host type: Windows Service, systemd, container, Kubernetes, scheduled task, cron, serverless, console host, or another host.
- Trigger model: SQL polling, queue, topic/subscription, event stream, schedule, file watcher, webhook handoff, manual command, or hybrid.
- Queue, broker, database, scheduler, filesystem, API, script runner, and provider versions.
- Job table, message schema, payload schema, input schema, CSV schema, artifact schema, and schema versioning.
- State machine, allowed transitions, terminal states, retryable states, and manual override paths.
- Claim, lease, lock, visibility timeout, heartbeat, acknowledgement, and ownership model.
- Poll interval, jitter, batch size, prefetch, concurrency, partitioning, ordering, and fairness.
- Idempotency key, uniqueness scope, duplicate-prevention strategy, retention period, and reconciliation behavior.
- Retry classification, attempt count, delay, backoff, jitter, retry budget, and provider `Retry-After` behavior.
- Poison-work, dead-letter, replay, requeue, manual retry, and cancellation controls.
- Side effects, including database writes, scripts, child processes, files, emails, APIs, billing, deletion, infrastructure changes, notifications, reports, and artifacts.
- Transaction boundaries, outbox/inbox use, durable handoff, and partial-failure behavior.
- Expected execution duration, maximum runtime, timeouts, hung-work detection, and graceful shutdown timeout.
- Deployment overlap, multi-instance behavior, rolling compatibility, scaling limits, and drain behavior.
- Scheduling time zone, daylight saving time behavior, missed-run behavior, overlap behavior, and manual-run behavior.
- Input paths, upload paths, artifact paths, approved storage roots, retention, cleanup, and download authorization.
- Security identity, permissions, credential sources, tenant boundaries, data classification, retention, and audit requirements.
- Logs, metrics, traces, alerts, dashboards, health checks, runbooks, and operational ownership.
- Existing tests, local emulators, test queues, test databases, test schedulers, mocks, fakes, fixtures, and safe child-process tests.
- Existing user changes from `git status --short`.

Agents MUST inspect adjacent job producers, state tables, queue configuration, consumers, retry code, process-launch code, and operational documentation before changing worker behavior. Guessing from file names or framework conventions is insufficient.

## Risk Classification

Worker work MUST be classified using [../governance/RISK_CLASSIFICATION.md](../governance/RISK_CLASSIFICATION.md). Risk MUST be reevaluated when target count, side-effect scope, execution identity, retry count, schedule, concurrency, tenant scope, or production destination changes.

Critical by default:

- Broad replay or requeue, mass notification, mass deletion, broad data repair, billing or payment side effects, cross-tenant processing, privileged script execution, production infrastructure changes, security-control disablement, unbounded process execution, queue purge, dead-letter purge, lease bypass, duplicate-prevention disablement, arbitrary command or script execution, credential or signing-key changes, and changing safety defaults from `DryRun` to execute.

High by default:

- Retry behavior, job claiming, lease renewal, visibility timeout, concurrency, scheduling, state transitions, queue acknowledgements, database polling, external API side effects, report publishing, file movement, email notification, script catalog behavior, child-process execution, cancellation, timeout behavior, and deployment scaling.

Moderate examples:

- Metrics-only changes, additional structured logs without sensitive data, nonproduction synthetic fixtures, and documentation-only updates with no behavior change.

Agents MUST NOT lower risk classification merely to reduce validation, approval, or evidence requirements.

## Worker Execution Models

Every worker MUST declare its execution model:

- Polling worker.
- Push or queue consumer.
- Scheduled worker.
- Event-driven worker.
- File-watcher worker.
- Batch worker.
- Script-runner worker.
- Orchestrator.
- Hybrid.

The model MUST define trigger, ownership, durability, delivery assumptions, ordering, concurrency, retry, cancellation, timeout, completion acknowledgement, failure handling, recovery, observability, and deployment overlap. No worker may rely on process memory as the sole source of truth for durable work.

## Job And Message State Model

Every durable worker MUST define a documented state machine. The standard does not require exact state names, but the worker MUST define equivalent lifecycle phases where applicable, such as `Pending`, `Scheduled`, `Claimed`, `Running`, `Succeeded`, `Failed`, `RetryScheduled`, `CancelRequested`, `Cancelled`, `TimedOut`, `DeadLettered`, `Skipped`, and `PartiallySucceeded`.

The state model MUST define:

- Allowed transitions, disallowed transitions, terminal states, retryable states, and manual override transitions.
- Ownership fields, attempt number, state version or concurrency token, and audit history.
- Created, scheduled, claimed, started, heartbeat, completed, and next-attempt timestamps.
- Correlation ID, idempotency key, job type and version, input schema version, worker instance ID, cancellation reason, failure category, sanitized failure summary, artifact or report references, and tenant-safe identifiers where applicable.

State transitions MUST be validated. Terminal jobs MUST NOT silently return to active states. Manual override requires authorization and audit. Job state and side-effect state MUST NOT contradict silently. Success MUST mean required work completed, not merely that a process launched, message arrived, or handler returned. Partial success MUST be explicit.

## Durable Job Ownership And Atomic Claiming

For SQL-polled workers, claiming MUST be atomic. A claim MUST use one transaction or engine-supported atomic statement, a concurrency predicate, a claim or lease owner, claim timestamp, lease expiration, state version or concurrency token, maximum claim batch size, deterministic ordering where priority matters, and indexes supporting claim queries.

Agents MUST NOT implement a check-then-update race, broad table lock merely for convenience, duplicate ownership, memory-only ownership, or claim logic that depends on a single worker instance. Database-specific review is required under [AGENTS_Database.md](AGENTS_Database.md); this standard does not prescribe one universal SQL statement.

Engine-appropriate patterns MAY include SQL Server `UPDATE` with `OUTPUT` and reviewed locking hints, `SELECT FOR UPDATE SKIP LOCKED` where supported, compare-and-swap using a version column, or queue-native visibility and acknowledgement semantics.

For queue workers, a message MUST NOT be acknowledged before durable completion or an approved durable handoff. Visibility timeout, lock duration, or lease duration MUST cover expected work or be renewed safely. Ack, nack, reject, abandon, defer, complete, and dead-letter semantics MUST be explicit. Message loss and duplicate-delivery behavior MUST be documented.

## Leases, Heartbeats, And Abandoned-Work Recovery

Workers that own durable work MUST define lease duration, heartbeat interval, renewal ownership check, maximum extension, stale-worker detection, recovery delay, recovery authorization, attempt increment behavior, safe reclamation, clock source, clock-skew handling, and observability for expired leases.

A worker MUST stop or fail safely if it loses ownership. Lease renewal MUST verify the current owner and state version. Leases MUST NOT be overwritten by another worker while an active owner is valid. A stale lease MUST NOT automatically prove the prior side effect did not occur. Recovery MUST account for uncertain completion. Reclaimed work MUST be idempotent or reconciled before retry. Heartbeat failure MUST NOT be hidden. Repeated reclamation MUST alert.

Database, broker, or server time SHOULD be used where clock differences affect leases. Local workstation time MUST NOT be the authority for production lease decisions.

## Delivery Semantics

Every worker MUST declare its delivery contract: at-most-once, at-least-once, effectively-once through idempotency, or another documented model.

Exactly-once delivery is prohibited as a claim unless proven end-to-end with durable constraints, acknowledgement behavior, producer and consumer contracts, idempotency, side-effect reconciliation, and failure-mode evidence. At-least-once delivery MUST assume duplicate messages. At-most-once delivery MUST document loss risk. Queue acknowledgement, transactions, outbox, inbox, deduplication, and side effects MUST be reviewed together. Producer and consumer contracts MUST agree on message identity and version. Message delivery success MUST NOT be confused with business-operation success.

## Idempotency And Duplicate Prevention

State-changing workers MUST be idempotent unless an approved design documents why they cannot be. Idempotency design MUST define durable idempotency key, uniqueness scope, retention period, duplicate behavior, in-progress behavior, completed behavior, failed-attempt behavior, payload hash or comparison where needed, tenant boundary, concurrency enforcement, unique constraint or equivalent where appropriate, reconciliation behavior, side-effect deduplication, and replay behavior.

In-memory deduplication alone is insufficient for durable work. "Check then act" without concurrency protection is insufficient. Duplicate input MUST NOT broaden scope. Empty input MUST NOT mean all jobs, all targets, all tenants, or all files. Exactly-once terminology requires evidence. Email, API calls, scripts, file writes, notifications, billing, and database writes require their own duplicate analysis.

## Ordering And Concurrency

Workers MUST define maximum global concurrency and maximum concurrency per tenant, target, partition, script, job type, external dependency, or other safety boundary where applicable. They MUST define ordering guarantee, partition key, out-of-order behavior, parallelism safety, resource limits, fairness, starvation behavior, lock or semaphore ownership, queue prefetch, batch size, and backpressure behavior.

Unbounded concurrency is prohibited. High queue depth MUST NOT automatically cause unlimited scale-out. Per-target serialization MUST be used where concurrent mutation would be unsafe. Concurrency changes require load and side-effect analysis. Ordering assumptions MUST be tested. Global locks require justification and failure recovery. Multi-instance deployment behavior MUST be proven or recorded as `NotRun` with reason.

## Polling Safety

SQL, API, or filesystem polling workers MUST define poll interval, jitter, empty-poll delay, error backoff, batch size, query timeout, cancellation, index usage, connection handling, maximum loop rate, clock or time source, pagination strategy, and shutdown behavior.

Busy loops are prohibited. Empty polls MUST delay. Failure loops MUST back off. Polling MUST support cancellation. Polling MUST NOT load the entire pending set into memory. SQL polling MUST use bounded queries and appropriate indexes. Polling failures MUST NOT be logged as success. Thundering-herd behavior MUST be mitigated.

File watchers MUST account for duplicate events, partial writes, rename patterns, restart reconciliation, path boundaries, maximum file size, safe file names, and producer readiness. Files MUST be considered ready only after an explicit readiness rule, such as atomic rename, completion marker, stable size, checksum, or provider-specific completion signal.

## Scheduling And Recurring Jobs

Scheduled jobs MUST define schedule expression, time zone, start time, end time where relevant, overlap behavior, missed-run behavior, catch-up behavior, manual-run behavior, disabled or paused behavior, jitter, maximum catch-up count, holiday or business calendar behavior where relevant, and approval for production schedule changes.

Schedule changes are behavior changes. Overlap MUST be explicitly allowed or prevented. Missed jobs MUST NOT silently replay without limits. Catch-up storms are prohibited. Manual runs MUST use the same authorization and validation controls as scheduled runs. Schedule evaluation MUST be testable.

## Time Zones, Daylight Saving Time, And Clock Behavior

Workers MUST define IANA or Windows time-zone identifiers as appropriate. Durable timestamps MUST use UTC unless an approved interoperable contract exists. Local time conversion MUST occur at display or scheduling boundaries with documented rules.

Local-time schedules MUST define daylight saving time skipped-time behavior, repeated-time behavior, ambiguous local-time behavior, and clock-skew tolerance. Duration measurement SHOULD use monotonic time where supported. Lease decisions SHOULD use database, broker, or server clock ownership when clock differences matter. Local workstation time assumptions are prohibited. Tests SHOULD cover DST transitions for local-time schedules.

## Retry Classification And Backoff

Retries MUST target transient failures only. Workers MUST define retryable and nonretryable categories, maximum attempt count, bounded delay, exponential backoff and jitter where appropriate, provider `Retry-After` handling where applicable, retry budget, cancellation preservation, idempotency preservation, attempt count recording, next-attempt time, and retry-storm mitigation.

Automatic retries MUST NOT apply to validation failures, authentication failures without a credential refresh path, authorization failures, unsupported input, permanent not-found conditions, business-rule rejection, signature failure, corrupt payload, explicit cancellation, or unsafe uncertain side effects without reconciliation. A retry MUST re-evaluate ownership and current state.

## Poison Work And Dead-Letter Handling

Workers MUST define poison criteria, maximum attempts, dead-letter destination, original message or job identity, sanitized failure details, attempt history, first and last failure timestamps, payload retention classification, alerting, operator ownership, replay authorization, replay limits, fix-before-replay requirements, expiration, and purge policy.

Poison work MUST NOT disappear. Dead-letter storage MUST be durable. Sensitive payloads MUST be protected. Dead-letter purge is Critical by default. Dead-letter replay MUST create an audit record. Replaying without correcting the failure cause is prohibited unless explicitly justified. Bulk replay requires blast-radius controls, `DryRun` or preview, target counts, limits, approval, and stop conditions.

## Replay And Manual Retry

Replay and manual retry MUST define authorization, reason, operator identity, scope, preview, maximum job count, tenant or target restrictions, idempotency review, current-state validation, new attempt identity, link to original work, audit trail, stop or cancel control, and result summary.

Empty selection MUST NOT mean all jobs. Wildcard replay is prohibited unless Critical controls are satisfied. Terminal-state mutation MUST be explicit. Manual retry MUST NOT erase the original failure. Replay MUST NOT silently reuse expired credentials or obsolete inputs. Old job-schema versions require compatibility handling.

## Cancellation And Graceful Shutdown

Workers MUST support cooperative cancellation. Cancellation tokens or equivalent cancellation signals MUST propagate through polling, queue receives, delays, database calls, API calls, file operations, script execution, child processes, retries, and long-running loops where the platform supports it.

Cancellation MUST define `CancelRequested` or equivalent state, who may request cancellation, authorization, cancellation reason, timing, race behavior with completion, cleanup, partial output handling, and final state. A worker that observes cancellation MUST stop accepting new work for that job, persist the correct state, and avoid claiming success unless completion actually happened.

Graceful shutdown MUST define drain behavior, stop accepting new work, in-flight handling, maximum shutdown duration, lease release or heartbeat stop behavior, process cleanup, acknowledgement behavior, and readiness transition. Shutdown MUST NOT acknowledge incomplete work as successful.

## Timeouts And Hung-Work Recovery

Workers MUST define job timeout, operation timeout, dependency timeout, queue receive timeout, database command timeout, script/process timeout, shutdown timeout, and maximum runtime. Hung-work recovery MUST define detection, state transition, cancellation or termination, process-tree cleanup, artifact cleanup, lease handling, and retry or dead-letter behavior.

Unbounded execution is prohibited. Child processes MUST have timeouts and process-tree cleanup where supported. Process launch is not operation success. Exit code, timeout, stderr, and output validation determine process result according to the approved contract.

## Partial Failure And Compensation

Workers MUST define partial-failure behavior for multi-step work. The design MUST identify which steps are durable, which side effects can repeat, which steps require compensation, which failures are terminal, which are retryable, and how operators reconcile uncertain outcomes.

Partial success MUST be explicit. Workers MUST NOT hide partial failure by marking the parent job `Succeeded`. Compensation MUST be tested where feasible or recorded as `NotRun` with reason. Operators MUST have enough sanitized evidence to recover without access to secrets or raw sensitive payloads.

## Side-Effect Ordering And Transactional Handoff

Side effects MUST be ordered to preserve correctness under retries, crashes, duplicate delivery, and cancellation. Database state changes, queue acknowledgement, external API calls, emails, reports, file movement, billing, notifications, and script execution MUST be reviewed together.

Workers SHOULD use outbox, inbox, durable handoff, idempotency keys, or equivalent patterns when crossing transactional boundaries. A message MUST NOT be acknowledged before durable completion or an approved durable handoff. External side effects inside database transactions MUST follow [AGENTS_Database.md](AGENTS_Database.md). Transaction commit uncertainty MUST be reconciled before unsafe retry. Producer and consumer state MUST NOT contradict silently.

## Script Runner And Child-Process Execution

Script-runner workers MUST use an approved script or job catalog. The catalog MUST define script identity, version, owner, allowed parameters, input schema, execution identity, working directory, timeout, accepted exit codes, output contract, artifact contract, risk classification, approval requirements, and rollback or recovery behavior.

Arbitrary scripts, paths, commands, shell snippets, or user command text MUST NOT be executed. User command text MUST NOT be passed to a shell. Native process calls MUST use safe argument APIs or argument arrays where practical, not string-built shell commands. Secrets MUST NOT be passed in visible command-line arguments. Working directory, executable path, script path, report path, and artifact path MUST be allowlisted or resolved beneath approved roots.

Workers MUST capture stdout, stderr, exit code, start time, end time, duration, timeout, cancellation, and sanitized output. Sensitive stdout and stderr MUST be redacted or suppressed. Accepted exit codes MUST be explicit. Nonzero exit codes MUST NOT be treated as success unless the catalog explicitly defines them as accepted for that operation. Process-tree cleanup is required for timeouts and cancellation where supported.

## Input, File, And Parameter Validation

Worker input MUST be validated before durable enqueue where feasible and again before execution where trust boundaries require it. Validation MUST cover job type, version, tenant, authorization, target count, empty input, duplicate input, unsupported input, CSV headers, CSV row limits, file size, file type, encoding, path boundaries, parameter types, ranges, allowlists, mutually exclusive options, and schema version.

Empty input MUST fail safely and MUST NOT mean all jobs, all tenants, all rows, all files, or all targets. Duplicate input MUST NOT broaden scope. Uploaded files and generated artifacts MUST use approved roots, safe file names, traversal protection, malware or content scanning where required, retention, cleanup, and authorization checks. CSV examples and fixtures MUST be synthetic.

## Security, Identities, And Least Privilege

Workers MUST run with least privilege. The execution identity MUST be explicit for the host, database, queue, storage, API, script runner, scheduler, and artifact store. Submission identity, approval identity, runtime identity, and elevated break-glass identity MUST be distinct where applicable.

Workers MUST enforce tenant boundaries and resource authorization server-side. A user who can submit a job MUST NOT automatically be allowed to run every catalog entry, target every tenant, replay every job, download every artifact, or view every failure. Manual replay, cancellation, dead-letter purge, schedule changes, and concurrency changes require authorization and audit.

Silent fallback to elevated identity is prohibited. Privileged script execution is Critical by default. Workers MUST NOT disable security controls, bypass certificate validation, ignore webhook signatures, or broaden scopes for convenience.

## Secrets And Credentials

Secrets MUST come from approved secret stores, managed identity, workload identity, certificate authentication, platform secret injection, or another approved mechanism. Secrets MUST NOT appear in source, ordinary configuration, job payloads, queue messages, command-line arguments, process listings, logs, traces, reports, artifacts, screenshots, or evidence.

Credential resolution MUST define source, precedence, rotation behavior, failure behavior, and environment separation. Expired, missing, or unauthorized credentials MUST fail safely and MUST NOT silently fall back to weaker credentials. Replay MUST NOT silently reuse expired credentials. If a secret may have been exposed, agents MUST stop normal completion claims and report remediation requirements.

## Data Classification, Retention, And Privacy

Worker payloads, logs, audit records, reports, artifacts, dead-letter storage, and evidence MUST be classified as Public, Internal, Confidential, Regulated, or Secret/Restricted according to repository policy. Classification MUST drive encryption, access, retention, redaction, masking, deletion, export, and review requirements.

Workers MUST minimize payloads, avoid storing full sensitive payloads where references are sufficient, define retention periods, support cleanup for abandoned artifacts, and preserve audit records required for accountability. Dead-letter and replay systems MUST protect sensitive payloads. Reports containing sensitive data MUST require authorization and SHOULD use expiring links where appropriate.

## Logging, Metrics, Tracing, And Audit

Structured logs MUST include applicable correlation ID, job or message ID, job type and version, attempt number, worker instance, tenant-safe identifier, state transition, duration, retry category, lease ownership event, cancellation event, exit code, artifact identifier, external dependency name, and outcome.

Logs MUST NOT include secrets, tokens, passwords, secret-bearing connection strings, private keys, raw regulated data, full sensitive payloads, unredacted command lines, sensitive stdout/stderr, or arbitrary uploaded file contents.

Metrics SHOULD include queue depth, oldest work age, claim rate, success/failure/cancel/timeout rate, retry rate, dead-letter count, lease expiration, processing duration, wait duration, concurrency, backpressure, dependency latency, process exit-code categories, artifact failures, schedule delay, and worker restarts.

Tracing and correlation MUST flow across producer, worker, database, queue, process, API, and artifact operations where supported. Audit events MUST record who submitted, approved, cancelled, replayed, or changed high-risk worker behavior; what job/script/version and targets were affected; when; why; result; and correlation ID.

## Health, Readiness, Liveness, And Startup

Workers MUST define liveness, readiness, and startup checks. Startup validation MUST confirm critical configuration, secret or certificate readiness, database and queue connectivity, migration or schema compatibility, script catalog readiness, writable artifact paths where required, scheduler readiness where applicable, and health-check timeout.

Health checks MUST have no side effects. Liveness MUST NOT fail merely because an optional dependency is unavailable. Readiness MUST fail when the worker cannot safely accept work. A worker MUST NOT claim jobs before startup validation completes. Health endpoints MUST NOT expose secrets, connection strings, sensitive queue names, topology, or raw errors. Readiness MUST account for draining during shutdown.

## Capacity, Rate Limiting, Backpressure, And Overload

Workers MUST define capacity assumptions, concurrency limits, queue prefetch limits, memory limits, CPU limits, disk and artifact limits, database connection limits, external API rate limits, per-tenant fairness, maximum queue age, overload behavior, backpressure, admission control, alert thresholds, and scaling limits.

Workers MUST NOT accept work indefinitely without capacity planning. Workers MUST NOT load entire queues, files, or pending sets into memory. Scale-out MUST preserve lease and idempotency correctness. Retry storms MUST NOT amplify outages. Backpressure MUST NOT be represented as success. Load shedding applies only to explicitly droppable work. Critical work MUST define priority and starvation behavior.

## Configuration And Feature Flags

Worker configuration MUST define poll intervals, batch sizes, prefetch, concurrency, timeouts, retries, backoff, jitter, lease values, heartbeat values, retention, artifact paths, allowed job types, allowed script catalog entries, and schedule settings. Strongly typed configuration and startup validation MUST be used where the platform supports them.

Configuration MUST have safe defaults, environment separation, bounds validation, no zero-delay accidental busy loop, no unlimited retry, no unlimited concurrency, no secrets in ordinary configuration, and no silent production fallback. Feature flags for risky rollout MUST define owner, purpose, default state, expiration, metrics, rollback, and compatibility behavior. Configuration changes that alter worker behavior are behavior changes and require validation.

## Deployment, Scaling, And Rolling Compatibility

Worker deployment MUST define deployment model, service name, runtime identity, instance count, rolling deployment behavior, old/new worker compatibility, job/message schema version compatibility, queue/topic compatibility, database migration order, drain behavior, shutdown grace, lease behavior during restart, rollback, feature flags, health checks, post-deployment observation, scaling limits, single-instance assumptions, and multi-instance tests.

Build success is not deployment success. Service installation is not runtime success. Process start is not readiness. Rollback MUST account for jobs created by newer versions. Old workers MUST NOT process incompatible new job types. New workers MUST handle or reject old job schemas explicitly. Deployment MUST NOT duplicate scheduled execution. Production schedule or concurrency changes require approval. Worker upgrades MUST NOT silently orphan active jobs.

## Testing Requirements

Worker changes MUST include applicable tests or justified statuses. Tests SHOULD use synthetic data, nonproduction queues and databases, local emulators, fakes, mocks, harmless child processes, ephemeral environments where approved, and deterministic clocks for schedule and lease behavior where possible. Production MUST NOT be used merely because a test environment is unavailable.

Applicable tests include state transitions, disallowed transitions, terminal-state behavior, atomic claiming, competing workers, lease renewal, lease loss, stale claim recovery, heartbeat failure, duplicate messages, idempotent rerun, concurrent duplicate delivery, ordering, partition behavior, retryable failure, nonretryable failure, backoff, jitter bounds, retry exhaustion, poison work, dead-lettering, replay authorization, bulk replay limits, cancellation before start, cancellation while running, cancellation/completion race, graceful shutdown, forced termination, timeouts, hung child processes, process-tree cleanup, partial failure, compensation, outbox/inbox behavior, queue ack timing, SQL polling empty state, polling error backoff, schedule overlap, missed runs, DST skipped and repeated times, input schema, empty input, CSV validation, maximum target count, unauthorized script or job, arbitrary command/path rejection, parameter injection attempts, secret redaction, artifact authorization and path boundaries, health readiness and liveness, configuration validation, rolling-version compatibility, multi-instance behavior, and capacity/backpressure behavior.

Skipped or unavailable tests require exact `NotRun`, `Blocked`, or `NotApplicable` status and reason.

## Validation Commands

Repository-root [../AGENTS.md](../AGENTS.md) is the source of truth for repository validation. Worker commands are conditional on language, runtime, host, queue, database, scheduler, and tooling. Evidence MUST record exact commands, working directory, tool version, exit code, test counts, and status. Missing infrastructure MUST be recorded as `NotRun` or `Blocked`. A build does not prove queue, schedule, lease, database, process, service, container, or deployment behavior.

.NET examples:

```powershell
dotnet --info
dotnet restore
dotnet build --no-restore --configuration Release
dotnet test --no-build --configuration Release
```

Windows Service inspection examples:

```powershell
Get-Service -Name "<service-name>"
sc.exe qc "<service-name>"
```

PowerShell examples:

```powershell
Invoke-Pester -Path tests -Output Detailed
Invoke-ScriptAnalyzer -Path . -Recurse -Severity Error
```

Container examples:

```powershell
docker build --tag "<worker-image>:<version>" .
docker run --rm "<worker-image>:<version>"
```

Kubernetes examples:

```powershell
kubectl apply --dry-run=server -f ".\deployment.yaml"
kubectl rollout status deployment/<worker-name>
```

Only commands valid for the repository's supported tooling SHOULD be used. Agents MUST NOT imply service, Docker, Kubernetes, SQL, queue, scheduler, deployment, GitHub Actions, or artifact validation ran when unavailable.

## Documentation Requirements

README files and runbooks MUST document worker purpose, runtime and host, trigger model, job/message schema, state machine, claim and lease model, delivery semantics, idempotency, ordering, concurrency, polling, scheduling, time zone and DST, retry policy, poison/dead-letter behavior, replay, cancellation, timeouts, side effects, script catalog and process execution where applicable, input schemas, configuration, secret sources, permissions, logs and metrics, health checks, capacity, deployment, scaling, rollback, recovery, troubleshooting, emergency stop, manual replay, artifact paths and retention, known limitations, and every public command-line option, environment variable, configuration key, job type, and operational mode.

Examples MUST be synthetic and safe.

## Completion Evidence

Completion evidence MUST align with [../governance/COMPLETION_EVIDENCE.md](../governance/COMPLETION_EVIDENCE.md) and root [../AGENTS.md](../AGENTS.md). Evidence for worker work MUST include exact files changed, exact commands, working directories, exit codes, tool versions, worker runtime and host, trigger model, queue/database/scheduler type, state-machine validation, claim/lease validation, delivery semantics, idempotency validation, duplicate test, retry/backoff test, poison/dead-letter test, replay test or status, cancellation test, graceful-shutdown test, timeout test, side-effect ordering, script/process validation where applicable, security and permission review, secret redaction test, input/file validation, health-check validation, concurrency/load result, deployment result, GitHub Actions status, artifact verification, remaining risks, approvals, and exceptions.

Permitted statuses are `Passed`, `Failed`, `Blocked`, `NotRun`, and `NotApplicable`. Unexecuted queue, database, scheduler, service, process, container, deployment, or GitHub validation MUST NOT be labeled `Passed`.

## Failure Behavior

Worker work is incomplete when state transitions are undefined, ownership is ambiguous, claiming is non-atomic, duplicate prevention is absent, exactly-once is claimed without proof, leases can be overwritten, lease loss is ignored, stale work is retried without idempotency or reconciliation, queue messages are acknowledged before durable completion, polling uses a busy loop, concurrency is unbounded, retries are unbounded, permanent failures are retried indefinitely, poison work disappears, dead-letter replay lacks authorization, empty replay scope can mean all jobs, cancellation is missing, shutdown accepts new work while draining, timeouts are absent, child processes can remain orphaned, process launch is treated as operation success, arbitrary scripts, paths, commands, or parameters can execute, secrets appear in arguments, logs, payloads, reports, artifacts, or evidence, side effects can repeat unsafely, partial failure is hidden, schedule overlap is undefined, DST behavior is undefined for local-time schedules, readiness allows unsafe job claiming, old/new worker versions are incompatible without controls, production schedule, replay, or concurrency changes lack approval, tests are skipped without exact status and reason, or GitHub, deployment, queue, database, service, process, container, scheduler, or production success is claimed without evidence.

Agents MUST downgrade completion status to `Failed`, `Blocked`, or `NotRun` when evidence requires it.

## Exception Handling

Exceptions MUST follow [../governance/EXCEPTION_PROCESS.md](../governance/EXCEPTION_PROCESS.md). Exceptions MUST be active, scoped, time-bounded, reviewed, risk-classified, approved by the accountable owner, and included in completion evidence.

Exceptions MUST NOT permit plaintext secrets, fabricated evidence, arbitrary command execution, unbounded retries, unbounded concurrency, empty scope meaning all work, hidden production targets, unauthorized replay, lost poison work, disabling duplicate protection without compensating controls, acknowledging work before durable completion without an approved model, relabeling `NotRun` as `Passed`, silent fallback to elevated identity, or unreviewed production schedule changes.

## Related Documents

- [AGENTS_Base.md](AGENTS_Base.md)
- [AGENTS_DotNet.md](AGENTS_DotNet.md)
- [AGENTS_Database.md](AGENTS_Database.md)
- [AGENTS_PowerShell.md](AGENTS_PowerShell.md)
- [AGENTS_Integration.md](AGENTS_Integration.md)
- [AGENTS_Infrastructure.md](AGENTS_Infrastructure.md)
- [../AGENTS.md](../AGENTS.md)
- [../governance/ORGANIZATION_CONTRACT.md](../governance/ORGANIZATION_CONTRACT.md)
- [../governance/COMPLETION_EVIDENCE.md](../governance/COMPLETION_EVIDENCE.md)
- [../governance/RISK_CLASSIFICATION.md](../governance/RISK_CLASSIFICATION.md)
- [../governance/EXCEPTION_PROCESS.md](../governance/EXCEPTION_PROCESS.md)
- [../governance/AI_GENERATED_CODE_POLICY.md](../governance/AI_GENERATED_CODE_POLICY.md)
- [../docs/ADOPTION_GUIDE.md](../docs/ADOPTION_GUIDE.md)
- [../docs/DOWNSTREAM_CONFIGURATION.md](../docs/DOWNSTREAM_CONFIGURATION.md)
- [../docs/TROUBLESHOOTING.md](../docs/TROUBLESHOOTING.md)

## Revision History

- 1.1.0: Rebuilt as a comprehensive enterprise Worker Service standard covering execution models, state machines, atomic claims, leases, delivery semantics, idempotency, concurrency, polling, scheduling, DST, retries, poison work, dead letters, replay, cancellation, graceful shutdown, timeouts, partial failure, side-effect ordering, script/process execution, input validation, security, secrets, privacy, observability, health, capacity, configuration, deployment, testing, validation, documentation, evidence, failures, exceptions, and cross-standard handoffs.
- 1.0.0: Initial worker-service standard with baseline requirements for discovery, risk, retries, scheduling, security, testing, evidence, and exceptions.
