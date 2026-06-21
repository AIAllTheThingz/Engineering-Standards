# Governance Consolidation Audit

| Status | Active |
| Version | 1.0.0 |
| Owner role | Engineering Standards Maintainers |
| Last reviewed | 2026-06-21 |

## Purpose

This audit records the repository-wide consolidation of governance documents, agent standards, validators, workflows, schemas, examples, templates, documentation, evidence, and release readiness for `AIAllTheThingz/Engineering-Standards`.

The machine-readable companion is [../governance/standards-consistency.json](../governance/standards-consistency.json), validated structurally by [../schemas/standards-consistency.schema.json](../schemas/standards-consistency.schema.json).

## Baseline

| Field | Value |
| --- | --- |
| Starting commit | `8009f3fc65dc873c31dbb753aeef9c8f1fd4262c` |
| Starting repository version | `1.0.0` |
| Default branch | `master` |
| Repository risk | `High` |
| Release authorization | Not granted |
| Branch-setting authorization | Not granted |
| GitHub-hosted evidence status | `Blocked` until authenticated workflow dispatch and artifact download are performed after the consolidation commit |

## Canonical Terms

Normative terminology is inherited from [../agents/AGENTS_Base.md](../agents/AGENTS_Base.md): MUST, MUST NOT, SHOULD, SHOULD NOT, and MAY. Technology standards may add implementation detail but MUST NOT redefine central governance terms.

Canonical risk values are `Low`, `Moderate`, `High`, and `Critical`.

Canonical completion statuses are `Passed`, `Failed`, `Blocked`, `NotRun`, and `NotApplicable`.

- `Passed` requires actual evidence.
- `Failed` means an executed or static check detected noncompliance.
- `Blocked` means a concrete dependency or condition prevented execution.
- `NotRun` means validation was not executed.
- `NotApplicable` means the check does not apply.

`Skipped` is not a canonical governance completion status for this repository version.

## Cross-Standard Matrix

| Path | Version | Status | Last reviewed | Owner | Validator min | Positive coverage | Negative coverage | Pester mutation | Resolution |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| [../governance/ORGANIZATION_CONTRACT.md](../governance/ORGANIZATION_CONTRACT.md) | 1.0.0 | Active | 2026-06-19 | Engineering Governance | N/A | N/A | N/A | N/A | Retained as authoritative governance policy. |
| [../governance/COMPLETION_EVIDENCE.md](../governance/COMPLETION_EVIDENCE.md) | 1.0.0 | Active | 2026-06-19 | Engineering Governance | N/A | Present | Present | Present | Completion status semantics align with schemas. |
| [../governance/RISK_CLASSIFICATION.md](../governance/RISK_CLASSIFICATION.md) | 1.0.0 | Active | 2026-06-19 | Engineering Governance | N/A | N/A | N/A | N/A | Risk values remain canonical. |
| [../governance/EXCEPTION_PROCESS.md](../governance/EXCEPTION_PROCESS.md) | 1.0.0 | Active | 2026-06-19 | Engineering Governance | N/A | N/A | N/A | N/A | Exception process remains canonical. |
| [../governance/AI_GENERATED_CODE_POLICY.md](../governance/AI_GENERATED_CODE_POLICY.md) | 1.0.0 | Active | 2026-06-19 | Engineering Governance | N/A | N/A | N/A | N/A | AI controls remain inherited. |
| [../AGENTS.md](../AGENTS.md) | 1.1.0 | Active | 2026-06-21 | Engineering Standards Maintainers | N/A | Present | Present | Present | Repository governance version synchronized to 1.1.0. |
| [../agents/AGENTS_Base.md](../agents/AGENTS_Base.md) | 1.0.0 | Active | 2026-06-19 | Engineering Standards Maintainers | 1.0.0 | Present | Present | Present | Base inheritance remains canonical. |
| [../agents/AGENTS_PowerShell.md](../agents/AGENTS_PowerShell.md) | 1.1.1 | Active | 2026-06-20 | Engineering Standards Maintainers | 1.1.1 | Present | Present | Present | Preserved. |
| [../agents/AGENTS_DotNet.md](../agents/AGENTS_DotNet.md) | 1.1.1 | Active | 2026-06-20 | Engineering Standards Maintainers | 1.1.1 | Present | Present | Present | Preserved. |
| [../agents/AGENTS_Database.md](../agents/AGENTS_Database.md) | 1.1.1 | Active | 2026-06-20 | Engineering Standards Maintainers | 1.1.1 | Present | Present | Present | Preserved. |
| [../agents/AGENTS_WorkerService.md](../agents/AGENTS_WorkerService.md) | 1.1.1 | Active | 2026-06-20 | Engineering Standards Maintainers | 1.1.1 | Present | Present | Present | Preserved. |
| [../agents/AGENTS_Integration.md](../agents/AGENTS_Integration.md) | 1.1.0 | Active | 2026-06-21 | Engineering Standards Maintainers | 1.1.0 | Present | Present | Present | Strengthened from 1.0.0 and added semantic validator coverage. |
| [../agents/AGENTS_Infrastructure.md](../agents/AGENTS_Infrastructure.md) | 1.1.1 | Active | 2026-06-20 | Engineering Standards Maintainers | 1.1.1 | Present | Present | Present | Preserved. |
| [../agents/AGENTS_WebFrontend.md](../agents/AGENTS_WebFrontend.md) | 1.1.1 | Active | 2026-06-21 | Engineering Standards Maintainers | 1.1.1 | Present | Present | Present | Preserved. |

## Discrepancies And Resolutions

