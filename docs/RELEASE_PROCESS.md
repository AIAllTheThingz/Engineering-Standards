# Release Process

| Status | Active |
| Version | 1.0.0 |
| Owner role | Release Maintainers |
| Last reviewed | 2026-06-19 |

## Purpose

This process defines how maintainers prepare, validate, approve, publish, and support releases of the engineering standards repository. A release is a governance event: downstream repositories may use it to justify approvals, branch protection, evidence, and agent behavior.

The release process applies to policy-only releases, schema releases, workflow releases, action releases, template releases, and emergency fixes.

## Release Types

Normal releases bundle reviewed governance improvements. Patch releases correct defects without changing downstream obligations. Emergency releases address security, broken CI, or incorrect governance behavior that creates material risk.

Every release type requires evidence. Emergency releases may compress review sequencing, but they do not remove the obligation to record validation, reviewer decisions, and downstream impact.

## Release Roles

A release maintainer coordinates scope, versioning, validation, tag creation, and publication. Area maintainers review affected files. Security maintainers review action, workflow, dependency, secret-handling, and scanner changes.

For High or Critical governance changes, release approval SHOULD include at least two maintainers who are not the sole authors of the change.

## Scope Definition

Define the release scope before updating `VERSION`. Identify changed controls, affected downstream repositories, schema changes, workflow changes, action pin changes, documentation changes, template changes, and migration actions.

Do not mix unrelated breaking changes into an emergency release. Ship the minimum repair, then follow with a normal release.

## Pre-Release Checklist

Before tagging, maintainers MUST confirm:

- `VERSION` matches the intended semantic version.
- Release notes or changelog entries describe downstream impact.
- Schemas and fixtures are synchronized.
- Templates reflect current required evidence and branch behavior.
- Reusable workflows call the correct scripts and upload evidence.
- Third-party actions are pinned by commit SHA.
- Examples validate against the current schemas and standards.
- Known warnings are reviewed.

## Validation

Run the standard release validation:

```powershell
pwsh -NoProfile -File scripts/Invoke-GovernanceValidation.ps1 -Path . -Category JsonSchemas,MarkdownLinks,DocumentationCompleteness,Contract,ForbiddenPatterns,RepositoryHealth,Evidence,Examples
```

Run Pester when scripts, actions, schemas, validators, or completion evidence behavior changed:

```powershell
pwsh -NoProfile -Command "Invoke-Pester -Path tests -Output Detailed"
```

If a validator is unavailable, record the result as `NotRun` or `Blocked` with the reason. Do not convert missing validation into success.

Before release approval, maintainers MUST also confirm:

- Clean worktree
- Final diff review
- Exact target SHA
- Branch-protection inspection status
- Success GitHub run for the exact release target
- Controlled-failure proof run for the exact release target
- Independent artifact download and verification

## Evidence Generation

Generate completion evidence after validation. Evidence must include the validation commands, exit codes, status, timestamps, warnings, skipped checks, and artifact references.

For release artifacts, include artifact hashes. For manual approvals, include reviewer identity, approval location, and approval date.

For governance workflow releases, verify both the success path and controlled-failure path in GitHub Actions. The success run may be a `push` or `workflow_dispatch` run, but it MUST target the exact approved implementation commit with mandatory examples, Pester, and documentation validation enabled. The controlled-failure run must use `controlled-failure-test=true` against that same implementation state and must fail only after evidence validation and artifact upload.

Download both evidence artifacts into isolated temporary directories, verify them with `scripts/Test-WorkflowEvidenceArtifact.ps1`, and record the successful artifact ZIP SHA-256 plus controlled-failure run metadata in `evidence/latest-verified-run.json`.

`validatedCommitSha` identifies the commit validated by the workflow. `evidenceCommitSha` identifies a commit containing checked-in local evidence when supplied. Do not require those fields to be equal for checked-in local evidence.

## Security Review

Security review is mandatory when the release changes GitHub Actions, PowerShell scripts, secret scanning, dependency controls, branch protection, authentication standards, infrastructure standards, database standards, or AI-generated code policy.

The reviewer MUST check for excessive permissions, untrusted input execution, unsafe `pull_request_target` use, shell injection, token exposure, unsanitized logs, and dependency pin drift.

## Release Approval

Release approval requires passing mandatory checks or documented approved exceptions. A maintainer must verify that release notes, versioning, evidence, and migration guidance agree.

Do not approve a release when evidence contradicts the stated status, required files are missing, mandatory controls are disabled without exception, or a known secret exposure is unresolved.

Do not approve a workflow-evidence release until `latest-verified-run.json` validates, the success artifact hash is independently recorded, the controlled-failure artifact is downloadable, absolute-path scans pass, secret-pattern scans pass, and sanitized Pester details are present.

## Tagging

Create an annotated tag for the release after approval:

```powershell
git tag -a v1.2.3 -m "Release v1.2.3"
git push origin v1.2.3
```

Tags SHOULD be protected. Do not rewrite release tags. If a tag is incorrect, publish a corrective patch release unless the security incident process explicitly authorizes a different action.

If no tag exists yet, document that the release is prepared but unpublished. Do not imply publication from a draft note or a prepared changelog entry.

## Publishing

Publish release notes that identify version, date, summary, breaking changes, new controls, fixed defects, workflow or action pin changes, schema changes, migration instructions, validation evidence, and known issues.

Downstream repositories should be told whether they must update immediately, may adopt at their normal cadence, or should wait for a follow-up fix.

## Post-Release Monitoring

After release, monitor downstream CI failures, security reports, issue templates, and maintainer feedback. If a release causes unexpected failures, triage whether the release exposed real drift or introduced a defect.

Defects in the central repository should be corrected with a patch release and clear guidance.

## Rollback

Rollback usually means publishing a corrective patch and advising downstream repositories to pin back to a known-good SHA. Do not delete or rewrite published tags except under documented security incident approval.

Rollback evidence must state which versions are affected, which version is recommended, and what downstream maintainers should do.

## Emergency Release

Emergency releases are limited to urgent security or operability fixes. The release maintainer may reduce normal batching, but MUST record incident context, affected versions, validation performed, skipped validation, compensating controls, approval, and follow-up tasks.

Emergency exceptions expire quickly and must be reviewed after the incident.

## Exceptions

Any release that skips required validation, ships with known failing mandatory checks, or changes support windows requires a `GOV-*` exception. The exception must be referenced in release notes and completion evidence.

Expired exceptions cannot justify a release.

## Related

- `docs/VERSIONING.md`
- `docs/MAINTAINER_GUIDE.md`
- `docs/ACTION_SECURITY.md`
- `governance/COMPLETION_EVIDENCE.md`
- `governance/EXCEPTION_PROCESS.md`
- `docs/TROUBLESHOOTING.md`
