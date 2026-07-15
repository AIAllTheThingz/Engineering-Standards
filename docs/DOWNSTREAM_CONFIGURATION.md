# Configuration Reference

| Status | Active |
| Version | 1.1.0 |
| Owner role | Schema Maintainers |
| Last reviewed | 2026-06-19 |

## Purpose

This reference defines the required configuration files used by downstream repositories: `project-manifest.json` and `governance.config.json`. The manifest describes what the repository is and the config describes which governance controls apply.

Both files are part of the compliance boundary. A pull request that changes either file can alter review obligations, workflow behavior, evidence requirements, and exception handling, so changes MUST be reviewed with the same care as code that affects production.

## File Ownership

Repository owners maintain the manifest and governance configuration. Schema maintainers own the JSON schemas and validators. Reviewers MUST reject configuration changes that make the repository appear lower risk than its actual behavior.

When ownership changes, update the manifest in the same pull request as CODEOWNERS and maintainer documentation. Configuration drift between ownership, documentation, and workflow behavior is a governance finding.

## Manifest Schema

`project-manifest.json` MUST conform to `schemas/project-manifest.schema.json`. It records the repository identity, governance version, risk classification, applicable standards, owners, evidence paths, and exceptions.

The manifest is intentionally concise. It should identify the project clearly without storing secrets, customer data, private endpoints, live account numbers, or operational credentials.

## Manifest Fields

| Field | Required | Meaning | Review expectation |
| --- | --- | --- | --- |
| `schemaVersion` | Yes | Manifest schema version. | Must match a supported schema version. |
| `projectName` | Yes | Human-readable project name. | Must be specific enough for evidence and review. |
| `repository` | Yes | Repository owner/name. | Must match the actual repository. |
| `description` | Yes | System purpose. | Must not be generic filler. |
| `governanceVersion` | Yes | Adopted semantic governance release. | Must be SemVer and must never contain a commit SHA. |
| `governanceCommitSha` | Yes in `1.2.0` | Immutable standards/workflow implementation. | Must be the full 40-character SHA used by the workflow reference. |
| `workflowInterfaceVersion` | Yes in `1.2.0` | Reusable workflow compatibility contract. | Initial supported interface is `1.0.0`; it is independent of the governance release. |
| `repositoryOwnerType` | Yes in `1.2.0` | GitHub repository owner kind. | Use `User` or `Organization` from trusted repository context. |
| `riskClassification` | Yes | Low, Moderate, High, or Critical. | Must reflect data, production, infrastructure, and security impact. |
| `applicableStandards` | Yes | Central agent standard files. | Must include the base standard and relevant technology standards. |
| `owners` | Yes | Legacy strings in `1.0.0`/`1.1.0`; structured typed owners in `1.2.0`. | Current owners require type, stable identifier, responsibility, and escalation. Syntax does not prove access. |
| `standardsConsumption` | Yes in `1.2.0` | `central-reference`, `vendored`, or `local` authority model. | Central-reference repository/SHA values must match trusted workflow context and the SHA must equal `governanceCommitSha`; vendored mode requires an immutable source SHA; vendored and local modes require a bounded local path. |
| `evidence` | Yes | Separate local paths and hosted-workspace declarations in `1.2.0`. | Hosted paths are relative to the workflow evidence workspace, not the caller checkout. |
| `exceptions` | No | Legacy identifiers or structured `1.2.0` records. | Current records must be approved, applicable, scoped, and unexpired. |
| `supportedEvidenceSchemaVersions` | No | Accepted evidence schema versions. | Use during additive migration windows such as `1.0.0` to `1.1.0`. |

## Governance Config Schema

`governance.config.json` MUST conform to `schemas/governance-config.schema.json`. It tells validators where to find required files, which standards apply, which categories to run, and which exceptions or allowlists are active.

The governance config MUST NOT be used to remove mandatory controls silently. If a mandatory control is disabled, the change requires an approved exception and compensating control.

## Governance Config Fields

| Field | Required | Meaning | Review expectation |
| --- | --- | --- | --- |
| `schemaVersion` | Yes | Config schema version. | Must be supported by validators. |
| `manifestPath` | Yes | Path to `project-manifest.json`. | Must resolve within the repository. |
| `governanceVersion` / `governanceCommitSha` | Yes in `1.2.0` | Release and immutable implementation identities. | Must agree with the manifest. |
| `workflowInterfaceVersion` / `workflowProfile` | Yes in `1.2.0` | Interface compatibility and selected execution profile. | Must agree with the manifest and actual workflow. |
| `workflowInterface` | Yes in `1.2.0` | Path, inputs, outputs, job, artifact, and check contract. | Must match interface `1.0.0`. |
| `requiredCheckNames` | Yes in `1.2.0` | Exact branch-protection checks. | Must match the workflow interface and live protection evidence. |
| `evidencePath` | Yes | Evidence directory or root. | Must be written by validation workflows. |
| `requiredDocumentationPaths` | Yes | Required local documents. | Must include README, SECURITY, CONTRIBUTING, and AGENTS. |
| `applicableAgentStandards` | Yes | Central standard paths. | Must align with manifest standards. |
| `additionalForbiddenPatterns` | No | Repository-specific scanner rules. | Must remain empty for central downstream validation until Issue #21 defines the supported model. |
| `reviewedAllowlist` | No | Approved scanner exceptions. | Must remain empty for central downstream validation until Issue #21 defines the supported model. |
| `schemaSupport` | No | Supported evidence schema versions and compatibility window. | Use to declare additive migration support explicitly. |
| `workflowInterfaces` / `branchProtectionCheckName` | Legacy | Older unstructured compatibility declarations. | Migrate to `workflowInterface` and `requiredCheckNames` in `1.2.0`. |
| `ownership.requiredCodeownerPaths` | No | Rooted literal CODEOWNERS paths requiring effective ownership. | List only repository paths that exist and need explicit protection; omit the property to require generic default `*` coverage without central-repository path assumptions. |
| `controls` | Yes | Control toggles. | Disabled mandatory controls require `GOV-*` exceptions. |
| `exceptions` | No | Active governance exceptions. | Must match exception records and evidence. |

