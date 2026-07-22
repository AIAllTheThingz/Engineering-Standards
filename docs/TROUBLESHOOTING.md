# Troubleshooting

| Status | Active |
| Version | 1.0.0 |
| Owner role | Support Maintainers |
| Last reviewed | 2026-07-15 |

## Purpose

This guide helps maintainers diagnose validation, evidence, workflow, and adoption failures. Troubleshooting must preserve evidence integrity: do not hide failures, rewrite results as Passed, or bypass required controls without an approved exception.

When a failure reveals a real governance gap, fix the gap. When a failure is caused by a validator defect, preserve the failing evidence and open a central repository fix.

## Triage Order

Start by identifying the failing category, command, working directory, exit code, and affected file. Then determine whether the failure is policy, schema, workflow, environment, tooling, or evidence related.

The authoritative aggregate report is `governance-validation.json`. Inspect
`validationProfile`, `mandatoryCategories`, `selectedCategories`, and `results`
before rerunning a child validator. A requested `-Category` list cannot explain
a missing mandatory category; if one is absent, treat it as a registry or
planning defect.

Do not change multiple controls at once during diagnosis. Small fixes make evidence easier to trust.

## Contract Validation Failures

Contract validation usually fails because `project-manifest.json` or `governance.config.json` is missing, malformed, points to nonexistent paths, references standards that do not exist, or contains expired exceptions.

Fix the manifest and config first. If the repository type is unusual, update the central schema rather than adding unsupported local fields.

For `GCS001` through `GCS013`, compare the manifest and configuration as one
contract. Common causes are a repository-name mismatch, release/SHA conflation,
owner-type mismatch, missing technology standard, incompatible workflow profile,
declared categories that are not executed, local/hosted evidence confusion,
inactive exception, required-check drift, or an uncontrolled schema `$id`.

## Schema Validation Failures

Schema failures mean the JSON does not match the declared contract. Common causes include missing required fields, invalid enum values, additional properties, incorrect path structure, or evidence statuses that contradict the schema.

Run:

```powershell
pwsh -NoProfile -File scripts/Test-JsonSchemas.ps1 -Path .
```

If a fixture fails after a schema change, update both valid and invalid fixtures intentionally.

If a repository still emits `1.0.0` evidence while the central generators now emit `1.1.0`, confirm that the validator compatibility window still accepts both versions. Unsupported future-major versions must fail rather than silently downgrade.

## Documentation Completeness Failures

Documentation completeness fails when required documents are too shallow, missing required concepts, contain empty headings, include unresolved placeholders outside templates, or use fake validation commands.

Author the missing content. Do not pad documents with repeated boilerplate. The document should explain requirements, validation, evidence, exception handling, failure behavior, and related references.

## Markdown Link Failures

Markdown link failures usually come from renamed files, deleted documents, or relative paths that no longer resolve. Fix the link target or remove the stale reference.

Run:

```powershell
pwsh -NoProfile -File scripts/Test-MarkdownLinks.ps1 -Path .
```

External links may be reviewed manually if the repository does not enable external-link validation.

## Evidence Validation Failures

Evidence validation fails when completion evidence is missing required fields, reports overall Passed while tests are Failed, Blocked, or NotRun, omits required command metadata, references missing artifacts, or contains contradictory approval information. The completion status vocabulary is `Passed`, `Failed`, `Blocked`, `NotRun`, and `NotApplicable`; framework-level skipped-test counts are recorded inside test details.

Regenerate completion evidence after validation runs. Never edit evidence to claim a run occurred when it did not.

## Codex Skill Validation Failures

Run `pwsh -NoProfile -File scripts/Test-CodexSkills.ps1 -Path . -OutputJson .tmp/codex-skills-validation.json` and use the stable `SKL001` through `SKL019` rule ID. Fix the bounded structural defect; do not execute a skill script to prove it is safe.

Safe YAML parsing failures require Python and the reviewed PyYAML dependency. Reference failures require a real in-bound file beneath the skill or approved authority path. Prompt-corpus structural success may coexist with `modelEvaluationStatus: NotRun`; this is honest and must not be changed to `Passed` without an approved controlled model evaluation. Candidate CI output must remain in the external runner temporary directory, with read-only permissions and no secrets.

## Forbidden Pattern Findings

Forbidden-pattern findings may indicate exposed secrets, unsafe shell behavior, risky workflow triggers, or documented examples of dangerous constructs. Treat blocking findings as security issues until proven otherwise.

