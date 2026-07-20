# AGENTS Integration Standard

| Field | Value |
| --- | --- |
| Status | Active |
| Version | 1.1.0 |
| Owner role | Engineering Standards Maintainers |
| Last reviewed | 2026-06-21 |
| Changelog | See [../CHANGELOG.md](../CHANGELOG.md). |

## Purpose

This document defines enterprise requirements for AI agents working on external integrations, API clients, vendor contracts, webhooks, message brokers, file transfers, batch feeds, and cross-system workflows. It inherits [AGENTS_Base.md](AGENTS_Base.md), [../governance/ORGANIZATION_CONTRACT.md](../governance/ORGANIZATION_CONTRACT.md), [../governance/COMPLETION_EVIDENCE.md](../governance/COMPLETION_EVIDENCE.md), [../governance/RISK_CLASSIFICATION.md](../governance/RISK_CLASSIFICATION.md), [../governance/EXCEPTION_PROCESS.md](../governance/EXCEPTION_PROCESS.md), and [../governance/AI_GENERATED_CODE_POLICY.md](../governance/AI_GENERATED_CODE_POLICY.md).

## Applicability

This standard applies to REST, GraphQL, SOAP, gRPC, WebSocket, SignalR-style integrations, webhooks, message brokers, event streams, SFTP, managed file transfer, batch feeds, vendor SDKs, API gateways, cross-system workflows, contract schemas, mocks, sandbox validation, credentials, certificates, mTLS, retries, rate limits, idempotency, deduplication, data mapping, logging, and integration evidence.

When integration work includes .NET code, PowerShell automation, database transactions, worker-service processing, infrastructure provisioning, or browser behavior, agents MUST also apply the corresponding technology standard:

- [.NET](AGENTS_DotNet.md) for .NET clients, APIs, authentication, serialization, hosted services, and generated clients.
- [PowerShell](AGENTS_PowerShell.md) for scripts, modules, credential handling, remoting, and validation automation.
- [Database](AGENTS_Database.md) for database transactions, outbox/inbox tables, ETL staging, schema changes, and data repair.
- [Worker Service](AGENTS_WorkerService.md) for background execution, queues, leases, retries, artifacts, cancellation, and job state.
- [Infrastructure](AGENTS_Infrastructure.md) for gateways, DNS, network paths, certificates, secrets, service accounts, queues, topics, and managed transfer infrastructure.
- [Web Frontend](AGENTS_WebFrontend.md) for browser API clients, CORS, WebSocket UI behavior, OAuth/OIDC browser flows, uploads, downloads, and polling.
- [Python](AGENTS_Python.md) for Python API clients, webhooks, queues, serialization, and file-transfer integrations.
- [Bash](AGENTS_Bash.md) for Bash HTTP, SSH, SFTP, remote-command, and vendor integration scripts.

## Normative Terminology

The terms MUST, MUST NOT, SHOULD, SHOULD NOT, and MAY use the meanings defined by [AGENTS_Base.md](AGENTS_Base.md). Integration-specific guidance MUST NOT redefine Low, Moderate, High, Critical, Passed, Failed, Blocked, NotRun, or NotApplicable.

Permitted completion statuses are `Passed`, `Failed`, `Blocked`, `NotRun`, and `NotApplicable`. `NotRun` means validation was not executed. `Blocked` means a concrete dependency or condition prevented execution. `NotApplicable` means the check does not apply. `Passed` requires actual evidence.

## Required Discovery

Before editing integration code, configuration, workflows, or documentation, agents MUST identify and record:

- Integration type, provider, endpoint class, API gateway path, transport, protocol, SDK, and exact API or schema version.
- Provider lifecycle, deprecation date, compatibility policy, breaking-change notification channel, and support tier.
- Authentication method, authorization scopes, workload identity, client credentials, certificates, mTLS, token audience, and credential storage.
- Tenant, account, subscription, environment, region, partner, and data-boundary model.
- Request and response schemas, media types, encoding, compression, pagination, filtering, sorting, continuation-token semantics, and maximum payload size.
- Timeout, cancellation, retryable and nonretryable error classification, retry budget, exponential backoff, jitter, `Retry-After`, rate limits, circuit breakers, and bulkheads.
- Idempotency keys, deduplication keys, ordering guarantees, replay behavior, partial success, batch semantics, and compensation model.
- Webhook signature algorithm, timestamp window, replay-defense mechanism, event authenticity source, delivery contract, and retry policy.
- Queue, topic, stream, or broker delivery semantics, acknowledgement point, poison-message handling, dead-letter queue, replay controls, and ordering partition key.
- SFTP or managed-file-transfer host key, path convention, encryption, checksum, atomic publication model, archive format, retention, and cleanup.
- Data mapping, schema validation, data classification, PII, PHI, regulated data, minimization, retention, and redaction requirements.
- Sandbox, mock, contract-test, emulator, and nonproduction endpoint availability.
- Required evidence, validation commands, known limitations, rollback, and exceptions.

