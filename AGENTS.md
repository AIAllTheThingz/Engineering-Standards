# AGENTS.md

This file defines repository-specific instructions for `AIAllTheThingz/Engineering-Standards`. It extends [agents/AGENTS_Base.md](agents/AGENTS_Base.md) and all applicable technology-specific standards. It does not replace the base standard or organization governance.

## Repository Identity

| Field | Value |
| --- | --- |
| Repository | `AIAllTheThingz/Engineering-Standards` |
| Purpose | Central governance repository for engineering policies, AI-agent standards, schemas, validation actions, reusable workflows, templates, examples, and evidence. |
| Default branch | `master` |
| Governance version | `1.1.0` |
| Risk classification | `High` |
| Repository type | `governance` |
| Data classification | `Internal` |
| Maintainers | `@AIAllTheThingz/engineering-standards-maintainers` |

Agents MUST treat this repository as security-sensitive because downstream repositories may rely on its policies, workflows, schemas, and agent instructions.

## Applicable Standards

Agents MUST apply:

- [agents/AGENTS_Base.md](agents/AGENTS_Base.md)
- [agents/AGENTS_PowerShell.md](agents/AGENTS_PowerShell.md)
- [agents/AGENTS_DotNet.md](agents/AGENTS_DotNet.md)
- [agents/AGENTS_WebFrontend.md](agents/AGENTS_WebFrontend.md)
- [agents/AGENTS_Database.md](agents/AGENTS_Database.md)
- [agents/AGENTS_WorkerService.md](agents/AGENTS_WorkerService.md)
- [agents/AGENTS_Integration.md](agents/AGENTS_Integration.md)
- [agents/AGENTS_Infrastructure.md](agents/AGENTS_Infrastructure.md)
- Governance documents in [governance/](governance/)

A technology-specific standard applies when files for that technology, its examples, its workflows, or its validation behavior are changed. Local instructions MAY strengthen these standards and MUST NOT weaken central governance.

## Repository Scope

Primary directories:

- `agents/`: base and technology-specific AI-agent standards.
- `governance/`: organization contract, completion evidence, risk, exceptions, and AI-generated-code policy.
- `schemas/`: JSON Schema contracts and semantic expectations.
- `scripts/`: local validation, evidence, and workflow-verification tooling.
- `actions/`: composite GitHub Actions implemented with PowerShell.
- `.github/workflows/`: executable entry and reusable workflows.
- `workflows/`: distribution templates, not executable reusable workflows from this location.
- `templates/`: repository, issue, pull-request, and operational templates.
- `examples/`: downstream adoption examples.
- `tests/`: Pester tests and schema fixtures.
- `evidence/`: checked-in local evidence and verified-run metadata.
- `docs/`: adoption, configuration, architecture, action security, maintenance, release, branch protection, and troubleshooting guides.

## Protected Areas

Agents MUST use extra caution for:

- Governance policies.
- Agent standards.
- Schemas and fixtures.
- GitHub Actions.
- Composite actions.
- Evidence generation and verification.
- Security tooling.
- Release metadata.

Changes to protected areas require focused scope, negative tests where behavior can fail, documentation updates when contracts change, current evidence when policy requires it, diff review, and real GitHub execution when workflow behavior changes.

## Repository-Specific Working Rules

Agents MUST:

- Make incremental changes with one incomplete phase at a time.
- Avoid broad shotgun rewrites.
- Avoid unrelated formatting churn.
- Preserve user changes shown by `git status`.
- Avoid deleting evidence unless replacing it with honest current evidence.
- Keep schemas, fixtures, validators, documentation, tests, and examples synchronized.
- Treat root `workflows/` files as distribution templates.
- Keep executable reusable workflows under `.github/workflows/`.
- Avoid direct workflow recursion.
- Avoid committing generated build output.
- Avoid absolute workstation or runner paths in evidence.
- Keep local evidence from claiming GitHub success.
- Use actual GitHub run metadata for GitHub artifact evidence.

Agents MUST NOT weaken branch protection, review, evidence, scanner, workflow, or security requirements for convenience.

## Required Local Commands

Agents MUST run the applicable subset for each change and MUST NOT claim a command passed unless it actually ran.

```powershell
pwsh -NoProfile -File scripts/Test-AgentStandards.ps1 -Path .
```

```powershell
pwsh -NoProfile -File scripts/Test-YamlSyntax.ps1 -Path .
```

```powershell
pwsh -NoProfile -File scripts/Test-GitHubWorkflowArchitecture.ps1 -Path . -DefaultBranch master
```

