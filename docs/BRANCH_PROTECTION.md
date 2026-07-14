# Branch Protection

| Status | Active |
| Version | 1.0.0 |
| Owner role | Repository Administrators |
| Last reviewed | 2026-07-12 |

## Purpose

Issue #19 introduces the provisional advisory check `Pull Request Governance / Validate pull request governance record`. Do not make it required until a post-merge controlled pull request proves the historical PR #12 pattern fails, a body-only edit passes, and the exact rendered name is recorded. Preserve the existing Governance and Candidate implementation validation checks and every Issue #18 protection when enabling or rolling back this check.

Branch protection converts governance policy into merge controls. This document defines the required protection model for repositories that adopt the engineering standards repository.

Protection must apply to the branch that receives production, release, or authoritative governance changes. In this organization, examples support both `master` and `main` because repositories may use either branch name.

## Applicability

Apply these rules to `master`, `main`, release branches, and any long-lived branch used for production deployments or shared governance artifacts. Temporary feature branches do not need the full rule set, but they must merge through a protected branch before release.

High and Critical repositories SHOULD use rulesets or branch protections that prevent administrators from bypassing controls except through a documented emergency process.

## Required Protection Rules

Protected branches MUST require pull requests before merge, at least one approving review, CODEOWNERS review where ownership exists, conversation resolution, required status checks, and restriction of force pushes and branch deletion.

Repositories handling production infrastructure, restricted data, authentication, authorization, cryptography, or destructive operations SHOULD require two approvals and up-to-date branches before merge.

## Observed Current State

Inspection date: `2026-06-27`
Observed-state timestamp: `2026-06-27T18:21:00Z`
Protection-configuration timestamp: `2026-06-27T13:54:22Z`

Inspection method:

```powershell
gh api repos/AIAllTheThingz/Engineering-Standards/branches/master/protection
```

Historical start state for `AIAllTheThingz/Engineering-Standards` during the release-protection task:

- Protected branch inspected: `master`
- Classic branch protection before configuration: not configured
- API result: `404 Branch not protected`
- Required checks observed before configuration: none through classic branch protection
- Repository rulesets API result: `[]`
- Ruleset state before configuration: no repository rulesets configured
- Exact governance check name observed from the successful validation run: `Governance / Governance validation`
- Observed repository head at inspection time: `ab45ee1f6b82449e3b595b7e0951dc00b4db364b`
- Observed successful current-head run: `28290761409`

Historical verification for the 2026-06-27 release-validation refresh:

- Protected branch inspected: `master`
- Current protected `master` head: `072df3c372d431e3ac5fd0e4569b55f93555ce95`
- Exact-target success run: `28293025156`
- Exact-target controlled-failure run: `28297679210`
- Required governance check: `Governance / Governance validation`
- Repository rulesets API result: `[]`
- Ruleset state: no repository rulesets configured; classic branch protection is the active mechanism.

Reviewer and ownership assessment during the same review:

- Direct collaborators visible through `gh api repos/AIAllTheThingz/Engineering-Standards/collaborators?affiliation=direct`: only `AIAllTheThingz` with admin permission.
- `CODEOWNERS` contains team-style identities under `@AIAllTheThingz/...`.
- Live team resolution through `gh api orgs/AIAllTheThingz/teams?per_page=100` returned `404 Not Found`, consistent with a user-owned repository context rather than a resolvable organization-team context.
- No eligible independent reviewer was identified at inspection time.
- At that inspection, CODEOWNERS review could not be required safely and the approving-review count remained at the strongest non-locking value then configured. The live state below supersedes that historical count.

This section is descriptive evidence, not a recommendation. The recommended configuration in this guide remains stricter than the currently observed repository setting.

## Verified Applied State

Verification method:

```powershell
gh api repos/AIAllTheThingz/Engineering-Standards/branches/master/protection
```

Verified configured state for `AIAllTheThingz/Engineering-Standards` from live API inspection at `2026-07-11T23:10:37Z`:

