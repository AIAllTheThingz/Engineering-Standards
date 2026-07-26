# Downstream Compatibility

| Field | Value |
| --- | --- |
| Status | Active |
| Version | 1.0.0 |
| Owner role | Release Maintainers |
| Last reviewed | 2026-07-26 |

## Purpose

This document defines how maintainers and downstream consumers determine whether a governance release, evidence schema, project-manifest schema, central reusable-workflow interface, or language-specific functional workflow remains supported. The machine-readable source of truth is [`governance/downstream-compatibility.json`](../governance/downstream-compatibility.json), validated against [`schemas/downstream-compatibility.schema.json`](../schemas/downstream-compatibility.schema.json).

The matrix distinguishes an immutable published release from the unreleased contract on `master`. A moving branch is never release evidence. Consumers must select an immutable release target or an explicitly recorded immutable workflow authority and must not infer compatibility from a matching semantic version alone.

## Compatibility Dimensions

The compatibility contract records these dimensions separately:

- Governance version and immutable release target.
- Central governance workflow interface.
- Project-manifest, test-evidence, and completion-result schema versions.
- Language-specific functional workflow interface, path, immutable implementation SHA, support status, and validation status.
- Migration guidance and deprecation state.

`Supported` means release maintainers accept security fixes, critical validator fixes, and migration questions for that published contract. `Preview` describes unreleased behavior and is not a published semantic compatibility promise.

## Published Matrix

Published `1.1.0` remains supported at annotated tag `v1.1.0`, resolving to commit `2704049d7e826975d956611b194214dd79ea3686`.

That release contains:

- Central governance workflow interface `1.0.0`.
- Project-manifest schemas `1.0.0` and `1.1.0`.
- Test-evidence schemas `1.0.0` and `1.1.0`.
- Completion-result schemas `1.0.0` and `1.1.0`.

Later Python, Bash, pull-request governance, release-lifecycle, controlled evaluator, and validator-dependency work is not part of `v1.1.0`.

## Unreleased Contract

Current unreleased development retains governance version `1.1.0` and central workflow interface `1.0.0`. It preserves the published schema versions and adds project-manifest schema `1.2.0` as Preview.

The independently canary-validated central downstream workflow authority remains:

`AIAllTheThingz/Engineering-Standards/.github/workflows/governance-ci-reusable.yml@de32b77e2043f5336a54b92ab9ed867abe93ba7e`

Repository self-CI currently freezes trusted and candidate governance validation at `a9158d0c7dc37db966da3a518c6155645e985b0c`. That self-CI implementation is not substituted for the external canary authority without a fresh five-scenario downstream verification.

## Functional Workflow Authorities

The machine-readable compatibility contract now identifies the separate Python and Bash functional authorities instead of merely telling consumers to go hunting for them:

| Language | Reusable workflow | Interface | Immutable authority | Support | Validation boundary |
| --- | --- | --- | --- | --- | --- |
| Python | `.github/workflows/python-ci-reusable.yml` | `1.0.0` | `e066df32a0deaee38fed4a4cd477d1f4b4b549ed` | Preview | Maintained first-party Python example and hosted Python example CI passed; no five-scenario functional external canary is claimed. |
| Bash | `.github/workflows/bash-ci-reusable.yml` | `1.0.0` | `d55bb8e6778030f5490e900ba52ba99ac6403827` | Preview | Maintained first-party Bash example and hosted Bash example CI passed; no five-scenario functional external canary is claimed. |

These functional workflow SHAs are distribution authorities recorded by `workflows/python-ci.yml` and `workflows/bash-ci.yml`. They are distinct from the central governance canary SHA and from repository self-CI.

## Consumer Procedure

1. Identify the exact published release or Preview contract.
2. Confirm every schema version used by the downstream repository.
3. Confirm the central governance workflow interface and immutable authority.
4. When Python or Bash functional validation is required, select the matching functional workflow entry by language and pin its exact `immutableSha`.
5. Confirm the entry's support and validation status without treating first-party evidence as an external canary.
6. Retain adoption evidence with the chosen compatibility entry and limitations.

Consumers must not substitute `master`, a mutable tag, an undocumented self-CI pin, or a convenient schema version. When a required combination is absent, stop adoption and open a compatibility issue.

## Release Gate

Before release approval, maintainers must update the compatibility matrix in the same unchanged candidate head as `VERSION`, changelog, release notes, schema declarations, workflow interfaces, migration guidance, and exact functional workflow authorities.

```powershell
pwsh -NoProfile -File scripts/Test-ReleaseLifecycle.ps1 -Path . -EvidencePath <release-lifecycle-record.json> -Stage PreRelease
```

The pre-release gate compares the lifecycle record with the matrix. Publication cannot make an unsupported combination valid merely by creating a tag. Reusable-workflow changes also require the applicable exact-candidate canary contract; self-CI is necessary but does not replace external consumer proof.

## Support, Evidence, And Exceptions

A deprecation must identify announcement time, replacement, intended removal version, downstream impact, and migration guidance. Removal requires a separately reviewed major release unless an urgent security condition is documented.

Evidence must identify commands, outcomes, candidate SHA, supported schemas, workflow interfaces, immutable workflow authorities, migration path, artifact hashes, approvals, and limitations. `Blocked`, `NotRun`, and `NotApplicable` must remain visible and cannot be relabeled as Passed.

An exception to a support window or compatibility gate requires a `GOV-*` record with owner, scope, rationale, expiration, compensating controls, and migration plan. Exceptions do not rewrite historical matrix entries and cannot convert unavailable external validation into Passed.

## Related

- [Release Status](RELEASE_STATUS.md)
- [Release Process](RELEASE_PROCESS.md)
- [Versioning](VERSIONING.md)
- [Downstream Governance Canary](DOWNSTREAM_CANARY.md)
- [Adoption Guide](ADOPTION_GUIDE.md)
- [Troubleshooting](TROUBLESHOOTING.md)
- [Issue #21 Contract Compatibility Proposal](migrations/ISSUE_21_CONTRACT_COMPATIBILITY_PROPOSAL.md)