| Area | Discrepancy | Resolution |
| --- | --- | --- |
| Repository version | Root version, manifests, workflow defaults, README, and templates still referenced `1.0.0`. | Repository version decision is `1.1.0`; authoritative repository-version locations were synchronized without changing historical release records. |
| Integration standard | Integration remained `1.0.0` and had lighter semantic controls than the other six technology standards. | Integration was strengthened to `1.1.0` with enforceable controls for API contracts, auth, secrets, retries, webhooks, queues, file transfer, schema validation, privacy, evidence, exceptions, and handoffs. |
| Validator coverage | Integration did not have comparable minimum-version, positive semantic, negative weakening, or Pester mutation coverage. | `scripts/Test-AgentStandards.ps1` and `tests/scripts/AgentStandards.Tests.ps1` now include Integration coverage. |
| Status terminology | Documentation had a stale mention of `Skipped` as an evidence status. | Documentation was normalized to `Passed`, `Failed`, `Blocked`, `NotRun`, and `NotApplicable`. |
| GitHub evidence | Current local state cannot prove hosted workflow success, controlled failure, artifact download, or branch settings. | These remain `Blocked` until authenticated GitHub execution and inspection are performed after the final consolidation commit. |

## Workflow Inventory

Executable workflows inspected:

- [../.github/workflows/governance-ci.yml](../.github/workflows/governance-ci.yml)
- [../.github/workflows/governance-ci-reusable.yml](../.github/workflows/governance-ci-reusable.yml)

Distribution workflow templates inspected:

- [../workflows/governance-ci.yml](../workflows/governance-ci.yml)
- [../workflows/powershell-ci.yml](../workflows/powershell-ci.yml)
- [../workflows/dotnet-ci.yml](../workflows/dotnet-ci.yml)
- [../workflows/database-ci.yml](../workflows/database-ci.yml)
- [../workflows/web-ci.yml](../workflows/web-ci.yml)

Example workflows inspected:

- `examples/powershell-project/.github/workflows/governance.yml`
- `examples/dotnet-project/.github/workflows/governance.yml`
- `examples/database-project/.github/workflows/governance.yml`
- `examples/web-project/.github/workflows/governance.yml`
- `examples/worker-service-project/.github/workflows/governance.yml`
- `examples/integration-project/.github/workflows/governance.yml`
- `examples/infrastructure-project/.github/workflows/governance.yml`
- `examples/combined-script-runner-project/.github/workflows/governance.yml`

Local workflow architecture validation checks immutable third-party action pins, local reusable workflow placement, recursion prevention, unsupported inputs, broad permissions, and default-branch alignment. Actual GitHub required-check and branch-protection settings require authenticated GitHub inspection.

## Schema And Evidence Review

Existing schema versions remain `1.0.0`; this consolidation does not introduce incompatible schema behavior. The repository governance version moves to `1.1.0`.

Schema additions:

- [../schemas/standards-consistency.schema.json](../schemas/standards-consistency.schema.json)

Evidence status values remain consistent across current schemas:

- `Passed`
- `Failed`
- `Blocked`
- `NotRun`
- `NotApplicable`

Checked-in historical evidence was not regenerated merely to create a success claim. `evidence/latest-verified-run.json` MUST NOT be updated until a real GitHub run artifact is downloaded and independently verified.

## Example Repository Review

| Example | Functional status | Validation |
| --- | --- | --- |
| `examples/powershell-project` | Functional | `pwsh -NoProfile -File examples/powershell-project/tools/Test-Example.ps1` |
| `examples/dotnet-project` | Functional when .NET SDK is available | `dotnet build` and `dotnet run` commands in the reusable workflow |
| `examples/database-project` | Functional static migration validation | `pwsh -NoProfile -File examples/database-project/tools/Test-Migrations.ps1 -Path examples/database-project` |
| `examples/web-project` | Functional when Node/npm are available | `npm ci`, lint, test, and build in the reusable workflow; local bundled Node can run scripts when npm is unavailable |
| `examples/worker-service-project` | Functional Pester tests | `Invoke-Pester -Path examples/worker-service-project/tests -Output Detailed` |
| `examples/integration-project` | Functional static contract validation | `pwsh -NoProfile -File examples/integration-project/tools/Test-Example.ps1 -Path examples/integration-project` |
| `examples/infrastructure-project` | Functional static non-mutating plan validation | `pwsh -NoProfile -File examples/infrastructure-project/tools/Test-Example.ps1 -Path examples/infrastructure-project` |
| `examples/combined-script-runner-project` | Functional static catalog and immutable-input validation | `pwsh -NoProfile -File examples/combined-script-runner-project/tools/Test-Example.ps1 -Path examples/combined-script-runner-project` |

## Release Readiness

Proposed repository version: `1.1.0`.

Proposed tag: `v1.1.0`.

Release tag created: no.

Release status: `Blocked` until:

- Local validation passes on the final consolidation commit.
- GitHub success workflow run is dispatched and inspected.
- Controlled-failure workflow run is dispatched and inspected.
- Workflow artifacts are downloaded into a safe temporary directory and independently verified.
- `evidence/latest-verified-run.json` is updated only with real verified run metadata.
- Branch protection is inspected through GitHub settings or API output.
- Explicit release authorization is granted.

## Remaining Risks

- GitHub-hosted validation and artifact verification cannot be proven from local files.
- Actual branch protection settings remain unverified without repository settings/API access.
- Integration is now semantically enforceable, and all eight downstream example categories exist; GitHub-hosted execution remains unverified until workflow runs are dispatched and artifacts are inspected.
- Historical checked-in evidence may describe earlier repository states and must be distinguished from current validation evidence.