- Protected branch: `master`
- Protection mechanism: classic branch protection
- Pull requests required: yes
- Required governance checks: `Governance / Governance validation` and `Candidate implementation validation / Candidate implementation validation`
- Strict up-to-date checks required: yes
- Conversation resolution required: yes
- Force pushes allowed: no
- Branch deletion allowed: no
- Administrator enforcement enabled: yes
- Required approving review count: `1`
- Dismiss stale reviews: yes
- Require CODEOWNERS review: no
- Require last-push approval: no
- Repository rulesets configured in parallel: none
- Verification result: `Passed`

## Issue 18 Pre-Change Inspection

Live inspection at `2026-07-12T17:10:00Z` confirmed that `AIAllTheThingz/Engineering-Standards` is owned by the GitHub user `AIAllTheThingz`, not an organization. Direct collaborators eligible to review were `AIAllTheThingz` (admin), `mezuccolini` (write), and `megad00die` (write). One expired invitation was observed and excluded. The existing team-style CODEOWNERS entries all produced live `Unknown owner` parser errors.

Classic protection on `master` remained the active branch mechanism: pull requests, one approval, both documented required checks, strict mode, stale-review dismissal, conversation resolution, administrator enforcement, force-push blocking, and deletion blocking were active. CODEOWNERS and last-push approval were not active. No repository rulesets existed.

The Issue 18 design preserves classic branch protection and does not stack a branch ruleset over it. With two independent write collaborators available for an owner-authored change, the High-risk plan recommends two approvals. After the corrected CODEOWNERS reaches `master`, the settings phase enables two approvals, CODEOWNERS review, and last-push approval. A separate tag-only ruleset targets `v*`; its final ID and verified post-change state must be recorded after mutation. The sanitized pre-change record is [`../evidence/github-settings-issue-18-pre.json`](../evidence/github-settings-issue-18-pre.json).

Repository health performs offline structural CODEOWNERS validation with owner type `Unknown` by default. It does not infer user or organization ownership from repository text, resolve identities, or prove repository access. Compatibility checks require explicit owner type from trusted live API evidence; reviewer eligibility requires separate collaborator and identity API reads.

This verified state requires both immutable trusted-baseline validation and unprivileged candidate implementation validation before merge.

## Historical Applied Configuration Strategy

When only the repository owner or sole maintainer is currently eligible to review, protection must remain strong without creating an unrecoverable lockout.

For `AIAllTheThingz/Engineering-Standards`, the 2026-06-27 release-protection task applied the following classic branch protection model, since superseded by the live state above:

- pull requests required
- required status check `Governance / Governance validation`
- strict up-to-date branch requirement enabled
- conversation resolution required
- force pushes blocked
- branch deletion blocked
- administrators enforced
- required approving review count set to `0`
- stale approvals dismissed when new commits are pushed
- CODEOWNERS review not required until resolvable independent owners exist
- no repository ruleset used in parallel

This historical configuration is not the current enforcement state and is not proof that independent review requirements have been satisfied for release approval.

## Required Checks

At minimum, require the governance workflow check produced by the reusable governance workflow. The required check set SHOULD include schema validation, documentation completeness, contract validation, forbidden-pattern scanning, repository health, evidence validation, and applicable technology checks.

Schema `1.2.0` records exact check strings in `requiredCheckNames` and the
workflow-interface declaration. For this repository the governed checks are
`Governance / Governance validation` and
`Candidate implementation validation / Candidate implementation validation`.
Local syntax validation cannot prove live branch settings; compare these values
with trusted GitHub protection evidence.

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

Repositories declare mandatory literal coverage paths in `ownership.requiredCodeownerPaths` within `governance.config.json`. Each entry must be a unique repository-rooted file or directory path; wildcards, traversal, drive or UNC paths, whitespace, comments, and placeholders are rejected. If the property is omitted, repository health remains reusable and requires only a valid default `*` rule instead of assuming this governance repository's directory layout.

Repository health evaluates required paths using CODEOWNERS last-match precedence. The final applicable supported rule must contain at least one structurally valid owner compatible with the explicitly supplied repository owner type. A later ownerless, malformed, placeholder, or incompatible override therefore fails even when an earlier rule was valid. Validation supports the documented safe subset used by this repository: `*`, rooted literal file or directory rules, and simple `*` or `**` globs. A decision-relevant pattern outside that subset fails closed and requires maintainer review rather than producing an optimistic ownership claim.

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
