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
| `governanceVersion` | Yes | Adopted standards version. | Must identify the central standards version or SHA. |
| `riskClassification` | Yes | Low, Moderate, High, or Critical. | Must reflect data, production, infrastructure, and security impact. |
| `applicableStandards` | Yes | Central agent standard files. | Must include the base standard and relevant technology standards. |
| `owners` | Yes | Accountable maintainers. | Must be real owners, not unowned aliases. |
| `evidence` | Yes | Evidence file paths. | Must match generated evidence artifacts. |
| `exceptions` | No | Approved `GOV-*` exceptions. | Must be current, scoped, and unexpired. |
| `workflowInterfaceVersion` | No | Workflow interface version expected by the repository. | Use when downstream automation binds to a specific reusable workflow contract. |
| `supportedEvidenceSchemaVersions` | No | Accepted evidence schema versions. | Use during additive migration windows such as `1.0.0` to `1.1.0`. |

## Governance Config Schema

`governance.config.json` MUST conform to `schemas/governance-config.schema.json`. It tells validators where to find required files, which standards apply, which categories to run, and which exceptions or allowlists are active.

The governance config MUST NOT be used to remove mandatory controls silently. If a mandatory control is disabled, the change requires an approved exception and compensating control.

## Governance Config Fields

| Field | Required | Meaning | Review expectation |
| --- | --- | --- | --- |
| `schemaVersion` | Yes | Config schema version. | Must be supported by validators. |
| `manifestPath` | Yes | Path to `project-manifest.json`. | Must resolve within the repository. |
| `evidencePath` | Yes | Evidence directory or root. | Must be written by validation workflows. |
| `requiredDocumentationPaths` | Yes | Required local documents. | Must include README, SECURITY, CONTRIBUTING, and AGENTS. |
| `applicableAgentStandards` | Yes | Central standard paths. | Must align with manifest standards. |
| `additionalForbiddenPatterns` | No | Repository-specific scanner rules. | Must remain empty for central downstream validation until Issue #21 defines the supported model. |
| `reviewedAllowlist` | No | Approved scanner exceptions. | Must remain empty for central downstream validation until Issue #21 defines the supported model. |
| `schemaSupport` | No | Supported evidence schema versions and compatibility window. | Use to declare additive migration support explicitly. |
| `workflowInterfaces` | No | Named workflow interfaces used by the repository. | Keep aligned with reusable workflow consumers. |
| `branchProtectionCheckName` | No | Exact required GitHub check name. | Use the exact check string after it exists in GitHub. |
| `controls` | Yes | Control toggles. | Disabled mandatory controls require `GOV-*` exceptions. |
| `exceptions` | No | Active governance exceptions. | Must match exception records and evidence. |

## Allowed Values

Risk classifications are `Low`, `Moderate`, `High`, and `Critical`. Data classifications are defined in `governance/RISK_CLASSIFICATION.md` and the organization contract. Status values in governance evidence are `Passed`, `Failed`, `Blocked`, `NotRun`, and `NotApplicable`.

Do not introduce new enum values in downstream repositories. If a new value is needed, change the central schema, add fixtures, update validators, and release a new governance version.

## Path Rules

Paths are repository-relative and MUST NOT escape the repository root. Absolute paths, traversal segments, and caller/standards workspace confusion are rejected. The caller checkout MUST contain no symbolic links, junctions, or other reparse points, including links whose targets remain inside the checkout. This deliberate fail-closed policy prevents workspace-boundary and validator-confusion attacks. Validators treat missing required files as failures. Paths should use forward slashes in JSON examples for consistency across operating systems.

Evidence paths should be stable. A changing path makes historical comparison and artifact review harder.

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

`Contract` is mandatory for all downstream callers. `MarkdownLinks`, `DocumentationCompleteness`, and `ForbiddenPatterns` are supported central static categories when present in validated configuration. Categories that imply repository-maintainer layout or caller code execution—such as `Examples`, `Pester`, `JsonSchemas`, `WorkflowArchitecture`, and `RepositoryHealth`—are rejected for downstream use; run caller-owned builds and tests in separate caller CI jobs. Any nonempty `controls.mandatoryControlsDisabled` fails closed unless a future interface can independently validate the approved exception.

The central downstream workflow does not yet apply repository-provided `additionalForbiddenPatterns` or `reviewedAllowlist`. Both arrays MUST be empty; a nonempty value fails with the unsupported field name instead of being silently ignored. The complete reviewed scanner-configuration model remains deferred to Issue #21.

The public downstream canary uses the smallest supported profile: `Contract` as its only validation category, empty repository-provided scanner arrays, and no disabled mandatory controls. Its negative fixtures separately prove version mismatch, required-file enforcement, and mandatory-control disablement. See [Downstream Governance Canary](DOWNSTREAM_CANARY.md); the canary profile does not remove additional controls applicable to a real consumer.

Existing callers must remove `run-examples`, `run-pester`, and `run-documentation-validation`. Those compatibility inputs were mandatory-true and misleading; removal is an intentional interface correction. GitHub Enterprise Server is unsupported because it does not provide the immutable `job.workflow_*` identity properties and the workflow does not use an unsafe fallback.

## Allowlist Rules

Allowlists are temporary review decisions, not permanent suppressions. Every allowlist entry MUST include a rule id or pattern, path scope, owner, explanation, approval reference, and expiration date.

Allowlists MUST be narrow. A repository-wide allowlist for a dangerous pattern requires explicit maintainer approval and must include a remediation plan.

## Exception Rules

Exceptions in either configuration file MUST reference approved `GOV-*` records. The exception must define scope, expiration, owner, compensating control, and renewal requirements.

Expired exceptions are invalid. A pull request that extends an exception must explain why remediation has not occurred and what changed in the risk assessment.

## Validation

Validate configuration locally:

```powershell
pwsh -NoProfile -File actions/validate-contract/Invoke-ContractValidation.ps1 -Path .
pwsh -NoProfile -File scripts/Test-JsonSchemas.ps1 -Path .
```

For complete repository validation, run:

```powershell
pwsh -NoProfile -File scripts/Invoke-GovernanceValidation.ps1 -Path . -Category JsonSchemas,Contract,RepositoryHealth,Evidence
```

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
