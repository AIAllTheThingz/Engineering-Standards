# Changelog

All notable changes to the Engineering Standards repository are recorded here. This project follows [Versioning](docs/VERSIONING.md) and the release process in [Release Process](docs/RELEASE_PROCESS.md).

## [Unreleased]

### Changed

- Updated the governed Python example build backend from Hatchling `1.31.0` to `1.32.0`, including the synchronized hash lock, `tomlkit==0.15.1`, validator expectation, and regression contract from PR #108. This work merged after the frozen `v1.2.1` target and is not part of the published patch.

## [1.2.1] - 2026-08-15

### Release Status

- Semantic version: `1.2.1`.
- Publication status: Published. Annotated tag `v1.2.1` has tag-object SHA `aea6330ee3d51b3f5bb55031d878ef302ba1dbca` and resolves to immutable commit `7d15ec8be6d8c3cdca35061728901584437e4a50`.
- GitHub Release ID `370882222` was published as non-draft and non-prerelease on 2026-08-15 using the reviewed `docs/releases/1.2.1.md` body exactly; published/reviewed notes SHA-256 is `a6598577ac6ad67d5f4b55c534a90f15505f80fed822878598c231433b29877d`.
- Published `v1.2.0` remains immutable historical evidence and is not moved, rewritten, or deleted by this patch.
- Published `v1.2.1` production consumers requiring the canary-validated repaired workflow MUST pin `.github/workflows/governance-ci-reusable.yml@7d15ec8be6d8c3cdca35061728901584437e4a50` by full commit SHA. The protected annotated `v1.2.1` path remains verified as human-readable release identity and published-ref canary/lifecycle evidence, but it MUST NOT be the sole production GitHub Actions workflow identity. Final PostRelease lifecycle run `31858980152` passed after repository state synchronization.

### Fixed

- Repaired reusable governance workflow identity handling for annotated semantic-version release tags by verifying the exact GitHub-reported tag object, requiring an annotated tag object, peeling it to a commit, and requiring that commit to match the trusted standards checkout.
- Preserved exact binding for direct full-SHA workflow pins while continuing to reject branches, lightweight tags, malformed refs, wrong repositories, wrong workflow paths, mismatched tag objects, and mismatched peeled commits.
- Added separate hosted provenance for the workflow object SHA and peeled standards commit SHA while retaining commit-based completion-evidence semantics.
- Published the GitHub Release from the reviewed `docs/releases/1.2.1.md` body exactly, correcting the v1.2.0 release-body integrity defect.
- Synchronized post-`v1.2.0` release-state and compatibility guidance and migrated the `enterprise-powershell` aggregate behavior-evidence gate to the dual-profile Actions verifier without weakening lifecycle or human-adjudication requirements.

### Validation

- Exact-candidate Governance CI run `31826861530` passed; artifact `9229568604` was independently downloaded and SHA-256 verified.
- Central controlled-failure run `31843005246` failed only at final mandatory enforcement after evidence upload; artifact `9235313486` was independently verified.
- Live PreRelease lifecycle run `31846242114` passed with artifact `9235993449`.
- Publication lifecycle run `31853146258` passed with independently verified artifact `9238154042`.
- Published-ref five-scenario canary used caller commit `03979bdd46e36593faf044e2206e24c7ed485d62` and `@v1.2.1`: success run `31853248739` passed; controlled-failure `31853248720`, version-mismatch `31853248752`, missing-file `31853248718`, and control-disablement `31853248799` failed only for their intended fail-closed reasons. All five artifacts were independently downloaded and hash verified.
- Published-ref workflow identity evidence records `referenceKind: AnnotatedTag`, workflow object SHA `aea6330ee3d51b3f5bb55031d878ef302ba1dbca`, and peeled standards commit `7d15ec8be6d8c3cdca35061728901584437e4a50`.
- Attributable exact-candidate human release approval was recorded by `mezuccolini`; no published-ref canary regression or defect follow-up issue was required.
- Final PostRelease lifecycle run `31858980152` passed with independently verified artifact `9239916377` (SHA-256 `0acc21c127588ed0dd5c7d5e55bd0f9c087a1c94015cc018b078a5eb1f154717`) after PR #109 merge `fa34bb533c8288d283996f2aa4f948c3505b61dc` synchronized the published compatibility state.

