# Release Process

| Status | Active |
| Version | 1.1.0 |
| Owner role | Release Maintainers |
| Last reviewed | 2026-07-15 |

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

The root `VERSION` identifies the latest published release. Work merged after its immutable tag target MUST remain accurately summarized under `CHANGELOG.md` `[Unreleased]` until a later release is approved and published. A historical hosted run validates only its recorded commit, not a later `master` head.

## Pre-Release Checklist

Before tagging, maintainers MUST confirm:

- `VERSION` matches the intended semantic version.
- Release notes or changelog entries describe downstream impact.
- Schemas and fixtures are synchronized.
- Templates reflect current required evidence and branch behavior.
- Reusable workflows call the correct scripts and upload evidence.
- Third-party actions are pinned by commit SHA.
- Release-critical runners and runtimes match the reviewed validator dependency lock.
- Dependency provenance evidence and the CycloneDX validator inventory match the intended release candidate.
- Examples validate against the current schemas and standards.
- Known warnings are reviewed.

## Validation

Run the standard release validation:

```powershell
pwsh -NoProfile -File scripts/Invoke-GovernanceValidation.ps1 -Path . -RepositoryOwnerType User
pwsh -NoProfile -File scripts/Test-ValidatorDependencies.ps1 -Path . -OutputJson .tmp/validator-dependencies.json
```

The aggregate includes the complete maintainer Pester suite. A focused rerun is
useful while diagnosing failures:

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
- Verified `environment.json`, `runtime-bootstrap.json`, `dependencies.json`, and `validator-sbom.cdx.json` for the exact release target
- External downstream canary success and four isolated expected-failure runs against the exact release candidate SHA

Every release candidate now requires the external canary success scenario at the exact candidate SHA. The complete lifecycle gate additionally requires the controlled failure and three contract-negative scenarios so publication evidence proves both compatibility and fail-closed behavior. Follow [Downstream Governance Canary](DOWNSTREAM_CANARY.md), verify every downloaded artifact independently, and record the canary commit, candidate standards SHA, run IDs, artifact IDs, hashes, and expected failure reasons in the release review. Any missing, stale, or unexpected result blocks release approval.

## Machine-Checked Lifecycle Gates

Release decisions are recorded with `schemas/release-lifecycle.schema.json` and enforced by `scripts/Test-ReleaseLifecycle.ps1`. The record binds every check, workflow run, artifact, canary scenario, approval, tag, and release observation to one lowercase full candidate SHA. `finalHeadSha` MUST remain equal to `candidateSha`; a new commit invalidates prior approval and exact-target evidence.

Prepare the record in `DryRun` mode first. Synthetic fixtures belong under `tests/fixtures`; they prove validator behavior and MUST NOT be presented as release Evidence. Live mode additionally verifies the current Git HEAD and clean worktree.

```powershell
pwsh -NoProfile -File scripts/Test-ReleaseLifecycle.ps1 `
  -Path . `
  -EvidencePath .tmp/releases/<version>-lifecycle.json `
  -Stage PreRelease `
  -OutputJson .tmp/releases/<version>-pre-release-result.json
```

The pre-release stage cannot pass until repository validation, Pester, PSScriptAnalyzer, JSON schemas, workflow architecture, governed skills, documentation, evidence, and release consistency have all passed against the candidate. It also requires the exact-target hosted success and controlled-failure runs, independent artifact verification, all five downstream canary scenarios, matching release metadata, formal human approval on the unchanged head, and current branch/tag protection observations.

After authorized publication, run `-Stage Publication`. This gate requires an annotated protected `v<version>` tag resolving to the candidate, `rewritten=false`, a published GitHub Release whose draft/prerelease state matches the version, reviewed-note hash agreement, and artifact hashes with provenance. Tag creation, release publication, and protection changes are external mutations and require explicit authorization; this validator never performs them.

After re-fetching external state, run `-Stage PostRelease`. This gate requires tag and GitHub Release verification, all canary scenarios against the published immutable ref, regression disposition, defect follow-up issues, an owned post-release record, and a refreshed [Downstream Compatibility](DOWNSTREAM_COMPATIBILITY.md) matrix. `NotRun` and `Blocked` remain honest non-passing states with actionable reasons.

## Evidence Generation

Generate completion evidence after validation. Evidence must include the validation commands, exit codes, status, timestamps, warnings, skipped checks, and artifact references.

For release artifacts, include artifact hashes. For manual approvals, include reviewer identity, approval location, and approval date.

Start the post-publication record from `templates/releases/POST_RELEASE_VERIFICATION.template.json`. The existing generated `evidence/releases/1.1.0-post-release-verification.json` remains historical Evidence in its original shape; new releases embed the equivalent observations in the lifecycle record and link the generated post-release record from `postRelease.recordPath`.

