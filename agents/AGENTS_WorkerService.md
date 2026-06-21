# AGENTS Worker Service Standard

| Field | Value |
| --- | --- |
| Status | Active |
| Version | 1.1.1 |
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

State transitions MUST be validated. Every progress, heartbeat, completion, failure, retry scheduling, cancellation, timeout, dead-letter, skip, and partial-success transition MUST verify the current worker or lease owner, expected current state, current state version or concurrency token, current lease or visibility ownership where applicable, and current attempt number where applicable. State transitions MUST use compare-and-swap, optimistic concurrency, an atomic predicate, queue-native ownership semantics, or an equivalent protected mechanism.

A worker that has lost ownership MUST NOT update progress, mark success, mark failure, schedule retry, complete or acknowledge the message, publish final artifacts, dead-letter the work, or mutate terminal state. Zero rows affected by an ownership-protected update MUST be treated as ownership loss or stale state, not success. Finalization MUST fail closed when ownership is ambiguous. Lease expiration alone MUST NOT authorize a stale worker to complete work. Manual overrides MUST NOT bypass state-version or ownership protections without Critical approval and audit. State mutation and required audit history SHOULD be persisted atomically where supported. Artifact publication and state finalization ordering MUST be defined. Side effects completed after ownership loss MUST be reconciled explicitly.

Terminal jobs MUST NOT silently return to active states. Manual override requires authorization and audit. Job state and side-effect state MUST NOT contradict silently. Success MUST mean required work completed, not merely that a process launched, message arrived, or handler returned. Partial success MUST be explicit.

## Durable Job Ownership And Atomic Claiming

For SQL-polled workers, claiming MUST be atomic. A claim MUST use one transaction or engine-supported atomic statement, a concurrency predicate, a claim or lease owner, claim timestamp, lease expiration, state version or concurrency token, maximum claim batch size, deterministic ordering where priority matters, and indexes supporting claim queries.

Agents MUST NOT implement a check-then-update race, broad table lock merely for convenience, duplicate ownership, memory-only ownership, or claim logic that depends on a single worker instance. Database-specific review is required under [AGENTS_Database.md](AGENTS_Database.md); this standard does not prescribe one universal SQL statement.

Engine-appropriate patterns MAY include SQL Server `UPDATE` with `OUTPUT` and reviewed locking hints, `SELECT FOR UPDATE SKIP LOCKED` where supported, compare-and-swap using a version column, or queue-native visibility and acknowledgement semantics.

For queue workers, a message MUST NOT be acknowledged before durable completion or an approved durable handoff. Visibility timeout, lock duration, or lease duration MUST cover expected work or be renewed safely. Ack, nack, reject, abandon, defer, complete, and dead-letter semantics MUST be explicit. Message loss and duplicate-delivery behavior MUST be documented.

Queue completion or acknowledgement MUST verify that the current receiver still owns the lock, lease, receipt handle, delivery tag, or equivalent token. Completion MUST fail closed when queue ownership is ambiguous or expired. Acknowledgement after lock or receipt-handle expiration MUST be treated as stale ownership, not success.

## Leases, Heartbeats, And Abandoned-Work Recovery

Workers that own durable work MUST define lease duration, heartbeat interval, renewal ownership check, maximum extension, stale-worker detection, recovery delay, recovery authorization, attempt increment behavior, safe reclamation, clock source, clock-skew handling, and observability for expired leases.

A worker MUST stop or fail safely if it loses ownership. Lease renewal MUST verify the current owner and state version. Leases MUST NOT be overwritten by another worker while an active owner is valid. A stale lease MUST NOT automatically prove the prior side effect did not occur. Recovery MUST account for uncertain completion. Reclaimed work MUST generate a new ownership context or attempt identity, and a new owner MUST NOT inherit stale in-memory state from a prior owner. Reclaimed work MUST be idempotent or reconciled before retry. Heartbeat failure MUST NOT be hidden. Stale heartbeat after reassignment MUST be rejected and audited. Repeated reclamation MUST alert.

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

