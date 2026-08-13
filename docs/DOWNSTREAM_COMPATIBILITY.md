# Downstream Compatibility

| Field | Value |
| --- | --- |
| Status | Active |
| Contract version | 1.1.0 |
| Latest published governance release | 1.2.0 |
| Published target | `6c0050de328ac083e69fbac8971a317689c2c1d6` |
| Owner role | Release Maintainers |
| Last reviewed | 2026-08-13 |

## Purpose

This document defines how maintainers and downstream consumers determine whether a governance release, evidence schema, project-manifest schema, central reusable-workflow interface, or language-specific functional workflow remains supported. The machine-readable source of truth is [`governance/downstream-compatibility.json`](../governance/downstream-compatibility.json), validated against [`schemas/downstream-compatibility.schema.json`](../schemas/downstream-compatibility.schema.json).

A moving branch is never release evidence. Consumers MUST select an immutable published release target or an explicitly recorded immutable workflow authority and MUST NOT infer compatibility from a matching semantic version alone.

## Contract Schema Versions

The compatibility document supports two record shapes:

- `1.0.0` preserves the historical shape and does not contain `functionalWorkflows`.
- `1.1.0` requires `functionalWorkflows` in the unreleased contract.

These document-schema versions are independent from the repository governance release version.

## Published Matrix

Published `1.2.0` is the latest supported governance release. Annotated tag `v1.2.0` has tag-object SHA `42fa18ed9744fa98ce1f9048e3610f7ed6ff7507` and resolves to immutable commit `6c0050de328ac083e69fbac8971a317689c2c1d6`. GitHub Release ID `369234609` was published on 2026-08-12.

Published `1.2.0` supports:

- Central governance workflow interface `1.0.0`.
- Project-manifest schemas `1.0.0`, `1.1.0`, and `1.2.0`.
- Test-evidence schemas `1.0.0` and `1.1.0`.
- Completion-result schemas `1.0.0` and `1.1.0`.

Published `1.1.0` remains historical and supported at annotated tag `v1.1.0`, resolving to commit `2704049d7e826975d956611b194214dd79ea3686`.

## Known v1.2.0 Follow-Up

Publication exposed two immutable-release defects tracked in issue #103:

1. The v1.2.0 reusable-workflow identity check does not correctly distinguish an annotated tag object SHA from the peeled commit SHA.
2. The GitHub Release body was auto-generated rather than matching the reviewed release-note body exactly.

Do not move, recreate, or rewrite `v1.2.0` to conceal these defects. They require a later patch release. Until that patch is published, consumers that require the independently canary-validated repaired central reusable workflow should pin the existing immutable authority directly:

`AIAllTheThingz/Engineering-Standards/.github/workflows/governance-ci-reusable.yml@de32b77e2043f5336a54b92ab9ed867abe93ba7e`

## Functional Workflow Authorities

| Language | Reusable workflow | Interface | Immutable authority | Support | Validation boundary |
| --- | --- | --- | --- | --- | --- |
| Python | `.github/workflows/python-ci-reusable.yml` | `1.0.0` | `e066df32a0deaee38fed4a4cd477d1f4b4b549ed` | Preview | Maintained Python example and hosted Python CI passed; no external functional canary is claimed. |
| Bash | `.github/workflows/bash-ci-reusable.yml` | `1.0.0` | `d55bb8e6778030f5490e900ba52ba99ac6403827` | Preview | Maintained Bash example and hosted Bash CI passed; no external functional canary is claimed. |

These SHAs are distribution authorities recorded by the corresponding workflow contracts. They are distinct from the central governance authority and repository self-CI.

## Consumer Procedure

1. Identify the exact published release or explicitly documented immutable authority.
2. Confirm the compatibility-document schema version.
3. Confirm every schema version used by the downstream repository.
4. Confirm the central workflow interface and immutable authority.
5. When Python or Bash functional validation is required, pin the matching functional workflow `immutableSha`.
6. Retain adoption evidence with the chosen entry and its stated limitations.

Production consumers MAY adopt immutable published `v1.2.0` for the published control set, subject to the documented issue #103 limitations. Consumers needing the repaired reusable-governance workflow should pin `de32b77e2043f5336a54b92ab9ed867abe93ba7e` until the patch release supersedes that guidance. They MUST NOT substitute `master`, another moving branch, or an undocumented mutable reference for an immutable supported authority.

## Future Release Gate

Future releases must synchronize the matrix with `VERSION`, changelog, release notes, schema declarations, workflow interfaces, migration guidance, and functional workflow authorities on the exact candidate head.

```powershell
pwsh -NoProfile -File scripts/Test-ReleaseLifecycle.ps1 -Path . -EvidencePath <release-lifecycle-record.json> -Stage PreRelease
```

Reusable-workflow changes also require the applicable exact-candidate external canary contract; repository self-CI is necessary but does not replace external consumer proof.

## Support, Evidence, And Exceptions

A deprecation MUST identify announcement time, replacement, intended removal version, downstream impact, and migration guidance. A supported contract MUST be removed only through a separately reviewed major release with migration guidance.

Evidence MUST identify commands, outcomes, candidate SHA, supported schemas, workflow interfaces, immutable workflow authorities, migration path, artifact hashes, approvals, and limitations. `Blocked`, `NotRun`, and `NotApplicable` remain visible and cannot be relabeled as `Passed`.

An exception requires a `GOV-*` record with owner, scope, rationale, expiration, compensating controls, and migration plan. Exceptions do not rewrite historical matrix entries and cannot convert unavailable external validation into `Passed`.

## Related

- [Release Status](RELEASE_STATUS.md)
- [Release Process](RELEASE_PROCESS.md)
- [Versioning](VERSIONING.md)
- [1.2.0 Release Record](releases/1.2.0.md)
- [Downstream Governance Canary](DOWNSTREAM_CANARY.md)
- [Adoption Guide](ADOPTION_GUIDE.md)
- [Troubleshooting](TROUBLESHOOTING.md)
