# Security

This is a nonproduction demonstration using synthetic data only.

Do not add real credentials, tokens, hostnames, tenant identifiers, customer data, internal endpoints, or executable production automation. The intentionally unsafe sample must never be run. Report suspected secret exposure privately to the repository maintainers and remove the affected demo material from circulation until reviewed.

Deterministic validation does not certify live model behavior. Production use requires the separate trusted evaluation, attributable review, and promotion controls documented by the Engineering Standards repository.

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