Automatic retries MUST NOT apply to validation failures, authentication failures without a credential refresh path, authorization failures, unsupported input, permanent not-found conditions, business-rule rejection, signature failure, corrupt payload, explicit cancellation, or unsafe uncertain side effects without reconciliation. A retry MUST re-evaluate ownership, current state, state version, lease or visibility ownership, and current attempt number before scheduling or executing retry.

## Poison Work And Dead-Letter Handling

Workers MUST define poison criteria, maximum attempts, dead-letter destination, original message or job identity, sanitized failure details, attempt history, first and last failure timestamps, payload retention classification, alerting, operator ownership, replay authorization, replay limits, fix-before-replay requirements, expiration, and purge policy.

Poison work MUST NOT disappear. Dead-letter storage MUST be durable. Dead-letter transitions MUST verify current owner, expected state, state version or concurrency token, lease or visibility ownership where applicable, and attempt number. Sensitive payloads MUST be protected. Dead-letter purge is Critical by default. Dead-letter replay MUST create an audit record. Replaying without correcting the failure cause is prohibited unless explicitly justified. Bulk replay requires blast-radius controls, `DryRun` or preview, target counts, limits, approval, and stop conditions.

## Replay And Manual Retry

Replay and manual retry MUST define authorization, reason, operator identity, scope, preview, maximum job count, tenant or target restrictions, idempotency review, current-state validation, new attempt identity, link to original work, audit trail, stop or cancel control, and result summary.

Empty selection MUST NOT mean all jobs. Wildcard replay is prohibited unless Critical controls are satisfied. Terminal-state mutation MUST be explicit. Manual retry MUST NOT erase the original failure. Replay MUST NOT silently reuse expired credentials or obsolete inputs. Old job-schema versions require compatibility handling.

## Cancellation And Graceful Shutdown

Workers MUST support cooperative cancellation. Cancellation tokens or equivalent cancellation signals MUST propagate through polling, queue receives, delays, database calls, API calls, file operations, script execution, child processes, retries, and long-running loops where the platform supports it.

Cancellation MUST define `CancelRequested` or equivalent state, who may request cancellation, authorization, cancellation reason, timing, race behavior with completion, cleanup, partial output handling, and final state. Cancellation and completion races MUST be resolved through ownership-protected state transition semantics. A worker that observes cancellation MUST stop accepting new work for that job, persist the correct state only when it still owns the work, and avoid claiming success unless completion actually happened.

Graceful shutdown MUST define drain behavior, stop accepting new work, in-flight handling, maximum shutdown duration, lease release or heartbeat stop behavior, process cleanup, acknowledgement behavior, and readiness transition. Shutdown MUST NOT acknowledge incomplete work as successful.

## Timeouts And Hung-Work Recovery

Workers MUST define job timeout, operation timeout, dependency timeout, queue receive timeout, database command timeout, script/process timeout, shutdown timeout, and maximum runtime. Hung-work recovery MUST define detection, state transition, cancellation or termination, process-tree cleanup, artifact cleanup, lease handling, and retry or dead-letter behavior.

Unbounded execution is prohibited. Child processes MUST have timeouts and process-tree cleanup where supported. Process launch is not operation success. Exit code, timeout, stderr, and output validation determine process result according to the approved contract.

## Partial Failure And Compensation

Workers MUST define partial-failure behavior for multi-step work. The design MUST identify which steps are durable, which side effects can repeat, which steps require compensation, which failures are terminal, which are retryable, and how operators reconcile uncertain outcomes.

Partial success MUST be explicit. Workers MUST NOT hide partial failure by marking the parent job `Succeeded`. Compensation MUST be tested where feasible or recorded as `NotRun` with reason. Operators MUST have enough sanitized evidence to recover without access to secrets or raw sensitive payloads.

## Side-Effect Ordering And Transactional Handoff

Side effects MUST be ordered to preserve correctness under retries, crashes, duplicate delivery, cancellation, lease loss, and stale ownership. Database state changes, queue acknowledgement, external API calls, emails, reports, file movement, billing, notifications, and script execution MUST be reviewed together.