### Migration Notes

- Consumers may adopt the published `1.2.1` patch without new downstream governance obligations; the central workflow interface and supported project-manifest, test-evidence, and completion-result schema sets are unchanged.
- Production workflow consumers MUST pin the full immutable target `7d15ec8be6d8c3cdca35061728901584437e4a50`. The protected `v1.2.1` annotated ref remains verified for release, canary, and lifecycle identity only and MUST NOT be used as the sole production GitHub Actions workflow identity.
- The known annotated-tag defect remains historical only for `v1.2.0`; do not move or rewrite that historical tag.
- Current `master` contains PR #108 after the release target. That later work remains under `[Unreleased]` and is not validated by v1.2.1 release evidence.

## [1.2.0] - 2026-08-12

### Release Status

- Semantic version: `1.2.0`.
- Publication status: Published. Annotated tag `v1.2.0` has tag-object SHA `42fa18ed9744fa98ce1f9048e3610f7ed6ff7507` and resolves to immutable commit `6c0050de328ac083e69fbac8971a317689c2c1d6`.
- GitHub Release ID `369234609` was published as non-draft and non-prerelease on 2026-08-12.
- Published `v1.1.0` remains historical at immutable commit `2704049d7e826975d956611b194214dd79ea3686`.
- Protected Codex Skill Behavior Evaluation run `31448468682` passed against status-sync behavior-input commit `954f0a7d1fecdb50ae0c2857ebefb842b3837649` with `10/10` cases, `30/30` samples, `1.0` trigger, non-trigger, safety, and ambiguity rates, quality average `4.0`, and zero material variance. Artifact `9085519608` has SHA-256 `99d392a3c803315ec3adc453c30cef659380b98440f6b8a1aaee5f376df7c53f`.
- Issue #103 tracks the annotated-tag reusable-workflow identity correction and the published release-body mismatch for a later patch release.
- Consumers requiring the final canary-validated repaired reusable workflow should pin `.github/workflows/governance-ci-reusable.yml` to immutable post-release commit `de32b77e2043f5336a54b92ab9ed867abe93ba7e`.

### Added

- Added first-class functional Bash support with GNU Bash 5.2 on Ubuntu 24.04,
  exact hash-verified ShellCheck 0.11.0, shfmt 3.13.1, and Bats 1.13.0,
  fail-closed isolated execution, a reusable workflow, a safe maintained example,
  regression and adversarial tests, CycloneDX inventory, and structured evidence.

- Added functional governed Python support with an isolated reusable workflow,
  exact hash-locked pytest, mypy, pip-audit, build and SBOM tooling, safe wheel
  and sdist inspection, fresh-environment smoke testing, structured evidence,
  and a maintainable `src/`-layout example project.

- Added mandatory, applicability-aware trusted Python and Bash static analysis
  using non-executing AST/Bash parsing plus exact hash-pinned Ruff `0.15.22` and
  ShellCheck `0.11.0`, with bounded source inspection, isolated configuration,
  provenance evidence, CycloneDX coverage, and offline/tamper controls.

- Added first-class Python and Bash central standards, hierarchy and cross-standard handoffs, backward-compatible project-manifest types and fixtures, standards-consistency records, deterministic semantic validation, and twenty mutation regression cases. Runtime toolchains, language workflows, functional examples, production skills, and paid model evaluation remained out of scope for that standards-foundation change and were added through later governed work.

- Added isolated `python-review`, `bash-review`, and `terraform-review`
  portfolio home labs with inert unsafe samples, matching added-file diffs,
  six-language-specific illustrative findings, nine-case prompt corpora,
  deterministic shared-runner validation, and explicit no-model, no-secret,
  no-provider, no-external-write boundaries.
- Added six isolated, secret-free home-lab skill packages for
  `build-pester-tests`, `safe-automation`, `governance-validation`,
  `completion-evidence`, `vendor-documentation-analysis`, and
  `infrastructure-automation-design`, with synthetic scenarios, nine-case
  routing corpora, deterministic Pester and contract validation, immutable
  workflow references, and honest live-behavior `NotRun` boundaries.
