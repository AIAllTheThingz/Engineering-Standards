# Engineering Standards

`AIAllTheThingz/Engineering-Standards` is the authoritative source for reusable engineering standards, AI-agent instructions, governance contracts, JSON schemas, repository templates, validation actions, reusable CI workflows, and release evidence.

## Why Centralized Governance Is Needed

Copied governance files drift. A security requirement added to one repository is forgotten in another. AI-agent instructions become inconsistent. Evidence schemas evolve without downstream repositories noticing. This repository centralizes the controls, versions them, and gives downstream repositories a repeatable way to consume them through immutable Git references.

## What This Repository Does

- Defines organization-wide engineering requirements.
- Defines inherited AI-agent standards for common technology domains.
- Provides schemas for project manifests, governance configuration, test evidence, artifact records, and completion results.
- Provides composite actions and reusable workflows for pull-request and release validation.
- Provides templates and examples that downstream repositories can adapt without copying central policy as the synchronization mechanism.
- Records release evidence so maintainers can inspect what was validated and what was not run.

## What This Repository Does Not Do

- It does not replace application-specific architecture decisions.
- It does not store secrets or production configuration.
- It does not guarantee legal or regulatory compliance by itself.
- It does not make the forbidden-pattern scanner a complete secret scanner or SAST tool.

## Governance Philosophy

The repository is safe by default, evidence driven, least-privilege oriented, and explicit about failures. Missing tools are `NotRun`, not `Passed`. Local instructions may strengthen central standards but may not weaken them.

## Authority Hierarchy

1. Applicable law, regulation, contractual requirements, and approved organizational security policy.
2. `governance/ORGANIZATION_CONTRACT.md`.
3. Applicable organization-wide governance documents.
4. `agents/AGENTS_Base.md`.
5. Applicable technology-specific `AGENTS_*.md` files.
6. Repository-root `AGENTS.md`.
7. Directory-local `AGENTS.md`.
8. Task-specific instructions.

Lower-level instructions MAY add implementation detail, stricter validation, project-specific requirements, and technology-specific constraints. Lower-level instructions MUST NOT disable mandatory controls, remove evidence, bypass testing, authorize prohibited destructive behavior, weaken risk classification, claim validation that did not run, or override policy without an approved exception.

## Architecture

```mermaid
flowchart TD
  ES["Engineering Standards"] --> GOV["Governance policies"]
  ES --> AG["Agent standards"]
  ES --> SC["JSON schemas"]
  ES --> ACT["Composite actions"]
  ES --> WF["Reusable workflows"]
  ES --> TPL["Templates and examples"]
  GOV --> DOWN["Downstream repositories"]
  AG --> DOWN
  SC --> EV["Evidence artifacts"]
  ACT --> CI["Pull request and release validation"]
  WF --> CI
  DOWN --> EV
  CI --> EV
```

## Repository Structure

- `governance/`: organization contract, evidence, risk, exceptions, and AI-generated-code policy.
- `agents/`: base and technology-specific AI-agent standards.
- `schemas/`: strongly typed JSON Schema contracts.
- `actions/`: composite GitHub Actions implemented with PowerShell 7.
- `.github/workflows/`: executable repository workflows and reusable workflows.
- `workflows/`: distribution templates; GitHub does not execute reusable workflows directly from this root directory.
- `templates/`: repository, pull-request, issue, test-plan, and threat-model templates.
- `examples/`: functional downstream example projects.
- `scripts/`: local validation and evidence tooling.
- `tests/`: Pester tests and schema fixtures.
- `docs/`: adoption, configuration, architecture, security, release, branch protection, and troubleshooting guidance.
- `evidence/`: final completion evidence and supporting test-result records for the current repository state.

## Major Documents

