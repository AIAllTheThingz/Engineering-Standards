# Release Status

| Field | Value |
| --- | --- |
| Status | Active |
| Published version | 1.1.0 |
| Owner role | Release Maintainers |
| Last verified | 2026-07-25 |

## Published Release

The latest published version is `1.1.0`. Annotated tag `v1.1.0` has tag-object SHA `d60ed3f1385678364976dfde73b4bb5e3580d702` and resolves to immutable commit `2704049d7e826975d956611b194214dd79ea3686`. The tag is unsigned.

GitHub Release ID `352430221`, [Engineering Standards v1.1.0](https://github.com/AIAllTheThingz/Engineering-Standards/releases/tag/v1.1.0), was published at `2026-07-11T05:05:47Z`. It is neither a draft nor a prerelease and has no assets. Its target commitish resolves to the same immutable release commit.

The historical GitHub Release body retains preparation-era wording that the tag and release were pending. The live tag and Release API state above are authoritative; this repository records the discrepancy without rewriting the historical external payload.

## Unreleased Development

Current `master` contains development after `v1.1.0`. The audited post-PR #84 merge commit is `e9fa50a0df28982b12ffc1ca55d40ac51d6e0ed3`. The authoritative feature inventory is [`CHANGELOG.md` `[Unreleased]`](../CHANGELOG.md#unreleased).

`VERSION` remains `1.1.0` because it identifies the latest published release. It does not imply that current `master` is identical to the published tag.

Unreleased development now includes:

- Governance contract and aggregate validation improvements.
- Pull-request body governance.
- Release lifecycle and downstream compatibility controls.
- First-class Python and Bash standards, trusted static analysis, functional reusable workflows, maintained examples, and evidence.
- Isolated home-lab skill demonstrations and the reconciled examples catalog.
- The suspended `enterprise-powershell` production skill and its controlled behavior-evaluation framework.
- Exact validator dependency locking, including PyYAML `6.0.3`, Ruff `0.15.22`, and ShellCheck `0.11.0`.
- Coordinated immutable self-CI pins, full trusted Git history for evidence validation, and corrected Bash evidence-freshness boundaries.

None of those changes is retroactively part of `v1.1.0`.

## Current Validation Baseline

Final PR #84 head `66c868ad157e34449435685cb961c8bade646ffe` passed Governance CI, Python example CI, Bash example CI, and Pull Request Governance. Git comparison confirmed that merge commit `e9fa50a0df28982b12ffc1ca55d40ac51d6e0ed3` is one commit ahead with no file differences.

The four final artifacts were independently downloaded, SHA-256 hashed, opened, and JSON parsed:

| Workflow | Run | Artifact | SHA-256 |
| --- | ---: | ---: | --- |
| Governance CI | `30184347651` | `8626616228` | `cddb475abd83a11afcaa0d14caff32e3917b50a4977edc6afbecf43661e98d7c` |
| Bash example CI | `30184347667` | `8626554934` | `0050a52137bd1aa2c9b9d9cd9dd7e1099d065292ecfebaf1fc2df49ffa5048f4` |
| Python example CI | `30184347650` | `8626555641` | `5ced6414e4623c2343f3be3b357811faa2b2cbb25f011cf453e45e5355b13d2a` |
| Pull Request Governance | `30184347707` | `8626552424` | `c805850081843465a8c870057e7dcb26e652b56558d8df0051d6c4dc5a823170` |

Every independently computed ZIP hash matched the GitHub digest, and every JSON file parsed successfully. [`evidence/latest-verified-run.json`](../evidence/latest-verified-run.json) contains the full verification record and historical controlled-failure boundary.

## Skill Lifecycle Boundary

`enterprise-powershell` remains `Suspended`. Its deterministic structure is governed, but the latest controlled behavior evidence is truthfully `Blocked` because no paid live model evaluation or `OPENAI_API_KEY` was used. The trusted manual evaluation workflow has merged to `master`; that fact does not manufacture a passing live evaluation or human adjudication.

The home-lab packages under `examples/` are demonstrations, not Active production skills. No production promotion is claimed.

## Immutable Consumer References

- Published `v1.1.0` control set: `2704049d7e826975d956611b194214dd79ea3686` through tag `v1.1.0`.
- Consumers requiring the final canary-validated repaired reusable workflow should pin `AIAllTheThingz/Engineering-Standards/.github/workflows/governance-ci-reusable.yml@de32b77e2043f5336a54b92ab9ed867abe93ba7e`.
- Current frozen repository self-CI implementation: `a9158d0c7dc37db966da3a518c6155645e985b0c`.

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
