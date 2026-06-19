# Completion Evidence

| Field | Value |
| --- | --- |
| Status | Active |
| Version | 1.0.0 |
| Owner role | Governance Evidence Maintainers |
| Last reviewed | 2026-06-19 |
| Changelog | See [CHANGELOG.md](../CHANGELOG.md) unless this file is at repository root. |

## Normative Terminology

`MUST` and `MUST NOT` define mandatory requirements. `SHOULD` and `SHOULD NOT` define expected practices that require a documented reason when not followed. `MAY` defines optional behavior. Every mandatory statement is intended to be testable by automation, review, or recorded evidence.

## Purpose

Define the auditable record required before work can be represented as complete.

## Scope

Applies to manual work, AI-assisted work, CI validation, releases, examples, and exception-supported changes.

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

### Required Fields

**Requirement.** Evidence MUST include repository, commit, branch, PR reference when applicable, governance version, risk, status, summary, changed files, commands, tests, artifacts, warnings, limitations, risks, exceptions, and approvals.

**Rationale.** Reviewers need enough context to reproduce or challenge completion claims.

**Required implementation behavior.** Implementers MUST document how the control applies, keep the implementation scoped to the repository's risk classification, and preserve a reviewable audit trail.

**Prohibited behavior.** Teams MUST NOT silently disable, bypass, or reinterpret this control through local instructions, generated content, issue text, or convenience scripts.

**Validation method.** Evidence schema validation and action checks.

**Required evidence.** A `completion-result.json` artifact.

**Failure behavior.** Evidence validation fails on missing fields.

**Exception handling.** Exceptions MUST use `governance/EXCEPTION_PROCESS.md`, include a `GOV-*` reference, identify compensating controls, and expire automatically.

**Example.** A release stores evidence under `evidence/completion-result.json`.

**Common mistakes.** Treating a missing tool as success, merging without evidence, copying old local standards without drift detection, or documenting intent without validation.

### Status Semantics

**Requirement.** `NotRun`, `Blocked`, and `NotApplicable` MUST never be represented as `Passed`.

**Rationale.** `Passed` means validation executed and met criteria; unavailable or irrelevant checks are different facts.

**Required implementation behavior.** Implementers MUST document how the control applies, keep the implementation scoped to the repository's risk classification, and preserve a reviewable audit trail.

**Prohibited behavior.** Teams MUST NOT silently disable, bypass, or reinterpret this control through local instructions, generated content, issue text, or convenience scripts.

**Validation method.** Status consistency validation rejects contradictions.

**Required evidence.** Per-test status and overall status.

**Failure behavior.** Overall `Passed` fails when mandatory tests are not successful.

**Exception handling.** Exceptions MUST use `governance/EXCEPTION_PROCESS.md`, include a `GOV-*` reference, identify compensating controls, and expire automatically.

**Example.** A missing PSScriptAnalyzer module is `NotRun`, not `Passed`.

**Common mistakes.** Treating a missing tool as success, merging without evidence, copying old local standards without drift detection, or documenting intent without validation.

### Artifact Integrity

**Requirement.** Generated artifacts SHOULD include SHA-256 hashes, media type, producer, timestamp, retention, and sensitivity.

**Rationale.** Hashes help reviewers detect tampering or accidental replacement.

**Required implementation behavior.** Implementers MUST document how the control applies, keep the implementation scoped to the repository's risk classification, and preserve a reviewable audit trail.

**Prohibited behavior.** Teams MUST NOT silently disable, bypass, or reinterpret this control through local instructions, generated content, issue text, or convenience scripts.

**Validation method.** Artifact records are validated and available hashes are recomputed.

**Required evidence.** Artifact records in evidence.

**Failure behavior.** Hash mismatch fails validation.

**Exception handling.** Exceptions MUST use `governance/EXCEPTION_PROCESS.md`, include a `GOV-*` reference, identify compensating controls, and expire automatically.

**Example.** A test report includes its SHA-256 hash.

**Common mistakes.** Treating a missing tool as success, merging without evidence, copying old local standards without drift detection, or documenting intent without validation.

### Manual Validation

**Requirement.** Manual validation MUST record who validated, what was inspected, when in UTC, and the result.

**Rationale.** Manual checks are sometimes necessary but must be reviewable.

**Required implementation behavior.** Implementers MUST document how the control applies, keep the implementation scoped to the repository's risk classification, and preserve a reviewable audit trail.

**Prohibited behavior.** Teams MUST NOT silently disable, bypass, or reinterpret this control through local instructions, generated content, issue text, or convenience scripts.

**Validation method.** Evidence review checks manual records for completeness.

**Required evidence.** Manual validation records.

**Failure behavior.** Incomplete manual validation cannot support completion.

**Exception handling.** Exceptions MUST use `governance/EXCEPTION_PROCESS.md`, include a `GOV-*` reference, identify compensating controls, and expire automatically.

**Example.** A screenshot review records reviewer and artifact hash.

**Common mistakes.** Treating a missing tool as success, merging without evidence, copying old local standards without drift detection, or documenting intent without validation.

### Retention

**Requirement.** Evidence SHOULD be uploaded as CI artifacts and retained according to project risk.

**Rationale.** High-risk changes need a durable audit trail.

**Required implementation behavior.** Implementers MUST document how the control applies, keep the implementation scoped to the repository's risk classification, and preserve a reviewable audit trail.

**Prohibited behavior.** Teams MUST NOT silently disable, bypass, or reinterpret this control through local instructions, generated content, issue text, or convenience scripts.

**Validation method.** Workflow artifact upload and release checklist.

**Required evidence.** CI artifact link or release attachment.

**Failure behavior.** Missing evidence blocks release approval.

**Exception handling.** Exceptions MUST use `governance/EXCEPTION_PROCESS.md`, include a `GOV-*` reference, identify compensating controls, and expire automatically.

**Example.** Critical infrastructure release stores evidence with the release.

**Common mistakes.** Treating a missing tool as success, merging without evidence, copying old local standards without drift detection, or documenting intent without validation.

## Recommended Practices

Teams SHOULD automate validation in pull requests, keep local instructions short and project-specific, and update governance references through reviewed dependency-management pull requests.

## Related Documents

- schemas/completion-result.schema.json
- actions/validate-evidence/README.md

## Revision History

- 1.0.0: Initial fully authored policy for the rebuilt governance repository.