- [Organization Contract](governance/ORGANIZATION_CONTRACT.md)
- [Completion Evidence](governance/COMPLETION_EVIDENCE.md)
- [Risk Classification](governance/RISK_CLASSIFICATION.md)
- [Exception Process](governance/EXCEPTION_PROCESS.md)
- [AI Generated Code Policy](governance/AI_GENERATED_CODE_POLICY.md)
- [Adoption Guide](docs/ADOPTION_GUIDE.md)
- [Downstream Configuration](docs/DOWNSTREAM_CONFIGURATION.md)
- [Action Security](docs/ACTION_SECURITY.md)
- [Maintainer Guide](docs/MAINTAINER_GUIDE.md)
- [Versioning](docs/VERSIONING.md)
- [Release Process](docs/RELEASE_PROCESS.md)
- [Branch Protection](docs/BRANCH_PROTECTION.md)
- [Troubleshooting](docs/TROUBLESHOOTING.md)
- [Templates](docs/TEMPLATES.md)
- [Changelog](CHANGELOG.md)

## Downstream Adoption Flow

1. Inventory existing local standards and CI checks.
2. Classify the project type and risk.
3. Add `project-manifest.json` and `governance.config.json`.
4. Add a local `AGENTS.md` that references the central base and technology standards.
5. Add a reusable workflow pinned to an immutable reference.
6. Run in advisory mode, remediate failures, then make validation blocking through branch protection.

## Example Workflow

```yaml
name: Governance
on:
  pull_request:
  push:
    branches: [master, main]
permissions:
  contents: read
jobs:
  governance:
    uses: AIAllTheThingz/Engineering-Standards/.github/workflows/governance-ci-reusable.yml@<commit-sha>
    with:
      project-path: .
      governance-version: 1.1.0
      run-examples: true
      run-pester: true
      run-documentation-validation: true
      artifact-retention-days: 30
```

The local event workflow is `.github/workflows/governance-ci.yml`. It triggers on pull requests, pushes to `master`, and manual `workflow_dispatch`, then calls `.github/workflows/governance-ci-reusable.yml` exactly once. Downstream repositories must call the reusable workflow path under `.github/workflows`, not files under the root `workflows/` template directory.

## Example Local AGENTS.md

```markdown
# AGENTS.md

This repository inherits:
- AIAllTheThingz/Engineering-Standards/agents/AGENTS_Base.md@<commit-sha>
- AIAllTheThingz/Engineering-Standards/agents/AGENTS_PowerShell.md@<commit-sha>

Local rules may add stricter validation and repository-specific commands. Local rules may not weaken central governance.
```

## Example Project Manifest

```json
{
  "schemaVersion": "1.0.0",
  "projectName": "Example Service",
  "repository": "example-org/example-service",
  "description": "Example service used to demonstrate governance adoption.",
  "projectType": "dotnet",
  "technologies": ["dotnet", "github-actions"],
  "governanceVersion": "1.1.0",
  "riskClassification": "Moderate",
  "dataClassification": "Internal",
  "environments": [
    {
      "name": "local",
      "type": "development",
      "production": false
    }
  ],
  "applicableStandards": ["agents/AGENTS_Base.md", "agents/AGENTS_DotNet.md"],
  "requiredWorkflows": ["governance"],
  "externalIntegrations": [],
  "secretsProvider": "example-secrets-provider",
  "productionApprovalRequired": false,
  "owners": ["@example-org/example-owners"],
  "evidence": {
    "completionEvidencePath": "evidence/local-completion-result.json",
    "testEvidencePath": "evidence/test-evidence.json"
  },
  "exceptions": []
}
```

## Local Validation

```powershell
pwsh -NoProfile -File scripts/Test-JsonSchemas.ps1 -Path .
pwsh -NoProfile -File scripts/Test-MarkdownLinks.ps1 -Path .
pwsh -NoProfile -File scripts/Test-DocumentationCompleteness.ps1 -Path .
pwsh -NoProfile -File scripts/Test-YamlSyntax.ps1 -Path .
pwsh -NoProfile -File scripts/Test-GitHubWorkflowArchitecture.ps1 -Path .
pwsh -NoProfile -File scripts/Invoke-GovernanceValidation.ps1 -Path .
Invoke-Pester -Path tests -Output Detailed
```

## Functional Examples

The PowerShell example at `examples/powershell-project` is functional and includes a module manifest, script module, Pester tests, validation script, workflow wiring, and generated test evidence. Run it from the repository root:

```powershell
pwsh -NoProfile -File examples/powershell-project/tools/Test-Example.ps1
```

The repository now separates example types explicitly:

- `examples/powershell-project`: functional PowerShell example.
- `examples/dotnet-project`: runtime-dependent .NET example.
- `examples/database-project`: non-mutating migration validation example.
- `examples/web-project`: runtime-dependent web example.
- `examples/worker-service-project`: functional worker-service example.
- `examples/integration-project`: synthetic governed integration flow with signature, replay, duplicate-delivery, partial-success, and redaction checks.
- `examples/infrastructure-project`: synthetic non-mutating plan validation example with generated plan evidence.
- `examples/combined-script-runner-project`: executable synthetic vertical slice demonstrating approved script catalog validation, queue state, idempotency, claim/lease, and atomic report publication.

## Release And Versioning

The repository uses semantic versioning. Breaking governance changes require major versions and migration guidance. Downstream CI SHOULD pin commit SHAs for maximum supply-chain integrity. Release notes are maintained in [CHANGELOG.md](CHANGELOG.md), and release procedure is defined in [Release Process](docs/RELEASE_PROCESS.md).

Current version: `1.1.0`.

## Security Reporting And Contributions

Security issues are handled through [SECURITY.md](SECURITY.md). Contributions must follow [CONTRIBUTING.md](CONTRIBUTING.md), include evidence, and avoid false completion claims.

## Release Readiness Notes

- Local checked-in evidence is stored in `evidence/local-completion-result.json`; GitHub-hosted completion evidence is stored in workflow artifacts.
- `commitSha` and `validatedCommitSha` identify the repository commit that was validated. `evidenceCommitSha` identifies the commit containing a checked-in evidence file when that value is intentionally recorded. GitHub artifact evidence leaves `evidenceCommitSha` null because the artifact is not committed.
- Local evidence remains `NotRun` overall when GitHub-hosted execution was not performed locally. It is not authoritative proof of a GitHub run.
- `evidence/latest-verified-run.json` records metadata for the most recently downloaded and independently verified GitHub success artifact plus the controlled-failure run.
- To trigger the success proof run: `gh workflow run "Governance CI" --ref master -f controlled-failure-test=false -f run-examples=true -f run-pester=true -f run-documentation-validation=true`.
- To trigger the controlled failure proof run: `gh workflow run "Governance CI" --ref master -f controlled-failure-test=true`.
- Download workflow evidence with `gh run download <run-id> --name governance-evidence-<run-id> --dir <safe-temp-dir>` and verify it with `scripts/Test-WorkflowEvidenceArtifact.ps1`.
- Forbidden-pattern scanning excludes generated evidence and build output by default. Use `-IncludeGeneratedEvidence` only for diagnostics.
- Detailed Pester audit evidence is stored as sanitized JSON in `evidence/pester-details.json`; raw Pester XML is temporary and is not uploaded.
- Final workflow enforcement occurs after final evidence validation and artifact upload, so controlled failures still produce downloadable evidence.
- The latest independently verified success run is `28281939062` for validated implementation commit `ad23160917584eacee2dd1a11369f7f81932ff57`.
- The paired controlled-failure proof run is `28282082709` and failed only at final enforcement after evidence upload.
- The independently computed ZIP SHA-256 values are `0d4b00aaed3895bbbda7aa044519c473a9cde9fc0d228004b1a414df8a5c29a5` for the success artifact and `58efdb73e05da832e5062db25add144c1cc8f95203475ad36dd598a079c4c489` for the controlled-failure artifact.
- `master` was inspected through the GitHub branch-protection API on 2026-06-27 and is currently not protected by classic branch protection.
- Repository rulesets were inspected on 2026-06-27 and none are configured.
- No Git tags or GitHub releases currently exist for this repository.
- Release readiness remains blocked because branch protection is not enforced and no tag or GitHub release has been authorized.

## Related Documents

This repository MUST be used with the governing documents in `governance/`, the agent standards in `agents/`, the executable workflows in `.github/workflows/`, the distribution templates in `workflows/`, and the validation evidence in `evidence/`. Consumers should start with `docs/ADOPTION_GUIDE.md`, then configure `project-manifest.json` and `governance.config.json` before enabling CI. Exceptions, validation results, and completion evidence are part of the same governance system; they are not optional side files.
