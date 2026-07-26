# Downstream Compatibility

| Field | Value |
| --- | --- |
| Status | Active |
| Version | 1.1.0 |
| Owner role | Release Maintainers |
| Last reviewed | 2026-07-26 |

## Purpose

This document defines how maintainers and downstream consumers determine whether a governance release, evidence schema, project-manifest schema, central reusable-workflow interface, or language-specific functional workflow remains supported. The machine-readable source of truth is [`governance/downstream-compatibility.json`](../governance/downstream-compatibility.json), validated against [`schemas/downstream-compatibility.schema.json`](../schemas/downstream-compatibility.schema.json).

The matrix distinguishes an immutable published release from the unreleased contract on `master`. A moving branch is never release evidence. Consumers MUST select an immutable release target or an explicitly recorded immutable workflow authority and MUST NOT infer compatibility from a matching semantic version alone.

## Contract Schema Versions

The compatibility document has two supported versions:

- `1.0.0` preserves the historical shape and does not contain `functionalWorkflows`.
- `1.1.0` requires `functionalWorkflows` in the unreleased contract.

The current schema accepts historical `1.0.0` records without forcing the new field. It rejects `functionalWorkflows` when the record still declares `1.0.0`, and it rejects a `1.1.0` record that omits them.

The standards-consistency document follows the same version boundary:

- `1.0.0` uses the original six-field `releaseReadiness` object.
- `1.1.0` requires `publishedRelease` and `nextReleaseReadiness`, plus a status-only legacy alias.

These document versions are independent from the repository governance release version.

## Compatibility Dimensions

The compatibility contract records these dimensions separately:

- Governance version and immutable release target.
- Central governance workflow interface.
- Project-manifest, test-evidence, and completion-result schema versions.
- Language-specific functional workflow interface, path, immutable implementation SHA, support status, and validation status.
- Migration guidance and deprecation state.

`Supported` means release maintainers accept critical fixes and migration questions for that published contract. `Preview` describes unreleased behavior and is not a published semantic compatibility promise.

## Published Matrix

Published `1.1.0` remains supported at annotated tag `v1.1.0`, resolving to commit `2704049d7e826975d956611b194214dd79ea3686`.

That release contains:

- Central governance workflow interface `1.0.0`.
- Project-manifest schemas `1.0.0` and `1.1.0`.
- Test-evidence schemas `1.0.0` and `1.1.0`.
- Completion-result schemas `1.0.0` and `1.1.0`.

Later Python, Bash, pull-request governance, release-lifecycle, controlled evaluator, and validator-dependency work is not part of `v1.1.0`.

## Unreleased Contract

Current unreleased development retains governance version `1.1.0` and central workflow interface `1.0.0`. The owned compatibility record uses document schema `1.1.0`.

The independently canary-validated central downstream workflow authority remains:

`AIAllTheThingz/Engineering-Standards/.github/workflows/governance-ci-reusable.yml@de32b77e2043f5336a54b92ab9ed867abe93ba7e`

Repository self-CI remains separate from that downstream authority until a fresh external validation is recorded.

## Functional Workflow Authorities

| Language | Reusable workflow | Interface | Immutable authority | Support | Validation boundary |
| --- | --- | --- | --- | --- | --- |
| Python | `.github/workflows/python-ci-reusable.yml` | `1.0.0` | `e066df32a0deaee38fed4a4cd477d1f4b4b549ed` | Preview | Maintained Python example and hosted Python CI passed; no external functional canary is claimed. |
| Bash | `.github/workflows/bash-ci-reusable.yml` | `1.0.0` | `d55bb8e6778030f5490e900ba52ba99ac6403827` | Preview | Maintained Bash example and hosted Bash CI passed; no external functional canary is claimed. |

These SHAs are distribution authorities recorded by `workflows/python-ci.yml` and `workflows/bash-ci.yml`. They are distinct from the central governance authority and repository self-CI.

## Consumer Procedure

1. Identify the exact published release or Preview contract.
2. Confirm the compatibility-document schema version.
3. Confirm every schema version used by the downstream repository.
4. Confirm the central workflow interface and immutable authority.
5. When Python or Bash functional validation is required, pin the matching functional workflow `immutableSha`.
6. Retain adoption evidence with the chosen entry and its stated limitations.

Consumers MUST NOT substitute `master`, a mutable tag, an undocumented self-CI pin, or a convenient schema version. When a required combination is absent, adoption MUST stop until the compatibility record is corrected or an approved exception exists.

## Release Gate

Before release approval, maintainers MUST update the matrix in the same unchanged candidate head as `VERSION`, changelog, release notes, schema declarations, workflow interfaces, migration guidance, and functional workflow authorities.

```powershell
pwsh -NoProfile -File scripts/Test-ReleaseLifecycle.ps1 -Path . -EvidencePath <release-lifecycle-record.json> -Stage PreRelease
```

The pre-release gate compares the lifecycle record with the matrix. Publication cannot make an unsupported combination valid merely by creating a tag.

## Support, Evidence, And Exceptions

A deprecation MUST identify announcement time, replacement, intended removal version, downstream impact, and migration guidance.

Evidence MUST identify commands, outcomes, candidate SHA, supported schemas, workflow interfaces, immutable workflow authorities, migration path, artifact hashes, approvals, and limitations. `Blocked`, `NotRun`, and `NotApplicable` remain visible.

An Exception requires a `GOV-*` record with owner, scope, rationale, expiration, compensating controls, and migration plan.

## Related

- [Release Status](RELEASE_STATUS.md)
- [Release Process](RELEASE_PROCESS.md)
- [Versioning](VERSIONING.md)
- [Downstream Governance Canary](DOWNSTREAM_CANARY.md)
- [Adoption Guide](ADOPTION_GUIDE.md)
- [Troubleshooting](TROUBLESHOOTING.md)
- [Issue #21 Contract Compatibility Proposal](migrations/ISSUE_21_CONTRACT_COMPATIBILITY_PROPOSAL.md)