```powershell
pwsh -NoProfile -File scripts/Test-JsonSchemas.ps1 -Path .
```

```powershell
pwsh -NoProfile -File scripts/Test-MarkdownLinks.ps1 -Path .
```

```powershell
pwsh -NoProfile -File scripts/Test-DocumentationCompleteness.ps1 -Path .
```

```powershell
pwsh -NoProfile -File actions/validate-contract/Invoke-ContractValidation.ps1 -Path .
```

```powershell
pwsh -NoProfile -File actions/forbidden-pattern-scan/Invoke-ForbiddenPatternScan.ps1 -Path . -OutputJson evidence/forbidden-patterns.json
```

```powershell
pwsh -NoProfile -File actions/repository-health/Invoke-RepositoryHealth.ps1 -Path .
```

```powershell
Invoke-Pester -Path tests -Output Detailed
```

```powershell
Invoke-ScriptAnalyzer -Path . -Recurse -Severity Error
```

Agents also MUST use Git review commands when relevant:

```bash
git status --short
git diff --check
git diff
git ls-files
```

## Change-Specific Validation Matrix

Changes under `.github/workflows/` require YAML validation, workflow call-graph validation, immutable action pin review, least-privilege permission review, and a real GitHub run when behavior changes.

Changes under `schemas/` require valid fixtures, invalid fixtures, semantic tests, and backward-compatibility review.

Changes under `actions/` require Pester tests, output wiring validation, failure-path testing, and security review.

Changes under `evidence/` require schema validation, commit-semantics validation, no absolute paths, no fabricated run metadata, and hash consistency.

Changes under `agents/`, root `AGENTS.md`, agent-standard validation tooling, or related instruction-hierarchy documentation require `Test-AgentStandards.ps1`, documentation completeness, link validation, cross-document consistency review, and no contradictory instruction hierarchy.

Changes under `examples/` require real build and test commands for the affected example. Fake commands that only print success are prohibited.

PowerShell changes require parser validation, Pester where behavior changes, and ScriptAnalyzer when available.

## Evidence Requirements

Local evidence is not authoritative proof of GitHub execution. GitHub evidence MUST come from actual workflow artifacts.

Evidence MUST remain honest:

- `validatedCommitSha` identifies validated content.
- `commitSha` MUST match `validatedCommitSha` for compatibility.
- `evidenceCommitSha` identifies the commit containing checked-in evidence when intentionally used.
- `latest-verified-run.json` records downloaded and independently verified GitHub run metadata.
- GitHub artifact evidence MUST use actual run ID, run attempt, branch, artifact name, and artifact hashes.
- Local evidence MUST use `executionContext: Local` and keep GitHub-hosted execution as `NotRun`.

Do not modify `evidence/latest-verified-run.json` unless a new GitHub run actually ran and its artifact was independently verified.

## Generated Files

Agents MUST NOT commit:

- `bin/`
- `obj/`
- `dist/`
- `coverage/`
- `TestResults/`
- Temporary Pester XML.
- Package caches.
- Local tool state.
- Unsanitized artifacts.

## Final Response Requirements

For this repository, final responses MUST report:

- Exact files changed.
- Exact commands run.
- Exit codes.
- Tests passed, failed, skipped, and not run.
- Evidence files updated.
- Whether GitHub Actions actually ran.
- Whether artifacts were verified.
- Remaining gaps.

The completion status MUST be one of `Passed`, `Failed`, `Blocked`, `NotRun`, or `NotApplicable`.

## Related Documents

- [governance/ORGANIZATION_CONTRACT.md](governance/ORGANIZATION_CONTRACT.md)
- [governance/COMPLETION_EVIDENCE.md](governance/COMPLETION_EVIDENCE.md)
- [governance/RISK_CLASSIFICATION.md](governance/RISK_CLASSIFICATION.md)
- [governance/EXCEPTION_PROCESS.md](governance/EXCEPTION_PROCESS.md)
- [governance/AI_GENERATED_CODE_POLICY.md](governance/AI_GENERATED_CODE_POLICY.md)
- [docs/GOVERNANCE_ARCHITECTURE.md](docs/GOVERNANCE_ARCHITECTURE.md)
- [docs/MAINTAINER_GUIDE.md](docs/MAINTAINER_GUIDE.md)
- [docs/ADOPTION_GUIDE.md](docs/ADOPTION_GUIDE.md)
- [docs/RELEASE_PROCESS.md](docs/RELEASE_PROCESS.md)
