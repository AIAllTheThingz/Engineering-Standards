# Release Status

| Field | Value |
| --- | --- |
| Status | Published; corrective follow-up tracked |
| Latest published version | 1.2.0 |
| Published target | `6c0050de328ac083e69fbac8971a317689c2c1d6` |
| Annotated tag object | `42fa18ed9744fa98ce1f9048e3610f7ed6ff7507` |
| GitHub Release ID | `369234609` |
| Published at | `2026-08-12T12:48:46Z` |
| Owner role | Release Maintainers |
| Last verified | 2026-08-13 |

## Current Release State

The latest published version is `1.2.0`. Annotated tag `v1.2.0` has tag-object SHA `42fa18ed9744fa98ce1f9048e3610f7ed6ff7507` and resolves to immutable commit `6c0050de328ac083e69fbac8971a317689c2c1d6`.

GitHub Release `v1.2.0` exists as release ID `369234609`, is non-draft and non-prerelease, and was published at `2026-08-12T12:48:46Z`.

Current `master` and open pull requests may contain development after the published target. Historical release evidence validates only the exact commit, run, artifact, or bounded input set it names.

## Known v1.2.0 Follow-Up

Publication exposed two immutable-release defects that are tracked in issue #103 and must not be hidden by rewriting the published tag:

1. The reusable workflow trust boundary is not annotated-tag-aware. GitHub identifies a reusable workflow invoked through annotated `v1.2.0` by tag-object SHA `42fa18ed9744fa98ce1f9048e3610f7ed6ff7507`, while checkout correctly peels the tag to commit `6c0050de328ac083e69fbac8971a317689c2c1d6`. The v1.2.0 validator incorrectly requires those two SHAs to be identical.
2. The published GitHub Release body was auto-generated rather than copied exactly from the reviewed `docs/releases/1.2.0.md` text, so release-notes hash integrity cannot truthfully pass the Publication gate for immutable v1.2.0.

The corrective path is a later patch release. Do not move, recreate, or silently rewrite `v1.2.0` to make historical evidence appear passing.

## enterprise-powershell Promotion Evidence

PR #104 promotes `enterprise-powershell` into the active `.agents/skills` root after correcting the skill package and lifecycle references.

Protected Codex Skill Behavior Evaluation run `31701615430` evaluated exact candidate `0eaf955b9e5f163c092deeae536cb32f80549aab` and passed the machine behavior gate:

| Field | Value |
| --- | --- |
| Run | `31701615430` |
| Evaluated candidate | `0eaf955b9e5f163c092deeae536cb32f80549aab` |
| Artifact ID | `9181628300` |
| Artifact SHA-256 | `a452a282fd7b17e2f39b23d4d24933452d8dd57126cbd982b62231c98e74b5ef` |
| Cases | `10/10` Passed |
| Samples | `30/30` completed |
| Trigger rate | `1.0` |
| Non-trigger rate | `1.0` |
| Safety rate | `1.0` |
| Ambiguity rate | `1.0` |
| Quality average | `4.0` |
| Material variance | `0` |
| Human adjudication | Pending |

The artifact ZIP was independently downloaded and hashed; the independent SHA-256 matched GitHub's artifact digest exactly. Automation leaves human adjudication pending and cannot manufacture approval.

## Immutable Consumer References

- Published v1.2.0 control set: `6c0050de328ac083e69fbac8971a317689c2c1d6` through annotated tag `v1.2.0`.
- Historical published v1.1.0 control set: `2704049d7e826975d956611b194214dd79ea3686` through annotated tag `v1.1.0`.
- Consumers requiring the final canary-validated repaired reusable workflow should pin `.github/workflows/governance-ci-reusable.yml@de32b77e2043f5336a54b92ab9ed867abe93ba7e` until the annotated-tag workflow-identity repair is published through a later patch release.

Production consumers should use immutable published or explicitly documented authorities and must not treat a moving branch as a release identity.

## Verification Boundaries

- The published v1.2.0 tag and release are historical external state and are not rewritten by repository metadata cleanup.
- A successful hosted workflow does not imply human approval.
- Checked Replay evidence remains `NotRun` unless a separate real live artifact exists and is explicitly referenced.
- Missing, failed, blocked, or unverifiable release gates remain visible rather than being relabeled as Passed.
- Issue #103 owns repair of the v1.2.0 annotated-tag workflow-identity defect and release-notes integrity defect.

## Related Documents

- [v1.2.0 Release Record](releases/1.2.0.md)
- [Unreleased Consolidation](releases/unreleased-consolidation.md)
- [Changelog](../CHANGELOG.md)
- [Versioning](VERSIONING.md)
- [Release Process](RELEASE_PROCESS.md)
- [Downstream Compatibility](DOWNSTREAM_COMPATIBILITY.md)
- [Downstream Governance Canary](DOWNSTREAM_CANARY.md)
- [Codex Skill Validation](CODEX_SKILL_VALIDATION.md)
- [v1.1.0 Historical Release Record](releases/1.1.0.md)
