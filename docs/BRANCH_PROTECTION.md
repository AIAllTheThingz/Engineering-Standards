# Branch Protection

| Status | Active |
| Version | 1.0.0 |
| Owner role | Repository Administrators |
| Last reviewed | 2026-06-19 |

## Purpose

Branch protection converts governance policy into merge controls. This document defines the required protection model for repositories that adopt the engineering standards repository.

Protection must apply to the branch that receives production, release, or authoritative governance changes. In this organization, examples support both `master` and `main` because repositories may use either branch name.

## Applicability

Apply these rules to `master`, `main`, release branches, and any long-lived branch used for production deployments or shared governance artifacts. Temporary feature branches do not need the full rule set, but they must merge through a protected branch before release.

High and Critical repositories SHOULD use rulesets or branch protections that prevent administrators from bypassing controls except through a documented emergency process.

## Required Protection Rules

Protected branches MUST require pull requests before merge, at least one approving review, CODEOWNERS review where ownership exists, conversation resolution, required status checks, and restriction of force pushes and branch deletion.

Repositories handling production infrastructure, restricted data, authentication, authorization, cryptography, or destructive operations SHOULD require two approvals and up-to-date branches before merge.

## Observed Current State

Inspection date: `2026-06-26`

Inspection method:

```powershell
gh api repos/AIAllTheThingz/Engineering-Standards/branches/master/protection
```

Observed result for `AIAllTheThingz/Engineering-Standards`:

- Protected branch inspected: `master`
- Classic branch protection: not configured
- API result: `404 Branch not protected`
- Required checks observed: none through classic branch protection
- Ruleset state: unverified by this document unless separately exported from repository settings

This section is descriptive evidence, not a recommendation. The recommended configuration in this guide remains stricter than the currently observed repository setting.

## Required Checks

At minimum, require the governance workflow check produced by the reusable governance workflow. The required check set SHOULD include schema validation, documentation completeness, contract validation, forbidden-pattern scanning, repository health, evidence validation, and applicable technology checks.

Technology-specific repositories must also require their build and test checks, such as .NET test, web lint/build/test, PowerShell parser and Pester validation, database migration validation, worker-service tests, or infrastructure plan validation.

## Workflow Permissions

Required workflows must use least-privilege permissions. For validation-only workflows, `contents: read` is the normal baseline. Do not grant write permissions unless a job genuinely needs them and the risk is reviewed.

Workflows that run on pull requests from untrusted contributors MUST NOT execute untrusted code with privileged tokens.

## Branch Names

New repositories may use either `main` or `master`, but governance examples include both in push filters:

```yaml
on:
  push:
    branches: [master, main]
```

If a repository uses only one protected branch, protect that branch and document the active branch in adoption evidence. Do not leave a production branch unprotected because examples mention another name.

## CODEOWNERS

CODEOWNERS must route reviews to real owners. Placeholder teams, deleted teams, and inactive aliases create a false sense of control and MUST be corrected before enforcement.

Critical paths such as workflows, actions, schemas, governance documents, deployment configuration, database migrations, and security-sensitive code SHOULD have explicit owner coverage.

## Merge Methods

Repositories SHOULD disable merge methods that undermine auditability. Squash merge is acceptable when pull request metadata and evidence remain available. Rebase merge is acceptable only when required checks and approvals remain attached to the pull request record.

Direct pushes to protected branches MUST be disabled except for tightly controlled emergency administration.

## Administrator Bypass

Administrator bypass should be disabled for High and Critical repositories. If bypass remains enabled, document who can bypass, when bypass is allowed, and how bypass evidence is reviewed.

Every bypass of mandatory checks requires incident or exception evidence.

## Signed Commits And Tags

Signed commits are recommended where the organization can support them consistently. Release tags SHOULD be protected and signed when available.

Unsigned commits do not automatically invalidate governance evidence, but repositories with elevated risk may require signing as part of branch protection.

## Dependabot And Automation

Automation accounts must satisfy the same branch protection requirements unless an approved automation-specific policy exists. Dependabot pull requests still need required checks and review rules appropriate to dependency risk.

Do not grant automation broad write tokens to bypass governance checks.

## Emergency Changes

Emergency changes may bypass normal review only through the emergency exception process. Evidence must include the reason, approver, time, affected branch, skipped checks, compensating controls, and follow-up review.

After the emergency, restore normal branch protection and run validation against the resulting branch state.

## Validation

Branch protection cannot be fully validated from repository files alone. Adoption evidence MUST include either settings export, screenshot reference, API output, or maintainer attestation that names protected branches and required checks.

Repository health validation confirms that required files and workflows exist, but reviewers must still verify GitHub settings.

## Evidence

Branch protection evidence must record protected branch names, required checks, review requirements, bypass policy, force-push and deletion settings, CODEOWNERS coverage, and the date reviewed.

For changes to branch protection, attach evidence to the pull request or release record.

## Exceptions

Exceptions require a `GOV-*` record. Valid reasons may include temporary migration between branch names, unavailable GitHub plan features, or urgent incident response. Invalid reasons include convenience, slow tests without remediation, missing owners, or untriaged failing checks.

Expired branch protection exceptions are enforcement failures.

## Related

- `docs/ADOPTION_GUIDE.md`
- `docs/RELEASE_PROCESS.md`
- `docs/ACTION_SECURITY.md`
- `governance/ORGANIZATION_CONTRACT.md`
- `governance/EXCEPTION_PROCESS.md`
- `.github/workflows/governance-ci.yml`