## Risk Classification

Integration changes use the canonical risk levels `Low`, `Moderate`, `High`, and `Critical` from [../governance/RISK_CLASSIFICATION.md](../governance/RISK_CLASSIFICATION.md).

Integration changes are High when they affect credentials, scopes, certificates, customer data, regulated data, payments, partner data, callback trust, retry behavior, data mapping, compatibility, event processing, queue acknowledgement, file integrity, or vendor contract behavior.

Integration changes are Critical when they disable certificate validation, disable webhook signatures, bypass authentication or authorization, broaden privileged scopes, commit client secrets, process untrusted callbacks as trusted events, export regulated data, mutate production partner systems without approval, or cause destructive cross-system side effects without rollback.

## Contract And Versioning Requirements

Every governed integration MUST define explicit API versions, schema versions, message versions, event versions, file layout versions, or vendor SDK versions where the provider supports them. Unversioned providers MUST be documented with provider lifecycle, compatibility assumptions, monitoring, and fallback.

Contract schemas MUST define required fields, optional fields, nullability, enum handling, timestamp format and time zone, number precision, media type, encoding, pagination, sorting, filtering, continuation-token behavior, partial-success representation, and error/problem response format.

HTTP 2xx, transport success, queue acknowledgement, file transfer success, or SDK call success MUST NOT automatically mean business success. Agents MUST evaluate the provider's business outcome contract, partial-failure model, warnings, and finalization state.

Continuation tokens MUST be treated as opaque. Clients MUST NOT parse, modify, forge, log sensitive token content, or use continuation tokens across tenants, accounts, filters, sorts, API versions, or incompatible requests.

Compatibility changes MUST include backward and forward behavior notes, sample payloads, generated-client refresh where applicable, contract tests, deprecation communication, and migration guidance. Removing fields, narrowing enums, changing identity semantics, changing idempotency keys, or changing partial-success behavior requires High or Critical review.

## Authentication, Authorization, And Secrets

Integrations MUST use least-privilege credentials separated by environment, tenant, account, and purpose. Client secrets, API keys, webhook secrets, private keys, certificates, tokens, connection strings, production endpoints with embedded credentials, and partner payloads MUST NOT be committed, logged, copied into evidence, or embedded in browser bundles.

OAuth/OIDC client-credentials flows, workload identity, managed identity, federated identity, mTLS, and certificate-based authentication MUST define issuer, audience, scopes, token lifetime, rotation, revocation, credential owner, storage, expiration, renewal, and failure behavior.

Certificate validation MUST NOT be disabled. mTLS integrations MUST define certificate subject, SANs, issuer, trust store, chain validation, revocation behavior, rotation window, expiration monitoring, private-key protection, and rollback.

Tenant, account, partner, and subscription boundaries MUST be enforced on every request, callback, message, file, and batch. Cross-tenant access requires explicit authorization, evidence, and review.

## Reliability And Resilience

Every integration MUST define timeouts and cancellation behavior for connection, request, response, stream, upload, download, queue receive, queue acknowledgement, batch processing, and shutdown where applicable.

Retries MUST classify retryable and nonretryable failures. Every error MUST NOT be treated as retryable. Retries MUST be bounded, use exponential backoff and jitter, respect `Retry-After` and provider rate limits, preserve idempotency, and stop on cancellation, authentication failure, authorization failure, schema failure, validation failure, permanent business failure, or exhausted retry budget.

Non-idempotent operations MUST use idempotency keys, deduplication, outbox/inbox, durable coordination, or an approved compensating-control pattern before retry. External calls SHOULD NOT occur inside database transactions by default. If unavoidable, the design requires High review, timeout limits, rollback or reconciliation, and [AGENTS_Database.md](AGENTS_Database.md) controls.

Circuit breakers, bulkheads, concurrency limits, request budgets, and rate-limit handling MUST prevent a failing provider from exhausting worker threads, browser loops, database connections, queue consumers, or downstream dependencies.

## Webhooks And Event Authenticity

Webhook handlers MUST validate signatures or event authenticity where the provider supports it. Timestamp, nonce, event ID, delivery ID, digest, or equivalent replay protection MUST be enforced within a bounded window. Signature verification MUST cover the exact raw payload bytes required by the provider.

