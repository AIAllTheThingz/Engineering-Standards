# Downstream Governance Canary

| Field | Value |
| --- | --- |
| Status | Active |
| Governance version | 1.2.1 |
| Owner role | Engineering Standards Maintainers |
| Canary repository | `AIAllTheThingz/Engineering-Standards-Canary` |
| Validated standards SHA | `7d15ec8be6d8c3cdca35061728901584437e4a50` |
| Last verified | 2026-08-15 |

## Purpose

The public downstream canary proves that the reusable governance workflow operates across a real repository boundary without copying central `scripts/`, `actions/`, `tests/`, or `examples/`. It is a release gate for reusable-workflow changes, not a template repository and not a substitute for each consumer's application-specific CI.

The canary is intentionally non-production, contains no secrets, and uses only the `Contract` validation category. Its manifest classifies it as an `integration` project with `Moderate` risk and `Public` data. Candidate release proof uses exact full-SHA workflow pins; PostRelease proof intentionally invokes the protected published semantic ref so annotated-tag identity is exercised across the real repository boundary.

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

The latest complete proof is the published `v1.2.1` PostRelease matrix from canary caller commit `03979bdd46e36593faf044e2206e24c7ed485d62`. All five isolated workflows invoked `AIAllTheThingz/Engineering-Standards/.github/workflows/governance-ci-reusable.yml@v1.2.1`. GitHub resolved that ref to annotated tag object `aea6330ee3d51b3f5bb55031d878ef302ba1dbca`, and the workflow identity resolver independently peeled and validated standards commit `7d15ec8be6d8c3cdca35061728901584437e4a50`.

| Scenario | Run | Artifact ID | Artifact SHA-256 | Result |
| --- | ---: | ---: | --- | --- |
| Success | `31853248739` | `9238210172` | `75da2fdf61b1c56b7c306eaf16fbb8d8b985f7ef41ee13d814dbd3b3d5c67d56` | Passed |
| Controlled failure | `31853248720` | `9238209524` | `595669f03ba1031ae5c693d2341b68545ef4d51e8dd6b0e3815d8226357db7a5` | Expected failure verified |
| Governance version mismatch | `31853248752` | `9238207090` | `586353be72b9b1d60d22e5225ae67c4e85f780286b61ad9644c43f2a820dab50` | Exact mismatch reason verified |
| Missing required file | `31853248718` | `9238208902` | `fcfd7c9b44a476e7b7d42a2eecabd92b013375d00001a75f3246fc01d882281e` | Exact `SECURITY.md` reason verified |
| Mandatory control disablement | `31853248799` | `9238211637` | `856b94df35b8d9921bd0aa3cc0ce6de12a2b2ae6f18e6e66f8be9c5a078ed3ca` | Exact disablement reason verified |

All five artifacts were independently downloaded and their ZIP SHA-256 values matched GitHub. Every `workflow-identity.json` records `referenceKind: AnnotatedTag`, workflow object `aea6330ee3d51b3f5bb55031d878ef302ba1dbca`, ref `refs/tags/v1.2.1`, and peeled standards commit `7d15ec8be6d8c3cdca35061728901584437e4a50`. Archive safety inspection found no unsafe paths, symlinks, runner/workspace absolute paths, PAT/API-key patterns, Windows absolute paths, or private-key markers.

This supersedes the older governance-1.1 canary baseline as the current central governance release proof. Historical runs remain valid only for the exact commits and artifacts they name.

## Release Gate

Before approving a reusable-workflow release or rotating the authoritative self-CI pin, maintainers MUST:

1. Update all five canary calls to the exact candidate commit SHA in one reviewable change.
2. Confirm the canary retains least privilege, immutable third-party action pins, no secrets or environments, and the prohibited-directory shape check.
3. Run all five scenarios against the exact candidate SHA.
4. Confirm success passes and each negative scenario fails for only its intended reason.
5. Download every evidence artifact into a temporary directory and independently verify repository, caller commit, branch, run identity, conclusion, and hash.
6. Record the runs, artifact IDs, hashes, candidate SHA, canary commit, and reviewer decision in the release pull request.
7. After authorized publication, rerun the full five-scenario matrix through the immutable published `v<version>` ref and verify the workflow tag-object identity, annotated reference kind, peeled standards commit, conclusions, artifacts, and hashes before PostRelease can pass.

A missing run, unexpected conclusion, absent artifact, verification failure, mutable pin, or unexplained difference blocks release. Self-CI success in this repository does not replace the external canary because it does not test the cross-repository caller boundary.

## Operations And Ownership

Engineering Standards maintainers own canary pin rotation, scenario maintenance, artifact verification, and failure triage. Canary changes MUST remain minimal and must not become a second copy of central governance implementation. Contract changes require synchronized updates to the valid root project and the smallest relevant fixture.

Artifacts are evidence of a particular run, caller commit, and standards SHA; they are not evergreen certification. Do not commit downloaded artifacts to either repository or copy their metadata into `evidence/latest-verified-run.json`, which is reserved for this repository's authoritative hosted verification record.

## Failure And Rollback

When a candidate fails unexpectedly, leave the candidate unapproved, preserve the run and artifact references, and identify whether the defect is in the reusable workflow, caller contract, fixture expectation, or GitHub execution environment. Correct the smallest owning change and rerun all five scenarios; do not relabel an unexpected result as an expected failure.

If a released workflow regresses downstream behavior, advise consumers to retain or restore the last independently verified full SHA while a focused corrective change is reviewed. Do not force-push canary history, rewrite release tags, weaken a scenario, or rotate the authoritative pin until the external proof is clean.

An exception to a mandatory canary scenario or verification requirement must follow the central exception process, remain scoped and time-bounded, and be recorded in release evidence. An exception must not relabel an unrun, failed, or unverifiable external scenario as Passed.

## Limitations

The governance canary validates the reusable static contract and its security boundary. A Python functional-workflow release additionally requires a clean governed Python caller pinned to the exact candidate SHA and hosted proof for static analysis, pytest, mypy, audit, build, archive inspection, isolated wheel installation, SBOM, completion evidence, and caller-configuration resistance.

A Bash functional-workflow release additionally requires the separate
`bash-functional` canary caller pinned to the exact candidate SHA. Its success
scenario must prove GNU Bash syntax, ShellCheck, shfmt, Bats, exact tool
provenance, SBOM, completion evidence, and a sanitized artifact. The independent
manual scenarios cover ShellCheck failure, formatting failure, Bats failure,
and a caller-configuration bypass attempt that the trusted baseline neutralizes.
Only one scenario may be selected per dispatch, every intended negative
scenario must fail for its named functional phase after evidence upload, and no
scenario may add secrets, environments, write permission, copied central
implementation, or production behavior. Environment, path-shadow, link,
special-file, archive, timeout, and evidence attacks remain mandatory central
regression cases.

Neither functional canary exercises deployments, private repositories, GitHub
Enterprise Server, or production integrations.

## Related

- [Adoption Guide](ADOPTION_GUIDE.md)
- [Downstream Configuration](DOWNSTREAM_CONFIGURATION.md)
- [Action Security](ACTION_SECURITY.md)
- [Release Process](RELEASE_PROCESS.md)
- [Troubleshooting](TROUBLESHOOTING.md)
- [Downstream Compatibility](DOWNSTREAM_COMPATIBILITY.md)
Reusable-workflow candidates that change Python or Bash validation must include
a canary caller containing clean maintained source and controlled static-failure
cases. Verify that caller configuration cannot disable the baseline, caller code
does not execute, the final exact candidate SHA is pinned, and downloaded
artifacts contain both language reports plus Ruff and ShellCheck dependency and
SBOM records.
