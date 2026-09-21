# Security

Do not add real tenant IDs, account numbers, credentials, state locations,
network ranges, production architecture, or provider access. The committed
design is fictional and non-deployable.

## Reporting and review

Follow the parent repository [security reporting process](../../SECURITY.md).
Provide a synthetic reproduction, the affected example path, and the observed
boundary violation. Do not include credentials, private payloads, or operational
logs in a public issue. A passing demonstration is not authorization to connect
this example to a real service or environment.

## Evidence handling

Before sharing a report, inspect generated files and diagnostic messages for
sensitive values. Preserve the distinction between simulated outcomes and
independently verified execution. Record unavailable checks with their actual
status and reason. Review dependency, input, and output changes against this
example's restrictions above; escalate any requirement for live access to the
repository maintainers before changing the demonstration boundary.