Unsigned webhooks, disabled signature verification, expanded timestamp windows, ignored replay protection, or trust in source IP alone require High or Critical review and an approved exception when used for protected behavior.

Duplicate events MUST be detected and handled idempotently. Duplicate events may be acknowledged, ignored, or replayed only according to an explicit contract and evidence. Partial success MUST NOT be displayed or recorded as full success.

## Queues, Streams, And Durable Coordination

Queue, topic, stream, and broker integrations MUST define delivery semantics, acknowledgement point, visibility timeout or lease, ordering key, consumer group, replay, poison-message threshold, dead-letter queue, retention, and backpressure behavior.

Queue delivery MUST NOT be described as exactly once automatically. Consumers MUST tolerate duplicates unless the broker contract and implementation provide stronger guarantees and evidence. Poison messages MUST have dead-letter handling or an approved equivalent remediation path.

When database state and external side effects must remain coordinated, integrations MUST use outbox, inbox, durable queue handoff, saga/orchestration state, idempotent reconciliation, or another approved durable coordination pattern. Missing durable coordination requires an approved exception and cannot be hidden by marking validation Passed.

## File Transfer And Batch Feeds

SFTP and managed-file-transfer integrations MUST validate host keys or equivalent server identity. Host-key validation MUST NOT be disabled. File transfers MUST define encryption, checksum or hash, file size, record count, schema version, naming convention, temporary path, final path, atomic publication, archive safety, retention, cleanup, and reprocessing behavior.

File hashes are required where a provider supplies them or where the repository controls both producer and consumer. Absence of provider hashes MUST be recorded with compensating validation such as size, record count, schema validation, and controlled publication.

Consumers MUST NOT process partially uploaded files as final. Publication MUST use an atomic rename, manifest marker, immutable object version, or equivalent completion signal. Archive extraction MUST protect against path traversal, bombs, unexpected nested archives, and excessive file counts.

Batch feeds MUST define full, incremental, replay, correction, deletion, late-arriving, duplicate, and partial-file semantics. Failed records MUST NOT be silently dropped.

## Data Mapping, Privacy, And Logging

Inbound and outbound payloads MUST be classified. PII, PHI, regulated data, credentials, tokens, private keys, session identifiers, authorization headers, signed URLs, partner secrets, and sensitive payload fragments MUST be redacted from logs, metrics, traces, evidence, screenshots, and test fixtures unless an approved protected evidence process applies.

Payloads MUST be validated against schemas before trusted processing. Untrusted payloads MUST NOT bypass schema validation because they came from a known vendor, gateway, queue, SFTP server, or SDK.

Data mapping MUST cover required fields, unknown fields, nulls, enums, string length, encoding, time zones, numeric precision, locale, identity fields, tenant fields, and destructive updates. Mapping failures MUST fail safely, produce actionable diagnostics without sensitive data, and avoid partial writes unless the partial-success contract permits them.

Correlation IDs MUST be non-secret, bounded, propagated consistently, and safe for logs. Metrics and alerts MUST identify provider, endpoint, operation, environment, status, latency, rate-limit events, retries, circuit-breaker state, dead letters, replay, and schema failures without exposing sensitive payloads.

## API Gateways, Proxies, And SDKs

API gateway and proxy integrations MUST define route ownership, authentication boundary, authorization policy, CORS and origin handling where applicable, request/response transformations, body size limits, timeout, retry policy, logging, WAF or policy-as-code controls, and backend identity.

Vendor SDKs MUST be pinned or constrained, reviewed for license and supply-chain risk, configured without plaintext secrets, and wrapped so provider errors, retries, logging, and telemetry follow this standard. SDK defaults MUST NOT override repository timeout, retry, certificate, proxy, telemetry, or redaction requirements.

## Testing And Validation

Integration changes MUST include the applicable subset of:

- Contract tests or schema validation for requests, responses, events, and files.
- Mock or simulator tests for success, permanent failure, transient failure, timeout, cancellation, rate limit, pagination, partial success, duplicate delivery, and malformed payloads.
- Webhook signature, timestamp, replay, duplicate, and schema-failure tests.
- Queue poison/dead-letter, retry, idempotency, ordering, lease/visibility-timeout, and replay tests.
- SFTP or file-transfer host-key, checksum, atomic publication, archive safety, and reprocessing tests.
- Sandbox or nonproduction smoke tests when safe and available.
- Negative tests for unauthorized, wrong tenant, expired credential, invalid certificate, schema drift, unknown enum, null, and oversized payload behavior.