When database state and external side effects must remain coordinated, workers MUST use outbox, inbox, durable queue handoff, idempotent reconciliation, saga or orchestration state, or another approved durable pattern. The selected pattern MUST be documented. A simple in-memory follow-up call is insufficient. A database commit followed by an untracked external call is insufficient. An external side effect followed by an unprotected status update is insufficient.

The worker MUST define recovery for database commit succeeds and publish fails, publish succeeds and database status update fails, side effect succeeds and worker crashes, queue acknowledgement fails after completion, duplicate delivery after side effect, cancellation during handoff, and timeout during handoff. Queue acknowledgement MUST NOT occur before the approved durable completion point. Database transactions MUST NOT be held open across remote calls. Transaction commit uncertainty MUST be reconciled before retry. The pattern MUST preserve correlation, idempotency, replay, and audit. Workers MUST NOT claim atomic cross-system behavior where no atomic mechanism exists. Compensation or reconciliation MUST be explicit where atomicity is impossible. Exactly-once business effect claims remain prohibited unless proven end-to-end.

External side effects inside database transactions MUST follow [AGENTS_Database.md](AGENTS_Database.md). Producer and consumer state MUST NOT contradict silently.

## Script Runner And Child-Process Execution

Script-runner workers MUST use an approved script or job catalog. The catalog MUST define script identity, version, owner, allowed parameters, input schema, execution identity, working directory, timeout, accepted exit codes, output contract, artifact contract, risk classification, approval requirements, and rollback or recovery behavior.

The approved catalog MUST define and verify an immutable executable identity before execution. The immutable identity MUST use at least one approved identity appropriate to the delivery model, such as commit SHA, package version plus package integrity, release artifact digest, container image digest, SHA-256 content hash, Authenticode signature and signer identity, signed package identity, or another approved cryptographic identity. The catalog entry MUST identify logical job or script ID, human-readable version, immutable content identity, expected executable or script path, approved publisher or signer where applicable, supported runtime, required modules or dependencies, risk classification, and approved execution identity.

The worker MUST verify the executable, script, module, package, hash, signature, signer, or container digest immediately before execution. Catalog metadata alone is insufficient if the underlying file can change. A file version string alone is insufficient. A path alone is insufficient. A mutable branch name is insufficient. A floating package tag is insufficient. A mutable container tag is insufficient for production execution unless resolved and pinned to an approved immutable digest. Hash mismatch, signature failure, signer mismatch, missing signature when required, package mismatch, dependency or module mismatch, unexpected container digest, or catalog mismatch MUST fail closed. Verification failure MUST NOT fall back to another script, path, version, signer, dependency, unsigned copy, or container tag.

Script and executable directories MUST NOT be writable by untrusted submitters or ordinary job users. The immutable identity MUST be recorded in the job execution record, audit record, completion evidence, and artifact metadata where relevant. Dependency or module identity MUST also be governed when dependencies can materially change execution behavior. Script updates MUST create a new immutable identity and catalog version. Rollback MUST identify the exact prior immutable version.

Arbitrary scripts, paths, commands, shell snippets, or user command text MUST NOT be executed. User command text MUST NOT be passed to a shell. Native process calls MUST use safe argument APIs or argument arrays where practical, not string-built shell commands. Secrets MUST NOT be passed in visible command-line arguments. Working directory, executable path, script path, report path, and artifact path MUST be allowlisted or resolved beneath approved roots.

Workers MUST capture stdout, stderr, exit code, start time, end time, duration, timeout, cancellation, and sanitized output. Sensitive stdout and stderr MUST be redacted or suppressed. Accepted exit codes MUST be explicit. Nonzero exit codes MUST NOT be treated as success unless the catalog explicitly defines them as accepted for that operation. Process-tree cleanup is required for timeouts and cancellation where supported.

PowerShell worker execution MUST also apply [AGENTS_PowerShell.md](AGENTS_PowerShell.md). For PowerShell jobs, the catalog MUST define supported PowerShell edition and version, entry script, required modules and versions, expected execution policy context, code-signing requirement, accepted switches, approved credential mode, `DryRun` and `WhatIf` behavior, and output/result contract. Authenticode validation MUST follow [AGENTS_PowerShell.md](AGENTS_PowerShell.md) when signing is required. The worker MUST validate signature status and approved signer before execution. A valid signature from an unapproved signer is insufficient. Timestamp and certificate-chain behavior MUST follow PowerShell governance. Signed code MUST NOT be modified after signing.