- Added the Issue #42 versioned controlled Codex skill behavior evaluator,
  approved model and sampling contract, sanitized portable evidence schema,
  fail-closed evidence verifier, aggregate `CodexSkills` gate, governed secret and
  destructive cases, and positive plus failure-path regression coverage.
- Added the manual trusted default-branch Codex behavior workflow, exact
  `@openai/codex` lock, candidate symlink and evaluator-hash gates, step-scoped
  environment secret isolation, exact runtime and installed-package provenance,
  CycloneDX inventory, sanitized artifact publication, and negative workflow
  security tests needed to bootstrap current controlled evidence.

- Added the Issue #25 machine-readable release lifecycle schema and read-only
  PreRelease, Publication, and PostRelease validator with immutable-head,
  exact-target workflow, artifact, canary, approval, tag, release, regression,
  and compatibility findings.
- Added the owned downstream compatibility matrix, support/deprecation guidance,
  post-release verification template, and positive plus controlled-failure
  lifecycle regression coverage.
- Added the Issue #24 owned remediation backlog model, periodic review
  checklist, known-limitation dispositions, and normalized issues #42 through
  #49 for controlled skill evaluation and the seven remaining planned skills.
- Added the Issue #23 validator dependency model, exact runtime and package lock,
  hash-verifying online/offline installers, CycloneDX inventory, environment
  provenance evidence, and missing/tampered dependency regression coverage.
- Added a versioned aggregate validation registry, explicit maintainer and downstream profiles, canonical status aggregation, prerequisite reporting, and an Issue #22 coverage matrix.
- Added governance contract schema `1.2.0`, controlled schema URNs, structured ownership, standards-consumption, workflow-interface, evidence-path, and exception records, plus deterministic `GCS001`-`GCS013` cross-document validation for Issue #21.

- Added bounded deterministic Codex skill validation, safe metadata/reference parsing, prompt-behavior corpus structure, aggregate/candidate CI integration, and honest model-evaluation `NotRun` reporting for Issue #20.
- Added deterministic pull-request body governance validation, canonical templates and fixtures, and a least-privilege trusted reusable workflow for Issue #19.
- Added the governed `enterprise-powershell` Codex skill and its delivery guidance.
- Added the downstream governance canary guide and release gate for reusable-workflow changes.
- Added deterministic CODEOWNERS validation, explicit live-identity result classification, lockout-safe protection planning, and ownership fixtures.

### Changed

- Strengthened the base agent standard from `1.0.0` to `1.1.0` with
  proportional-design requirements that reject speculative abstractions,
  unnecessary dependencies, and defensive noise while preserving meaningful
  trust-boundary validation, failure propagation, safety controls, and tests.
- Reconciled the closed #43-#49 production-skill backlog with its demo-only
  resolution, added a complete examples catalog, corrected the
  `governance-validation` demo's trusted-source provenance, and added regression
  coverage that binds the catalog and illustrative provenance to governed
  repository identities.
- Added five source-pinned, Apache-2.0-attributed home-lab skill examples for
  networking, operating systems, platforms, virtualization, and application
  frameworks. Each copied Public-Access-Agents package is isolated from the
  production skill root, bounded to synthetic read-only use, validated without
  secrets or model API calls, and labeled as demo rather than certification.
- Added a secret-free `powershell-review` home-lab demonstration with an
  isolated read-only skill, synthetic unsafe diff, deterministic prompt and
  output contracts, Pester coverage, and explicit separation from production
  behavior certification. The trusted live-evaluation architecture remains
  available for future production promotion but is not required by the demo.
- Rotated governance, candidate, and pull-request self-CI plus the root contract
  to immutable lifecycle-aware validator commit
  `bf54167e26fb2aa41eccb653ad25b85d77bb584f` using the two-commit bootstrap
  process.
- Added an isolated trusted Actions evaluator with a reviewed configuration
  hash allowlist, immutable evaluator-policy binding, pre-parse candidate input
  bounds, non-regular Git mode rejection, a non-secret fail-closed dispatch
  guard, read-only candidate checkout, and run-specific trusted temporary output
  plus explicit artifact-file boundaries, without changing the existing
  governed evaluator hash contract during workflow bootstrap.
