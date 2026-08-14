# Downstream Compatibility

| Field | Value |
| --- | --- |
| Status | Active; 1.2.1 preview prepared |
| Contract version | 1.2.0 |
| Latest published governance release | 1.2.0 |
| Published target | `6c0050de328ac083e69fbac8971a317689c2c1d6` |
| Prepared governance release | 1.2.1, unpublished |
| Owner role | Release Maintainers |
| Last reviewed | 2026-08-14 |

## Purpose

This document defines how maintainers and downstream consumers determine whether a governance release, evidence schema, project-manifest schema, central reusable-workflow interface, or language-specific functional workflow remains supported. The machine-readable source of truth is [`governance/downstream-compatibility.json`](../governance/downstream-compatibility.json), validated against [`schemas/downstream-compatibility.schema.json`](../schemas/downstream-compatibility.schema.json).

A moving branch is never release evidence. Consumers MUST select an immutable published release target or an explicitly recorded immutable workflow authority and MUST NOT infer compatibility from a matching semantic version alone.

## Contract Schema Versions

The compatibility document supports three record shapes:

- `1.0.0` preserves the historical shape and does not contain `functionalWorkflows` or an explicit canary status.
- `1.1.0` requires `functionalWorkflows` and retains the historical concrete `canaryValidatedWorkflowSha` shape.
- `1.2.0` requires `functionalWorkflows` plus explicit `canaryValidationStatus`. `Passed` requires a full immutable `canaryValidatedWorkflowSha`; `Failed`, `Blocked`, `NotRun`, and `NotApplicable` require the canary authority to remain `null` so historical evidence cannot be silently reused for a new candidate.

These document-schema versions are independent from the repository governance release version.

## Published Matrix

Published `1.2.0` remains the latest supported governance release. Annotated tag `v1.2.0` has tag-object SHA `42fa18ed9744fa98ce1f9048e3610f7ed6ff7507` and resolves to immutable commit `6c0050de328ac083e69fbac8971a317689c2c1d6`. GitHub Release ID `369234609` was published on 2026-08-12.

Published `1.2.0` supports:

- Central governance workflow interface `1.0.0`.
- Project-manifest schemas `1.0.0`, `1.1.0`, and `1.2.0`.
- Test-evidence schemas `1.0.0` and `1.1.0`.
- Completion-result schemas `1.0.0` and `1.1.0`.

Published `1.1.0` remains historical and supported at annotated tag `v1.1.0`, resolving to commit `2704049d7e826975d956611b194214dd79ea3686`.

## Prepared v1.2.1 Preview

Version `1.2.1` is prepared and unpublished. The preview intentionally keeps the same central workflow interface and supported schema sets as `1.2.0`; the patch is corrective rather than a new downstream governance obligation.

The prepared patch repairs issue #103 by making reusable governance workflow identity validation explicitly annotated-tag-aware while preserving exact commit binding. GitHub's tag-object SHA and the peeled standards commit are verified separately and recorded as separate provenance values. Direct full-SHA pins remain supported. Branches, lightweight tags, malformed refs, unexpected repositories, unexpected workflow paths, mismatched tag objects, and mismatched peeled commits fail closed.

The machine-readable preview records `canaryValidationStatus: NotRun` and a null canary authority until exact-candidate external validation is actually observed. Historical governance-1.1 canary evidence is therefore preserved as history rather than relabeled as proof for 1.2.1.

The prepared semantic version and preview matrix do not make the branch or its current head a production authority. Exact final-candidate hosted proof, the five-scenario external canary, independent artifact verification, attributable approval, and publication remain required.

## Historical v1.2.0 Follow-Up

Issue #103 records two defects discovered after `v1.2.0` publication:

1. the published reusable workflow did not distinguish the annotated tag-object SHA from its peeled commit SHA;
2. the GitHub Release body was auto-generated instead of matching reviewed release notes exactly.

Do not move, recreate, delete, or rewrite `v1.2.0` to conceal these defects. Until `v1.2.1` is published and PostRelease verification succeeds, 1.2 consumers needing the complete published workflow set should use the full published target commit `6c0050de328ac083e69fbac8971a317689c2c1d6` rather than annotated `v1.2.0`.

The independently canary-validated `de32b77e2043f5336a54b92ab9ed867abe93ba7e` authority is historical governance-1.1 evidence. It is not the complete 1.2 distribution and is not relabeled as 1.2.1 validation.

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

Production consumers MUST NOT substitute `master`, the `1.2.1` preparation branch, another moving branch, or an undocumented mutable reference for an immutable supported authority.

## Future Release Gate

The prepared patch must synchronize the matrix with `VERSION`, changelog, release notes, schema declarations, workflow interfaces, migration guidance, and functional workflow authorities on the exact final candidate head.

```powershell
pwsh -NoProfile -File scripts/Test-ReleaseLifecycle.ps1 -Path . -EvidencePath <release-lifecycle-record.json> -Stage PreRelease
```

Reusable-workflow changes also require the exact-candidate external canary contract; repository self-CI is necessary but does not replace external consumer proof. After publication, the canary must also exercise the published annotated `v1.2.1` ref before PostRelease can pass.

## Support, Evidence, And Exceptions

A deprecation MUST identify announcement time, replacement, intended removal version, downstream impact, and migration guidance. A supported contract MUST be removed only through a separately reviewed major release with migration guidance.

Evidence MUST identify commands, outcomes, candidate SHA, supported schemas, workflow interfaces, immutable workflow authorities, migration path, artifact hashes, approvals, and limitations. `Blocked`, `NotRun`, and `NotApplicable` remain visible and cannot be relabeled as `Passed`.

An exception requires a `GOV-*` record with owner, scope, rationale, expiration, compensating controls, and migration plan. Exceptions do not rewrite historical matrix entries and cannot convert unavailable external validation into `Passed`.

## Related

- [Release Status](RELEASE_STATUS.md)
- [Prepared v1.2.1 Release Notes](releases/1.2.1.md)
- [Release Process](RELEASE_PROCESS.md)
- [Versioning](VERSIONING.md)
- [v1.2.0 Historical Release Record](releases/1.2.0.md)
- [Downstream Governance Canary](DOWNSTREAM_CANARY.md)
- [Adoption Guide](ADOPTION_GUIDE.md)
- [Troubleshooting](TROUBLESHOOTING.md)
