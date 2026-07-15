# Downstream Compatibility

| Status | Active |
| Version | 1.0.0 |
| Owner role | Release Maintainers |
| Last reviewed | 2026-07-15 |

## Purpose

This document defines how maintainers and downstream consumers determine whether a governance release, evidence schema, project-manifest schema, or reusable-workflow interface remains supported. The machine-readable source of truth is [`governance/downstream-compatibility.json`](../governance/downstream-compatibility.json), validated against [`schemas/downstream-compatibility.schema.json`](../schemas/downstream-compatibility.schema.json).

The matrix distinguishes an immutable published release from the unreleased contract on `master`. A moving branch is never release Evidence. Consumers MUST select an immutable release target or a separately canary-validated full workflow SHA and must not infer compatibility from a matching semantic version alone.

## Compatibility Dimensions

Governance version, source commit, workflow interface, project-manifest schema, test-evidence schema, and completion-result schema are independent dimensions. The matrix records them separately because a schema can remain supported while the current implementation adds a newer optional contract, and a repaired workflow SHA can be newer than the latest published release.

`Supported` means release maintainers accept security fixes, critical validator fixes, and migration questions for that contract. `SecurityFixesOnly` narrows support without declaring the contract safe for new adoption. `Unsupported` means consumers MUST migrate or hold an approved, time-bounded Exception. `Preview` describes unreleased behavior and is not a published compatibility promise.

## Current Matrix

The published `1.1.0` release remains supported at annotated tag `v1.1.0`, resolving to commit `2704049d7e826975d956611b194214dd79ea3686`. That release supports project-manifest, test-evidence, and completion-result schema versions `1.0.0` and `1.1.0`, with workflow interface `1.0.0`.

Current unreleased development retains those contracts and adds preview project-manifest schema `1.2.0`. The preview contract separates semantic governance version, immutable governance commit, workflow interface, structured ownership, standards consumption, evidence locations, and exceptions. Consumers adopting that preview MUST follow the Issue #21 migration guide and pin the exact reviewed implementation SHA.

The repaired reusable workflow at `de32b77e2043f5336a54b92ab9ed867abe93ba7e` is independently canary validated but is not part of `v1.1.0`. This distinction prevents a later implementation repair from being misrepresented as content of an earlier tag.

## Release Gate

Before release approval, maintainers MUST update the matrix in the same unchanged candidate head as `VERSION`, changelog, release notes, schema declarations, workflow interface, and migration guidance. Run:

```powershell
pwsh -NoProfile -File scripts/Test-ReleaseLifecycle.ps1 -Path . -EvidencePath <release-lifecycle-record.json> -Stage PreRelease
```

The pre-release gate compares the lifecycle record with this matrix. A candidate cannot pass if its declared project-manifest versions or workflow interface are missing. A publication cannot make an unsupported combination valid merely by creating a tag.

## Support And Deprecation

The repository intends to support the current major and one previous major when such a previous major exists. Because no `0.x` support track is currently declared, `previousMajor` is `null`; that value is an explicit state, not missing data.

A deprecation MUST identify announcement time, replacement, intended removal version, downstream impact, and migration guidance. Removal requires a separately reviewed major release unless an urgent security condition is documented. Post-release verification must confirm the matrix was updated, and release notes must state whether consumers should migrate immediately, at their normal cadence, or not at all.

## Consumer Procedure

Downstream owners should locate the exact governance release or preview contract, confirm each schema version used by their repository, confirm the reusable-workflow interface, and then pin the referenced immutable SHA. They should retain their adoption Evidence with the chosen matrix entry and canary result. A consumer must not substitute `master`, a mutable version tag, or an undocumented workflow pin.

When a required combination is absent, stop adoption and open a compatibility issue. Do not edit the downstream manifest to a convenient version, weaken required checks, or relabel a `Blocked` or `NotRun` result as Passed.

## Validation And Evidence

Validation includes JSON parsing, schema metadata checks, lifecycle semantic checks, exact-SHA consistency, all five canary scenarios, and release consistency. Evidence must identify commands, exit codes, candidate SHA, workflow interface, supported schemas, migration path, artifact hashes, human approvals, and any remaining limitations.

The post-release verifier MUST re-fetch the tag and GitHub Release, re-run or confirm the canary against the published immutable reference, record downstream regressions, create issues for defects, and set `compatibilityMatrixUpdated` only after this file and its JSON source agree.

## Exceptions

An Exception to a support window or compatibility gate requires a `GOV-*` record with owner, scope, rationale, expiration, compensating controls, and migration plan. Exceptions do not rewrite historical matrix entries and cannot turn unavailable external validation into Passed. Expired exceptions block release readiness.

## Related

- [Release Process](RELEASE_PROCESS.md)
- [Versioning](VERSIONING.md)
- [Downstream Governance Canary](DOWNSTREAM_CANARY.md)
- [Adoption Guide](ADOPTION_GUIDE.md)
- [Troubleshooting](TROUBLESHOOTING.md)
- [Issue #21 Contract Compatibility Proposal](migrations/ISSUE_21_CONTRACT_COMPATIBILITY_PROPOSAL.md)