If the finding is documentation or a known false positive, use a narrow reviewed allowlist with owner, reason, path, rule id, and expiration. Prefer rewriting examples to avoid dangerous-looking patterns.

## Repository Health Failures

Repository health failures identify missing required files, invalid manifest or config, absent tests, missing action metadata, incomplete docs, or CODEOWNERS concerns. Fix missing files before tuning validators.

CODEOWNERS warnings often mean placeholders or organization-specific teams need confirmation. Resolve them before branch protection enforcement.

## Workflow Failures

Workflow failures often come from wrong reusable workflow paths, branch filters that do not include the active branch, missing permissions, unpinned actions, or artifact upload paths that are not created on failure.

Confirm that downstream repositories call:

```yaml
uses: AIAllTheThingz/Engineering-Standards/.github/workflows/governance-ci-reusable.yml@<pinned-commit-sha>
```

Entry workflows should call reusable workflows. Reusable workflows should not call entry workflows.

Cross-repository runs should show sibling `caller`, `standards`, and `evidence` workspaces. A missing central script under `caller/` is not an adoption requirement; validators must load from `standards/`. Failures mentioning `job.workflow_sha` or `job.workflow_repository` usually mean the run is on GitHub Enterprise Server, which is unsupported because those immutable identity properties are unavailable and no safe fallback exists.

If `project-path` fails validation, use a normal relative directory below the caller repository. Do not use absolute paths or `..`. Remove every symbolic link, junction, and reparse point from caller content, including links to internal files or directories and links outside the selected `project-path`. This is an intentional fail-closed defense against workspace-boundary and validator-confusion attacks, not only an escape check. If a caller still passes `run-examples`, `run-pester`, or `run-documentation-validation`, remove those retired inputs and keep project-specific execution in separate caller-owned jobs.

If validation names `additionalForbiddenPatterns` or `reviewedAllowlist` as unsupported, leave that array empty for the central downstream workflow. These repository-provided scanner extensions are rejected rather than silently ignored until the reviewed configuration model in Issue #21 is implemented.

## Validator Dependency and Runtime Failures

For functional Bash failures, first run the governed example from Ubuntu 24.04
with GNU Bash 5.2, PowerShell 7, and Python 3.12:

```powershell
pwsh -NoProfile -File examples/bash-project/tools/Test-Example.ps1
```

Use its `-ToolCache <path> -Offline` mode only after the exact artifacts in
`bash-toolchain.lock.json` have been cached and verified. A missing artifact or
unavailable approved source is `Blocked`; a malformed lock, digest mismatch,
unsafe archive entry, link, destination reuse, or actual-version mismatch is
`Failed`. Do not substitute PATH-provided ShellCheck, shfmt, or Bats and do not
update a digest merely to match downloaded content.

If hosted Bash validation rejects a project before Bats runs, inspect the
syntax, ShellCheck, formatting, filesystem, and toolchain phase records. Remove
symbolic or hard links, FIFOs, sockets, devices, traversal, startup variables,
caller `.shellcheckrc` or shfmt configuration, and executable shadows. Test
failures are valid only after all non-executing gates passed. Download the
artifact through the GitHub Actions API and preserve both the original ZIP and
the independent artifact metadata JSON. Run
`scripts/Test-BashWorkflowEvidenceArtifact.ps1` with `-ZipPath`,
`-ArtifactMetadataPath`, the exact repository, commit, branch, run ID, artifact
name and ID, expected conclusion, and controlled-failure phase before making a
hosted success or expected-failure claim.

If the hosted toolchain bootstrap is `Blocked` or `Failed`, the workflow
normalizes and uploads its bootstrap record under the usual Bash artifact name
before final enforcement fails the job. Completion and functional phase records
are intentionally absent because those phases did not run.

The trusted driver requires Linux Landlock ABI 1 or newer for local filesystem
isolation. Hosted execution requires ABI 4 or newer so TCP connect and bind can
also be denied. An unsupported kernel is `Blocked`; do not disable the sandbox
or describe the TCP restriction as complete network isolation. Timeout cleanup
uses both a process group and a child subreaper, so a surviving detached caller
process is a validation failure.

Run the dependency validator before changing a workflow or installing a
replacement package:

```powershell
pwsh -NoProfile -File scripts/Test-ValidatorDependencies.ps1 -Path . -OutputJson .tmp/validator-dependencies.json
```

`DEP001` through `DEP010` identify malformed or drifting lock, runtime, source,
action, package, and Python-requirement declarations. `DEP011` means an exact
package is unavailable; offline execution is `Blocked` until the reviewed cache
is restored. `DEP012` means content is mismatched or tampered and is always
`Failed`; delete the isolated cache copy, independently obtain the official
artifact, verify the reviewed digest, and investigate unexpected content before
rerunning. Do not update a digest merely to match what a package source returned.