Modifying PowerShell jobs MUST preserve `-WhatIf`, `-Confirm`, and `-DryRun` where the governed script defines them. The worker MUST NOT silently remove, override, or neutralize safe execution switches. Execute mode MUST be explicit and authorized. The worker MUST intentionally capture the success/output stream, error stream, warning stream, verbose stream, debug stream, and information stream. Sensitive output from every stream MUST be redacted. The worker MUST distinguish terminating and nonterminating errors. Nonterminating errors MUST NOT be ignored merely because the PowerShell process exits with code zero. The script or wrapper MUST define how nonterminating errors affect the final result. `$LASTEXITCODE`, `$?`, terminating exceptions, error records, and the script-defined result contract MUST be interpreted according to the script contract. Process exit code alone MUST NOT be treated as complete proof of PowerShell success.

A stable structured result contract MUST be preferred for governed scripts. The contract SHOULD include outcome/status, success boolean where appropriate, exit code, terminating error count, nonterminating error count, warning count, started/completed timestamps, duration, target count, changed count, skipped count, failed count, sanitized error summary, report and artifact references, correlation ID, job ID, attempt number, script logical ID, script immutable identity, worker instance, and `DryRun`/`WhatIf`/Execute mode. The worker MUST validate the result contract. Missing or malformed required result fields MUST fail safely. A script claiming success while reporting failed targets MUST NOT be accepted as full success. Partial success MUST remain explicit. Standard output text scraping alone SHOULD NOT be the primary result contract for enterprise scripts. PowerShell remoting, credentials, reporting, email, signing, and configuration MUST continue to follow [AGENTS_PowerShell.md](AGENTS_PowerShell.md).

## Input, File, And Parameter Validation

Worker input MUST be validated before durable enqueue where feasible and again before execution where trust boundaries require it. Validation MUST cover job type, version, tenant, authorization, target count, empty input, duplicate input, unsupported input, CSV headers, CSV row limits, file size, file type, encoding, path boundaries, parameter types, ranges, allowlists, mutually exclusive options, and schema version.

Empty input MUST fail safely and MUST NOT mean all jobs, all tenants, all rows, all files, or all targets. Duplicate input MUST NOT broaden scope. Uploaded files and generated artifacts MUST use approved roots, safe file names, traversal protection, malware or content scanning where required, retention, cleanup, and authorization checks. CSV examples and fixtures MUST be synthetic.

Job input MUST become immutable, versioned, or content-addressed after durable submission. The worker MUST execute against the exact approved input version. The job record MUST store or reference input schema version, immutable payload snapshot or immutable object reference, content hash, file size where relevant, original safe file name, storage object/version identifier where supported, submission timestamp, submitter identity, approval identity where required, target count, and tenant or scope boundary.

Mutable external files MUST NOT be referenced only by path. Uploaded CSV or input files MUST NOT be replaceable after approval without creating a new job version or new approval event. The worker MUST verify content hash before execution. The worker MUST revalidate schema, authorization, scope, file integrity, target count, tenant, catalog compatibility, and input version before execution. Time-of-check/time-of-use changes MUST be detected. Hash mismatch or version mismatch MUST fail closed. Input replacement MUST NOT silently update the existing job. A changed input requires a new immutable version and appropriate reapproval. Temporary staging paths MUST NOT be treated as durable approved input. File access permissions MUST prevent ordinary users from modifying approved input. Job payloads MUST NOT contain plaintext secrets. Large inputs MUST use approved object references rather than uncontrolled database blobs when repository design requires it. Retention and cleanup MUST preserve required auditability. Dead-letter and replay MUST retain or reference the original immutable input version.

## Artifact And Report Publication Integrity

Worker artifacts and reports MUST be associated with job ID, attempt number, correlation ID, script or job logical ID, script immutable identity, worker instance, creation timestamp, content type, size, content hash, classification, retention, and authorization boundary.

