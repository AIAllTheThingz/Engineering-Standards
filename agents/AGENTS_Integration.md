# AGENTS Integration Standard

| Field | Value |
| --- | --- |
| Status | Active |
| Version | 1.0.0 |
| Owner role | Engineering Standards Maintainers |
| Last reviewed | 2026-06-19 |
| Changelog | See [../CHANGELOG.md](../CHANGELOG.md). |

## Purpose

This document defines enterprise requirements for AI agents working on external integrations, API clients, vendor contracts, webhooks, data exchange jobs, file transfers, partner feeds, and cross-system workflows. It inherits [AGENTS_Base.md](AGENTS_Base.md).

## Applicability

This standard applies to REST, GraphQL, SOAP, gRPC, message-based, webhook, file-based, SFTP, event-stream, and vendor SDK integrations, including mocks, contract tests, schemas, credentials, retry policies, and integration documentation.

## Required Discovery

Before editing, agents MUST identify:

- Provider, API version, contract, and deprecation policy.
- Authentication method and credential storage.
- Authorization scopes and tenant/account boundaries.
- Rate limits, pagination, filtering, sorting, and payload size limits.
- Timeout, retry, backoff, circuit-breaker, and idempotency behavior.
- Webhook signature verification or event authenticity controls.
- Test endpoints, sandbox data, mocks, and contract tests.
- Data classification for inbound and outbound payloads.

## Risk Classification

Integration changes are High when they affect credentials, scopes, customer data, payments, webhooks, data mapping, retry behavior, or vendor contract compatibility. They are Critical when they disable signature verification, broaden privileged scopes, export regulated data, or process untrusted callbacks as trusted events.

## Contract And Versioning Requirements

Agents MUST use explicit API versions when the provider supports them. Contract changes SHOULD include schema updates, sample payloads, compatibility notes, and tests for backward and forward behavior.

Integrations MUST normalize provider errors into safe internal errors without leaking secrets or raw sensitive payloads.

## Authentication And Secrets

Integration credentials MUST be separated by environment and stored in approved secret mechanisms. Agents MUST NOT commit API keys, webhook secrets, private keys, production endpoints with embedded credentials, or real partner payloads.

Webhook handlers MUST verify signatures or authenticity where the provider supports it. Disabling verification is Critical and requires approved exception.

## Reliability Requirements

Integrations SHOULD define timeouts, bounded retries, exponential backoff, rate-limit handling, circuit breaking, idempotency keys, pagination limits, and dead-letter or replay behavior where applicable.

Retries MUST be safe for the operation. Non-idempotent external calls SHOULD use idempotency keys or duplicate detection.

## Data Handling

Inbound and outbound payloads MUST be classified. Logs and evidence MUST redact credentials, tokens, regulated data, and unnecessary payload details. Data transformations SHOULD be tested for required fields, unknown fields, nulls, encoding, time zones, and schema drift.

## Testing Requirements

Integration changes SHOULD include:

- Contract tests or schema validation.
- Mock tests for success and failure.
- Retry, timeout, rate-limit, and pagination tests.
- Signature verification tests for webhooks.
- Nonproduction smoke test when safe and available.
- Negative tests for malformed, unauthorized, duplicate, and replayed events.

If a sandbox or provider endpoint is unavailable, record `NotRun` or `Blocked`.

## Evidence

Evidence MUST include API version, credential mode, contract tests, mock tests, smoke-test result or reason not run, rate-limit/retry validation, payload redaction review, and remaining risks.

## Failure Behavior

The work is incomplete if credentials are exposed, provider version is ambiguous, webhook authenticity is unverified, retries are unbounded, payloads are logged unsafely, contract tests are missing without explanation, or evidence claims sandbox validation passed when it did not run.

## Related Documents

- [AGENTS_Base.md](AGENTS_Base.md)
- [AGENTS_WorkerService.md](AGENTS_WorkerService.md)
- [../governance/RISK_CLASSIFICATION.md](../governance/RISK_CLASSIFICATION.md)
- [../governance/COMPLETION_EVIDENCE.md](../governance/COMPLETION_EVIDENCE.md)

## Exception Handling

Exceptions MUST follow [../governance/EXCEPTION_PROCESS.md](../governance/EXCEPTION_PROCESS.md). Vendor outages, unavailable sandboxes, or missing test credentials MUST be recorded honestly and MUST NOT be relabeled as success.
