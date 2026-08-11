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

Version `1.2.0` is a backward-compatible minor release preparation. PR #100 merged the primary release-preparation change set into protected `master` as `0a47444c0416c397dad769e7e66f9ad7e3119195`. Exact release-candidate selection is deliberately deferred until PR #101 finishes status synchronization, is merged, and the repository tree is frozen. Pre-freeze SHAs are preparation history, not exact-candidate release evidence. The selected candidate is recorded in release lifecycle evidence rather than by a post-selection metadata commit that would move the candidate again.

## Codex Skill Behavior Evidence

Protected live behavior run `31448468682` is historical evidence for the exact bounded input set at commit `954f0a7d1fecdb50ae0c2857ebefb842b3837649`:

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

Review subsequently required a final newline in `.agents/suspended-skills/README.md`. That file is part of the evaluator's bounded skill-input set, so the formatting-only correction changed the behavior hash. Run `31448468682` therefore must not be treated as the final unchanged-input evaluation for PR #101.

The final protected behavior rerun remains pending until the PR #101 behavior-bound input set is stable. The checked schema `1.3.0` Replay evidence must also be regenerated against that same stabilized input set and remains Replay/`NotRun`; it cannot be relabeled as live or passing evidence. `enterprise-powershell` remains physically outside the discoverable active-skills root, and attributable human adjudication remains pending. Automation does not manufacture human approval.

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

`1.2.0` is not approved for tagging or publication yet. The following remain required:

1. Complete the final protected Codex behavior rerun for PR #101's stabilized behavior-bound input set and refresh the checked Replay/`NotRun` evidence truthfully.
2. Merge the remaining release-preparation status synchronization and freeze the exact candidate SHA.
3. Pass the complete hosted Governance CI success path for that candidate.
4. Run and independently verify the controlled-failure proof for that candidate.
5. Run and independently verify all five downstream governance canary scenarios.
6. Verify required artifacts, hashes, runtime/dependency provenance, and evidence contents.
7. Complete the release-lifecycle PreRelease record without relabeling `NotRun` or `Blocked` results.
8. Obtain attributable formal release approvals and human behavior adjudication where required.
9. Obtain explicit tag and publication authorization.
10. Create an annotated protected `v1.2.0` tag only after authorization.
11. Publish and independently verify the GitHub Release, then pass Publication and PostRelease gates.

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
