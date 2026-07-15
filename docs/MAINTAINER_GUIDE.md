# Maintainer Guide

| Status | Active |
| Version | 1.0.0 |
| Owner role | Engineering Standards Maintainers |
| Last reviewed | 2026-07-15 |

## Purpose

This guide defines how maintainers operate the engineering standards repository. Maintainers protect the integrity of governance documents, schemas, actions, reusable workflows, examples, templates, evidence, and release artifacts.

Maintainers are not only document editors. They own the control system that downstream repositories rely on for safe review, validation, and change governance.

## Maintainer Responsibilities

Maintainers MUST keep governance documents authoritative, validators executable, schemas compatible with fixtures, workflows pinned, examples current, and evidence honest. A maintainer review must consider both policy language and whether the policy is actually enforced by automation or reviewer process.

Maintainers also own downstream communication. Breaking changes, new mandatory controls, deprecations, and emergency fixes must be documented in release notes and migration guidance.

## Stewardship Model

Each major area SHOULD have a named steward: governance policy, schemas, PowerShell validation, GitHub Actions, templates, security review, examples, and releases. A single person can hold multiple steward roles, but no critical release should depend on undocumented ownership.

This repository is user-owned. Its enforceable owners are the verified GitHub users `@AIAllTheThingz`, `@mezuccolini`, and `@megad00die`; organization-team syntax is not valid here. Re-query direct collaborator access and CODEOWNERS parser errors before changing review enforcement. A future transfer to an organization requires replacing user routing only after the destination teams exist, are visible, and have repository access.

When a maintainer leaves or changes responsibilities, update CODEOWNERS, release notes contacts, and repository health expectations in the same maintenance cycle.

## Change Intake

Changes enter through pull requests, issues, security reports, or emergency maintainer action. Every change must identify its reason, affected control area, risk classification, validation plan, and downstream impact.

Requests that weaken a mandatory control MUST be treated as exceptions or breaking governance changes. They cannot be merged as routine documentation edits.

## Backlog Stewardship

Planned active work MUST have an authoritative GitHub issue before or in the
same change that documents it. The issue records the accountable role, assigned
owner, risk, user value, dependencies, target release or milestone guidance,
acceptance criteria, required validation and evidence, and rollback. Planning
documents link to the issue and do not copy volatile status or progress
checkboxes.

Maintainers review the backlog monthly and before each release candidate. They
inventory planned work and known limitations, deduplicate against existing
issues, revisit accepted-risk and non-action decisions, and verify live issue
assignment through GitHub. Empty skill directories and vague one-line issues do
not satisfy ownership. Follow [Backlog Management](BACKLOG_MANAGEMENT.md) for
the normalized backlog, limitation dispositions, priority rules, review
checklist, and Exception triggers.

## Review Requirements

Policy changes require review from a governance maintainer. Schema changes require valid and invalid fixtures. Validator changes require Pester tests. Workflow changes require action pin review, permission review, evidence review, and artifact behavior review.

Security-sensitive changes require review against `docs/ACTION_SECURITY.md`. Changes that affect AI-generated code, secrets, dependency review, authentication, authorization, cryptography, infrastructure, database migrations, or destructive operations require heightened scrutiny.

The protected `master` branch currently requires one approval, but the High-risk target is two while two independent reviewers remain available. CODEOWNERS and last-push enforcement are safe only while at least one eligible reviewer other than the author or last pusher remains available. Pending invitations, bots, comments, and the author reviewing their own pull request do not satisfy independent review. If reviewer availability cannot meet the risk target, administrators must select the strongest non-locking approval count, preserve checks, conversation resolution, stale-review dismissal, force-push blocking, deletion blocking, and administrator enforcement, and document the segregation-of-duties gap.

## Schema Maintenance

When changing a schema, update the schema file, at least one valid fixture, at least one invalid fixture when the rule changes, validator expectations, documentation, and completion evidence. Removing an allowed value or adding a required field is a breaking change unless a compatibility path exists.