For governance workflow releases, verify both the success path and controlled-failure path in GitHub Actions. The success run may be a `push` or `workflow_dispatch` run, but it MUST target the exact approved implementation commit with mandatory examples, Pester, and documentation validation enabled. The controlled-failure run must use `controlled-failure-test=true` against that same implementation state and must fail only after evidence validation and artifact upload.

Download both evidence artifacts into isolated temporary directories, verify them with `scripts/Test-WorkflowEvidenceArtifact.ps1`, and record the successful artifact ZIP SHA-256 plus controlled-failure run metadata in `evidence/latest-verified-run.json`.

`validatedCommitSha` identifies the commit validated by the workflow. `evidenceCommitSha` identifies a commit containing checked-in local evidence when supplied. Do not require those fields to be equal for checked-in local evidence.

## Security Review

Security review is mandatory when the release changes GitHub Actions, PowerShell scripts, secret scanning, dependency controls, branch protection, authentication standards, infrastructure standards, database standards, or AI-generated code policy.

The reviewer MUST check for excessive permissions, untrusted input execution, unsafe `pull_request_target` use, shell injection, token exposure, unsanitized logs, dependency pin drift, moving runner labels, mismatched runtime versions, unverified package content, missing source provenance, and incomplete SBOM evidence.

Validator environment changes follow [Validator Dependency Model](VALIDATOR_DEPENDENCIES.md).
The release reviewer must confirm the lock, workflows, hashes, actual hosted
inventory, failure tests, and update rationale agree. Package or container
publication requires separate explicit authorization; a release PR must not
silently create a new distribution channel.

## Release Approval

Release approval requires passing mandatory checks or documented approved exceptions. A maintainer must verify that release notes, versioning, evidence, and migration guidance agree.

When a release changes governance contract or reusable-workflow semantics,
review `governanceVersion`, `governanceCommitSha`, and
`workflowInterfaceVersion` independently. Rotate the central self-CI pin only
after the implementation commit exists, validate the rotated commit through
GitHub Actions, and preserve the prior supported schema versions until their
separate major-version removal is approved.

Do not approve a release when evidence contradicts the stated status, required files are missing, mandatory controls are disabled without exception, or a known secret exposure is unresolved.

Do not approve a workflow-evidence release until `latest-verified-run.json` validates, the success artifact hash is independently recorded, the controlled-failure artifact is downloadable, absolute-path scans pass, secret-pattern scans pass, and sanitized Pester details are present.

## Tagging

Create an annotated tag for the release after approval:

```powershell
git tag -a v1.2.3 -m "Release v1.2.3"
git push origin v1.2.3
```

Release tags matching `v*` MUST be protected by the repository tag ruleset when the platform supports it. The ruleset blocks tag deletion and non-fast-forward updates and permits bypass only through the narrow accountable repository-administrator path. Re-query the ruleset before each release; do not infer protection from this document. If the platform cannot enforce tag rules, capture the API limitation and require independent release approval, immutable target verification, tag/ref audit, and a corrective patch release rather than rewriting a tag.

Do not rewrite release tags. If a tag is incorrect, publish a corrective patch release unless the security incident process explicitly authorizes a different action. Any emergency tag bypass requires a `GOV-*` record and post-action ref plus ruleset verification.

If no tag exists yet, document that the release is prepared but unpublished. Do not imply publication from a draft note or a prepared changelog entry.

## Publishing

Publish release notes that identify version, date, summary, breaking changes, new controls, fixed defects, workflow or action pin changes, schema changes, migration instructions, validation evidence, and known issues.

Publication is not complete when a tag command returns successfully. Re-fetch the tag object and peeled target, query the GitHub Release, hash the published notes and artifacts, then pass the Publication lifecycle gate. A draft release, an unverified tag, or a notes mismatch MUST remain unpublished in repository status records.

Downstream repositories should be told whether they must update immediately, may adopt at their normal cadence, or should wait for a follow-up fix.

## Post-Release Monitoring

After release, monitor downstream CI failures, security reports, issue templates, and maintainer feedback. If a release causes unexpected failures, triage whether the release exposed real drift or introduced a defect.

Run the canary at the published immutable reference, record every observed regression, and create one owned follow-up issue per defect before passing the PostRelease gate. Update support and deprecation state in `governance/downstream-compatibility.json`; do not leave compatibility decisions only in prose.

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
- `docs/DOWNSTREAM_CANARY.md`
- `docs/DOWNSTREAM_COMPATIBILITY.md`
- `docs/VALIDATOR_DEPENDENCIES.md`
