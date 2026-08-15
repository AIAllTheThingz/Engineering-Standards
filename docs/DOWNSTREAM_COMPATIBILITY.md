# Downstream Compatibility

| Field | Value |
| --- | --- |
| Status | Active; v1.2.1 published; published-ref canary verified; final PostRelease lifecycle pending |
| Contract version | 1.2.0 |
| Latest published governance release | 1.2.1 |
| Published target | `7d15ec8be6d8c3cdca35061728901584437e4a50` |
| Current master contract | 1.2.1 Preview; newer than published target |
| Owner role | Release Maintainers |
| Last reviewed | 2026-08-15 |

## Purpose

This document defines how maintainers and downstream consumers determine whether a governance release, evidence schema, project-manifest schema, central reusable-workflow interface, or language-specific functional workflow remains supported. The machine-readable source of truth is [`governance/downstream-compatibility.json`](../governance/downstream-compatibility.json), validated against [`schemas/downstream-compatibility.schema.json`](../schemas/downstream-compatibility.schema.json).

A moving branch is never release evidence. Consumers MUST select an immutable published release target or an explicitly recorded immutable workflow authority and MUST NOT infer compatibility from a matching semantic version alone.

## Contract Schema Versions

- `1.0.0` preserves the historical compatibility shape.
- `1.1.0` adds functional workflow authorities.
- `1.2.0` adds explicit `canaryValidationStatus`; only `Passed` may carry a concrete `canaryValidatedWorkflowSha`, while `Failed`, `Blocked`, `NotRun`, and `NotApplicable` require that authority to remain null.

These compatibility-document schema versions are independent from the repository governance release version.

## Published Matrix

Published `1.2.1` is the latest supported governance release. Annotated tag `v1.2.1` has tag-object SHA `aea6330ee3d51b3f5bb55031d878ef302ba1dbca` and resolves to immutable commit `7d15ec8be6d8c3cdca35061728901584437e4a50`. GitHub Release ID `370882222` was published on 2026-08-15 from the reviewed release-note body exactly.

Published `1.2.1` supports:

- Central governance workflow interface `1.0.0`.
- Project-manifest schemas `1.0.0`, `1.1.0`, and `1.2.0`.
- Test-evidence schemas `1.0.0` and `1.1.0`.
- Completion-result schemas `1.0.0` and `1.1.0`.

The full published-ref five-scenario canary used caller commit `03979bdd46e36593faf044e2206e24c7ed485d62`. Success run `31853248739` passed and all four isolated negative scenarios failed only for their intended reasons. Every artifact records the annotated workflow object `aea6330ee3d51b3f5bb55031d878ef302ba1dbca` separately from peeled standards commit `7d15ec8be6d8c3cdca35061728901584437e4a50`.

Published `1.2.0` and `1.1.0` remain historical supported entries in the machine-readable matrix. Their immutable tags and targets are not rewritten by this patch.

## Current Master Preview

Current `master` contains PR #108 after the frozen v1.2.1 release target. The root governance version therefore remains `1.2.1`, but the `unreleasedContract` describes newer moving-branch development rather than the contents of published `v1.2.1`.

For that reason the current-master Preview records `canaryValidationStatus: NotRun` and `canaryValidatedWorkflowSha: null`. The successful published-ref canary is release evidence for `v1.2.1`; it is not silently reused as certification of later `master`.

The current unreleased migration guide is [`docs/releases/unreleased.md`](releases/unreleased.md).

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

Production workflow consumers SHOULD use full commit SHA `7d15ec8be6d8c3cdca35061728901584437e4a50` for the published v1.2.1 governance workflow. The protected semantic ref `v1.2.1` has completed published-ref annotated-tag canary verification and may be used where protected release refs are explicitly accepted. Final PostRelease lifecycle validation remains pending until this repository synchronization is merged. `master` and validation/preparation branches are not production authorities.

## Historical v1.2.0 Follow-Up

Issue #103 recorded the v1.2.0 annotated-tag identity defect and release-body mismatch. Published v1.2.1 corrects both without mutating v1.2.0. Historical evidence remains attributable to the exact version, commit, run, and artifact it names.

## Support, Evidence, And Exceptions

A deprecation MUST identify announcement time, replacement, intended removal version, downstream impact, and migration guidance. Evidence MUST identify actual commands or runs, outcomes, candidate SHA, schema/interface versions, immutable authorities, artifact hashes, approvals, and limitations. `Blocked`, `NotRun`, and `NotApplicable` remain visible and cannot be relabeled as `Passed`.

An exception requires a `GOV-*` record with owner, scope, rationale, expiration, compensating controls, and migration plan. Exceptions do not rewrite historical matrix entries and cannot convert unavailable external validation into `Passed`.

## Related

- [Release Status](RELEASE_STATUS.md)
- [Published v1.2.1 Release Notes](releases/1.2.1.md)
- [Unreleased Development](releases/unreleased.md)
- [Release Process](RELEASE_PROCESS.md)
- [Versioning](VERSIONING.md)
- [Downstream Governance Canary](DOWNSTREAM_CANARY.md)
- [Adoption Guide](ADOPTION_GUIDE.md)
- [Troubleshooting](TROUBLESHOOTING.md)