Schemas MUST reject ambiguous evidence. For example, overall Passed status cannot coexist with failed mandatory tests.

Additive schema changes should prefer a minor schema version with a documented
compatibility window. Contract `1.2.0` retains `1.0.0` and `1.1.0` instance
support while templates and examples move forward. Maintainers must keep schema,
semantic validator, fixtures, templates, examples, workflow interface, and
migration rationale synchronized; required fields must never be backported
silently into an older document version.

## Validator Maintenance

Validators MUST fail closed for malformed required inputs and write structured output when an output path is requested. They must not leak secrets in logs. They should distinguish `Failed`, `Blocked`, and `NotRun` instead of flattening everything into failure.

The aggregate validator and `scripts/governance-validation.registry.psd1` are the
authoritative validation surface. Maintainer profile categories, order,
applicability, prerequisites, and trust behavior must be changed in the registry
with synchronized tests and documentation. Explicit category selection can
filter optional categories only; it cannot remove mandatory checks.

When updating validators, run focused Pester tests and the aggregate governance validation. Tests must cover positive cases, negative cases, and any edge case that caused a bug or regression.

Codex skill changes require `scripts/Test-CodexSkills.ps1`, prompt-corpus structural validation, safe metadata/reference review, and human trigger-quality review. Deterministic CI must not execute skill scripts or relabel unevaluated model behavior as passed.

## Workflow Maintenance

Reusable workflows MUST use least-privilege permissions, pinned third-party actions, explicit checkout behavior, deterministic job names, clear artifact retention, and evidence generation on failure using `if: always()` where appropriate.

Entry workflows should call reusable workflows. Reusable workflows must not call entry workflows. Avoid circular invocation and avoid branch filters that exclude the repository's active protected branch.

Final enforcement MUST run after final test evidence, final completion evidence, final evidence validation, and artifact upload. A controlled failure must still upload evidence before enforcement fails the job.

## Validator Dependency Maintenance

Maintainers MUST treat runner labels, setup actions, runtimes, parsers, test
frameworks, analyzers, and their package sources as security-sensitive validator
code. The supported environment is declared in
`.github/dependencies/validator-dependencies.psd1`; duplicate workflow values
must match that lock and may not drift independently.

Dependabot action and pip pull requests are review signals. Maintainers must
verify the official source, publisher, support lifecycle, release notes,
vulnerability status, full action SHA, exact artifact, and SHA-256 before
updating the lock. Pester and PSScriptAnalyzer updates are manual because the
PSGallery package hash and extracted manifest are reviewed together. A remote
source is never trusted merely because TLS or PSGallery/PyPI supplied the file.

Run `scripts/Test-ValidatorDependencies.ps1`, missing-cache and tamper tests,
Pester, PSScriptAnalyzer, aggregate validation, exact-SHA GitHub success and
controlled-failure runs, artifact verification, and the external canary before
rotating an authoritative workflow pin. Review `environment.json`,
`runtime-bootstrap.json`, `dependencies.json`, and
`validator-sbom.cdx.json`. Follow the complete update and offline procedure in
[Validator Dependency Model](VALIDATOR_DEPENDENCIES.md).

## Template Maintenance

Templates must be usable as starting points, not decorative examples. Repository templates must prompt for owners, risk, evidence, validation commands, rollback, security reporting, and exceptions. Issue and pull request templates must collect enough information for maintainers to triage without asking for secrets.

Template placeholders are allowed inside `templates/`, but they must be explicit, safe, and easy to replace. Templates must not include fake success commands.

## Evidence Maintenance

Every substantive pull request MUST refresh completion evidence or explain why evidence is intentionally unchanged. Evidence is generated after validation, records actual outcomes, and includes skipped or blocked checks honestly.

Maintainers MUST reject evidence that claims success without commands, exit codes, scope, timestamps, or reviewer context. Contradictory evidence is a governance failure.

Checked-in local evidence and GitHub artifact evidence have different authority. Local evidence records the local execution context and may remain `NotRun` for GitHub-hosted execution. GitHub artifact evidence is authoritative only after a real workflow run, artifact download, independent hash verification, metadata verification, absolute-path scan, and secret-pattern scan.

