# Downstream Governance Canary

| Field | Value |
| --- | --- |
| Status | Active |
| Governance version | 1.1.0 |
| Owner role | Engineering Standards Maintainers |
| Canary repository | `AIAllTheThingz/Engineering-Standards-Canary` |
| Validated standards SHA | `091841c94fba6039443a40b7c4a28e5b9a3af2d2` |
| Last verified | 2026-07-11 |

## Purpose

The public downstream canary proves that the reusable governance workflow operates across a real repository boundary without copying central `scripts/`, `actions/`, `tests/`, or `examples/`. It is a release gate for reusable-workflow changes, not a template repository and not a substitute for each consumer's application-specific CI.

The canary is intentionally non-production, contains no secrets, and uses only the `Contract` validation category. Its manifest classifies it as an `integration` project with `Moderate` risk and `Public` data. The workflow has only `contents: read` permission and pins every reusable-workflow call to one reviewed full commit SHA.

## Repository Shape

The root success project contains the required adoption documents, manifest, governance configuration, workflow, and this canary's operating guide. Two fixture projects provide isolated invalid inputs. A separate repository-shape job fails if directories named `scripts`, `actions`, `tests`, or `examples` are introduced anywhere in the canary.

The workflow exposes a closed `workflow_dispatch` choice with exactly five scenarios:

| Scenario | Input under test | Expected conclusion |
| --- | --- | --- |
| `success` | Valid root project | Success |
| `controlled-failure` | Reusable workflow's controlled-failure input | Failure after evidence upload |
| `governance-version-mismatch` | Caller input does not match the manifest | Failure |
| `missing-required-file` | Fixture omits `SECURITY.md` | Failure |
| `mandatory-control-disablement` | Fixture requests a mandatory control disablement | Failure |

Only the selected scenario job runs during manual dispatch. Pull requests and pushes to `main` run the success scenario. Negative scenarios remain independently selectable so one intended failure cannot mask another.

## Verified Baseline

The initial cross-repository proof used canary commit `e3e841e67f27606c43b5e2179f838f3f0314aaf1` and Engineering Standards commit `091841c94fba6039443a40b7c4a28e5b9a3af2d2`. Every run uploaded evidence, and each downloaded artifact passed independent verification with `scripts/Test-WorkflowEvidenceArtifact.ps1`.

| Scenario | Run | Governance job | Artifact ID | Artifact SHA-256 | Result |
| --- | ---: | ---: | ---: | --- | --- |
| Success | `29172568985` | `86596048593` | `8253932910` | `6f9960dbfe7c7aa4929dc8a34473ed3c74c1d62d40192591d214b6da41160680` | Passed |
| Controlled failure | `29172598746` | `86596124907` | `8253939949` | `601c1b78456c01387ca13a803b239e115ff93ed50a5a37c955e775accdfebc19` | Expected failure verified |
| Governance version mismatch | `29172599524` | `86596125975` | `8253940477` | `598cebbd5cb8ca4c8f0fb7af90a11867401a58a8f5382ebc9baf8f7d79b2d1d3` | Expected failure verified |
| Missing required file | `29172600326` | `86596128396` | `8253940162` | `c996a6bab915f5fe3c755cdaab878ebe56aff0e50c4729e3e0a7bacc3f6c2d49` | Expected failure verified |
| Mandatory control disablement | `29172601001` | `86596130760` | `8253940790` | `36bfd31bedd1c6799ae1201e175dad2b6019ae128e23458c3bd0d9f6d8599d39` | Expected failure verified |

The pull-request success artifact records the GitHub-generated merge commit `6597c1acc53e04862d8e755d2df6267b17477727` at `1/merge`; manual scenario artifacts record the exact canary head above. All artifacts record the immutable standards workflow identity. This distinction prevents a synthetic pull-request merge identity from being misreported as the branch head.

## Release Gate

Before approving a reusable-workflow release or rotating the authoritative self-CI pin, maintainers MUST:

1. Update all five canary calls to the exact candidate commit SHA in one reviewable change.
2. Confirm the canary retains least privilege, immutable third-party action pins, no secrets or environments, and the prohibited-directory shape check.
3. Run all five scenarios against the exact candidate SHA.
4. Confirm success passes and each negative scenario fails for only its intended reason.
5. Download every evidence artifact into a temporary directory and independently verify repository, caller commit, branch, run identity, conclusion, and hash.
6. Record the runs, artifact IDs, hashes, candidate SHA, canary commit, and reviewer decision in the release pull request.

A missing run, unexpected conclusion, absent artifact, verification failure, mutable pin, or unexplained difference blocks release. Self-CI success in this repository does not replace the external canary because it does not test the cross-repository caller boundary.

## Operations And Ownership

Engineering Standards maintainers own canary pin rotation, scenario maintenance, artifact verification, and failure triage. Canary changes MUST remain minimal and must not become a second copy of central governance implementation. Contract changes require synchronized updates to the valid root project and the smallest relevant fixture.

Artifacts are evidence of a particular run, caller commit, and standards SHA; they are not evergreen certification. Do not commit downloaded artifacts to either repository or copy their metadata into `evidence/latest-verified-run.json`, which is reserved for this repository's authoritative hosted verification record.

## Failure And Rollback

When a candidate fails unexpectedly, leave the candidate unapproved, preserve the run and artifact references, and identify whether the defect is in the reusable workflow, caller contract, fixture expectation, or GitHub execution environment. Correct the smallest owning change and rerun all five scenarios; do not relabel an unexpected result as an expected failure.

If a released workflow regresses downstream behavior, advise consumers to retain or restore the last independently verified full SHA while a focused corrective change is reviewed. Do not force-push canary history, rewrite release tags, weaken a scenario, or rotate the authoritative pin until the external proof is clean.

## Limitations

The canary validates the reusable governance contract and its security boundary. It does not exercise consumer builds, tests, deployments, private repositories, GitHub Enterprise Server, repository-specific scanner extensions, or every supported static category. Those concerns remain with caller-owned CI and their applicable adoption evidence.

## Related

- [Adoption Guide](ADOPTION_GUIDE.md)
- [Downstream Configuration](DOWNSTREAM_CONFIGURATION.md)
- [Action Security](ACTION_SECURITY.md)
- [Release Process](RELEASE_PROCESS.md)
- [Troubleshooting](TROUBLESHOOTING.md)
