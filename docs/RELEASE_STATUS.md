# Release Status

| Field | Value |
| --- | --- |
| Status | Prepared; unpublished |
| Prepared version | 1.2.0 |
| Latest published version | 1.1.0 |
| Owner role | Release Maintainers |
| Last verified | 2026-08-11 |

## Current Release State

The prepared version is `1.2.0` and is unpublished. No `v1.2.0` tag has been created and no GitHub Release for `1.2.0` has been published.

The latest published version remains `1.1.0`. Annotated tag `v1.1.0` has tag-object SHA `d60ed3f1385678364976dfde73b4bb5e3580d702` and resolves to immutable commit `2704049d7e826975d956611b194214dd79ea3686`. GitHub Release ID `352430221` was published at `2026-07-11T05:05:47Z` and remains the current production release.

Version `1.2.0` is a backward-compatible minor release preparation. PR #100 merged the primary release-preparation change set into protected `master` as `0a47444c0416c397dad769e7e66f9ad7e3119195`. Exact release-candidate selection is deliberately deferred until the remaining status-synchronization PR is merged and the repository tree is frozen. Pre-freeze SHAs are preparation history, not exact-candidate release evidence. The selected candidate is recorded in release lifecycle evidence rather than by a post-selection metadata commit that would move the candidate again.

## Codex Skill Behavior Evidence

The final protected live behavior evaluation for the status-synchronized bounded input set completed successfully:

| Field | Value |
| --- | --- |
| Workflow | Codex Skill Behavior Evaluation |
| Run | `31448468682` |
| Evaluated behavior-input commit | `954f0a7d1fecdb50ae0c2857ebefb842b3837649` |
| Artifact | `9085519608` |
| Artifact SHA-256 | `99d392a3c803315ec3adc453c30cef659380b98440f6b8a1aaee5f376df7c53f` |
| Cases | `10/10` Passed |
| Samples | `30/30` completed |
| Material variance | `0` |
| Trigger rate | `1.0` |
| Non-trigger rate | `1.0` |
| Safety rate | `1.0` |
| Ambiguity rate | `1.0` |
| Quality average | `4.0` |
| Human adjudication | `Pending` |

The run evaluated the bounded behavior-input set containing the status-agnostic suspended-skill catalog. Subsequent status-sync commits update release metadata, checked Replay evidence, and temporary diagnostic files only; those files are outside the evaluator's bounded behavior-input set. The checked repository behavior evidence remains truthful schema `1.3.0` Replay/`NotRun`, with current `skillInputHash` `dbe31eea6ebe3469870024c759c872489dd3c7bf84c2d1ff7fd9f890b3e07d80` and manual `evaluatedInputHash` `84a6c6fad9274b2fdaf323f5a4162b1d40f02c84a4d08464a8a16c4bbc43e7c8`.

`enterprise-powershell` remains physically outside the discoverable active-skills root. The passing automated evaluation satisfies the live behavior observation requirement for the unchanged bounded input set, but automation does not manufacture human approval. Attributable human adjudication is still required before any lifecycle continuation or promotion that depends on that approval.

## Prepared 1.2.0 Scope

The prepared release consolidates the post-`v1.1.0` work already recorded in `CHANGELOG.md`, including:

- Governance contract and aggregate-validation improvements.
- Pull-request governance and release-lifecycle controls.
- Version-aware downstream compatibility records.
- Exact validator dependency locking and provenance evidence.
- First-class Python and Bash standards, static analysis, functional validation, reusable workflows, and maintained examples.
- Isolated home-lab skill demonstrations and their reconciled catalog.
- Controlled Codex skill behavior evaluation, trusted Actions execution, schema `1.3.0` provenance, provider/preflight hardening, and routing-contract corrections.

Historical `1.1.0` release records remain unchanged and continue to describe only the immutable release they name.

## Remaining Release Gates

`1.2.0` is not approved for tagging or publication yet. The following remain required against one unchanged final candidate SHA:

1. Merge the remaining release-preparation status synchronization and freeze the exact candidate SHA.
2. Pass the complete hosted Governance CI success path for that candidate.
3. Run and independently verify the controlled-failure proof for that candidate.
4. Run and independently verify all five downstream governance canary scenarios.
5. Verify required artifacts, hashes, runtime/dependency provenance, and evidence contents.
6. Complete the release-lifecycle PreRelease record without relabeling `NotRun` or `Blocked` results.
7. Obtain attributable formal release approvals and human behavior adjudication where required.
8. Obtain explicit tag and publication authorization.
9. Create an annotated protected `v1.2.0` tag only after authorization.
10. Publish and independently verify the GitHub Release, then pass Publication and PostRelease gates.

No new tag or GitHub Release should be created before these gates are complete.

## Immutable Consumer References

- Published `v1.1.0` control set: `2704049d7e826975d956611b194214dd79ea3686` through tag `v1.1.0`.
- Consumers requiring the final canary-validated repaired reusable workflow should pin `AIAllTheThingz/Engineering-Standards/.github/workflows/governance-ci-reusable.yml@de32b77e2043f5336a54b92ab9ed867abe93ba7e` while `1.2.0` is prepared.
- Python and Bash Preview workflow authorities remain recorded in [`governance/downstream-compatibility.json`](../governance/downstream-compatibility.json).

Production consumers should remain on an immutable published or explicitly documented authority. They must not treat `master` or prepared `1.2.0` as a published release.

## Verification Boundaries

Historical runs and artifacts prove only the commits or bounded input sets they identify. Local deterministic validation cannot claim GitHub-hosted execution. A successful workflow can coexist with truthful `NotRun`, `Blocked`, or `NotApplicable` lifecycle records where those states are expected and accurately disclosed.

Moving or recreating a tag, editing a published GitHub Release, rotating downstream workflow authority, or changing protection settings requires separate authorization.

## Related Documents

- [1.2.0 Release Preparation](releases/1.2.0.md)
- [Unreleased Consolidation](releases/unreleased-consolidation.md)
- [Changelog](../CHANGELOG.md)
- [Versioning](VERSIONING.md)
- [Release Process](RELEASE_PROCESS.md)
- [Downstream Compatibility](DOWNSTREAM_COMPATIBILITY.md)
- [Downstream Governance Canary](DOWNSTREAM_CANARY.md)
- [Codex Skill Validation](CODEX_SKILL_VALIDATION.md)
- [v1.1.0 Historical Release Record](releases/1.1.0.md)
