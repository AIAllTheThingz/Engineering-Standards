# Downstream Compatibility

| Field | Value |
| --- | --- |
| Status | Active |
| Contract version | 1.1.0 |
| Published governance release | 1.1.0 |
| Prepared governance version | 1.2.0 |
| Owner role | Release Maintainers |
| Last reviewed | 2026-08-10 |

## Purpose

This document defines how maintainers and downstream consumers determine whether a governance release, evidence schema, project-manifest schema, central reusable-workflow interface, or language-specific functional workflow remains supported. The machine-readable source of truth is [`governance/downstream-compatibility.json`](../governance/downstream-compatibility.json), validated against [`schemas/downstream-compatibility.schema.json`](../schemas/downstream-compatibility.schema.json).

The matrix distinguishes immutable published releases from the prepared Preview contract. A moving branch is never release evidence. Consumers MUST select an immutable published release target or an explicitly recorded immutable workflow authority and MUST NOT infer compatibility from a matching semantic version alone.

## Contract Schema Versions

The compatibility document supports two record shapes:

- `1.0.0` preserves the historical shape and does not contain `functionalWorkflows`.
- `1.1.0` requires `functionalWorkflows` in the unreleased contract.

These document-schema versions are independent from the repository governance release version.

## Published Matrix

Published `1.1.0` remains supported at annotated tag `v1.1.0`, resolving to commit `2704049d7e826975d956611b194214dd79ea3686`.

That published release contains:

- Central governance workflow interface `1.0.0`.
- Project-manifest schemas `1.0.0` and `1.1.0`.
- Test-evidence schemas `1.0.0` and `1.1.0`.
- Completion-result schemas `1.0.0` and `1.1.0`.

The later Python, Bash, pull-request governance, release-lifecycle, controlled Codex evaluator, validator-dependency, and project-manifest `1.2.0` work is not retroactively part of `v1.1.0`.

## Prepared 1.2.0 Contract

The prepared version is `1.2.0` and is unpublished. It remains `Preview` until the complete release lifecycle passes and an authorized immutable `v1.2.0` tag and GitHub Release are created and independently verified.

The prepared contract retains central workflow interface `1.0.0` and supports project-manifest schemas `1.0.0`, `1.1.0`, and `1.2.0`. Test-evidence and completion-result schema support remains `1.0.0` and `1.1.0`.

The independently canary-validated central downstream workflow authority remains:

`AIAllTheThingz/Engineering-Standards/.github/workflows/governance-ci-reusable.yml@de32b77e2043f5336a54b92ab9ed867abe93ba7e`

Repository self-CI remains separate from that downstream authority until fresh exact-candidate external validation is recorded for the prepared release.

## Functional Workflow Authorities

| Language | Reusable workflow | Interface | Immutable authority | Support | Validation boundary |
| --- | --- | --- | --- | --- | --- |
| Python | `.github/workflows/python-ci-reusable.yml` | `1.0.0` | `e066df32a0deaee38fed4a4cd477d1f4b4b549ed` | Preview | Maintained Python example and hosted Python CI passed; no external functional canary is claimed. |
| Bash | `.github/workflows/bash-ci-reusable.yml` | `1.0.0` | `d55bb8e6778030f5490e900ba52ba99ac6403827` | Preview | Maintained Bash example and hosted Bash CI passed; no external functional canary is claimed. |

These SHAs are distribution authorities recorded by the corresponding workflow contracts. They are distinct from the central governance authority and repository self-CI.

## Consumer Procedure

1. Identify the exact published release or explicitly Preview contract.
2. Confirm the compatibility-document schema version.
3. Confirm every schema version used by the downstream repository.
4. Confirm the central workflow interface and immutable authority.
5. When Python or Bash functional validation is required, pin the matching functional workflow `immutableSha`.
6. Retain adoption evidence with the chosen entry and its stated limitations.

Production consumers SHOULD remain on published `v1.1.0` until `v1.2.0` is published. They MUST NOT substitute `master`, an unpublished semantic version, a mutable tag, an undocumented self-CI pin, or a convenient schema version for an immutable supported reference.

## Release Gate

Before `1.2.0` release approval, maintainers MUST update the matrix in the same unchanged candidate head as `VERSION`, changelog, release notes, schema declarations, workflow interfaces, migration guidance, and functional workflow authorities.

```powershell
pwsh -NoProfile -File scripts/Test-ReleaseLifecycle.ps1 -Path . -EvidencePath <release-lifecycle-record.json> -Stage PreRelease
```

The pre-release gate compares the lifecycle record with this matrix. Publication cannot make an unsupported combination valid merely by creating a tag. Reusable-workflow changes also require the applicable exact-candidate external canary contract; repository self-CI is necessary but does not replace external consumer proof.

## Support, Evidence, And Exceptions

A deprecation MUST identify announcement time, replacement, intended removal version, downstream impact, and migration guidance. A supported contract MUST be removed only through a separately reviewed major release with migration guidance.

Evidence MUST identify commands, outcomes, candidate SHA, supported schemas, workflow interfaces, immutable workflow authorities, migration path, artifact hashes, approvals, and limitations. `Blocked`, `NotRun`, and `NotApplicable` remain visible and cannot be relabeled as `Passed`.

An exception requires a `GOV-*` record with owner, scope, rationale, expiration, compensating controls, and migration plan. Exceptions do not rewrite historical matrix entries and cannot convert unavailable external validation into `Passed`.

## Related

- [Release Status](RELEASE_STATUS.md)
- [Release Process](RELEASE_PROCESS.md)
- [Versioning](VERSIONING.md)
- [1.2.0 Release Preparation](releases/1.2.0.md)
- [Downstream Governance Canary](DOWNSTREAM_CANARY.md)
- [Adoption Guide](ADOPTION_GUIDE.md)
- [Troubleshooting](TROUBLESHOOTING.md)
