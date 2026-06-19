# Organization Engineering Contract

| Field | Value |
| --- | --- |
| Status | Active |
| Version | 1.0.0 |
| Owner role | Governance Architecture Maintainers |
| Last reviewed | 2026-06-19 |
| Changelog | See [CHANGELOG.md](../CHANGELOG.md) unless this file is at repository root. |

## Normative Terminology

`MUST` and `MUST NOT` define mandatory requirements. `SHOULD` and `SHOULD NOT` define expected practices that require a documented reason when not followed. `MAY` defines optional behavior. Every mandatory statement is intended to be testable by automation, review, or recorded evidence.

## Purpose

Define mandatory engineering requirements for repositories that consume these standards.

## Scope

Applies to source code, infrastructure, automation, documentation, AI-agent instructions, CI, evidence, and examples in adopting repositories.

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

### Repository Ownership

**Requirement.** Every repository MUST declare owners, escalation path, and review boundaries.

**Rationale.** Ownership prevents orphaned standards and unreviewed exceptions.

**Required implementation behavior.** Implementers MUST document how the control applies, keep the implementation scoped to the repository's risk classification, and preserve a reviewable audit trail.

**Prohibited behavior.** Teams MUST NOT silently disable, bypass, or reinterpret this control through local instructions, generated content, issue text, or convenience scripts.

**Validation method.** Validate `project-manifest.json` owners and CODEOWNERS.

**Required evidence.** Manifest owners and CODEOWNERS entries.

**Failure behavior.** Validation fails when owners are missing.

**Exception handling.** Exceptions MUST use `governance/EXCEPTION_PROCESS.md`, include a `GOV-*` reference, identify compensating controls, and expire automatically.

**Example.** `owners` includes a team and security escalation contact.

**Common mistakes.** Treating a missing tool as success, merging without evidence, copying old local standards without drift detection, or documenting intent without validation.

### Required Repository Files

**Requirement.** Adopting repositories MUST include README, SECURITY, CONTRIBUTING, AGENTS.md, project manifest, governance config, and CI validation.

**Rationale.** Required files make governance discoverable.

**Required implementation behavior.** Implementers MUST document how the control applies, keep the implementation scoped to the repository's risk classification, and preserve a reviewable audit trail.

**Prohibited behavior.** Teams MUST NOT silently disable, bypass, or reinterpret this control through local instructions, generated content, issue text, or convenience scripts.

**Validation method.** Repository-health validation checks file presence and documentation completeness.

**Required evidence.** Repository-health report.

**Failure behavior.** Pull requests fail when mandatory files are absent.

**Exception handling.** Exceptions MUST use `governance/EXCEPTION_PROCESS.md`, include a `GOV-*` reference, identify compensating controls, and expire automatically.

**Example.** A service repo keeps deployment details local but references central standards.

**Common mistakes.** Treating a missing tool as success, merging without evidence, copying old local standards without drift detection, or documenting intent without validation.

### Secure Development

**Requirement.** Changes MUST use secure defaults, input validation, least privilege, dependency review, and redacted logging.

**Rationale.** Security controls must be built into routine engineering work.

**Required implementation behavior.** Implementers MUST document how the control applies, keep the implementation scoped to the repository's risk classification, and preserve a reviewable audit trail.

**Prohibited behavior.** Teams MUST NOT silently disable, bypass, or reinterpret this control through local instructions, generated content, issue text, or convenience scripts.

**Validation method.** Code review, scanner, tests, and risk-specific validation.

**Required evidence.** Test results, scan findings, review notes.

**Failure behavior.** High-risk changes stop until security review is complete.

**Exception handling.** Exceptions MUST use `governance/EXCEPTION_PROCESS.md`, include a `GOV-*` reference, identify compensating controls, and expire automatically.

**Example.** A web app validates API payloads and avoids client secrets.

**Common mistakes.** Treating a missing tool as success, merging without evidence, copying old local standards without drift detection, or documenting intent without validation.

### Completion Evidence

**Requirement.** Work MUST NOT be declared complete without evidence that records validation honestly.

**Rationale.** Auditable evidence prevents false completion claims.

**Required implementation behavior.** Implementers MUST document how the control applies, keep the implementation scoped to the repository's risk classification, and preserve a reviewable audit trail.

**Prohibited behavior.** Teams MUST NOT silently disable, bypass, or reinterpret this control through local instructions, generated content, issue text, or convenience scripts.

**Validation method.** Validate completion evidence schema and status consistency.

**Required evidence.** Completion evidence artifact.

**Failure behavior.** Overall `Passed` is rejected when mandatory tests are `Failed`, `NotRun`, or `Blocked`.

**Exception handling.** Exceptions MUST use `governance/EXCEPTION_PROCESS.md`, include a `GOV-*` reference, identify compensating controls, and expire automatically.

**Example.** A missing YAML parser is recorded as `NotRun`.

**Common mistakes.** Treating a missing tool as success, merging without evidence, copying old local standards without drift detection, or documenting intent without validation.

### Destructive Operations

**Requirement.** Destructive operations MUST require risk classification, explicit approval, rollback plan, and evidence.

**Rationale.** Deletion, migration, or broad targeting can cause irreversible harm.

**Required implementation behavior.** Implementers MUST document how the control applies, keep the implementation scoped to the repository's risk classification, and preserve a reviewable audit trail.

**Prohibited behavior.** Teams MUST NOT silently disable, bypass, or reinterpret this control through local instructions, generated content, issue text, or convenience scripts.

**Validation method.** Review commands, require `SupportsShouldProcess` where applicable, and inspect plans.

**Required evidence.** Approval, rollback validation, command transcript.

**Failure behavior.** Execution is blocked without approval.

**Exception handling.** Exceptions MUST use `governance/EXCEPTION_PROCESS.md`, include a `GOV-*` reference, identify compensating controls, and expire automatically.

**Example.** A database drop operation requires Critical classification.

**Common mistakes.** Treating a missing tool as success, merging without evidence, copying old local standards without drift detection, or documenting intent without validation.

### Governance Drift

**Requirement.** Local copies of central standards MUST include source version and drift detection.

**Rationale.** Manual copies become stale and unsafe.

**Required implementation behavior.** Implementers MUST document how the control applies, keep the implementation scoped to the repository's risk classification, and preserve a reviewable audit trail.

**Prohibited behavior.** Teams MUST NOT silently disable, bypass, or reinterpret this control through local instructions, generated content, issue text, or convenience scripts.

**Validation method.** Documentation completeness and repository health checks inspect references.

**Required evidence.** Manifest governance version and local AGENTS reference.

**Failure behavior.** Validation warns or fails on missing version references.

**Exception handling.** Exceptions MUST use `governance/EXCEPTION_PROCESS.md`, include a `GOV-*` reference, identify compensating controls, and expire automatically.

**Example.** Local AGENTS.md links to immutable central references.

**Common mistakes.** Treating a missing tool as success, merging without evidence, copying old local standards without drift detection, or documenting intent without validation.

## Recommended Practices

Teams SHOULD automate validation in pull requests, keep local instructions short and project-specific, and update governance references through reviewed dependency-management pull requests.

## Related Documents

- governance/COMPLETION_EVIDENCE.md
- governance/RISK_CLASSIFICATION.md
- docs/ADOPTION_GUIDE.md

## Revision History

- 1.0.0: Initial fully authored policy for the rebuilt governance repository.