## Allowed Values

Risk classifications are `Low`, `Moderate`, `High`, and `Critical`. Data classifications are defined in `governance/RISK_CLASSIFICATION.md` and the organization contract. Status values in governance evidence are `Passed`, `Failed`, `Blocked`, `NotRun`, and `NotApplicable`.

Do not introduce new enum values in downstream repositories. If a new value is needed, change the central schema, add fixtures, update validators, and release a new governance version.

## Path Rules

Paths are repository-relative and MUST NOT escape the repository root. Absolute paths, traversal segments, and caller/standards workspace confusion are rejected. The caller checkout MUST contain no symbolic links, junctions, or other reparse points, including links whose targets remain inside the checkout. This deliberate fail-closed policy prevents workspace-boundary and validator-confusion attacks. Validators treat missing required files as failures. Paths should use forward slashes in JSON examples for consistency across operating systems.

`ownership.requiredCodeownerPaths` uses rooted CODEOWNERS literals such as `/src/` or `/SECURITY.md`; the leading slash anchors the pattern at the repository root and is not an operating-system absolute path. Entries must be unique using exact case and nonempty. Drive paths, UNC paths, single-dot or trailing-dot segments, traversal, wildcards, comments, whitespace, and placeholder segments are rejected. A configured path that does not exist with exact casing fails repository health. Values ending in `/` must identify directories, while values without `/` must identify files. For a configured directory, repository health evaluates the effective owners of every concrete contained file and does not discover outside that explicitly configured directory; an empty directory falls back to its configured base path. Omitting `ownership` is backward compatible: the validator still requires a valid default `*` CODEOWNERS rule, but it does not assume that downstream repositories contain Engineering Standards directories.

For every configured path, repository health evaluates rules in file order and validates the owners on the last matching rule. It supports `*`, rooted or unrooted literal file and directory rules, and simple `*` or `**` globs. If a later unsupported pattern could change the ownership decision, validation fails closed with the pattern and line number. This structural check does not prove that an identity exists or has write access; that requires trusted live GitHub evidence.

Evidence paths should be stable. In `1.2.0`, `evidence.local` resolves beneath
the caller repository, while `evidence.hosted` resolves beneath the workflow's
separate evidence workspace. A hosted path is not required to exist in the
caller checkout. Absolute paths, traversal, and local/hosted workspace confusion
fail validation.

## Standards consumption

`central-reference` executes files from the immutable central checkout and
requires `sourceRepository` plus `sourceCommitSha`. `vendored` records those
source fields plus `localPath` and requires drift review. `local` makes the
bounded `localPath` authoritative and omits central source fields. Missing
sources fail closed; validators never silently switch modes.

In `vendored` and `local` modes, `localPath` names an authoritative subtree of
the caller repository. Every caller-root-relative `applicableStandards` entry
must resolve beneath that subtree as a physical regular file. Empty or partial
trees, directories presented as standards, traversal, links, junctions, and
reparse points fail closed. A matching file in the trusted central checkout is
not a fallback for missing local or vendored content.

## Workflow Configuration

Downstream repositories call `AIAllTheThingz/Engineering-Standards/.github/workflows/governance-ci-reusable.yml@<full-commit-sha>`. Supported inputs are:

| Input | Default | Meaning |
| --- | --- | --- |
| `project-path` | `.` | Caller-repository-relative path to validate. Absolute paths, traversal, link hops, and workspace escapes are invalid. |
| `governance-version` | `1.1.0` | Expected governance version; it must match `project-manifest.json`. |
| `artifact-retention-days` | `30` | Evidence artifact retention period. |
| `controlled-failure-test` | `false` | Repository-owned proof path that records a failed check, uploads evidence, and then fails enforcement. |

Outputs are `evidence-path` and `artifact-name`. Root files under `workflows/` are distribution templates and must not be referenced as cross-repository reusable workflows.

The reusable workflow checks out caller content under `caller/`, trusted central tooling under `standards/`, and reports under `evidence/`. The standards checkout is selected from GitHub's immutable `job.workflow_repository` and `job.workflow_sha` context; callers cannot supply either value. Evidence keeps the caller repository and commit as `repository`, `commitSha`, and `validatedCommitSha`, and records the standards workflow repository/SHA separately.