Artifact publication MUST use an atomic publish model where supported: write to an approved temporary location, complete and flush the artifact, validate size and content, compute integrity hash, apply classification and access metadata, move or rename atomically to the final approved location, persist final artifact metadata, and expose the download or reference link only after finalization. Partial artifacts MUST NOT be presented as final. Existing final artifacts MUST NOT be silently overwritten. Artifact naming MUST avoid path traversal, collision, and tenant crossover. Final artifact paths MUST be unique or versioned.

A failed attempt MUST NOT overwrite a successful attempt's artifact. Retried jobs MUST produce attempt-specific artifact identities unless an approved idempotent publication design exists. Artifact integrity MUST be verified before exposing a report or download link. Authorization MUST be checked at access time, not only when the link is generated. Sensitive artifacts SHOULD use short-lived or expiring links where appropriate. Public or guessable report URLs are prohibited for protected data. Temporary and abandoned artifacts MUST have cleanup rules. Cleanup MUST NOT delete artifacts required for audit, legal hold, or active investigation.

Artifact publication failure MUST affect job outcome according to the job contract. A job MUST NOT be marked fully successful when a required artifact failed to publish. Artifact hash and metadata MUST be included in completion evidence where applicable.

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

Applicable tests include state transitions, disallowed transitions, terminal-state behavior, atomic claiming, competing workers, lease renewal, lease loss, stale claim recovery, heartbeat failure, stale heartbeat after reassignment, old owner completion/failure/retry/artifact publication after lease transfer, concurrent completion attempts, completion versus cancellation race, completion versus lease expiration, zero-row update behavior, queue lock or receipt-handle expiration, reclaimed job with new attempt identity, duplicate messages, idempotent rerun, concurrent duplicate delivery, ordering, partition behavior, retryable failure, nonretryable failure, backoff, jitter bounds, retry exhaustion, poison work, dead-lettering, replay authorization, bulk replay limits, cancellation before start, cancellation while running, graceful shutdown, forced termination, timeouts, hung child processes, process-tree cleanup, partial failure, compensation, mandatory outbox/inbox/durable handoff behavior, queue ack timing, SQL polling empty state, polling error backoff, schedule overlap, missed runs, DST skipped and repeated times, input schema, immutable input snapshot/version/hash, file changed after submission or approval, input object version change, CSV row-count change, unauthorized tenant change, input path redirection, approved input deleted before execution, replay against original immutable input, empty input, CSV validation, maximum target count, unauthorized script or job, immutable script identity, content hash mismatch, signature failure, wrong signer, unsigned script when signing is required, mutable catalog path changed after approval, unexpected container digest, dependency/module mismatch, attempted fallback to another version, arbitrary command/path rejection, parameter injection attempts, PowerShell terminating error, nonterminating error with exit code zero, malformed or missing structured result, partial success, `DryRun`, `WhatIf`, unauthorized Execute mode, stream redaction, native command failure inside PowerShell, inconsistent process exit code and structured result, secret redaction, artifact hashing, atomic artifact publication, partial write, worker crash before final rename, duplicate artifact name, unauthorized artifact access, tenant crossover, retry overwrite attempt, required report generation failure, expired link, abandoned temporary cleanup, final artifact reference created before publication, successful job with failed required artifact, health readiness and liveness, configuration validation, rolling-version compatibility, multi-instance behavior, and capacity/backpressure behavior.

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

Container validation MUST use explicit nonproduction configuration. Normal worker execution MUST NOT be launched merely as a smoke test because it can claim real work, contact production dependencies, or run indefinitely. Validation SHOULD use configuration validation mode, startup-check mode, health-check mode, version/help command, explicit no-work test mode, or ephemeral local dependencies. Network access SHOULD be disabled or restricted when not required. Production credentials MUST NOT be mounted. Production queue or database endpoints MUST NOT be used. Container validation MUST have a bounded timeout. The command MUST NOT claim queue or database validation unless those integrations actually ran. The image SHOULD be pinned by digest for release verification where appropriate. If no generic safe command exists, each downstream worker MUST provide a documented validation or no-work startup mode.

Safer container examples:

