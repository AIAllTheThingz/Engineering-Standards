# Configuration Reference

| Status | Active |
| Version | 1.0.0 |
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
| `additionalForbiddenPatterns` | No | Repository-specific scanner rules. | Must not duplicate central rules without reason. |
| `reviewedAllowlist` | No | Approved scanner exceptions. | Must include owner, reason, scope, and expiration. |
| `optionalValidationCategories` | No | Additional validation categories. | Optional does not mean unreviewed. |
| `controls` | Yes | Control toggles. | Disabled mandatory controls require `GOV-*` exceptions. |
| `exceptions` | No | Active governance exceptions. | Must match exception records and evidence. |

## Allowed Values

Risk classifications are `Low`, `Moderate`, `High`, and `Critical`. Data classifications are defined in `governance/RISK_CLASSIFICATION.md` and the organization contract. Status values in evidence are `Passed`, `Failed`, `Blocked`, `Skipped`, `NotRun`, and `NotApplicable` when the schema permits it.

Do not introduce new enum values in downstream repositories. If a new value is needed, change the central schema, add fixtures, update validators, and release a new governance version.

## Path Rules

Paths are repository-relative and MUST NOT escape the repository root. Validators treat missing required files as failures. Paths should use forward slashes in JSON examples for consistency across operating systems.

Evidence paths should be stable. A changing path makes historical comparison and artifact review harder.

## Workflow Configuration

Downstream repositories call `AIAllTheThingz/Engineering-Standards/.github/workflows/governance-ci-reusable.yml@<immutable-reference>`. Required inputs are:

| Input | Default | Meaning |
| --- | --- | --- |
| `project-path` | `.` | Repository-relative path to validate. Absolute paths and traversal are invalid. |
| `governance-version` | `1.0.0` | Expected governance version, compared with `project-manifest.json` when present. |
| `run-examples` | `true` | Runs functional example validations for this repository. |
| `run-pester` | `true` | Runs repository Pester tests. |
| `run-documentation-validation` | `true` | Runs substantive documentation checks. |
| `artifact-retention-days` | `30` | Evidence artifact retention period. |

Outputs are `evidence-path` and `artifact-name`. Root files under `workflows/` are distribution templates and must not be referenced as cross-repository reusable workflows.

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
- `docs/ADOPTION_GUIDE.md`
- `docs/TROUBLESHOOTING.md`