Use `validatedCommitSha` for the commit validated by commands. Use `evidenceCommitSha` only when recording the commit that contains a checked-in evidence file. Do not repeatedly regenerate evidence solely to make those fields equal.

After proving a workflow run, update `evidence/latest-verified-run.json` with metadata only: run ID, attempt, artifact ID, artifact ZIP SHA-256, validated commit, controlled-failure run, verification timestamp, and verifier.

When release readiness depends on a current GitHub run, select the exact target SHA first, then dispatch success and controlled-failure proof runs against that target. Do not reuse older verified runs for newer commits.

## Release Preparation

Before release, update `VERSION`, changelog or release notes, migration guidance, examples, schemas, templates, and documentation as needed. Confirm that downstream invocation examples reference the correct reusable workflow.

Release candidates should be tested from a clean checkout. If local tooling is unavailable, record the missing tool as `NotRun` or `Blocked` and decide whether release can proceed based on risk.

## Emergency Maintenance

Emergency changes are allowed for security fixes, broken validation affecting many repositories, or incorrect standards that create production risk. Emergency changes still require evidence, reviewer sign-off after the fact when immediate review is impossible, and a follow-up issue for any skipped validation.

Administrator bypass is not a routine merge path. An emergency bypass requires an approved or emergency `GOV-*` record, exact branch and commit scope, named operator and approver, skipped-control evidence, post-change validation, settings re-verification, and prompt restoration of normal enforcement.

Emergency releases MUST identify affected versions, downstream action required, rollback guidance, and whether existing evidence should be considered stale.

## Drift Management

Governance drift occurs when documentation, schemas, workflows, templates, and examples disagree. Maintainers SHOULD run drift checks during each release and whenever a central control is changed.

Common drift examples include a schema field that documentation does not describe, an example workflow that calls the wrong reusable file, a template that omits required evidence, or a branch protection guide that names checks that no longer exist.

## Validation

Run the maintainer validation set before merging substantive changes:

```powershell
pwsh -NoProfile -File scripts/Invoke-GovernanceValidation.ps1 -Path . -RepositoryOwnerType User
pwsh -NoProfile -File scripts/Test-ValidatorDependencies.ps1 -Path . -OutputJson .tmp/validator-dependencies.json
```

The aggregate report is non-passing when a mandatory category is `Failed`,
`Blocked`, or `NotRun`. Missing tools are recorded as `NotRun`; install the
declared prerequisites rather than omitting the category.

`User` is explicit because this repository is verified as user-owned. Hosted
schema `1.2.0` validation derives the trusted value from GitHub event metadata
and fails closed if it is unavailable or unsupported. Legacy `1.0.0` and
`1.1.0` downstream contracts may retain `Unknown`; validation must never derive
owner type from a repository-name string or caller-controlled repository data.

If Pester is unavailable, record `NotRun` with the reason, tool version context, and compensating review.

## Evidence

Maintainer evidence must include command output or structured reports for the validation set, Pester when applicable, manual review notes for policy-only changes, and artifact hashes when release artifacts are produced.

Evidence must identify known warnings. Warnings are acceptable only when reviewed and understood.

## Exception Handling

Maintainers may approve exceptions only within their authority. Exceptions must be scoped, temporary, justified, and tied to compensating controls. A maintainer who owns the affected change should not be the only approver for a High or Critical exception.

Expired exceptions must be removed, renewed, or converted into tracked remediation work before release.

## Related

- `docs/VERSIONING.md`
- `docs/RELEASE_PROCESS.md`
- `docs/ACTION_SECURITY.md`
- `docs/VALIDATOR_DEPENDENCIES.md`
- `docs/BACKLOG_MANAGEMENT.md`
- `governance/EXCEPTION_PROCESS.md`
- `governance/COMPLETION_EVIDENCE.md`
- `docs/TROUBLESHOOTING.md`
