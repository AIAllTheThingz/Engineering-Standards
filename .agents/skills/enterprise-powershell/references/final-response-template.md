# Enterprise PowerShell Final Response Template

Use this structure for the final delivery report. Keep failures, blocked checks, and validation that did not run visible.

## Summary

State what was created or changed, the intended operational outcome, and the applicable runtime and risk classification.

## Files Changed

List every created, modified, renamed, or deleted file with a brief purpose.

## Behavior Implemented

Describe:

- Public entry points and parameter sets.
- Supported operational modes.
- Target input and validation.
- Configuration behavior and precedence.
- Credential modes and precedence.
- Read-only and state-changing behavior.
- Logging, reporting, notification, and scheduling behavior.
- Retry, timeout, idempotence, rollback, and partial-failure behavior.

## Validation Performed

For each command that actually ran, report:

| Command | Exit code | Result | Evidence |
| --- | ---: | --- | --- |
| `<exact command>` | `<code>` | `Passed`, `Failed`, or another governed status | `<counts, artifact, or concise result>` |

Include test counts, failures, warnings, skipped tests, and tool versions when available.

## Validation Not Performed

List each applicable check that did not run and classify it as `Blocked`, `NotRun`, or `NotApplicable` with the reason.

Do not omit unavailable PowerShell hosts, external integration tests, GitHub Actions, production validation, or artifact verification.

## Security Considerations

Report:

- Credential and secret handling.
- Target boundaries and least privilege.
- Redaction behavior.
- TLS, host-key, and remoting posture.
- Destructive-operation gates.
- Dependency and supply-chain considerations.
- Any suspected exposure or required rotation.

## Rollback And Recovery

State:

- How source changes can be reverted.
- Which runtime actions are reversible.
- Which runtime actions are irreversible.
- Required compensating actions or operator recovery steps.
- Any saved plan, before state, backup, or recovery artifact.

## Remaining Risks

List unresolved assumptions, untested integrations, unavailable tools, environment dependencies, compatibility gaps, and operational limitations.

## Completion Status

Use exactly one governed overall status:

- `Passed`
- `Failed`
- `Blocked`
- `NotRun`
- `NotApplicable`

Do not use `Passed` when mandatory validation is `Failed`, `Blocked`, or `NotRun`.
