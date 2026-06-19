# AGENTS Worker Service Standard

| Field | Value |
| --- | --- |
| Status | Active |
| Version | 1.0.0 |
| Owner role | Engineering Standards Maintainers |
| Last reviewed | 2026-06-19 |
| Changelog | See [../CHANGELOG.md](../CHANGELOG.md). |

## Purpose

This document defines enterprise requirements for AI agents working on background workers, queue consumers, scheduled jobs, report generators, daemons, batch processors, and unattended automation. It inherits [AGENTS_Base.md](AGENTS_Base.md).

## Applicability

This standard applies to worker services implemented in any language, including .NET workers, PowerShell scheduled automation, queue consumers, cron jobs, event processors, file watchers, ETL jobs, notification jobs, and long-running service loops.

## Required Discovery

Before editing, agents MUST identify:

- Job trigger, schedule, queue, event source, or polling mechanism.
- State transitions and persisted state.
- Idempotency key or duplicate-prevention strategy.
- Lease, lock, concurrency, and visibility-timeout behavior.
- Retry, backoff, poison-message, dead-letter, and replay behavior.
- Cancellation, graceful shutdown, and timeout handling.
- Side effects such as emails, billing, deletion, external API calls, and data writes.
- Observability, health checks, metrics, and alerting.

## Risk Classification

Worker changes are High when they affect billing, notifications, data mutation, queue replay, duplicate prevention, external side effects, production schedules, or retry behavior. They are Critical when they can broadly replay, delete, bill, notify, corrupt data, or disable safety controls in production.

## Implementation Requirements

Workers MUST define safe lifecycle behavior. Long-running loops MUST support cancellation and graceful shutdown. Jobs MUST avoid unbounded concurrency, infinite retry loops, and hidden partial failures.

State-changing workers SHOULD be idempotent. If idempotency is impossible, the design MUST document duplicate risk and compensating controls. Side effects SHOULD happen after durable state decisions or use an outbox, transaction, lease, or equivalent pattern.

## Retry And Failure Handling

Retries MUST include limits, backoff, and classification of retryable versus nonretryable failures. Poison messages MUST move to a dead-letter path or equivalent after exhaustion. Partial failures MUST be observable and recoverable.

Workers MUST NOT swallow failures silently. They SHOULD emit structured logs and metrics for success, failure, retry, skip, dead-letter, and processing duration.

## Scheduling And Concurrency

Scheduled jobs MUST define time zone, cadence, overlap behavior, missed-run behavior, and manual-run behavior. Queue workers MUST define concurrency, visibility timeout, lease renewal, and duplicate handling.

Agents MUST consider clock drift, deployment restarts, multiple instances, and replay scenarios.

## Security And Data Handling

Worker secrets MUST use approved secret mechanisms. Workers MUST run with least privilege and only access the queues, storage, APIs, and data they require. Logs MUST redact sensitive payloads.

Workers that process confidential or regulated data require data classification review and evidence of redaction and retention behavior.

## Testing Requirements

Tests SHOULD cover:

- State transitions.
- Idempotency and duplicate messages.
- Retry and backoff.
- Poison-message or dead-letter behavior.
- Cancellation and graceful shutdown.
- Timeout handling.
- Partial failure and recovery.
- Side-effect ordering.

Integration tests SHOULD use local or nonproduction queues and synthetic data.

## Evidence

Evidence MUST include commands run, test counts, worker runtime, queue/scheduler assumptions, retry and idempotency validation, skipped integration tests and reasons, and remaining operational risks.

## Failure Behavior

The work is incomplete if duplicate prevention is unaddressed, retries are unbounded, cancellation is missing, poison messages disappear, side effects can repeat unsafely, production schedules are changed without approval, or evidence omits worker-specific validation.

## Related Documents

- [AGENTS_Base.md](AGENTS_Base.md)
- [AGENTS_DotNet.md](AGENTS_DotNet.md)
- [AGENTS_Integration.md](AGENTS_Integration.md)
- [../governance/RISK_CLASSIFICATION.md](../governance/RISK_CLASSIFICATION.md)

## Exception Handling

Exceptions MUST follow [../governance/EXCEPTION_PROCESS.md](../governance/EXCEPTION_PROCESS.md). Missing queue infrastructure or scheduler access MUST be recorded as `NotRun` or `Blocked`.