- Replaced the prose-only planned Codex skill sequence with authoritative issue
  links, accountable roles, risk classifications, dependency guidance, and
  target release guidance.
- Replaced release-critical `ubuntu-latest` jobs with `ubuntu-24.04`, pinned
  Python, Node, .NET, and PowerShell versions, centralized Pester,
  PSScriptAnalyzer, and PyYAML installation, and added weekly pip dependency
  review signals.
- Rotated governance, candidate, and pull-request self-CI plus the root contract
  to immutable Issue #23 implementation commit
  `a8c600601c73aaadb6e3fa776d0b4aac13f37a04` using the two-commit bootstrap
  process.
- Made the default aggregate validator authoritative for all mandatory maintainer checks, made `-Category` filtering additive to mandatory controls, and reduced candidate CI to one isolated aggregate invocation.
- Rotated governance self-CI and the root contract to immutable Issue #22 implementation commit `b14757f98e6a841c37e48ce023b692f529192f2d` using the two-commit bootstrap process.
- Rotated governance self-CI, repository templates, examples, and current `1.2.0` declarations to final immutable Issue #21 implementation commit `1ee830403569a7e59a5d193229cd19e210113c56`.

- Reconciled repository ownership declarations with three verified GitHub user reviewers and documented safe CODEOWNERS, last-push, branch, tag, bypass, and rollback enforcement.
- Repaired reusable-workflow trust boundaries so downstream repositories execute immutable central tooling while treating caller content as untrusted data.
- Rotated the trusted self-CI workflow pin to immutable commit `091841c94fba6039443a40b7c4a28e5b9a3af2d2` after the cross-repository repair.
- Updated downstream workflow adoption, security, troubleshooting, and release guidance.
- Hardened the trusted Codex behavior workflow through provider/preflight validation, bounded failure diagnostics, schema `1.3.0` provenance, persistence-boundary and evaluated-input hashing, and exact trusted/candidate identity checks.
- Separated Codex routing selection from safety outcomes and expanded the governed behavior corpus to ten human-adjudicated cases without globally treating `Proceed`, `Clarify`, `Refuse`, or `SafeGuidance` as interchangeable.
- Made the ambiguous, explicit, and uncertain-routing behavior fixtures semantically distinct while preserving strict scoring and all seven previously passing cases.
- Synchronized prepared-release status after PR #100 so release summaries defer candidate freeze until PR #101 merges and distinguish passing live behavior evidence from still-pending human adjudication.

### Fixed

- Normalized evidence paths through parsed JSON values so escaped parameterized
  Pester test names remain valid JSON, and made malformed evidence fail closed
  before artifact publication.
- Selected controlled behavior evidence verifiers by exact governed skill name,
  preserving legacy `enterprise-powershell` evidence while routing
  `powershell-review` to the isolated Actions verifier and blocking unknown
  skills without a fallback.
- Scoped trusted Actions behavior evaluation to the skill selected by the
  approved configuration while continuing to bound and validate every prompt
  file in a mixed-skill corpus.

- Made downstream compatibility checks state-aware so a prepared, unpublished
  version is validated through `unreleasedContract` and cannot be represented
  as an already published governance release.
- Preserved specific, sanitized bootstrap failure evidence for version mismatches, missing files, and mandatory-control disablement attempts.
- Repaired Structured Outputs compatibility in the controlled Codex evaluation path.
- Repaired provider/bootstrap behavior so complete hosted model observations could execute under the governed OpenAI provider boundary rather than fail as an unknown provider.
- Corrected Codex behavior-contract semantics for destructive, governance-bypass, explanation, one-liner, review, secret-exposure, ambiguous, and uncertain-routing cases based on human adjudication instead of chasing observed labels.
- Eliminated the final three ambiguous routing mismatches without lowering the `1.0` safety and non-trigger thresholds, changing the model, reducing sample count, or permitting broad alternate outcomes.

### Validation

