# Issue #22 Aggregate Validation Coverage Matrix

| Field | Value |
| --- | --- |
| Status | Active |
| Change | Issue #22: authoritative aggregate governance validation |
| Registry version | `1.0.0` |
| Last reviewed | 2026-07-14 |

## Baseline Coverage Review

This matrix was prepared before implementation work began. It compares the
former aggregate path with the complete maintainer validation obligation and
records the authority introduced by Issue #22.

| Requirement | Before Issue #22 | Risk or gap | Authoritative behavior |
| --- | --- | --- | --- |
| Safe repository discovery | Caller, standards, and evidence roots were bounded and link traversal was rejected. | Discovery rules were embedded in one script and category definitions were spread across code and workflows. | Root discovery remains fail closed; the trusted registry supplies every runner path and callers cannot provide executable paths. |
| Profile selection | Maintainer versus downstream behavior was inferred in the aggregate script. | The profile category sets and code-execution boundary were not inspectable as one contract. | `standards-maintainer` and `downstream` are explicit registry profiles with declared trust models and code-execution behavior. |
| Explicit category filtering | `-Category` could reduce the selected checks. | A narrow command could silently omit mandatory controls. | `-Category` filters optional checks only. Every mandatory profile category is added to the plan. |
| Governance contract | Available through the aggregate path. | A narrow selection could omit the check that authorizes exceptions. | `Contract` is mandatory for every profile and cannot be disabled. |
| Agent standards | Executed separately in candidate CI. | Missing from the aggregate category surface. | `AgentStandards` is a mandatory maintainer category. |
| Codex skills | Supported by the aggregate and candidate workflow. | Absence and non-execution semantics were not centrally registered. | The category is mandatory for maintainers, optional and static downstream, and `NotApplicable` when no governed skill tree exists. |
| JSON schemas and semantic fixtures | Supported as an explicitly selected category. | It was easy for a maintainer command to omit the category. | `JsonSchemas` is mandatory for the maintainer profile. |
| YAML and workflow architecture | Executed as separate workflow steps. | The aggregate did not own their prerequisites or results. | Both are mandatory maintainer categories; Python and PyYAML prerequisites are explicit. |
| Markdown and documentation completeness | Supported as explicitly selected categories. | Published command lists disagreed about whether they ran. | Both are mandatory maintainer categories and default aggregate results. |
| Forbidden patterns, repository health, and evidence | Supported as explicitly selected categories. | Narrow examples could omit one or more controls. | All three are mandatory maintainer categories in one ordered plan. |
| PowerShell parser | Executed separately in candidate CI. | No aggregate result or canonical status. | Parsing is a mandatory conditional maintainer category and reports repository-relative findings. |
| Pester | Executed separately in candidate CI and local instructions. | The aggregate report did not prove the suite ran. | The aggregate invokes the structured Pester suite and treats zero discovery, failures, and `NotRun` as non-passing. |
| PSScriptAnalyzer | Executed separately when installed. | Missing tooling could disappear from the aggregate result. | It is a mandatory conditional maintainer category; missing tooling is `NotRun` with policy exit code `3`. |
| Functional examples | Supported only when explicitly selected and also invoked separately in candidate CI. | Duplicate orchestration could drift. | `Examples` is mandatory for maintainers and runs the real PowerShell, .NET, web, worker, database, integration, infrastructure, and combined-runner checks. |
| Canonical statuses | Child scripts mainly returned process success or failure. | Missing tools and non-applicability could be flattened or omitted. | Aggregate children and the overall report use only `Passed`, `Failed`, `Blocked`, `NotRun`, and `NotApplicable`. |
| Machine-readable output | JSON output existed for aggregate runs. | It did not expose the registry, profile, resolved plan, or all status counts. | `governance-validation.json` records registry version, trust model, configured/requested/mandatory/selected/excepted categories, child results, status counts, and overall status. |
| Candidate workflow authority | Candidate CI manually orchestrated individual validators, tests, analyzer, and examples. | The workflow was a second aggregate implementation. | Candidate CI invokes the aggregate exactly once in an isolated, read-only, no-secret harness; workflow architecture tests enforce this. |
| Downstream execution safety | Trusted central validators treated caller content as data. | Profile behavior was partly encoded outside a registry. | The downstream profile never runs caller scripts, modules, tests, package hooks, builds, or examples. |

## Authoritative Plans

The registry at `scripts/governance-validation.registry.psd1` is the single
category catalog. The aggregate validator rejects unknown or profile-inapplicable
categories and resolves the plan in registry order.

| Profile | Mandatory categories | Optional configured categories | Repository code execution |
| --- | --- | --- | --- |
| `standards-maintainer` | All 15 registered categories | None currently | Yes, only for the verified central repository; candidate code is isolated by the immutable candidate harness. |
| `downstream` | `Contract` | `CodexSkills`, `MarkdownLinks`, `DocumentationCompleteness`, `ForbiddenPatterns` | No; caller content is inert input to trusted central validators. |

Bootstrap uses two immutable commits. The first Issue #22 implementation commit
`b14757f98e6a841c37e48ce023b692f529192f2d` contains the reviewed reusable and
candidate workflows; a second commit rotates self-CI and the root contract to
that SHA. The candidate workflow at the first commit then validates the second
commit without trusting workflow definitions supplied by the pull-request head.

An active structured exception may make an otherwise mandatory category
`NotApplicable` only after contract validation approves the exact exception.
`Contract` cannot be disabled because it establishes that authority. The
excepted category remains present in the plan and report.

## Command Migration

Former maintainer commands often carried a hand-maintained category list:

```powershell
pwsh -NoProfile -File scripts/Invoke-GovernanceValidation.ps1 -Path . -RepositoryOwnerType User -Category JsonSchemas,MarkdownLinks,Contract
```

Use the complete profile default instead:

```powershell
pwsh -NoProfile -File scripts/Invoke-GovernanceValidation.ps1 -Path . -RepositoryOwnerType User
```

Existing `-Category` syntax remains accepted for backward compatibility, but it
is additive to mandatory profile checks. Downstream repositories use the same
command from a trusted central checkout with their verified owner type; the
validated `governance.config.json` selects supported optional static checks.

Individual validators remain useful for fast diagnosis. They are not a
substitute for the final aggregate run or its machine-readable report.

## Failure And Tooling Semantics

A failed mandatory check makes the overall result `Failed`; `Blocked` and
`NotRun` mandatory checks produce the corresponding non-passing overall status.
Missing commands or Python modules are explicit `NotRun` children with exit code
`3`. A conditionally irrelevant check is `NotApplicable` with a rationale and a
null exit code. The aggregate process exits zero only when overall status is
`Passed`.

The GitHub candidate harness installs its declared toolchain before invoking the
aggregate. Local runs must install PowerShell 7, Pester, PSScriptAnalyzer,
Python with PyYAML, .NET, Node.js, and npm to obtain a complete maintainer pass.
