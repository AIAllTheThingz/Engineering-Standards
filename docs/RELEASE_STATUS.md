# Release Status

| Field | Value |
| --- | --- |
| Status | Active |
| Published version | 1.1.0 |
| Owner role | Release Maintainers |
| Last verified | 2026-07-27 |

## Published Release

The latest published version is `1.1.0`. Annotated tag `v1.1.0` has tag-object SHA `d60ed3f1385678364976dfde73b4bb5e3580d702` and resolves to immutable commit `2704049d7e826975d956611b194214dd79ea3686`. The tag is unsigned.

GitHub Release ID `352430221`, [Engineering Standards v1.1.0](https://github.com/AIAllTheThingz/Engineering-Standards/releases/tag/v1.1.0), was published at `2026-07-11T05:05:47Z`. It is neither a draft nor a prerelease and has no assets. Its target commitish resolves to the same immutable release commit.

The historical GitHub Release body retains stale preparation-era statements that the tag and release were pending. The live tag and Release API state above are authoritative; this repository records the discrepancy without rewriting the historical external payload.

## Unreleased Development

Current `master` contains development after the published target `v1.1.0`. The audited post-PR #90 merge commit is `16277a220035446924ef19f18d713486c6d364c1`. The authoritative feature inventory is [`CHANGELOG.md` `[Unreleased]`](../CHANGELOG.md#unreleased).

`VERSION` remains `1.1.0` because it identifies the latest published release. It does not imply that current `master` is identical to the published tag.

Unreleased development now includes:

- Governance contract and aggregate validation improvements.
- Pull-request body governance.
- Release lifecycle and version-aware downstream compatibility controls.
- First-class Python and Bash standards, trusted static analysis, functional reusable workflows, maintained examples, and evidence.
- Isolated home-lab skill demonstrations and the reconciled examples catalog.
- The suspended `enterprise-powershell` production skill and its controlled behavior-evaluation framework.
- Exact validator dependency locking, including PyYAML `6.0.3`, Ruff `0.15.22`, and ShellCheck `0.11.0`.
- Coordinated immutable self-CI pins, full trusted Git history for evidence validation, and corrected Bash evidence-freshness boundaries.
- Preserved historical `1.0.0` compatibility records and current `1.1.0` split release-state contracts.

None of those changes is retroactively part of `v1.1.0`.

## Current Validation Baseline

Final PR #90 head `d75a37a60f2c82a8ea7cefafd714ce0309ea237e` passed Governance CI, candidate implementation validation, Python example CI, Bash example CI, and Pull Request Governance. Git comparison confirmed that merge commit `16277a220035446924ef19f18d713486c6d364c1` is one commit ahead with no file differences. The validated head and merged `master` therefore have identical repository content.

This historical PR #90 evidence validates only the recorded equivalent tree and does not validate current `master` after later file changes.

The four final artifacts were independently downloaded, SHA-256 hashed, opened, and JSON parsed:

| Workflow | Run | Artifact | SHA-256 |
| --- | ---: | ---: | --- |
| Governance CI | `30232343849` | `8640640280` | `f41437b4c8457225fc111f8c9d78b2d8a53463241630afc4c6145d9eb84c0914` |
| Bash example CI | `30232343840` | `8640496837` | `bc05a83235a76d619b8590d177ed2f1a7995be8012197d40764c4b549051a70e` |
| Python example CI | `30232343796` | `8640499356` | `6cd9a75cd33057b78d646153a4b328fef68b50357d0ed33e5bcfc5c31dca0c81` |
| Pull Request Governance | `30233092086` | `8640716524` | `185af693d1e5a38d29324e8f65aff02c6224923edf425a9fdec08ca98954a3a0` |

Every independently computed ZIP hash matched the GitHub digest, and all 38 JSON files parsed successfully. The Governance artifact truthfully retains one `Blocked` result for the suspended `enterprise-powershell` behavior gate and nine `NotRun` declarations for model behavior that was not executed. No final artifact contained a `Failed` result. This table is the retained PR #90 verification record. [`evidence/latest-verified-run.json`](../evidence/latest-verified-run.json) records the newest independently verified run and the historical controlled-failure boundary; it is not the PR #90 record.

## Skill Lifecycle Boundary

`enterprise-powershell` remains `Suspended`. Its deterministic structure is governed, but the latest controlled behavior evidence is truthfully `Blocked` because no paid live model evaluation or `OPENAI_API_KEY` was used. The trusted manual evaluation workflow has merged to `master`; that fact does not manufacture a passing live evaluation or human adjudication.

The home-lab packages under `examples/` are demonstrations, not Active production skills. No production promotion is claimed.

## Immutable Consumer References

- Published `v1.1.0` control set: `2704049d7e826975d956611b194214dd79ea3686` through tag `v1.1.0`.
- Consumers requiring the final canary-validated repaired reusable workflow should pin `AIAllTheThingz/Engineering-Standards/.github/workflows/governance-ci-reusable.yml@de32b77e2043f5336a54b92ab9ed867abe93ba7e`.
- Current frozen repository self-CI implementation: `335452c509991729cf60d94eb756f8f59d190011`.

The second and third references are post-release implementation commits, not published semantic releases. The self-CI implementation SHA must not replace the canary-validated downstream reference without a new external canary verification.

Production consumers must never substitute `master` or another moving branch for an immutable reviewed reference.

## Next Release Readiness

Repository consolidation is complete. The next release is `NotRun`, not `Passed`, because maintainers have not yet selected:

- A new semantic version.
- An unchanged candidate SHA.
- A complete pre-release lifecycle record.
- Fresh exact-candidate success and controlled-failure evidence.
- Fresh Python, Bash, and PR-governance artifacts.
- All five downstream canary results against the candidate.
- Attributable release approvals.
- Explicit tag and publication authorization.

No new tag or GitHub Release should be created until those steps pass for one unchanged candidate.

## Verification Boundaries

Historical runs and artifacts prove only the commits they name. Local deterministic validation cannot claim a GitHub-hosted run. A successful workflow may contain governed `Blocked`, `NotRun`, or `NotApplicable` lifecycle records when those outcomes are explicitly non-mandatory and accurately disclosed; it must not contain an unreported mandatory failure.

Moving or recreating a tag, editing the GitHub Release, publishing a new release, or rotating the downstream canary authority requires separate authorization.

## Related Documents

- [Governance Consolidation Audit](GOVERNANCE_CONSOLIDATION_AUDIT.md)
- [Changelog](../CHANGELOG.md)
- [Versioning](VERSIONING.md)
- [Release Process](RELEASE_PROCESS.md)
- [v1.1.0 release record](releases/1.1.0.md)
- [Post-release verification evidence](../evidence/releases/1.1.0-post-release-verification.json)
- [Downstream Compatibility](DOWNSTREAM_COMPATIBILITY.md)
- [Downstream Governance Canary](DOWNSTREAM_CANARY.md)