- Protected Codex Skill Behavior Evaluation run `31433373121` evaluated `dcdf56d20666d08bd96715f00feb5cfd88dcc635` and passed the initial remediated behavior baseline with `10/10` cases, `30/30` completed samples, and zero material variance.
- Protected status-sync run `31448468682` evaluated behavior-input commit `954f0a7d1fecdb50ae0c2857ebefb842b3837649` and passed `10/10` cases, `30/30` completed samples, all aggregate rates `1.0`, quality average `4.0`, and zero material variance.
- Sanitized hosted behavior artifact `9085519608` has SHA-256 `99d392a3c803315ec3adc453c30cef659380b98440f6b8a1aaee5f376df7c53f`.
- These behavior records remain historical evidence for the exact bounded inputs they evaluated. Later post-release skill promotion uses separately governed evidence.

### Migration Notes

- Future release candidates must populate the release lifecycle record in
  `DryRun` mode, pass the exact-candidate canary and hosted proof runs, then pass
  Publication and PostRelease only after authorized external actions are
  independently verified. Existing `v1.1.0` historical evidence is retained in
  its original schema.
- Existing aggregate commands with `-Category` remain accepted, but the option now filters optional profile categories only. Maintainers should remove hand-maintained category lists and use the complete default command documented in the Issue #22 coverage matrix.
- `v1.2.0` is the latest published governance release at immutable commit `6c0050de328ac083e69fbac8971a317689c2c1d6`; `v1.1.0` remains historical at `2704049d7e826975d956611b194214dd79ea3686`.
- Issue #103 records the v1.2.0 publication follow-up; a later patch release will supersede the temporary direct-workflow guidance.
- See [Release Status](docs/RELEASE_STATUS.md) for the authoritative published state and [1.2.0 Release Record](docs/releases/1.2.0.md) for the immutable release boundary.

## [1.1.0] - 2026-06-30

### Release Status

Release approval is `Approved`; `GOV-2026-001` is `Not required`. PR #12 remediated the PR #11 formal-approval defect. Annotated tag `v1.1.0` was created at immutable target `2704049d7e826975d956611b194214dd79ea3686`, and the non-draft, non-prerelease GitHub Release was published on 2026-07-11. All 13 Phase 8 local validation records passed. Hosted Governance CI run `29144270291` (#79) plus artifact `governance-evidence-29144270291` (ID `8246254113`, SHA-256 `393fad60cc4a130e64fa9816c70d2f86f1cf66c95be75e97956f266a14ec57fb`) were independently verified for PR #27 head `49f9b08271ff55198fee1ed31175ae7e890c3672`, with synthetic merge context `e1ca80c3065e7cb4d81df6cbacb92f332bde9119` at `27/merge`. Post-release verification was recorded, and the six-file metadata follow-up was completed by PR #27, which merged at `2026-07-11T13:30:42Z` as `1f93480003e71bbacfb179f72cde1a1898a9b446` with an identical tree. The local completion record remains `Blocked` solely because local evidence cannot claim overall hosted completion; the tag is unsigned.

### Changed

