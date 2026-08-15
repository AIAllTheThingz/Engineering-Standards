# Unreleased Development After v1.2.1

| Field | Value |
| --- | --- |
| Status | Preview; unpublished current-master development |
| Governance version | `1.2.1` |
| Published baseline | `v1.2.1` |
| Published target | `7d15ec8be6d8c3cdca35061728901584437e4a50` |
| Current-master canary status | `NotRun` |
| Owner role | Release Maintainers |

## Purpose

This document is the migration guide for the current `unreleasedContract` in `governance/downstream-compatibility.json`. Published `v1.2.1` is immutable release evidence; this file describes development merged after that release target and does not claim a new release or reuse historical canary proof for moving `master`.

## Current Unreleased Scope

- PR #108 updated the governed Python example build backend from Hatchling `1.31.0` to `1.32.0`.
- The synchronized toolchain adds exact `tomlkit==0.15.1` runtime locking and updates the owned validator/regression expectation.
- This work merged after the frozen v1.2.1 target and therefore remains `[Unreleased]`.

No later semantic governance version has been selected. The root `VERSION` remains `1.2.1` until maintainers deliberately start another release-preparation cycle.

## Consumer Guidance

- Production GitHub Actions workflow consumers MUST pin exact commit `7d15ec8be6d8c3cdca35061728901584437e4a50` for the published v1.2.1 governance workflow. The semantic `v1.2.1` ref remains release/canary identity and MUST NOT be the sole production workflow identity.
- Do not pin `master`, the semantic `v1.2.1` ref, or this unreleased state as a production GitHub Actions workflow authority; production workflow identity requires the full commit SHA.
- The published v1.2.1 five-scenario canary proves the immutable release path; it does not validate the later PR #108 master state, and final PostRelease lifecycle validation remains pending until the release-state synchronization is merged.
- The current `unreleasedContract` therefore truthfully remains `canaryValidationStatus: NotRun` with `canaryValidatedWorkflowSha: null`.

## Published Baseline

Annotated tag `v1.2.1` has tag-object SHA `aea6330ee3d51b3f5bb55031d878ef302ba1dbca` and peels to `7d15ec8be6d8c3cdca35061728901584437e4a50`. GitHub Release ID `370882222` is non-draft/non-prerelease and its body matches the reviewed `docs/releases/1.2.1.md` SHA-256 `a6598577ac6ad67d5f4b55c534a90f15505f80fed822878598c231433b29877d`.

The complete published-ref canary successfully exercised `@v1.2.1`, including one success scenario and four isolated fail-closed scenarios.

## Related Records

- [Published v1.2.1 Release Notes](1.2.1.md)
- [Release Status](../RELEASE_STATUS.md)
- [Downstream Compatibility](../DOWNSTREAM_COMPATIBILITY.md)
- [Downstream Governance Canary](../DOWNSTREAM_CANARY.md)
- [Changelog](../../CHANGELOG.md)
