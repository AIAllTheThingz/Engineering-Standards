# Downstream Governance Canary

| Field | Value |
| --- | --- |
| Status | Active |
| Governance version | 1.1.0 |
| Owner role | Engineering Standards Maintainers |
| Canary repository | `AIAllTheThingz/Engineering-Standards-Canary` |
| Validated standards SHA | `de32b77e2043f5336a54b92ab9ed867abe93ba7e` |
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

The corrected cross-repository proof used canary commit `a7671ec1b8b702fc7703e49a7819bbffffd04fc3` and Engineering Standards functional candidate `de32b77e2043f5336a54b92ab9ed867abe93ba7e`. Every run uploaded evidence, and each downloaded artifact passed independent verification with `scripts/Test-WorkflowEvidenceArtifact.ps1`. This table validates that functional candidate, not a later metadata-only documentation commit. Release lifecycle records use the same five-scenario contract and bind it to the candidate declared in [Downstream Compatibility](DOWNSTREAM_COMPATIBILITY.md).

| Scenario | Run | Governance job | Artifact ID | Artifact SHA-256 | Result |
| --- | ---: | ---: | ---: | --- | --- |
| Success | `29174960763` | `86602384012` | `8254615849` | `5442a898d2fef5d957b2c982c4c932fe58dad01da3c5b92b3758657f47d7293f` | Passed |
| Controlled failure | `29174961493` | `86602386096` | `8254615773` | `a12f37222cf30c98296e85ebbffb97f8e13bd467ae3d923783163d4141b59e97` | Expected failure verified |
| Governance version mismatch | `29174962200` | `86602384436` | `8254615629` | `1099b349006aaa8ea7801a30cebda46370258622d5cfcef06c792c21ad4df922` | Exact mismatch reason verified |
| Missing required file | `29174962956` | `86602391036` | `8254616287` | `4dd42b75ea3d992cabe0b6c1519753fc17e86eb5cb01eac79f90bfb9fdfd606f` | Exact `SECURITY.md` reason verified |
| Mandatory control disablement | `29174963655` | `86602388751` | `8254616945` | `3a6ba0b648c0adf3fd7a4b0fb7f27ccf526a6e5e0110197c36da755724c6b3ac` | Exact disablement reason verified |

All five manual artifacts record the exact canary head and immutable standards workflow identity above. The version-mismatch and mandatory-disablement artifacts use `BootstrapValidation` and preserve the sanitized exception message; the missing-file artifact preserves the Contract diagnostic identifying `SECURITY.md`.

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

An exception to a mandatory canary scenario or verification requirement must follow the central exception process, remain scoped and time-bounded, and be recorded in release evidence. An exception must not relabel an unrun, failed, or unverifiable external scenario as Passed.

## Limitations

The canary validates the reusable governance contract and its security boundary. It does not exercise consumer builds, tests, deployments, private repositories, GitHub Enterprise Server, repository-specific scanner extensions, or every supported static category. Those concerns remain with caller-owned CI and their applicable adoption evidence.

## Related

- [Adoption Guide](ADOPTION_GUIDE.md)
- [Downstream Configuration](DOWNSTREAM_CONFIGURATION.md)
- [Action Security](ACTION_SECURITY.md)
- [Release Process](RELEASE_PROCESS.md)
- [Troubleshooting](TROUBLESHOOTING.md)
- [Downstream Compatibility](DOWNSTREAM_COMPATIBILITY.md)
