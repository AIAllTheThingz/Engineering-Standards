# Backlog Management

| Field | Value |
| --- | --- |
| Status | Active |
| Version | 1.0.0 |
| Owner role | Engineering Standards Maintainers |
| Last reviewed | 2026-07-15 |
| Review cadence | Monthly and before every release candidate |

## Purpose

This document defines how Engineering Standards converts planned work, known
limitations, deferred decisions, and follow-up validation into an owned
remediation backlog. GitHub issues are authoritative for work status,
acceptance criteria, dependencies, and delivery decisions. Documentation
provides stable context and links; it MUST NOT become a second task tracker.

Active work must not exist only as an unchecked Markdown list, a roadmap
paragraph, a changelog limitation, or an evidence warning. A real remaining
action requires an issue. A limitation that does not justify work requires an
explicit accepted-risk, resolved, scope-boundary, or non-action disposition
with an accountable role and rationale.

## Authoritative Backlog Model

Every actionable backlog issue MUST contain:

- An accountable role and an assigned GitHub owner.
- A risk classification using [Risk Classification](../governance/RISK_CLASSIFICATION.md).
- User value and a target release or milestone recommendation.
- Explicit dependencies and blocking relationships.
- A bounded problem, required outcome, scope, and non-goals.
- Testable acceptance criteria.
- Required Validation and Evidence.
- A rollback or suspension plan.
- Enough implementation context to generate a focused Codex prompt without
  rediscovering the issue's purpose.

Issue state is authoritative. Planning documentation intentionally omits
volatile percentages, current-state checkboxes, and copied progress notes. If
an owner, target, dependency, or acceptance criterion changes, update the issue
first. Update documentation only when the stable sequence, policy, or
disposition changes.

## Prioritization Model

Maintainers evaluate backlog order in this sequence:

1. Control failure and risk: active security, evidence, release, or governance
   failures outrank capability work.
2. Dependency leverage: work that blocks several owned issues outranks an
   isolated enhancement of similar risk.
3. User value: work that enables safe, repeatable use outranks speculative
   breadth.
4. Readiness and size: a focused ready item may be completed before a larger
   item when doing so does not delay a blocking control.

Priority bands are guidance rather than issue state:

| Band | Meaning |
| --- | --- |
| P0 | Active control failure, incident, or release blocker requiring immediate triage. |
| P1 | Enables multiple backlog items or closes a mandatory governance/release gate. |
| P2 | High-value owned capability with satisfied or clearly scheduled dependencies. |
| P3 | Later capability, experiment, or accepted deferral that does not block a current control. |

Risk cannot be lowered to improve apparent priority. An Exception to a
mandatory control follows the governed exception process; it is not a backlog
label or a substitute for remediation.

## Current Active Backlog

There are no open issues in the normalized backlog discovered by Issue #24.
Live GitHub state remains authoritative; new production work requires a new or
reopened issue with current acceptance criteria, ownership, dependencies, risk,
validation, evidence, and rollback requirements.

## Resolution Ledger