If a sandbox, provider endpoint, credential, broker, certificate authority, file-transfer endpoint, or network route is unavailable, record `NotRun` or `Blocked` with the exact reason. Production MUST NOT be used merely because nonproduction is unavailable.

## Validation Commands

Use the repository validation commands in the root [../AGENTS.md](../AGENTS.md). Integration-specific projects SHOULD add commands such as:

```powershell
pwsh -NoProfile -File tools/Test-ContractSchemas.ps1 -Path .
pwsh -NoProfile -File tools/Test-WebhookVerification.ps1 -Path .
pwsh -NoProfile -File tools/Test-IntegrationMocks.ps1 -Path .
```

When tools are unavailable, record `NotRun` or `Blocked`; do not echo fake success.

## Evidence

Evidence MUST include command, working directory, tool/runtime version, exit code, started/completed timestamps, environment, identity, commit SHA, validated commit SHA, API or schema version, credential mode, contract-test result, mock-test result, sandbox/smoke-test result or reason not run, retry/rate-limit validation, idempotency validation, payload redaction review, artifact hashes where files are exchanged, approval evidence, exceptions, known limitations, and remaining risk.

Unexecuted integration validation, unavailable sandboxes, missing credentials, unavailable brokers, missing certificates, missing provider access, or missing external endpoints MUST NOT be labeled `Passed`.

Agents MUST NOT fabricate commands, exit codes, workflow runs, provider responses, webhook deliveries, queue messages, file hashes, approvals, screenshots, artifact downloads, production verification, or sandbox validation.

## Failure Behavior

The work is incomplete if:

- Required discovery is missing.
- API, schema, event, file, or SDK version is ambiguous.
- Credentials, secrets, tokens, private keys, sensitive payloads, or partner data are exposed.
- Authentication, authorization, tenant boundary, certificate validation, webhook signature, or replay protection is missing without approved exception.
- Retries are unbounded, all errors are retryable, retry loops lack jitter, or rate limits are ignored.
- Idempotency, deduplication, dead-letter, poison-message, partial-success, or durable coordination behavior is missing where applicable.
- SFTP host keys are not validated, files lack integrity checks where available, or partial files can be processed as final.
- Untrusted payloads bypass schema validation.
- Production is used as a substitute for unavailable nonproduction validation.
- Missing, failed, blocked, or unexecuted validation is relabeled as `Passed`.
- Evidence is fabricated, contradictory, incomplete, or missing required NotRun/Blocked reasons.

## Exception Handling

Exceptions MUST follow [../governance/EXCEPTION_PROCESS.md](../governance/EXCEPTION_PROCESS.md). Every exception MUST include a `GOV-*` identifier, owner, scope, risk, approval, compensating control, expiration, and remediation plan.

Exceptions MUST NOT permit fabricated evidence, relabeling `NotRun` or `Failed` as `Passed`, permanent silent bypass, committed secrets, disabled certificate validation without Critical review, or expired exception use. Expired exceptions MUST fail validation.

## Related Documents

- [AGENTS_Base.md](AGENTS_Base.md)
- [AGENTS_PowerShell.md](AGENTS_PowerShell.md)
- [AGENTS_DotNet.md](AGENTS_DotNet.md)
- [AGENTS_Database.md](AGENTS_Database.md)
- [AGENTS_WorkerService.md](AGENTS_WorkerService.md)
- [AGENTS_Infrastructure.md](AGENTS_Infrastructure.md)
- [AGENTS_WebFrontend.md](AGENTS_WebFrontend.md)
- [../governance/RISK_CLASSIFICATION.md](../governance/RISK_CLASSIFICATION.md)
- [../governance/COMPLETION_EVIDENCE.md](../governance/COMPLETION_EVIDENCE.md)
- [../governance/EXCEPTION_PROCESS.md](../governance/EXCEPTION_PROCESS.md)

## Revision History

- 1.1.0: Consolidated Integration as an enterprise semantic standard covering REST, GraphQL, SOAP, gRPC, WebSocket, SignalR-style integrations, webhooks, queues, streams, SFTP, managed file transfer, batch feeds, vendor SDKs, API gateways, contract schemas, authentication, authorization, secrets, mTLS, retries, rate limits, idempotency, durable coordination, file integrity, data mapping, privacy, telemetry, evidence, failures, exceptions, and cross-standard handoffs.
- 1.0.0: Initial Integration standard with baseline requirements for discovery, contracts, authentication, reliability, data handling, testing, evidence, and exceptions.