`Contract` is mandatory for all downstream callers. `MarkdownLinks`, `DocumentationCompleteness`, `ForbiddenPatterns`, and `CodexSkills` are supported central static categories when present in validated configuration. `CodexSkills` treats caller skill content as inert data and never executes skill scripts, tools, dependencies, or model evaluations. `AgentStandards`, `JsonSchemas`, `YamlSyntax`, `WorkflowArchitecture`, `RepositoryHealth`, `Evidence`, `Examples`, `Pester`, `PSScriptAnalyzer`, and `PowerShellParser` are maintainer-only and fail downstream semantic validation; run caller-owned builds and tests in separate caller CI jobs. For schema version `1.2.0`, a nonempty `controls.mandatoryControlsDisabled` collection requires `Contract` validation and proceeds only when GCS010 and GCS011 validate an active structured exception for the exact control. Explicit category overrides cannot omit `Contract`. Legacy schema versions `1.0.0` and `1.1.0` remain fail-closed for every nonempty collection.

The central downstream workflow does not apply repository-provided `additionalForbiddenPatterns` or `reviewedAllowlist`. Both arrays MUST be empty; a nonempty value fails with the unsupported field name instead of being silently ignored.

The public downstream canary uses the smallest supported profile: `Contract` as its only validation category, empty repository-provided scanner arrays, and no disabled mandatory controls. Its negative fixtures separately prove version mismatch, required-file enforcement, and mandatory-control disablement. See [Downstream Governance Canary](DOWNSTREAM_CANARY.md); the canary profile does not remove additional controls applicable to a real consumer.

Existing callers must remove `run-examples`, `run-pester`, and `run-documentation-validation`. Those compatibility inputs were mandatory-true and misleading; removal is an intentional interface correction. GitHub Enterprise Server is unsupported because it does not provide the immutable `job.workflow_*` identity properties and the workflow does not use an unsafe fallback.

## Allowlist Rules

Allowlists are temporary review decisions, not permanent suppressions. Every allowlist entry MUST include a rule id or pattern, path scope, owner, explanation, approval reference, and expiration date.

Allowlists MUST be narrow. A repository-wide allowlist for a dangerous pattern requires explicit maintainer approval and must include a remediation plan.

## Exception Rules

In schema `1.2.0`, exceptions are structured records containing identifier,
status, scope, owner, approver, approval date, expiration, affected control,
compensating controls, remediation plan, and evidence reference. A disabled
mandatory control must reference an approved, unexpired record for that exact
control. Older schema versions retain identifier strings for compatibility.

Expired exceptions are invalid. A pull request that extends an exception must explain why remediation has not occurred and what changed in the risk assessment.

## Validation

Validate configuration locally:

```powershell
pwsh -NoProfile -File actions/validate-contract/Invoke-ContractValidation.ps1 -Path .
pwsh -NoProfile -File scripts/Test-JsonSchemas.ps1 -Path .
```

For complete repository validation, run:

```powershell
$RepositoryOwnerType = 'Organization' # Replace only with GitHub's verified User or Organization owner type.
pwsh -NoProfile -File scripts/Invoke-GovernanceValidation.ps1 -Path . -RepositoryOwnerType $RepositoryOwnerType
```

The aggregate resolves the `downstream` profile from the validated repository
identity. `Contract` is mandatory and cannot be filtered; supported configured
static categories are added without executing repository-owned code. An
explicit `-Category` value filters optional downstream categories only.

The aggregate validator uses `RepositoryOwnerType` value `Unknown` by default
and does not infer ownership from the repository name. Schema `1.2.0` requires
the hosted reusable workflow to supply exactly `User` or `Organization` from
trusted `github.event.repository.owner.type` metadata and fails closed when that
metadata is absent or unsupported. Legacy `1.0.0` and `1.1.0` contracts may
retain `Unknown` for backward compatibility. A trusted local caller may pass a
verified value explicitly, for example `-RepositoryOwnerType User`. The value
is forwarded to Contract and repository-health validation; other values and
case variants fail parameter validation.

## Evidence

Configuration changes require evidence that schema validation passed, contract validation passed, and affected examples still validate. If the change affects required documentation or agent standards, include documentation completeness evidence.

If a configuration change is reviewed manually, evidence must identify the reviewer, date, files reviewed, and any limitations.

## Failure Behavior

If schema validation fails, the configuration is invalid and MUST NOT merge. If contract validation fails, correct the path, field, standard reference, or exception record before requesting review.

If a downstream repository cannot satisfy a required field because the schema does not model its situation, open a schema change in the central repository rather than inventing unsupported fields locally.

## Related

- `schemas/project-manifest.schema.json`
- `schemas/governance-config.schema.json`
- `governance/ORGANIZATION_CONTRACT.md`
- `governance/EXCEPTION_PROCESS.md`
- `docs/DOWNSTREAM_CANARY.md`
- `docs/ADOPTION_GUIDE.md`
- `docs/TROUBLESHOOTING.md`