| Priority | Work | Issue | Accountable role | Resolution |
| --- | --- | --- | --- | --- |
| P1 | Release-readiness, post-release, and downstream compatibility gates | [#25](https://github.com/AIAllTheThingz/Engineering-Standards/issues/25) | Release Maintainers | Completed. |
| P1 | Controlled Codex skill behavior evaluation | [#42](https://github.com/AIAllTheThingz/Engineering-Standards/issues/42) | AI Governance Maintainers | Completed; the production promotion gate remains available. |
| P2 | `powershell-review` skill | [#43](https://github.com/AIAllTheThingz/Engineering-Standards/issues/43) | PowerShell Standards Maintainers | Not planned; superseded by the [`powershell-review` home lab](../examples/powershell-review-home-lab/README.md). |
| P2 | `build-pester-tests` skill | [#44](https://github.com/AIAllTheThingz/Engineering-Standards/issues/44) | PowerShell Test Maintainers | Not planned; superseded by the [`build-pester-tests` home lab](../examples/build-pester-tests-home-lab/README.md). |
| P2 | `safe-automation` skill | [#45](https://github.com/AIAllTheThingz/Engineering-Standards/issues/45) | Automation Safety Maintainers | Not planned; superseded by the [`safe-automation` home lab](../examples/safe-automation-home-lab/README.md). |
| P2 | `governance-validation` skill | [#46](https://github.com/AIAllTheThingz/Engineering-Standards/issues/46) | Governance Validation Maintainers | Not planned; superseded by the [`governance-validation` home lab](../examples/governance-validation-home-lab/README.md). |
| P2 | `completion-evidence` skill | [#47](https://github.com/AIAllTheThingz/Engineering-Standards/issues/47) | Governance Evidence Maintainers | Not planned; superseded by the [`completion-evidence` home lab](../examples/completion-evidence-home-lab/README.md). |
| P3 | `vendor-documentation-analysis` skill | [#48](https://github.com/AIAllTheThingz/Engineering-Standards/issues/48) | Integration And Documentation Maintainers | Not planned; superseded by the [`vendor-documentation-analysis` home lab](../examples/vendor-documentation-analysis-home-lab/README.md). |
| P3 | `infrastructure-automation-design` skill | [#49](https://github.com/AIAllTheThingz/Engineering-Standards/issues/49) | Infrastructure Standards Maintainers | Not planned; superseded by the [`infrastructure-automation-design` home lab](../examples/infrastructure-automation-design-home-lab/README.md). |

The demo packages are isolated, secret-free portfolio implementations. They do
not satisfy production discovery, live model evaluation, attributable approval,
or Candidate-to-Active promotion acceptance criteria. A future production
promotion is separate work and must not be inferred from these resolutions.

## Deduplication Ledger

Issue #24 did not create new work for controls already owned by the remediation
roadmap:

| Area | Authoritative issue | Disposition |
| --- | --- | --- |
| Cross-repository reusable workflow | [#15](https://github.com/AIAllTheThingz/Engineering-Standards/issues/15) | Existing roadmap issue; completed. |
| External downstream canary | [#16](https://github.com/AIAllTheThingz/Engineering-Standards/issues/16) | Existing roadmap issue; completed. |
| Release/version reconciliation | [#17](https://github.com/AIAllTheThingz/Engineering-Standards/issues/17) | Existing roadmap issue; completed. |
| CODEOWNERS and branch/tag protection | [#18](https://github.com/AIAllTheThingz/Engineering-Standards/issues/18) | Existing roadmap issue; completed. |
| Pull-request body governance | [#19](https://github.com/AIAllTheThingz/Engineering-Standards/issues/19) | Existing roadmap issue; completed. |
| Deterministic Codex skill validation | [#20](https://github.com/AIAllTheThingz/Engineering-Standards/issues/20) | Existing roadmap issue; completed. The controlled behavior gate was delivered by #42. |
| Manifest/configuration semantics | [#21](https://github.com/AIAllTheThingz/Engineering-Standards/issues/21) | Existing roadmap issue; completed. |
| Authoritative aggregate validator | [#22](https://github.com/AIAllTheThingz/Engineering-Standards/issues/22) | Existing roadmap issue; completed. Demo-only orchestration is documented by the #46 resolution. |
| Reproducible validation environment | [#23](https://github.com/AIAllTheThingz/Engineering-Standards/issues/23) | Existing roadmap issue; completed. Deferred container/signing decisions remain documented below. |
| Release lifecycle gate | [#25](https://github.com/AIAllTheThingz/Engineering-Standards/issues/25) | Existing roadmap issue; completed. |

## Known Limitation Dispositions

The inventory covered README, changelog, release records, consolidation audit,
skill-validation documentation, dependency documentation, canary guidance, and
checked-in evidence. Historical evidence remains truthful for its recorded
commit and is not rewritten merely because later work resolved a limitation.

| Limitation or deferred item | Accountable role | Disposition |
| --- | --- | --- |
| Actual skill selection, over-trigger avoidance, and response quality are not deterministically proven. | AI Governance Maintainers | Permanent deterministic boundary. [#42](https://github.com/AIAllTheThingz/Engineering-Standards/issues/42) delivered the controlled live-evaluation gate; no production promotion is currently planned. |
| The `v1.1.0` tag is unsigned. | Release Maintainers | Accepted historical risk. Do not rewrite the published tag; future release work must use the lifecycle gate delivered by #25 to verify protection and provenance. |
| The published `v1.1.0` release body contains stale preparation language. | Release Maintainers | Documented non-action from #17. API state and `docs/RELEASE_STATUS.md` remain authoritative; the historical payload is not silently rewritten. |
| Historical `1.1.0` notes report missing local YAML parsing and PSScriptAnalyzer. | Validator Dependency Maintainers | Resolved for current development by #23's pinned dependency model; preserved as historical release context. |
| Historical `1.1.0` notes report incomplete non-PowerShell examples. | Example Maintainers | Resolved by the current functional example set; preserved as historical release context. |
| Local validation cannot prove live GitHub settings, hosted execution, or artifact publication. | Repository and Release Maintainers | Permanent trust boundary, not missing implementation. #18 delivered settings verification and #25 delivered release proof controls. |
| GitHub's `ubuntu-24.04` label is versioned but not an immutable image digest. | Validator Dependency Maintainers | Accepted residual risk under #23 with runtime/hash verification. Digest-pinned container work remains deferred until its build, signing, scanning, retention, and compatibility cost is justified. |
| A signed validator module or release bundle is not published. | Validator Dependency Maintainers | Deferred non-action because publication/signing authority and a complete distribution design do not exist. Reopen as a focused issue only when those prerequisites exist. |
| The downstream canary does not exercise consumer builds, private repositories, GitHub Enterprise Server, or every caller category. | Downstream Repository Owners | Intentional scope boundary. Caller-owned CI and adoption Evidence remain authoritative; create a central issue only after a supported central use case is approved. |
| Dependabot PR #1 and PR #2 were deferred outside `v1.1.0`. | Validator Dependency Maintainers | Both pull requests are closed and not merged. Current dependency updates follow #23's reviewed hash/pin process; no active remediation remains. |

An accepted risk or non-action decision MUST be revisited if its assumptions
change, a mandatory control becomes unmet, downstream failures appear, or a
release review identifies new material impact.

## Documentation Reference Rules

Active planning documentation links to an issue by number and stable purpose.
It does not copy completion percentage, current assignee activity, or acceptance
checkboxes. GitHub owns those volatile fields. A resolution ledger may record a
durable final disposition when closure has an attributable comment and the
documentation no longer presents the work as active.

When documentation introduces planned active work, the author MUST create or
identify the issue in the same change and include the issue link. Rejected or
deferred proposals must retain a rationale, owner role, and review trigger. Empty
skill directories, placeholder implementations, and vague one-line issues are
not valid backlog evidence.

Closing an issue requires an attributable resolution comment and linked pull
request or non-action rationale. If closure changes a stable plan, dependency,
or known-limitation disposition, update this document in the same maintenance
cycle.

## Periodic Backlog Review Checklist

Engineering Standards Maintainers perform this review monthly and during every
release-readiness review:

- Inventory planned work and limitation language in README, changelog, release
  records, audits, skill documentation, dependency guidance, and current
  Evidence.
- Verify every active item has one authoritative issue, an assignee, accountable
  role, risk, user value, dependencies, target guidance, acceptance criteria,
  Validation, Evidence, and rollback.
- Reconcile dependencies for cycles, closed blockers, and work that now belongs
  to an existing issue.
- Review accepted-risk and non-action assumptions; create an issue or Exception
  when the original rationale no longer holds.
- Close duplicates with a durable reference to the surviving issue.
- Split vague or oversized tasks only when each resulting issue has independent
  value and acceptance criteria.
- Remove stale prose checklists and replace active status text with authoritative
  issue links.
- Run documentation completeness, Markdown link, Codex skill, and authoritative
  governance validation.
- Verify new issue creation and live assignment through GitHub rather than
  relying only on documentation.

## Validation And Evidence

Repository validation enforces that each demo-resolved skill in
`docs/CODEX_SKILLS.md` appears in an issue-linked resolution table row and
rejects the old prose-only numbered or unchecked-list form. Local validation
proves repository references and structure; it cannot prove live issue state.
The maintainer review therefore records the GitHub issue URLs and verifies them
through the GitHub API.

Historical Issue #24 evidence includes the created issue numbers, documentation
and link validation results, Codex skill validation, Pester results,
authoritative governance validation, GitHub Actions state, and checks that
remained `NotRun` or `Blocked`.

## Related

- [Codex Skills](CODEX_SKILLS.md)
- [Codex Skill Validation](CODEX_SKILL_VALIDATION.md)
- [Maintainer Guide](MAINTAINER_GUIDE.md)
- [Release Process](RELEASE_PROCESS.md)
- [Release Status](RELEASE_STATUS.md)
- [Completion Evidence](../governance/COMPLETION_EVIDENCE.md)
- [Exception Process](../governance/EXCEPTION_PROCESS.md)
- [Issue #24](https://github.com/AIAllTheThingz/Engineering-Standards/issues/24)
