# Pull Request Body Governance

| Status | Active |
| --- | --- |
| Version | 1.0.0 |
| Owner role | Engineering Standards Maintainers |
| Last reviewed | 2026-07-12 |

## Purpose

This contract defines the deterministic pull-request body record accepted by Engineering Standards. Pull-request bodies, actors, event data, and changed filenames are untrusted data. Validation never evaluates that data as PowerShell or shell input and never writes the complete body to logs or evidence.

## Frozen Rule Matrix

The exact failure messages below are stable operator-facing messages. A configured exception can suppress a rule only when the active exception names the mapped mandatory control; validation never grants approval.

| Rule ID | Requirement | Required section | Canonical syntax | Positive examples | Negative examples | Changed-path dependency | Automation behavior | Exception behavior | Failure message | Severity |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| PRG001 | Exactly one canonical occurrence of every required heading; ignore headings in fences, block quotes, and HTML comments. | All ten governance sections | `## Summary` through `## Governance Exceptions`, once each | Ten unique headings | Missing, duplicate, quoted, commented, or fenced heading | No | Same rules for every actor | Not exceptable | `PRG001: Include exactly one occurrence of every required governance heading.` | Error |
| PRG002 | Sections must be substantive and free of known template prompts or standalone placeholders. | All | Completed prose/records after comments are removed | `Adds deterministic PR governance validation.` | Empty, `TODO`, `TBD`, `Placeholder`, `Describe what changed` | No | Same rules for every actor | Not exceptable | `PRG002: Replace empty, placeholder, or untouched template content with substantive governance information.` | Error |
| PRG003 | Select exactly one known change type; options may occur once only. | Change Type | One `[x]` or `[X]` among `Documentation-only`, `Patch fix`, `Backward-compatible governance addition`, `Breaking governance change`, `Security fix`, `Emergency change` | `- [x] Patch fix` | None/multiple checked, unknown or duplicate option | Used by PRG014 | Same rules for every actor | Control `pull-request-change-type` may be excepted | `PRG003: Select exactly one canonical change type and include each option once.` | Error |
| PRG004 | Provide one exact risk value and substantive rationale; never infer or lower it. | Risk Classification | `Risk: High` and `Rationale: ...` | `Risk: Moderate` plus rationale | Missing/invalid/multiple value or placeholder rationale | No | Same rules for every actor | Control `pull-request-risk` may be excepted | `PRG004: Provide exactly one canonical risk value and a substantive rationale.` | Error |
| PRG005 | Provide substantive security review; `None` requires explicit review and no sensitive changed path. | Security Impact | `Status: Reviewed` plus `Details: ...`, or `Status: None` plus reviewed reason | Reviewed workflow impact | Bare `None`; `None` with sensitive path | Yes: workflows, actions, scripts, governance, schemas, security/ownership/config/build/dependency/infrastructure definitions | No bot bypass | Control `pull-request-security-impact` may be excepted | `PRG005: Provide a substantive security-impact assessment; None requires explicit review and no security-sensitive changed paths.` | Error |
| PRG006 | Record classification, privacy, logging, retention, and production/customer-data effect; none/N/A needs reason. | Data Impact | Five labeled fields, or reviewed `NotApplicable` with reason | `Classification: Internal` plus four impacts | Missing field or unexplained none/N/A | No | Same rules for every actor | Control `pull-request-data-impact` may be excepted | `PRG006: Record classification, privacy, logging, retention, and production/customer-data impact with reasons.` | Error |
| PRG007 | Record testing command/name, working directory, exit code/outcome, and warnings/limitations. | Testing Performed | Repeated records containing `Command`, `Working directory`, `Outcome`, `Limitation` | Exact Pester command and `Exit code: 0` | Generic `Passed`; missing command/result | No | Same rules for every actor | Control `pull-request-testing` may be excepted | `PRG007: Record testing performed with command or validation name, working directory, outcome, and limitations.` | Error |
| PRG008 | Record omitted-test governance status and reason; `Skipped` is not a governance status. | Tests Not Performed | `Status: NotRun`, `Status: Blocked`, or `Status: NotApplicable`, plus `Reason: ...` | `NotApplicable` because no required tests omitted | `Skipped`; status without reason | No | Same rules for every actor | Control `pull-request-tests-not-performed` may be excepted | `PRG008: Use NotRun, Blocked, or NotApplicable for omitted tests and provide a reason.` | Error |
| PRG009 | Provide at least one concrete repository path, run/artifact ID, commit SHA, review record, or sanitized screenshot reference. | Evidence | `- Path: evidence/result.json`, `- Run: 123; Artifact: name` | Concrete path or run ID | `Tests passed`, `See CI`, `N/A` alone | No | Same rules for every actor | Control `pull-request-evidence` may be excepted | `PRG009: Provide at least one concrete evidence reference and any required reason.` | Error |
| PRG010 | Provide risk-appropriate rollback/recovery. Behavior changes require target, preconditions, steps, verification, irreversible effects, and owner/role. | Rollback Plan | Six labeled fields; documentation-only may use a scoped explained revert | Commit revert plus verification and owner | `Revert PR`, `Undo changes`, `N/A` alone | Documentation-only changes permit reduced form | Same rules for every actor | Control `pull-request-rollback` may be excepted | `PRG010: Provide a substantive rollback or recovery plan appropriate to the selected change type.` | Error |
| PRG011 | Declare `None` or valid configured `GOV-*` IDs; references do not approve or automatically waive rules. | Governance Exceptions | `None` or comma/newline-separated `GOV-[0-9]{4}-[0-9]{3,}` identifiers | Active configured exception mapped to a control | Malformed, absent, expired, or unmapped exception | Reads governance config | Same rules for every actor | Only active, approved, scoped configuration mappings apply | `PRG011: Declare None or valid active GOV-* exceptions that map to the affected controls.` | Error |
| PRG012 | Governance statuses must use the canonical vocabulary where a status is required. | Security Impact; Tests Not Performed; testing records | `Passed`, `Failed`, `NotRun`, `Blocked`, `NotApplicable` | `Outcome: Passed` | `Skipped`, `Success`, `N/A` as status | No | Same rules for every actor | Not exceptable | `PRG012: Replace noncanonical governance status aliases with Passed, Failed, NotRun, Blocked, or NotApplicable.` | Error |
| PRG013 | Reject a no-security-impact claim when a security-sensitive category changed; report categories only. | Security Impact | A substantive reviewed impact for sensitive changes | Workflow impact described | `Status: None` with `.github/workflows/**` | Yes; categories from PRG005 | No bot bypass | Control `pull-request-security-contradiction` may be excepted | `PRG013: Security impact cannot be None because security-sensitive changed-path categories were detected.` | Error |
| PRG014 | Reject Documentation-only when executable, workflow/action, schema, governance configuration, operational script, project, or build files changed. | Change Type | Select another canonical type for non-documentation paths | Documentation-only with prose docs only | Documentation-only with `.ps1`, schema JSON, workflow YAML, project/build file | Yes: extension and protected-directory classification | No bot bypass | Control `pull-request-documentation-contradiction` may be excepted | `PRG014: Documentation-only conflicts with non-documentation changed-path categories.` | Error |
| PRG015 | Automation and Dependabot receive no unconditional bypass and must submit or be edited to a compliant body. | All | Same canonical template for human and bot actors | Completed Dependabot body | Default incomplete bot body | No | Maintainer may edit body; workflow has no write token | Not exceptable | `PRG015: Automation actors must provide the same complete canonical governance record as human actors.` | Error |
| PRG016 | Fail safely on null/empty/oversized body, invalid PR/repository metadata, or incomplete changed-file retrieval; external metadata failures are Blocked. | Input metadata | Nonempty body at most 65536 UTF-16 characters; positive PR number; `owner/repository`; complete JSON file list | Complete bounded fixture/event | Null/empty/oversized body, invalid identity, incomplete pagination | Yes: complete file list required | Same fail-closed behavior | Not exceptable | `PRG016: Pull-request metadata is missing, invalid, oversized, or incomplete; validation cannot pass.` | Error |

