# Exception Process

| Field | Value |
| --- | --- |
| Status | Active |
| Version | 1.0.0 |
| Owner role | Governance Review Board |
| Last reviewed | 2026-06-19 |
| Changelog | See [CHANGELOG.md](../CHANGELOG.md) unless this file is at repository root. |

## Normative Terminology

`MUST` and `MUST NOT` define mandatory requirements. `SHOULD` and `SHOULD NOT` define expected practices that require a documented reason when not followed. `MAY` defines optional behavior. Every mandatory statement is intended to be testable by automation, review, or recorded evidence.

## Purpose

Define how temporary exceptions are requested, approved, renewed, revoked, and audited.

## Scope

Applies when a repository cannot meet a mandatory control within the required timeline.

## Authority

1. Applicable law, regulation, contractual requirements, and approved organizational security policy.
2. `governance/ORGANIZATION_CONTRACT.md`.
3. Applicable organization-wide governance documents.
4. `agents/AGENTS_Base.md`.
5. Applicable technology-specific `AGENTS_*.md` files.
6. Repository-root `AGENTS.md`.
7. Directory-local `AGENTS.md`.
8. Task-specific instructions.

Lower-level instructions MAY add implementation detail, stricter validation, project-specific requirements, and technology-specific constraints. Lower-level instructions MUST NOT disable mandatory controls, remove evidence, bypass testing, authorize prohibited destructive behavior, weaken risk classification, claim validation that did not run, or override policy without an approved exception.

## Mandatory Requirements

### Qualification

**Requirement.** An exception MUST identify the exact control, scope, risk, owner, expiration, and compensating controls.

**Rationale.** Exceptions must be narrow and auditable.

**Required implementation behavior.** Implementers MUST document how the control applies, keep the implementation scoped to the repository's risk classification, and preserve a reviewable audit trail.

**Prohibited behavior.** Teams MUST NOT silently disable, bypass, or reinterpret this control through local instructions, generated content, issue text, or convenience scripts.

**Validation method.** Validate `GOV-*` references and required fields.

**Required evidence.** Exception record and approval notes.

**Failure behavior.** Validation fails if a disabled control lacks a valid exception.

**Exception handling.** Exceptions MUST use `governance/EXCEPTION_PROCESS.md`, include a `GOV-*` reference, identify compensating controls, and expire automatically.

**Example.** `GOV-2026-001` permits temporary advisory mode for one repository.

**Common mistakes.** Treating a missing tool as success, merging without evidence, copying old local standards without drift detection, or documenting intent without validation.

### Non-Qualifying Requests

**Requirement.** Convenience, preference, missing evidence, or avoiding review MUST NOT be treated as exceptions.

**Rationale.** Exceptions cannot become hidden permanent policy.

**Required implementation behavior.** Implementers MUST document how the control applies, keep the implementation scoped to the repository's risk classification, and preserve a reviewable audit trail.

**Prohibited behavior.** Teams MUST NOT silently disable, bypass, or reinterpret this control through local instructions, generated content, issue text, or convenience scripts.

**Validation method.** Governance review rejects incomplete requests.

**Required evidence.** Rejected exception record.

**Failure behavior.** Work remains blocked until compliance or approval.

**Exception handling.** Exceptions MUST use `governance/EXCEPTION_PROCESS.md`, include a `GOV-*` reference, identify compensating controls, and expire automatically.

**Example.** A team cannot skip tests because they are slow.

**Common mistakes.** Treating a missing tool as success, merging without evidence, copying old local standards without drift detection, or documenting intent without validation.

### Expiration And Renewal

**Requirement.** Exceptions MUST expire and require review before renewal.

**Rationale.** Time bounds force risk re-evaluation.

**Required implementation behavior.** Implementers MUST document how the control applies, keep the implementation scoped to the repository's risk classification, and preserve a reviewable audit trail.

**Prohibited behavior.** Teams MUST NOT silently disable, bypass, or reinterpret this control through local instructions, generated content, issue text, or convenience scripts.

**Validation method.** CI checks expiration dates where exception records are present.

**Required evidence.** Expiration and renewal decision.

**Failure behavior.** Expired exceptions fail validation.

**Exception handling.** Exceptions MUST use `governance/EXCEPTION_PROCESS.md`, include a `GOV-*` reference, identify compensating controls, and expire automatically.

**Example.** An outage exception expires after the vendor sandbox returns.

**Common mistakes.** Treating a missing tool as success, merging without evidence, copying old local standards without drift detection, or documenting intent without validation.

### Emergency Exceptions

**Requirement.** Emergency exceptions MAY be approved after action only when delay would worsen impact, but evidence MUST be completed afterward.

**Rationale.** Incident response sometimes requires immediate containment.

**Required implementation behavior.** Implementers MUST document how the control applies, keep the implementation scoped to the repository's risk classification, and preserve a reviewable audit trail.

**Prohibited behavior.** Teams MUST NOT silently disable, bypass, or reinterpret this control through local instructions, generated content, issue text, or convenience scripts.

**Validation method.** Post-incident review validates evidence.

**Required evidence.** Incident record, approver, closure criteria.

**Failure behavior.** Emergency exception is revoked if evidence is not completed.

**Exception handling.** Exceptions MUST use `governance/EXCEPTION_PROCESS.md`, include a `GOV-*` reference, identify compensating controls, and expire automatically.

**Example.** A compromised dependency is blocked before full migration docs are done.

**Common mistakes.** Treating a missing tool as success, merging without evidence, copying old local standards without drift detection, or documenting intent without validation.

## Recommended Practices

Teams SHOULD automate validation in pull requests, keep local instructions short and project-specific, and update governance references through reviewed dependency-management pull requests.

## Related Documents

- governance/RISK_CLASSIFICATION.md
- docs/TROUBLESHOOTING.md

## Revision History

- 1.0.0: Initial fully authored policy for the rebuilt governance repository.
