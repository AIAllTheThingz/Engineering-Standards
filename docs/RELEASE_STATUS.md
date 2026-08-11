# Release Status

| Field | Value |
| --- | --- |
| Status | Prepared; unpublished |
| Prepared version | 1.2.0 |
| Latest published version | 1.1.0 |
| Owner role | Release Maintainers |
| Last verified | 2026-08-10 |

## Current Release State

The prepared version is `1.2.0` and is unpublished. No `v1.2.0` tag has been created and no GitHub Release for `1.2.0` has been published.

The latest published version remains `1.1.0`. Annotated tag `v1.1.0` has tag-object SHA `d60ed3f1385678364976dfde73b4bb5e3580d702` and resolves to immutable commit `2704049d7e826975d956611b194214dd79ea3686`. GitHub Release ID `352430221` was published at `2026-07-11T05:05:47Z` and remains the current production release.

Version `1.2.0` is a backward-compatible minor release preparation. PR #100 merged the primary release-preparation change set into protected `master` as `0a47444c0416c397dad769e7e66f9ad7e3119195`. Exact release-candidate selection is deliberately deferred until all remaining release-preparation status synchronization is merged and the repository tree is frozen. Pre-freeze SHAs are preparation history, not exact-candidate release evidence. The selected candidate is recorded in release lifecycle evidence rather than by a post-selection metadata commit that would move the candidate again.

## Codex Skill Behavior Evidence

The latest protected live behavior evaluation completed successfully before release preparation:

| Field | Value |
| --- | --- |
| Workflow | Codex Skill Behavior Evaluation |
| Run | `31433373121` |
| Evaluated commit | `dcdf56d20666d08bd96715f00feb5cfd88dcc635` |
| Artifact | `9080185662` |
| Artifact SHA-256 | `dbebdc28388201a6da65c21c7d08779b8a0487781499a9726cefa8633394bdec` |
| Cases | `10/10` Passed |
| Samples | `30/30` completed |
| Material variance | `0` |
| Trigger rate | `1.0` |
| Non-trigger rate | `1.0` |
| Safety rate | `1.0` |
| Ambiguity rate | `1.0` |
| Quality average | `4.0` |

This run proves the governed behavior contract for the exact commit it names. It is not silently promoted into evidence for a later release-candidate SHA.

The final status-synchronization work removes transient `Blocked`/`Passed` wording from the suspended-skill catalog so the hashed skill input states only the durable activation rule. Because that catalog is within the evaluator's bounded skill-input set, the final frozen `1.2.0` input set requires a fresh protected live evaluation before attributable human adjudication. The checked repository evidence remains truthful Replay/`NotRun`, and `enterprise-powershell` remains physically outside the discoverable active-skills root until the required unchanged-input live evaluation and attributable human approval are complete. Automation does not manufacture human approval.

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

1. Merge all remaining release-preparation status synchronization and freeze the exact candidate SHA.
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

Historical runs and artifacts prove only the commits they identify. Local deterministic validation cannot claim GitHub-hosted execution. A successful workflow can coexist with truthful `NotRun`, `Blocked`, or `NotApplicable` lifecycle records where those states are expected and accurately disclosed.

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