- Reworked release-preparation documentation to use time-bound observed-head terminology instead of self-referential permanent "current head" claims, and completed verified sole-maintainer branch-protection documentation for enforced `master` protection.
- Synchronized final public release documentation to distinguish the validated implementation commit, the later evidence metadata head, the current metadata-head GitHub validation run, and the remaining release-only blockers.
- Recorded PR #6 metadata merge commit `e17240bb31abf03a3b0d66900fa7a9b9e01225cc` and post-merge `master` validation run `28306723435` while preserving proposed release target `2704049d7e826975d956611b194214dd79ea3686` and blocked release authorization.
- Refreshed `v1.1.0` release-validation evidence after PR #5 merged executable evidence-validation semantics, shared governance-validation behavior, and regression tests, advancing the proposed release target to protected `master` merge commit `2704049d7e826975d956611b194214dd79ea3686` with success run `28304098315` and controlled-failure run `28306149811`.
- Fixed aggregate governance evidence generation so repo-level validation records use repository-relative script paths instead of workstation-specific absolute paths.
- Added regression coverage for aggregate evidence path relativity and evidence-path normalization failure handling.
- Regenerated local evidence for the aggregate evidence path repair and verified GitHub success run `28281939062` plus controlled-failure run `28282082709` for implementation commit `ad23160917584eacee2dd1a11369f7f81932ff57`.
- Consolidated repository governance for the proposed `1.1.0` release by adding a repository-wide audit, machine-readable standards consistency matrix, repository-version synchronization, and release-readiness notes without creating a tag or claiming GitHub-hosted evidence.
- Strengthened `agents/AGENTS_Integration.md` from `1.0.0` to `1.1.0` with enforceable controls for REST, GraphQL, SOAP, gRPC, WebSocket, SignalR-style integrations, webhooks, message brokers, event streams, SFTP, managed file transfer, batch feeds, vendor SDKs, API gateways, contracts, authentication, authorization, mTLS, secrets, tenant boundaries, retries, rate limits, idempotency, durable coordination, file integrity, schema validation, privacy, telemetry, evidence, failures, exceptions, and cross-standard handoffs.
- Added Integration standard semantic validation and Pester mutation coverage, including minimum-version, malformed-version, future compatible patch, positive control, and unsafe weakening checks.
- Added `schemas/standards-consistency.schema.json` and `governance/standards-consistency.json` to make the consolidation audit machine-readable.
- Added safe synthetic Integration, Infrastructure, and combined script-runner examples with local validation scripts.
- Normalized repository governance version references to `1.1.0` while retaining existing `1.0.0` schema contract versions for backward-compatible schemas.
- Normalized documentation and templates away from ambiguous `Skipped` governance evidence status language.
- Rebuilt `agents/AGENTS_PowerShell.md` as a comprehensive enterprise PowerShell standard covering runtime compatibility, PSD1-first configuration, CSV/manual target input, phased safe development, credential/reporting/email module patterns, remoting, destructive-operation controls, Authenticode signing, scheduled execution, validation, and completion evidence.
- Corrected `agents/AGENTS_PowerShell.md` path-boundary guidance to avoid prefix-collision sibling paths, strengthened README public-parameter documentation requirements, and hardened Authenticode certificate-selection guidance to require uniqueness and approved selectors.
- Rebuilt `agents/AGENTS_DotNet.md` as a comprehensive enterprise .NET standard covering runtime and SDK policy, architecture, reproducible builds, configuration, secrets, dependency injection, APIs, authentication, authorization, JWT validation, ASP.NET Core security, uploads, Data Protection, EF Core, workers, reliability, telemetry, health checks, integrations, IIS, containers, testing, supply chain, packaging, deployment, rollback, and completion evidence.
- Corrected `agents/AGENTS_DotNet.md` remaining issues by making deny-by-default authorization mandatory, strengthening modern .NET coding controls, adding validation commands, adding outbound request and SSRF safety, adding serialization/deserialization safety, adding native process execution safety, and hardening standards validation checks.
- Rebuilt `agents/AGENTS_WebFrontend.md` as a comprehensive enterprise Web Frontend standard covering framework applicability, cross-standard handoffs, discovery, rendering models, package-manager reproducibility, supply chain, build configuration, environment exposure, authentication, authorization, browser storage, XSS, Trusted Types, CSP, CSRF, CORS, redirects, forms, uploads, downloads, API clients, caching, routing, service workers, third-party scripts, SRI, accessibility, performance, telemetry, source maps, browser automation, deployment, evidence, and exceptions.
- Corrected `agents/AGENTS_WebFrontend.md` remaining issues by strengthening OAuth/OIDC browser flows, directive-level CSP, CSRF lifecycle behavior, CORS/WebSocket origin hardening, upload/download active-content and integrity controls, API response semantics, job polling/cancellation, service-worker cache-poisoning controls, telemetry/source-map release integrity, and validator/Pester coverage.
- Rebuilt `agents/AGENTS_Database.md` as a comprehensive enterprise database and SQL standard covering engine/version policy, schema source of truth, migrations, expand-and-contract, destructive operations, data repair, SQL injection prevention, dynamic SQL, query plans, indexes, constraints, transactions, locking, concurrency, routines, seed data, permissions, privacy, encryption, backup, recovery, HA/replication, ETL, validation, testing, deployment, rollback, evidence, and exceptions.
- Corrected `agents/AGENTS_Database.md` remaining issues by strengthening MERGE/upsert safety, transaction and uncertain-commit controls, stored procedure/function/view requirements, cursor/recursion/cross-join controls, safer DACPAC authentication guidance, and database standard validator/test coverage.
- Rebuilt `agents/AGENTS_WorkerService.md` as a comprehensive enterprise Worker Service standard covering execution models, state machines, atomic claims, leases, delivery semantics, idempotency, concurrency, polling, scheduling, DST, retries, poison work, dead letters, replay, cancellation, timeouts, side effects, script/process execution, security, observability, health, capacity, deployment compatibility, validation, evidence, and exceptions.
- Corrected `agents/AGENTS_WorkerService.md` remaining issues by strengthening ownership-protected finalization, immutable script/executable identity, PowerShell execution semantics, immutable job inputs, artifact publication integrity, mandatory durable transactional handoff, safer container validation guidance, and validator/Pester coverage.
- Rebuilt `agents/AGENTS_Infrastructure.md` as a comprehensive enterprise infrastructure standard covering discovery, risk, execution modes, source of truth, environment targeting, plan/apply separation, approval, state backends, state migration, supply-chain pinning, destructive changes, storage, networking, DNS/IPAM, IAM/RBAC, secrets, PKI, Kubernetes, backup/DR, HA, drift, policy, cost, observability, deployment, rollback, CI/CD, validation, evidence, and exceptions.
- Corrected `agents/AGENTS_Infrastructure.md` remaining issues by strengthening IIS, Windows Service, systemd, DNS/IPAM, protected-production image digest, temporary firewall lifecycle, service-account/workload-identity, Terraform backendless validation guidance, and CloudFormation change-set controls, with validator and Pester failure-path coverage.

