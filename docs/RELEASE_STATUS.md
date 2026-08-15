# Release Status

| Field | Value |
| --- | --- |
| Status | Published; PostRelease lifecycle complete |
| Latest published version | 1.2.1 |
| Published v1.2.1 target | `7d15ec8be6d8c3cdca35061728901584437e4a50` |
| Published v1.2.1 tag object | `aea6330ee3d51b3f5bb55031d878ef302ba1dbca` |
| Published v1.2.1 GitHub Release ID | `370882222` |
| Owner role | Release Maintainers |
| Last verified | 2026-08-15 |

## Current Release State

The latest published version is `1.2.1`. Annotated tag `v1.2.1` has tag-object SHA `aea6330ee3d51b3f5bb55031d878ef302ba1dbca` and resolves to immutable commit `7d15ec8be6d8c3cdca35061728901584437e4a50`. GitHub Release `370882222` is non-draft and non-prerelease and was published on 2026-08-15 from the reviewed `docs/releases/1.2.1.md` content exactly.

The published release-note SHA-256 is `a6598577ac6ad67d5f4b55c534a90f15505f80fed822878598c231433b29877d`. Published `v1.2.0` remains immutable historical evidence at commit `6c0050de328ac083e69fbac8971a317689c2c1d6`; it is not moved, recreated, deleted, or rewritten.

## v1.2.1 Lifecycle Evidence

- Exact-candidate Governance CI: run `31826861530`, Passed; artifact `9229568604` independently verified.
- Exact-candidate controlled failure: run `31843005246`, expected failure only at final mandatory enforcement; artifact `9235313486` independently verified.
- Live PreRelease lifecycle: run `31846242114`, Passed; artifact `9235993449` independently verified.
- Publication lifecycle: run `31853146258`, Passed; artifact `9238154042` independently verified.
- Final PostRelease lifecycle: run `31858980152`, Passed; artifact `9239916377` independently downloaded and SHA-256 verified as `0acc21c127588ed0dd5c7d5e55bd0f9c087a1c94015cc018b078a5eb1f154717`.
- Published-ref PostRelease canary caller: `03979bdd46e36593faf044e2206e24c7ed485d62`.
- Published-ref success: `31853248739`; expected-negative runs: `31853248720`, `31853248752`, `31853248718`, `31853248799`. All five artifacts were independently hash verified.
- Every published-ref artifact records workflow object `aea6330ee3d51b3f5bb55031d878ef302ba1dbca`, reference kind `AnnotatedTag`, and peeled standards commit `7d15ec8be6d8c3cdca35061728901584437e4a50`.
- No unexpected regression was observed and no defect follow-up issue is required.

## Consumer Authority

Published `v1.2.1` consumers requiring the canary-validated repaired workflow should pin `.github/workflows/governance-ci-reusable.yml@7d15ec8be6d8c3cdca35061728901584437e4a50` for maximum supply-chain integrity. The protected annotated `v1.2.1` reference is verified by the full published-ref five-scenario canary. Final PostRelease lifecycle validation passed in run `31858980152`; artifact `9239916377` was independently hash verified and the refreshed compatibility state from PR #109 was machine-checked.

The v1.2.1 patch does not change downstream obligations, central workflow interface `1.0.0`, or the supported project-manifest, test-evidence, and completion-result schema sets.

## Current Master Boundary

Current `master` contains development after the published target because PR #108 merged after `7d15ec8be6d8c3cdca35061728901584437e4a50`. That post-release work is `[Unreleased]`. Historical v1.2.1 evidence does not validate current `master`; it validates only the immutable published target.

The machine-readable `unreleasedContract` therefore retains governance version `1.2.1` but remains Preview with `canaryValidationStatus: NotRun` and a null canary authority. The published v1.2.1 PostRelease canary is not relabeled as validation of newer moving branch content.

## Issue #103 Disposition

The published `v1.2.1` PostRelease matrix proves the original annotated-tag reusable-workflow identity defect is repaired: GitHub's annotated tag-object SHA is verified separately from the peeled standards commit and both are preserved in hosted evidence. The v1.2.0 release-body mismatch is also corrected by the exact reviewed-body publication contract.

Issue #103 was closed as completed after PR #109 merged at `fa34bb533c8288d283996f2aa4f948c3505b61dc` and final PostRelease lifecycle run `31858980152` passed against the refreshed compatibility state.

## Related Documents

- [Published v1.2.1 Release Notes](releases/1.2.1.md)
- [Unreleased Development](releases/unreleased.md)
- [Changelog](../CHANGELOG.md)
- [Versioning](VERSIONING.md)
- [Release Process](RELEASE_PROCESS.md)
- [Downstream Compatibility](DOWNSTREAM_COMPATIBILITY.md)
- [Downstream Governance Canary](DOWNSTREAM_CANARY.md)
