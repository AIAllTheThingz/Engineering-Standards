# Contributing

| Field | Value |
| --- | --- |
| Status | Active |
| Version | 1.0.0 |
| Owner role | Governance Maintainers |
| Last reviewed | 2026-06-19 |
| Changelog | See [CHANGELOG.md](CHANGELOG.md). |

## Purpose

Pull requests must use the exact headings and record syntax in [Pull Request Body Governance](docs/PR_BODY_GOVERNANCE.md). Select exactly one change type and use only `Passed`, `Failed`, `NotRun`, `Blocked`, or `NotApplicable` where a governance status is requested. Dependabot and internal automation follow the same rules. Editing a body retriggers the advisory check without a code commit; the exact rendered check name must be verified before branch-protection enforcement.

This guide defines how contributors change the Engineering Standards repository safely. Contributions may alter governance obligations for downstream repositories, so documentation, validation, evidence, and release impact are part of the change, not afterthoughts.

## Before You Start

Classify the change before editing. A typo fix, schema change, workflow change, validator change, agent standard change, and release preparation change carry different review requirements. If the change affects production workflows, secrets, evidence semantics, branch protection, authentication, authorization, infrastructure, database migration, or destructive operation rules, treat it as security-sensitive.

Contributors MUST avoid adding real secrets, production endpoints, customer data, private keys, or live credentials. Use synthetic examples only.

## Local Setup

Use PowerShell 7 and Git. Pester is required for script and action test coverage. PSScriptAnalyzer is recommended; when it is unavailable, evidence must record `NotRun` rather than claiming success.

Core validation commands:

```powershell
pwsh -NoProfile -File scripts/Invoke-GovernanceValidation.ps1 -Path . -RepositoryOwnerType User
pwsh -NoProfile -File scripts/Test-ValidatorDependencies.ps1 -Path . -OutputJson .tmp/validator-dependencies.json
```

The aggregate default runs every mandatory maintainer category, including
Pester, PSScriptAnalyzer, and functional examples. Use the narrower commands
below while iterating, then finish with the aggregate command above:

```powershell
pwsh -NoProfile -File scripts/Test-JsonSchemas.ps1 -Path .
pwsh -NoProfile -File scripts/Test-MarkdownLinks.ps1 -Path .
pwsh -NoProfile -File scripts/Test-DocumentationCompleteness.ps1 -Path .
```

## Branching

Use short, descriptive branch names such as `governance/evidence-validation`, `docs/release-prep`, or `fix/workflow-artifacts`. Do not push directly to protected branches except through the documented emergency process.

Pull requests MUST explain risk classification, reason for change, security impact, data impact, tests performed, tests not performed, evidence, rollback, and exceptions.

## Documentation Changes

Documentation changes are substantive when they add, remove, or reinterpret a requirement. New or changed controls MUST define applicability, requirement, validation, evidence, exception handling, and failure behavior.

Governance contract changes additionally require a versioned compatibility
proposal before schema edits. Keep manifest/config schemas, semantic finding
IDs, valid and invalid fixtures, templates, examples, workflow-interface fields,
branch-protection check names, evidence locations, and migration documentation
in the same focused pull request.

Do not use repeated boilerplate to satisfy completeness checks. Author the operational details needed by maintainers and downstream repositories.

## Schema And Evidence Changes

Schema changes require valid and invalid fixtures, validator updates, documentation updates, and evidence that the schema behavior was tested. Evidence changes must preserve the rule that overall Passed cannot coexist with failed, blocked, or not-run mandatory validation.

Any change to completion status semantics is release-sensitive and may be breaking.

## Action And Workflow Changes

Composite actions and reusable workflows require security review. Third-party actions must be pinned by full commit SHA. Permissions must be least privilege. Artifact upload behavior must be explicit. Evidence generation should run on failure when possible so reviewers can diagnose the failure.

Reusable workflows must not call entry workflows. Downstream examples must call the reusable workflow, not the local entry workflow.

## Agent Standard Changes

Agent standards must preserve the authority hierarchy. Local or technology-specific instructions may strengthen central requirements but MUST NOT weaken mandatory controls.

Changes involving AI-generated code, prompt injection, secrets, false test evidence, destructive operations, production changes, authentication, cryptography, infrastructure, or database migrations require heightened review.

## Examples

Examples must be functional. A project example should include realistic files, validation commands, evidence behavior, and documentation. Fake commands such as placeholder lint or test output are not acceptable outside templates.

When updating an example, run its local validation path and central contract validation.

## Evidence

Substantive changes MUST refresh `evidence/test-results.json` and `evidence/completion-result.json` or explain why evidence is unchanged. Evidence must name actual commands, outcomes, limitations, warnings, and any skipped or blocked validation.

Do not edit evidence to claim a command ran when it did not.

## Review

CODEOWNERS identifies required review areas. Governance policy, schemas, actions, workflows, release files, and security-sensitive examples require the appropriate owners.

Reviewers MUST reject contradictory evidence, disabled mandatory controls without exceptions, expired exceptions, unsafe workflow permissions, unresolved secret exposure, and changes that lower risk classification without justification.

## Exceptions

Exceptions require an approved `GOV-*` record with scope, owner, reason, expiration, compensating control, and remediation plan. Exceptions are temporary and must be removed when the underlying issue is fixed.

## Related

- [Organization Contract](governance/ORGANIZATION_CONTRACT.md)
- [Completion Evidence](governance/COMPLETION_EVIDENCE.md)
- [Risk Classification](governance/RISK_CLASSIFICATION.md)
- [Maintainer Guide](docs/MAINTAINER_GUIDE.md)
- [Release Process](docs/RELEASE_PROCESS.md)
- [Security Policy](SECURITY.md)