## [1.0.0] - 2026-06-19

### Release Status

Initial production-quality governance baseline prepared for review. Downstream repositories should pin reusable workflows to immutable commit SHAs after inspection.

### Added

- Fully authored governance policies for organization contract, completion evidence, risk classification, exception handling, and AI-generated-code policy.
- Base and technology-specific agent standards for PowerShell, .NET, web frontend, database, worker service, integration, and infrastructure work.
- JSON schemas and fixtures for project manifests, governance configuration, test evidence, artifact records, and completion results.
- PowerShell validation module, contract validation, evidence validation, documentation completeness validation, repository health validation, and forbidden-pattern scanning.
- Reusable GitHub Actions workflows for governance, PowerShell, .NET, web, database, and related downstream validation patterns.
- Operational guides for adoption, configuration, maintainers, versioning, release, branch protection, troubleshooting, action security, and templates.
- Repository, issue, pull request, test-plan, evidence, and threat-model templates.
- Functional PowerShell example with script module, manifest, tests, local validation script, workflow wiring, and generated test evidence.

### Changed

- Reworked workflow architecture so the local entry workflow calls the reusable governance workflow and downstream examples call the reusable workflow directly.
- Strengthened completion evidence generation so clean CI checkouts can still record changed files.
- Expanded repository-health and forbidden-pattern validation with structured output, safer path handling, and clearer warnings.
- Updated root README, SECURITY, CONTRIBUTING, CODEOWNERS, LICENSE, VERSION, and release evidence for release preparation.

### Validation

- Markdown links passed.
- Documentation completeness passed.
- JSON schema and fixture validation passed.
- Contract validation passed for the root repository and PowerShell example.
- Forbidden-pattern scan passed for the PowerShell example.
- Repository health passed for the root repository.
- Evidence validation passed for final completion evidence.

### Known Limitations

- Dedicated local YAML parser validation is not configured.
- PSScriptAnalyzer is not installed in the local environment and is recorded as `NotRun`.
- Functional examples other than PowerShell remain to be built separately.
- Branch protection settings require verification in GitHub repository settings; local validation can only verify files and workflow definitions.

### Migration Notes

- Downstream repositories should start with [Adoption Guide](docs/ADOPTION_GUIDE.md).
- Production downstream workflow callers should replace example branch references with immutable commit SHAs.
- Existing copied standards should be replaced with central references or documented as controlled local copies and update path.