Compare `runtime-bootstrap.json` and `dependencies.json` with
`.github/dependencies/validator-dependencies.psd1`. A setup-action success does
not override an actual-version mismatch. An unavailable PyPI, PSGallery, GitHub
release, or setup-action source remains `Blocked`, never an implied pass. Use the
offline procedure in [Validator Dependency Model](VALIDATOR_DEPENDENCIES.md)
when a reviewed cache is available. If the CycloneDX file is missing, the
environment evidence is incomplete and release approval remains blocked.

For final evidence verification, trigger a success run with:

```powershell
gh workflow run "Governance CI" --ref master -f controlled-failure-test=false
```

Trigger a controlled failure run with:

```powershell
gh workflow run "Governance CI" --ref master -f controlled-failure-test=true
```

Download evidence into a temporary directory and verify it without extracting over the repository:

```powershell
gh run download <run-id> --name governance-evidence-<run-id> --dir <safe-temp-dir>
pwsh -NoProfile -File scripts/Test-WorkflowEvidenceArtifact.ps1 -ArtifactPath <safe-temp-dir> -ExpectedRepository AIAllTheThingz/Engineering-Standards -ExpectedCommitSha <sha> -ExpectedBranch master -ExpectedRunId <run-id> -ExpectedConclusion success
```

`evidence/latest-verified-run.json` is metadata for the most recent independently verified success artifact and controlled-failure run. It is not a copy of the artifact.

### External Canary Failures

For a reusable-workflow candidate, use the public canary procedure in [Downstream Governance Canary](DOWNSTREAM_CANARY.md). Confirm that all five jobs use the same exact candidate SHA and that the repository-shape job succeeds. A success-scenario failure is always blocking. A negative scenario is valid only when it fails for its named reason after uploading evidence; an unrelated setup, checkout, syntax, permissions, or artifact failure is not a successful negative test.

Download each artifact separately and verify its caller repository, exact caller commit or documented pull-request merge commit, branch, run ID, conclusion, and standards workflow identity. If verification fails, preserve the run reference, correct the owning workflow or fixture, and rerun all five scenarios. Do not rotate pins, weaken fixtures, or treat self-CI as a substitute.

### Release Lifecycle Findings

Run the exact requested gate and keep its JSON report:

```powershell
pwsh -NoProfile -File scripts/Test-ReleaseLifecycle.ps1 -Path . -EvidencePath <release-lifecycle-record.json> -Stage PreRelease -OutputJson .tmp/release-lifecycle-result.json
```

`RLG000`-`RLG004` identify unsafe paths, parse defects, or dishonest status/reason pairs. `RLG010`-`RLG014` identify missing artifact identity, digest, download, or independent verification. `RLG020` means one observation targets a different commit; replace stale Evidence and reapprove the final head rather than editing the SHA to look consistent.

`RLG030`-`RLG038` identify incomplete canary coverage or an unexpected scenario conclusion. All five scenarios must target the same exact candidate and preserve their individual artifacts. `RLG040`-`RLG046` indicate that release metadata disagrees with `governance/downstream-compatibility.json`; update the owning schema, migration guidance, or matrix on the candidate branch.

`RLG050`-`RLG091` cover top-level binding and pre-release controls, including release-note hashes, mandatory validation, hosted runs, approvals, and protection observations. `RLG100`-`RLG110` block publication for tag, GitHub Release, note, or provenance defects. `RLG120`-`RLG126` block post-release completion when re-fetch, canary, regression follow-up, post-release record, or compatibility updates are absent. `RLG130`-`RLG132` apply only to Live mode and require the recorded candidate to equal a clean Git HEAD.

A `NotRun` or `Blocked` external check is useful honest Evidence but cannot pass a release gate. Perform the missing action or retain the non-passing state and reason. Do not use a synthetic fixture as release proof, rewrite a tag to repair a mismatch, or publish while the Publication gate fails.

## Pester Failures

Pester failures indicate validator behavior changed or a regression was introduced. Read the failing test name before changing implementation. If a test is obsolete because governance policy changed, update the policy, validator, and test together.

Run:

```powershell
pwsh -NoProfile -Command "Invoke-Pester -Path tests -Output Detailed"
```

Workflow artifacts include sanitized Pester detail in `evidence/pester-details.json`. If that file contains runner, user-profile, repository-root, or temporary absolute paths, fix `scripts/Convert-PesterResultToSanitizedJson.ps1` before trusting the artifact.

