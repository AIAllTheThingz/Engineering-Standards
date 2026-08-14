# Unreleased Governance Preview

| Field | Value |
| --- | --- |
| Status | Unreleased preview |
| Published baseline | `v1.2.0` |
| Published target | `6c0050de328ac083e69fbac8971a317689c2c1d6` |
| Governance version | `1.2.0` |
| Owner role | Release Maintainers |

## Purpose

This document is the migration guide for the current `unreleasedContract` in `governance/downstream-compatibility.json`. It describes development after published `v1.2.0`; it is not a release record, tag authorization, or production compatibility promise.

The unreleased contract intentionally retains governance version `1.2.0` until a later release version is selected. Post-release fixes and preview workflow authorities must remain distinguishable from the immutable `v1.2.0` release.

## Consumer Guidance

- Use the full published target SHA `6c0050de328ac083e69fbac8971a317689c2c1d6` for the complete published 1.2 governance, Python, and Bash workflow set.
- Do not invoke the reusable governance workflow through annotated `v1.2.0` while issue #103 remains open; the annotated-tag workflow-identity defect is a known published limitation.
- The post-release `de32b77e2043f5336a54b92ab9ed867abe93ba7e` authority is a governance-only repair and is not a complete 1.2 workflow distribution.
- Preview Python and Bash workflow authorities are recorded separately in `governance/downstream-compatibility.json` and must not be presented as published v1.2.0 release identities.
- Downstream consumers that require only published behavior should remain on immutable published authorities until a later patch or minor release incorporates the post-release corrections.

## Current Unreleased Changes

Current post-v1.2.0 development includes release-state synchronization and behavior-evidence verifier routing corrections. The authoritative change list remains the [Unreleased](../../CHANGELOG.md#unreleased) section of the changelog.

## Related Records

- [Release Status](../RELEASE_STATUS.md)
- [v1.2.0 Release Record](1.2.0.md)
- [Downstream Compatibility](../DOWNSTREAM_COMPATIBILITY.md)
- [Downstream Governance Canary](../DOWNSTREAM_CANARY.md)
- [Changelog](../../CHANGELOG.md)
