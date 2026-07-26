# Downstream Compatibility

| Field | Value |
| --- | --- |
| Status | Active |
| Version | 1.0.0 |
| Owner role | Release Maintainers |
| Last reviewed | 2026-07-25 |

## Purpose

This document defines how maintainers and downstream consumers determine whether a governance release, evidence schema, project-manifest schema, or reusable-workflow interface remains supported. The machine-readable source of truth is [`governance/downstream-compatibility.json`](../governance/downstream-compatibility.json), validated against [`schemas/downstream-compatibility.schema.json`](../schemas/downstream-compatibility.schema.json).

The matrix distinguishes an immutable published release from the unreleased contract on `master`. A moving branch is never release evidence. Consumers must select an immutable release target or a separately canary-validated full workflow SHA and must not infer compatibility from a matching semantic version alone.

## Compatibility Dimensions

Governance version, source commit, workflow interface, project-manifest schema, test-evidence schema, completion-result schema, and language-specific functional workflow are independent dimensions.

`Supported` means release maintainers accept security fixes, critical validator fixes, and migration questions for that contract. `SecurityFixesOnly` narrows support without recommending new adoption. `Unsupported` requires migration or a time-bounded approved exception. `Preview` describes unreleased behavior and is not a published compatibility promise.

## Published Matrix

Published `1.1.0` remains supported at annotated tag `v1.1.0`, resolving to commit `2704049d7e826975d956611b194214dd79ea3686`.

That release contains:

- Workflow interface `1.0.0`.
- Project-manifest schemas `1.0.0` and `1.1.0`.
- Test-evidence schemas `1.0.0` and `1.1.0`.
- Completion-result schemas `1.0.0` and `1.1.0`.

Later Python, Bash, pull-request governance, release-lifecycle, controlled evaluator, and validator-dependency work is not part of `v1.1.0`.

## Unreleased Contract

Current unreleased development retains governance version `1.1.0` and workflow interface `1.0.0`. It preserves the published schema versions and adds project-manifest schema `1.2.0` as Preview.

The preview contract separates:

- Semantic governance version.
- Immutable governance implementation SHA.
- Workflow interface version.
- Structured ownership.
- Standards-consumption mode.
- Local and hosted evidence locations.
- Governed exception records.

Python and Bash now have first-class central standards plus separate functional reusable workflows. Those functional workflows add language-specific implementation and evidence behavior without changing the central governance workflow interface version.

Consumers adopting Preview functionality must follow the Issue #21 migration guide and pin the exact reviewed implementation SHA. A semantic version match alone is insufficient.

## Immutable Workflow Authorities

The repaired reusable workflow at `de32b77e2043f5336a54b92ab9ed867abe93ba7e` remains the independently canary-validated downstream authority recorded in the compatibility matrix.

Repository self-CI currently freezes trusted and candidate governance validation at `a9158d0c7dc37db966da3a518c6155645e985b0c`. That commit includes later dependency, trusted-history, and Bash evidence-boundary repairs. It is not substituted for the canary-validated downstream authority because no new five-scenario external canary verification has been recorded for it.

The final PR #84 head `66c868ad157e34449435685cb961c8bade646ffe` passed Governance CI, Python CI, Bash CI, and Pull Request Governance. Merge commit `e9fa50a0df28982b12ffc1ca55d40ac51d6e0ed3` has no file differences from that validated head. This proves the repository tree, not a new downstream compatibility promise.

## Release Gate

Before release approval, maintainers must update the compatibility matrix in the same unchanged candidate head as `VERSION`, changelog, release notes, schema declarations, workflow interface, and migration guidance.

Run:

```powershell
pwsh -NoProfile -File scripts/Test-ReleaseLifecycle.ps1 -Path . -EvidencePath <release-lifecycle-record.json> -Stage PreRelease
```

The pre-release gate compares the lifecycle record with the matrix. Publication cannot make an unsupported combination valid merely by creating a tag.

For reusable-workflow changes, the exact candidate must also pass all five scenarios in [Downstream Governance Canary](DOWNSTREAM_CANARY.md). Self-CI is necessary but does not replace the external consumer proof.

## Support And Deprecation

The repository intends to support the current major and one previous major when such a previous major exists. Because no `0.x` support track is declared, `previousMajor` is `null`; that is an explicit state.

A deprecation must identify announcement time, replacement, intended removal version, downstream impact, and migration guidance. Removal requires a separately reviewed major release unless an urgent security condition is documented.

Post-release verification must confirm the matrix was updated, and release notes must state whether consumers should migrate immediately, at their normal cadence, or not at all.

## Consumer Procedure

1. Identify the exact published release or Preview contract.
2. Confirm every schema version used by the downstream repository.
3. Confirm the central governance workflow interface version.
4. Confirm any Python or Bash functional workflow requirements separately.
5. Select the immutable release target or recorded canary-validated SHA.
6. Retain adoption evidence with the chosen compatibility entry and canary result.

Consumers must not substitute `master`, a mutable tag, an undocumented self-CI pin, or a convenient schema version. When a required combination is absent, stop adoption and open a compatibility issue.

## Validation And Evidence

Compatibility validation includes JSON schema checks, lifecycle semantic checks, exact-SHA consistency, workflow-interface comparison, all five canary scenarios when applicable, and release consistency.

Evidence must identify commands, outcomes, candidate SHA, supported schemas, workflow interface, migration path, artifact hashes, approvals, and limitations. `Blocked`, `NotRun`, and `NotApplicable` must remain visible and cannot be relabeled as Passed.

## Exceptions

An exception to a support window or compatibility gate requires a `GOV-*` record with owner, scope, rationale, expiration, compensating controls, and migration plan. Exceptions do not rewrite historical matrix entries and cannot convert unavailable external validation into Passed.

## Related

- [Release Status](RELEASE_STATUS.md)
- [Release Process](RELEASE_PROCESS.md)
- [Versioning](VERSIONING.md)
- [Downstream Governance Canary](DOWNSTREAM_CANARY.md)
- [Adoption Guide](ADOPTION_GUIDE.md)
- [Troubleshooting](TROUBLESHOOTING.md)
- [Issue #21 Contract Compatibility Proposal](migrations/ISSUE_21_CONTRACT_COMPATIBILITY_PROPOSAL.md)