If forbidden-pattern output appears to recursively report old scanner findings, confirm the scan excluded generated evidence. Use `-IncludeGeneratedEvidence` only when intentionally diagnosing evidence output.

## YAML Parsing Gaps

If local YAML tooling is unavailable, record YAML validation as `NotRun` rather than Passed. GitHub Actions will still parse workflows remotely, but local evidence must accurately state what was and was not checked.

Install a supported YAML parser or add a validator before making YAML syntax claims in completion evidence.

## Branch Protection Issues

If required checks do not appear in branch protection settings, first run the workflow on the target branch so GitHub creates the check name. Then configure the exact check name.

If a repository changed from `master` to `main`, update workflow branch filters, branch protection rules, documentation, and adoption evidence together.

If the GitHub API returns `404 Branch not protected`, treat that as the observed current state. Do not infer protection from local docs, required workflow files, or CODEOWNERS alone.

## Template Issues

For pull-request governance failures, use the reported `PRG001`-`PRG016` identifiers and [Pull Request Body Governance](PR_BODY_GOVERNANCE.md). Edit the existing body to replace placeholders, select one change type, add exact statuses and evidence, or resolve path contradictions. A `Blocked` PRG016 result means metadata or changed-file retrieval was incomplete and cannot pass.

Templates may contain placeholders inside `templates/`, but generated repository files must replace them. If documentation completeness fails after copying a template, fill in repository-specific details instead of suppressing the validator.

Issue and pull request templates should request sanitized evidence. Do not ask users to paste secrets, production tokens, private keys, or customer data.

## Exception Issues

Expired exceptions fail validation or review. Renewing an exception requires updated risk assessment, owner approval, new expiration, and evidence of compensating controls.

An exception cannot approve false evidence or known secret exposure.

## Recovery Steps

After fixing a failure, rerun the smallest relevant validator, then run aggregate validation. Regenerate completion evidence only after the final validation run.

```powershell
pwsh -NoProfile -File scripts/Invoke-GovernanceValidation.ps1 -Path . -RepositoryOwnerType User
```

An aggregate process exit of `1` is expected for overall `Failed`, `Blocked`,
or `NotRun`. Install a missing prerequisite reported with policy exit code `3`;
do not remove that category from the command.

If a central bug blocks many downstream repositories, open an emergency fix in this repository, document affected versions, and publish guidance.

## Evidence

Troubleshooting evidence should include failing command, exit code, logs with secrets redacted, changed files, rerun command, final result, and any manual reviewer notes.

When a tool was unavailable, include runtime context and mark the status honestly as `NotRun` or `Blocked`.

## Python Functional Validation

Use exact CPython 3.12.11 and install `requirements-ci.lock` with
`--only-binary=:all: --require-hashes --no-deps`. A missing or hash-mismatched
artifact is `Blocked`; a pytest, mypy, vulnerability, build, archive, install,
or smoke-test defect is `Failed`. Advisory-service or network unavailability
must remain `Blocked`, never Passed. Inspect the individual `python-*.json`
reports and `python-project-sbom.cdx.json` before retrying. Caller pytest/mypy/
Ruff configuration is intentionally ignored by the trusted baseline.

## Related

- `docs/ADOPTION_GUIDE.md`
- `docs/DOWNSTREAM_CONFIGURATION.md`
- `docs/BRANCH_PROTECTION.md`
- `docs/ACTION_SECURITY.md`
- `docs/DOWNSTREAM_CANARY.md`
- `docs/DOWNSTREAM_COMPATIBILITY.md`
- `docs/VALIDATOR_DEPENDENCIES.md`
- `governance/COMPLETION_EVIDENCE.md`
- `governance/EXCEPTION_PROCESS.md`
## Python Or Bash Static Validation Is Blocked

Confirm dependency bootstrap completed and exported
`VALIDATOR_RUFF_PATH`, `VALIDATOR_SHELLCHECK_PATH`,
`VALIDATOR_PYTHON_PATH`, and `VALIDATOR_BASH_PATH`. Do not substitute an ambient
or caller-local executable. In offline mode, populate the cache with the exact
filenames in `.github/dependencies/validator-dependencies.psd1`. Exit `3` means
the trusted artifact or runtime was unavailable; exit `1` means malformed lock,
tamper/hash mismatch, unsafe archive content, wrong installed version, timeout,
or a static finding. Review `dependencies.json`,
`python-static-analysis.json`, and `bash-static-analysis.json` before retrying.
