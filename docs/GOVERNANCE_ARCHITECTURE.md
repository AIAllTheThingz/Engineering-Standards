# Governance Architecture

| Status | Active |
| Version | 1.0.0 |
| Owner role | Platform Architecture Maintainers |
| Last reviewed | 2026-06-19 |

## Authority Layers

1. Applicable law, regulation, contractual requirements, and approved organizational security policy.
2. `governance/ORGANIZATION_CONTRACT.md`.
3. Applicable organization-wide governance documents.
4. `agents/AGENTS_Base.md`.
5. Applicable technology-specific `AGENTS_*.md` files.
6. Repository-root `AGENTS.md`.
7. Directory-local `AGENTS.md`.
8. Task-specific instructions.

Lower-level instructions MAY add implementation detail, stricter validation, project-specific requirements, and technology-specific constraints. Lower-level instructions MUST NOT disable mandatory controls, remove evidence, bypass testing, authorize prohibited destructive behavior, weaken risk classification, claim validation that did not run, or override policy without an approved exception.

## Data Flow

```mermaid
sequenceDiagram
  participant Repo as Downstream Repo
  participant Workflow as Reusable Workflow
  participant Action as Composite Actions
  participant Schema as Schemas
  participant Evidence as Evidence Artifact
  Repo->>Workflow: workflow_call with pinned version
  Workflow->>Action: validate contract, docs, evidence, scanner, health
  Action->>Schema: validate JSON records
  Action->>Evidence: write reports
  Workflow->>Evidence: upload artifact
```

## Workflow Architecture

The event-triggered workflow is `.github/workflows/governance-ci.yml`. It runs on pull requests, pushes to `master`, and manual `workflow_dispatch`, and its only job calls `.github/workflows/governance-ci-reusable.yml`.

The reusable workflow is `.github/workflows/governance-ci-reusable.yml`. It is triggered only by `workflow_call`, defines all supported inputs, runs validation jobs, generates completion evidence, and uploads evidence artifacts. It MUST NOT call the event workflow, itself, or any workflow that calls it back.

Root files under `workflows/` are distribution templates. GitHub does not execute reusable workflows directly from that location. Cross-repository callers must use `AIAllTheThingz/Engineering-Standards/.github/workflows/governance-ci-reusable.yml@<immutable-reference>`.

## Trust Boundaries

Pull-request content, filenames, configuration, evidence, and generated artifacts are untrusted. Central workflow code is trusted only at the pinned version. Secrets are outside the validation boundary and are not required for pull-request validation.

## Failure Behavior

Mandatory failures return nonzero. The reusable workflow generates evidence with `if: always()` and uploads validation reports even when a mandatory step fails. Missing tools are `NotRun` and must be shown in evidence; mandatory local workflow validation includes YAML syntax and workflow architecture checks.

The workflow ordering is validation steps, initial test evidence, initial completion evidence, initial evidence validation, final test evidence, final completion evidence, final evidence validation, artifact upload, then final enforcement. Success requires all mandatory steps, final evidence validation, and artifact upload to pass. Controlled failure runs intentionally fail only after failure evidence is generated, evidence validates, and the artifact uploads.

## Reusable Inputs And Outputs

Inputs are `project-path`, `governance-version`, `run-examples`, `run-pester`, `run-documentation-validation`, and `artifact-retention-days`. Outputs are `evidence-path` and `artifact-name`. Artifact uploads include validation reports, scanner reports, Pester output, and completion evidence.

Pester output is split into `pester-summary.json` and sanitized `pester-details.json`. Raw Pester XML is generated only as a temporary conversion input and is not uploaded unless it passes path-sanitization validation.

Generated evidence, build output, package directories, coverage, and test result folders are excluded from ordinary forbidden-pattern scans. `-IncludeGeneratedEvidence` exists for explicit diagnostic scans.

Completion evidence uses `validatedCommitSha` for the validated repository content and `evidenceCommitSha` for checked-in evidence files when supplied. GitHub artifact evidence leaves `evidenceCommitSha` null and is tied to `githubRunId` plus `githubRunAttempt`.

## Governance Operating Requirements

Teams MUST apply this document together with the organization contract, completion evidence policy, exception process, and risk classification model. Validation MUST include the automated checks that apply to the repository type plus a reviewer assessment of any material risk that automation cannot prove. Evidence MUST be stored in the repository or attached to the pull request, and it must distinguish Passed, Failed, Blocked, Skipped, and NotRun results without contradiction.

## Exception Handling

Exceptions MUST follow `governance/EXCEPTION_PROCESS.md`. An exception request needs a `GOV-*` reference, owner, expiry date, compensating control, rollback plan when applicable, and approval from the accountable maintainer. Expired exceptions are treated as failures until renewed or remediated.

## Related Documents

- `governance/ORGANIZATION_CONTRACT.md`
- `governance/COMPLETION_EVIDENCE.md`
- `governance/RISK_CLASSIFICATION.md`
- `governance/EXCEPTION_PROCESS.md`
- `docs/ADOPTION_GUIDE.md`
- `scripts/Test-GitHubWorkflowArchitecture.ps1`
