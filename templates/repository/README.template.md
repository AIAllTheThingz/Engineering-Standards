# <Project Name>

## Purpose

Describe the business or engineering problem this repository solves, the primary users, the systems it affects, and the operational consequence of failure.

## Ownership

- Product or system owner: `<owner>`
- Technical maintainer: `<maintainer>`
- Security reviewer: `<security-contact>`
- On-call or escalation path: `<escalation-path>`

## Architecture

Document the major components, trust boundaries, data flows, external integrations, deployment model, background jobs, storage systems, and runtime dependencies.

Include diagrams or links when available. Do not include credentials, private endpoints, customer data, or production-only secrets.

## Risk And Data Classification

- Risk classification: `<Low|Moderate|High|Critical>`
- Data classification: `<Public|Internal|Confidential|Restricted>`
- Production environments: `<none|names>`
- Destructive operations: `<yes|no and explanation>`

Explain why the classification is correct. Mention authentication, authorization, infrastructure changes, database migrations, financial impact, privacy impact, or regulated data where applicable.

## Requirements

List supported runtimes, package managers, SDKs, local services, cloud permissions, database dependencies, and test accounts required for validation.

Use example values only. Do not document live secrets or production credentials.

## Installation And Configuration

Provide setup steps with safe example values:

```powershell
<setup-command>
```

Configuration values must come from the approved secrets provider or documented non-secret configuration files.

## Validation

List the exact commands maintainers run before review:

```powershell
<lint-command>
<build-command>
<test-command>
<security-command>
```

For skipped checks, record `NotRun`, `Skipped`, or `Blocked` in evidence with the reason.

## Deployment

Describe deployment entry points, approval requirements, environment promotion order, release artifacts, and smoke checks.

Production changes require completion evidence and rollback instructions.

## Rollback

Describe rollback commands, data recovery steps, migration rollback limits, feature flag controls, and escalation contacts.

If rollback is not possible, explain the compensating recovery plan.

## Security

Document authentication, authorization, secret storage, dependency review, logging redaction, data retention, and incident reporting expectations.

Never place credentials, tokens, private keys, customer records, or production endpoints in issues, prompts, logs, examples, or evidence.

## Governance

- Governance version: `<immutable-reference>`
- Central standards: `<standards-list>`
- Manifest: `project-manifest.json`
- Configuration: `governance.config.json`
- Completion evidence: `evidence/completion-result.json`
- Active exceptions: `None` or `GOV-*`

This repository MUST follow the organization contract, completion evidence policy, risk classification model, exception process, and applicable agent standards.

## Related

- `project-manifest.json`
- `governance.config.json`
- `AGENTS.md`
- `SECURITY.md`
- `CONTRIBUTING.md`
