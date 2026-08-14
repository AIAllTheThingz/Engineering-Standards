# Prepared v1.2.1 Governance Preview

| Field | Value |
| --- | --- |
| Status | Prepared; unpublished |
| Prepared version | `1.2.1` |
| Published baseline | `v1.2.0` |
| Published target | `6c0050de328ac083e69fbac8971a317689c2c1d6` |
| Governance version | `1.2.1` |
| Owner role | Release Maintainers |

## Purpose

This document is the migration guide for the current `unreleasedContract` in `governance/downstream-compatibility.json`. It describes the prepared `1.2.1` patch state after published `v1.2.0`; it is not a published release record, tag authorization, or production compatibility promise.

The prepared version is `1.2.1` and is unpublished. Published `v1.2.0` remains immutable historical state.

## Prepared Patch Scope

- Repair annotated-tag reusable-workflow identity handling without weakening immutable commit binding.
- Record the GitHub workflow object SHA separately from the peeled standards commit SHA.
- Preserve fail-closed behavior for branches, lightweight tags, malformed refs, wrong repositories, wrong workflow paths, mismatched tag objects, and mismatched peeled commits.
- Publish the eventual `v1.2.1` GitHub Release from the reviewed `docs/releases/1.2.1.md` body exactly rather than using auto-generated notes.
- Carry forward the post-`v1.2.0` release-state, compatibility-guidance, and behavior-verifier corrections already merged to `master`.

## Consumer Guidance

- Production consumers needing the complete published 1.2 governance, Python, and Bash workflow set should continue to use full published target SHA `6c0050de328ac083e69fbac8971a317689c2c1d6` while the patch remains unpublished.
- Do not invoke the reusable governance workflow through annotated `v1.2.0`; issue #103 remains open until the new patch release completes published-ref verification and PostRelease.
- Historical governance-1.1 canary authority `de32b77e2043f5336a54b92ab9ed867abe93ba7e` remains historical evidence and is not the prepared `1.2.1` consumer authority.
- Preview Python and Bash workflow authorities remain recorded separately in `governance/downstream-compatibility.json` and are not relabeled by the governance patch.
- Do not pin the moving preparation branch or infer publication from the selected semantic version.

## Validation State

The exact final `1.2.1` candidate has not yet completed its required hosted proof and external canary matrix at this preparation step. Required final-candidate Governance CI, controlled failure, five downstream scenarios, independent artifact verification, and attributable human approval remain `NotRun` until observed. Publication and PostRelease require separately authorized external actions after merge.

## Release Integrity

`docs/releases/1.2.1.md` is the intended GitHub Release body. It must remain byte-for-byte stable after final release approval, and publication must use that reviewed content rather than generated notes so the lifecycle notes hash can be verified.

## Related Records

- [Prepared v1.2.1 Release Notes](1.2.1.md)
- [Release Status](../RELEASE_STATUS.md)
- [v1.2.0 Historical Release Record](1.2.0.md)
- [Downstream Compatibility](../DOWNSTREAM_COMPATIBILITY.md)
- [Downstream Governance Canary](../DOWNSTREAM_CANARY.md)
- [Changelog](../../CHANGELOG.md)