## Canonical Pull Request Record

The required headings are `Summary`, `Change Type`, `Risk Classification`, `Security Impact`, `Data Impact`, `Testing Performed`, `Tests Not Performed`, `Evidence`, `Rollback Plan`, and `Governance Exceptions`. Each uses a level-two Markdown heading and occurs exactly once. The pull-request template is the authoritative copyable form.

The body limit is 65,536 UTF-16 characters. This bound and line-based parsing limit denial-of-service risk. LF and CRLF are accepted. Identifiers are compared without Unicode compatibility normalization.

## Changed-Path Classification

Security-sensitive categories include workflow (`.github/workflows/**`), action (`actions/**`), validator or operational script (`scripts/**`), governance policy (`governance/**`), schema (`schemas/**`), security/ownership (`SECURITY.md`, `CODEOWNERS`), governance configuration (`governance.config.json`, `project-manifest.json`), and authentication, authorization, secret, dependency, scanner, infrastructure, project, or build definitions.

Non-documentation categories include the protected directories above; PowerShell, .NET, JavaScript/TypeScript, Python, shell, and SQL source; JSON schemas and governance configuration; workflow/action YAML; and project/build files. Operational Markdown policy changes are not automatically Low risk, but Markdown alone does not trigger PRG014.

## Workflow And Failure Behavior

The `Pull Request Governance` workflow runs on `opened`, `edited`, `reopened`, `synchronize`, and `ready_for_review`. It uses `pull_request`, `contents: read`, and `pull-requests: read`; it receives no secrets, never checks out PR-head content, obtains filenames through the paginated GitHub API, and uploads a sanitized JSON result even on failure. Editing the PR body retriggers validation without a code commit.

The provisional check name is `Pull Request Governance / Validate pull request governance record`. Maintainers must verify the exact rendered name from a hosted run before adding it to branch protection. Adoption is advisory until the controlled post-merge negative-to-positive test passes and the verified name is made required without removing existing checks.

## Local Validation

```powershell
pwsh -NoProfile -File scripts/Test-PullRequestGovernance.ps1 -BodyPath tests/fixtures/pr-governance/valid/compliant-high-risk.md -ChangedFilesPath tests/fixtures/pr-governance/valid/compliant-high-risk-files.json -Actor test-user -Repository AIAllTheThingz/Engineering-Standards -PullRequestNumber 999 -OutputJson .tmp/pr-governance-result.json
```

The wrapper returns zero only for a passed record. Failed records return a nonzero exit code; unreliable external metadata returns `Blocked`. Output contains rule IDs, section names, categories, and a body SHA-256, never the raw body.

## Rollback

Revert the reviewed Issue #19 implementation commit or merge. Remove only the Issue #19 entry workflow or restore its prior immutable pin through a reviewed pull request. If branch protection is later enabled, remove only the verified Issue #19 check while preserving all Issue #18 protections and existing required checks.

## Related Documents

- [Organization Contract](../governance/ORGANIZATION_CONTRACT.md)
- [Exception Process](../governance/EXCEPTION_PROCESS.md)
- [Completion Evidence](../governance/COMPLETION_EVIDENCE.md)
- [Action Security](ACTION_SECURITY.md)
- [Branch Protection](BRANCH_PROTECTION.md)
- [Troubleshooting](TROUBLESHOOTING.md)
