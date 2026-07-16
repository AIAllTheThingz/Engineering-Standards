# Enterprise PowerShell Delivery Checklist

Use this checklist after reading the applicable governance and agent standards. It is an operational aid, not a replacement for those authorities.

Mark each item as `Passed`, `Failed`, `Blocked`, `NotRun`, or `NotApplicable` with a reason where required.

## Discovery And Scope

- Applicable `AGENTS.md`, base standard, PowerShell standard, and governance documents were read.
- Repository status and pre-existing user changes were inspected.
- Requested behavior and acceptance criteria are explicit.
- Supported PowerShell versions are declared.
- Affected files, public contracts, integrations, and dependencies are identified.
- Risk is classified using the governing risk standard.
- Read-only, state-changing, and destructive operations are separated.
- Target boundaries, environments, and data classification are known.
- Vendor or API behavior is based on authoritative documentation rather than guesswork.
- Assumptions and unresolved dependencies are recorded.

## Architecture

- Existing architecture is preserved unless restructuring is explicitly justified.
- Entry-point orchestration is separated from reusable functions.
- Public and private functions are separated where practical.
- Configuration, credentials, reporting, notifications, and generated artifacts have clear boundaries.
- Generated output is outside source directories.
- Reusable modules own real behavior and are not empty placeholders.
- Module manifests intentionally export the supported public surface.
- Runtime and module dependencies are pinned or constrained appropriately.

## Configuration And Input

- Environment-specific values are externalized.
- PSD1 is used unless an approved alternative is documented.
- A sanitized example configuration exists.
- Secrets are absent from configuration and examples.
- Required keys, types, ranges, allowed values, and unknown keys are validated.
- Path resolution uses a stable documented base.
- Configuration precedence is documented.
- CSV headers, blanks, duplicates, malformed records, and conflicting values are validated.
- Manual target input is supported when the workflow is not intentionally bulk-only.
- Empty input fails safely and never means all targets.
- Requested and canonical target identities are preserved in results.

## Credentials And Security

- Credential modes and precedence are explicit.
- Noninteractive execution does not depend on prompts.
- Secure credential sources do not silently fall back to weaker modes.
- Current-user behavior is intentional and documented.
- CyberArk, vault, certificate, managed identity, or token settings contain no secrets in source control.
- TLS validation and SSH host-key validation remain enabled.
- Passwords, tokens, authorization headers, private keys, and credential objects are not logged or reported.
- Authentication, authorization, connectivity, and dependency failures are distinguished.
- Least privilege and minimum required scopes are documented.
- Secret exposure response is documented when applicable.

## Safe Execution

- Default behavior is non-mutating.
- Discovery and validation are usable before execution is enabled.
- `DryRun` performs no mutation.
- Every mutation is inside `$PSCmdlet.ShouldProcess()`.
- State-changing public commands declare `SupportsShouldProcess`.
- `ConfirmImpact` matches risk.
- Exact target identity is revalidated immediately before mutation.
- Empty, wildcard, root, broad, ambiguous, and unapproved targets are rejected.
- Execution requires an explicit mode or gate.
- Before and after state are captured when safe and useful.
- Rollback, compensation, or operator recovery is documented.
- `Force` does not bypass safety validation or `ShouldProcess`.
- WinRM, CredSSP, firewall, SSH, delegation, trusted hosts, and certificate validation are not modified implicitly.

## Reliability

- Entry points use strict mode unless a compatibility exception is documented.
- Unrecoverable failures terminate with meaningful exit behavior.
- External resources are handled with `try`, `catch`, and `finally`.
- Timeouts, retries, backoff, and concurrency are bounded.
- Only transient, safely repeatable operations are retried.
- Rate limits and `Retry-After` are respected where applicable.
- Current state is checked before mutation.
- Repeated execution is safe or its limitations are explicit.
- Per-target failures do not disappear into a false overall success.
- Partial success is visible.
- Sessions, clients, temporary files, and maintenance states are cleaned up.
- Resume or recovery behavior exists for long-running orchestration where justified.

## Logging And Reporting

- Logs contain timestamp, severity, run ID, component, target, operation, and sanitized message.
- Log paths, retention, and verbosity are configurable where applicable.
- Console output does not corrupt pipeline output.
- A single normalized result contract drives output formats.
- Reports include mode, requested target, resolved target, status, planned action, performed action, changed-state indicator, error category, sanitized error, and retry count.
- CSV formula injection is mitigated.
- HTML values are encoded.
- JSON output has a stable documented contract.
- Report filenames avoid collisions.
- Report-write failures are surfaced.
- Logs, reports, and evidence contain no secrets.

## Documentation

- Top-level headers explain purpose, safety, dependencies, configuration, inputs, outputs, and examples.
- Every public function and user-facing script has complete comment-based help.
- Nontrivial private functions have a purpose contract.
- README prerequisites and supported runtimes are accurate.
- Installation and dependencies are documented.
- Every public parameter and switch is documented.
- Parameter sets, defaults, accepted values, conflicts, and safety implications are documented.
- Discovery, validation, `DryRun`, `WhatIf`, report, and execute behavior are distinguished.
- CSV and configuration schemas are documented with synthetic examples.
- Credential modes and precedence are documented.
- Logging, reporting, email, scheduling, signing, exit codes, troubleshooting, security, rollback, and recovery are documented when applicable.
- Examples are safe and do not name real production systems.
- No placeholders or TODO-based completion claims remain.

## Tests And Validation

- Parser validation ran for changed PowerShell files.
- Module manifests were validated when present.
- Pester unit tests cover positive, negative, boundary, and failure paths.
- Integration tests use synthetic or approved nonproduction targets.
- `WhatIf` tests prove mutation is not called.
- `DryRun` tests prove mutation is not called.
- Input validation and empty-input safety are tested.
- Credential precedence and failure categories are tested with synthetic values.
- Retry and timeout behavior are tested.
- Idempotence and partial failure are tested where applicable.
- Path traversal and unsafe-root rejection are tested where applicable.
- Reporting and redaction behavior are tested.
- PSScriptAnalyzer ran when available.
- Repository-specific governance, documentation, schema, workflow, and security validation ran when applicable.
- Exact commands, exit codes, counts, failures, skipped checks, and unavailable tools are recorded.

## Final Review And Evidence

- Final diff contains no unrelated changes.
- No secret, token, credential, internal endpoint, or sensitive production identifier was introduced.
- Public behavior and documentation are synchronized.
- Backward compatibility was evaluated.
- Generated files and temporary test output are excluded.
- Rollback implications are understood.
- Completion evidence is internally consistent.
- GitHub-hosted execution is not claimed unless it actually occurred.
- Mandatory `Failed`, `Blocked`, or `NotRun` checks remain visible.
- Overall status follows the governing completion rules.
