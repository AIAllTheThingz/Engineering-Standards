# Release Status

| Field | Value |
| --- | --- |
| Status | Prepared; unpublished |
| Prepared version | 1.2.1 |
| Latest published version | 1.2.0 |
| Published v1.2.0 target | `6c0050de328ac083e69fbac8971a317689c2c1d6` |
| Published v1.2.0 tag object | `42fa18ed9744fa98ce1f9048e3610f7ed6ff7507` |
| Published v1.2.0 GitHub Release ID | `369234609` |
| Owner role | Release Maintainers |
| Last verified | 2026-08-14 |

## Current Release State

The prepared version is `1.2.1` and is unpublished. No `v1.2.1` tag or GitHub Release is claimed by this repository state.

The latest published version remains `1.2.0`. Annotated tag `v1.2.0` has tag-object SHA `42fa18ed9744fa98ce1f9048e3610f7ed6ff7507` and resolves to immutable commit `6c0050de328ac083e69fbac8971a317689c2c1d6`. GitHub Release `v1.2.0` is historical external state and is not rewritten by the patch preparation.

Current `master` contains development after the published target. Historical release evidence is bounded to the exact commit, run, artifact, or input set it names and does not validate current `master`.

## Prepared v1.2.1 Scope

The patch release is scoped to issue #103 and the post-`v1.2.0` corrections already merged to `master`:

- make the reusable governance workflow explicitly aware of annotated release-tag object identity while preserving exact peeled-commit binding;
- reject branches, lightweight tags, malformed refs, wrong repositories, wrong workflow paths, mismatched tag objects, and mismatched peeled commits;
- record both workflow object identity and peeled standards commit identity in hosted evidence;
- require the future `v1.2.1` GitHub Release body to match the reviewed `docs/releases/1.2.1.md` content exactly rather than using auto-generated notes;
- include the post-release release-state, compatibility-guidance, and `enterprise-powershell` verifier-routing corrections merged through PR #106.

The root governance workflow interface remains `1.0.0`; supported project-manifest, test-evidence, and completion-result schema sets are unchanged.

## Validation State

- Repository and candidate hosted validation for the final `1.2.1` candidate: `NotRun` until the pull-request candidate is frozen and GitHub reports final results.
- Controlled-failure hosted proof for the final candidate: `NotRun`.
- Five-scenario downstream canary against the exact final candidate SHA: `NotRun`.
- Independent artifact verification for those runs: `NotRun`.
- Attributable final-head human release approval: `NotRun`.
- Tag creation, GitHub Release publication, Publication gate, and PostRelease gate: `NotRun` and require separate authorized external actions.

No pending gate above is inferred from historical evidence.

## Historical v1.2.0 Follow-Up

Issue #103 remains the owning defect record until the prepared patch passes PreRelease, is explicitly authorized and published as a new immutable release, passes the published annotated-tag canary path, and completes PostRelease verification. The existing `v1.2.0` tag and release must not be moved, recreated, deleted, or silently rewritten.

## Immutable Consumer References

- Published v1.2.0 control set: full commit `6c0050de328ac083e69fbac8971a317689c2c1d6`. Consumers should use the full SHA rather than annotated `v1.2.0` while issue #103 remains unresolved.
- Historical published v1.1.0 control set: `2704049d7e826975d956611b194214dd79ea3686` through annotated tag `v1.1.0`.
- Historical governance-1.1 consumers requiring the final canary-validated repaired reusable workflow should pin `.github/workflows/governance-ci-reusable.yml@de32b77e2043f5336a54b92ab9ed867abe93ba7e`; this retained authority is historical evidence and is not the prepared v1.2.1 candidate authority.
- Prepared `1.2.1` is not yet a production consumer authority. Consumers must not pin the moving preparation branch or treat preparation as publication.

## Verification Boundaries

- A successful hosted workflow does not imply human approval unless attributable adjudication is separately recorded.
- Checked behavior evidence may claim `Passed` only when its exact live artifact and attributable human adjudication are both present and verifiable.
- Missing, failed, blocked, or unverifiable release gates remain visible rather than being relabeled as `Passed`.
- The reviewed `docs/releases/1.2.1.md` file is the intended publication body; using generated release notes would recreate the release-integrity defect.

## Related Documents

- [Prepared v1.2.1 Release Notes](releases/1.2.1.md)
- [v1.2.0 Historical Release Record](releases/1.2.0.md)
- [Unreleased / Prepared Migration Guide](releases/unreleased.md)
- [Changelog](../CHANGELOG.md)
- [Versioning](VERSIONING.md)
- [Release Process](RELEASE_PROCESS.md)
- [Downstream Compatibility](DOWNSTREAM_COMPATIBILITY.md)
- [Downstream Governance Canary](DOWNSTREAM_CANARY.md)
- [Codex Skill Validation](CODEX_SKILL_VALIDATION.md)