```powershell
docker build --tag "<worker-image>:<version>" .
docker run --rm `
  --network none `
  "<worker-image>@<approved-digest>" `
  --validate-configuration
docker run --rm "<worker-image>:<version>" --version
```

The switches above are illustrative placeholders and apply only when the downstream worker actually supports them. Unsupported switches MUST NOT be documented as executed validation.

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

Completion evidence MUST align with [../governance/COMPLETION_EVIDENCE.md](../governance/COMPLETION_EVIDENCE.md) and root [../AGENTS.md](../AGENTS.md). Evidence for worker work MUST include exact files changed, exact commands, working directories, exit codes, tool versions, worker runtime and host, trigger model, queue/database/scheduler type, state-machine validation, ownership-protected finalization validation, claim/lease validation, delivery semantics, idempotency validation, duplicate test, retry/backoff test, poison/dead-letter test, replay test or status, cancellation test, graceful-shutdown test, timeout test, side-effect ordering, durable transactional handoff validation, immutable script identity, PowerShell stream/result validation where applicable, immutable input snapshot/version/hash validation, artifact hash and metadata validation, script/process validation where applicable, security and permission review, secret redaction test, input/file validation, health-check validation, concurrency/load result, container validation mode when applicable, deployment result, GitHub Actions status, artifact verification, remaining risks, approvals, and exceptions.

Permitted statuses are `Passed`, `Failed`, `Blocked`, `NotRun`, and `NotApplicable`. Unexecuted queue, database, scheduler, service, process, container, deployment, or GitHub validation MUST NOT be labeled `Passed`.

## Failure Behavior

Worker work is incomplete when state transitions are undefined, ownership is ambiguous, claiming is non-atomic, stale owners can mutate or finalize jobs, zero-row protected updates are treated as success, finalization can proceed with ambiguous ownership, duplicate prevention is absent, exactly-once is claimed without proof, leases can be overwritten, lease loss is ignored, stale work is retried without idempotency or reconciliation, queue messages are acknowledged before durable completion, cross-system side effects lack an approved durable handoff, polling uses a busy loop, concurrency is unbounded, retries are unbounded, permanent failures are retried indefinitely, poison work disappears, dead-letter replay lacks authorization, empty replay scope can mean all jobs, cancellation is missing, shutdown accepts new work while draining, timeouts are absent, child processes can remain orphaned, process launch is treated as operation success, immutable script or executable identity is missing or not verified, PowerShell exit code alone is treated as success, PowerShell streams or nonterminating errors are ignored, job input can be replaced after approval, mutable file paths are treated as approved input identity, artifact hashes are missing, partial artifacts can be exposed as final, required artifact publication failure is hidden, arbitrary scripts, paths, commands, or parameters can execute, secrets appear in arguments, logs, payloads, reports, artifacts, or evidence, side effects can repeat unsafely, partial failure is hidden, schedule overlap is undefined, DST behavior is undefined for local-time schedules, readiness allows unsafe job claiming, old/new worker versions are incompatible without controls, production schedule, replay, or concurrency changes lack approval, normal worker startup is used as an uncontrolled container smoke test, production credentials are used for container validation, tests are skipped without exact status and reason, or GitHub, deployment, queue, database, service, process, container, scheduler, or production success is claimed without evidence.

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

- 1.1.1: Corrected remaining Worker Service standard gaps by strengthening ownership-protected finalization, stale-owner rejection, immutable script identity, PowerShell execution semantics, immutable job inputs, artifact publication integrity, mandatory durable transactional handoff, safer container validation, and validator/Pester hardening.
- 1.1.0: Rebuilt as a comprehensive enterprise Worker Service standard covering execution models, state machines, atomic claims, leases, delivery semantics, idempotency, concurrency, polling, scheduling, DST, retries, poison work, dead letters, replay, cancellation, graceful shutdown, timeouts, partial failure, side-effect ordering, script/process execution, input validation, security, secrets, privacy, observability, health, capacity, configuration, deployment, testing, validation, documentation, evidence, failures, exceptions, and cross-standard handoffs.
- 1.0.0: Initial worker-service standard with baseline requirements for discovery, risk, retries, scheduling, security, testing, evidence, and exceptions.
