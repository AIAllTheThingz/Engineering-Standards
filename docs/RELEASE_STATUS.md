# Release Status

| Field | Value |
| --- | --- |
| Status | Active |
| Version | 1.1.0 |
| Owner role | Release Maintainers |
| Last verified | 2026-07-12 |

## Published Release

The latest published version is `1.1.0`. Annotated tag `v1.1.0` has tag-object SHA `d60ed3f1385678364976dfde73b4bb5e3580d702` and resolves to immutable commit `2704049d7e826975d956611b194214dd79ea3686`. The tag is unsigned.

GitHub Release ID `352430221`, [Engineering Standards v1.1.0](https://github.com/AIAllTheThingz/Engineering-Standards/releases/tag/v1.1.0), was published at `2026-07-11T05:05:47Z`; it is neither a draft nor a prerelease and has no assets. Its target commitish is the same immutable release commit.

The published GitHub Release body retains stale preparation-era statements that the tag and release are pending. The API state above is authoritative. This reconciliation records the limitation without editing the historical external release payload.

## Unreleased Development

Current `master` contains development after the published target. The authoritative inventory is [`CHANGELOG.md` `[Unreleased]`](../CHANGELOG.md#unreleased). The root `VERSION` remains `1.1.0` because it identifies the latest published release, not the moving development head.

Post-release implementation includes the enterprise PowerShell and PowerShell
review Codex skills, the controlled skill behavior evaluator, cross-repository reusable-workflow
repair, trusted pin rotation, downstream canary gate, and specific bootstrap
failure evidence. None is part of `v1.1.0`. Issue #25 completed the release
lifecycle controls; it did not approve, tag, or publish the planned `1.2.0`, so
Issue #42's `1.2.0` target remains unreleased planning metadata.

PRs #26 through #28 performed post-publication verification and release-record maintenance. Their historical evidence remains valid only for the commits it names; `evidence/latest-verified-run.json` retains the accepted PR #27 `master` record and does not validate current `master`. Issue #17 candidate and final-head runs are reported in PR #32 because pull-request merge-context evidence cannot honestly satisfy the record's `master`-branch contract.

## Immutable Consumer References

- Published `v1.1.0` control set: `2704049d7e826975d956611b194214dd79ea3686` (tag `v1.1.0`).
- Final canary-validated repaired reusable workflow: `AIAllTheThingz/Engineering-Standards/.github/workflows/governance-ci-reusable.yml@de32b77e2043f5336a54b92ab9ed867abe93ba7e`.

The second reference is an immutable post-release commit, not a published release. Production consumers must not substitute a moving branch.

## Historical Review Integrity

PR #10 completed release approval with two formal approvals. PR #11 later merged with one formal approval and one `COMMENTED` review; PR #12 preserved that defect and remediated it with two formal approvals. These states are not reclassified here.

## Verification Boundaries

Local deterministic validation compares repository-controlled records with the locally available Git tag. Live GitHub API verification remains a separate integration activity. Historical runs and artifacts prove only their recorded commits. Moving or recreating the tag, or editing the GitHub Release, requires separate authorization.

## Related Documents

- [Changelog](../CHANGELOG.md)
- [Versioning](VERSIONING.md)
- [Release Process](RELEASE_PROCESS.md)
- [v1.1.0 release record](releases/1.1.0.md)
- [Post-release verification evidence](../evidence/releases/1.1.0-post-release-verification.json)
- [Downstream Compatibility](DOWNSTREAM_COMPATIBILITY.md)
