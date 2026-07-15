# Changelog

All notable changes to the Engineering Standards repository are recorded here. This project follows [Versioning](docs/VERSIONING.md) and the release process in [Release Process](docs/RELEASE_PROCESS.md).

## [Unreleased]

### Added

- Added a versioned aggregate validation registry, explicit maintainer and downstream profiles, canonical status aggregation, prerequisite reporting, and an Issue #22 coverage matrix.
- Added governance contract schema `1.2.0`, controlled schema URNs, structured ownership, standards-consumption, workflow-interface, evidence-path, and exception records, plus deterministic `GCS001`-`GCS013` cross-document validation for Issue #21.

- Added bounded deterministic Codex skill validation, safe metadata/reference parsing, prompt-behavior corpus structure, aggregate/candidate CI integration, and honest model-evaluation `NotRun` reporting for Issue #20.
- Added deterministic pull-request body governance validation, canonical templates and fixtures, and a least-privilege trusted reusable workflow for Issue #19.
- Added the governed `enterprise-powershell` Codex skill and its delivery guidance.
- Added the downstream governance canary guide and release gate for reusable-workflow changes.
- Added deterministic CODEOWNERS validation, explicit live-identity result classification, lockout-safe protection planning, and ownership fixtures.

### Changed

- Made the default aggregate validator authoritative for all mandatory maintainer checks, made `-Category` filtering additive to mandatory controls, and reduced candidate CI to one isolated aggregate invocation.
- Rotated governance self-CI, repository templates, examples, and current `1.2.0` declarations to final immutable Issue #21 implementation commit `1ee830403569a7e59a5d193229cd19e210113c56`.

- Reconciled repository ownership declarations with three verified GitHub user reviewers and documented safe CODEOWNERS, last-push, branch, tag, bypass, and rollback enforcement.
- Repaired reusable-workflow trust boundaries so downstream repositories execute immutable central tooling while treating caller content as untrusted data.
- Rotated the trusted self-CI workflow pin to immutable commit `091841c94fba6039443a40b7c4a28e5b9a3af2d2` after the cross-repository repair.
- Updated downstream workflow adoption, security, troubleshooting, and release guidance.

### Fixed

- Preserved specific, sanitized bootstrap failure evidence for version mismatches, missing files, and mandatory-control disablement attempts.

### Migration Notes

- Existing aggregate commands with `-Category` remain accepted, but the option now filters optional profile categories only. Maintainers should remove hand-maintained category lists and use the complete default command documented in the Issue #22 coverage matrix.
- `v1.1.0` remains the latest published release and does not contain these changes. Consumers needing that control set may use tag `v1.1.0` at `2704049d7e826975d956611b194214dd79ea3686`.
- Consumers requiring the final canary-validated repaired reusable workflow should pin `.github/workflows/governance-ci-reusable.yml` to immutable post-release commit `de32b77e2043f5336a54b92ab9ed867abe93ba7e`.
- See [Release Status](docs/RELEASE_STATUS.md) for the authoritative published-versus-unreleased boundary.

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
- Corrected `agents/AGENTS_Infrastructure.md` remaining issues by strengthening IIS, Windows Service, systemd, DNS/IPAM, protected-production image digest, temporary firewall lifecycle, service-account/workload-identity, Terraform backendless validation, and CloudFormation change-set controls, with validator and Pester failure-path coverage.

## [1.0.0] - 2026-06-19

### Release Status

Initial production-quality governance baseline prepared for review. Downstream repositories should pin reusable workflows to immutable commit SHAs after inspection.

### Added

- Fully authored governance policies for organization contract, completion evidence, risk classification, exception handling, and AI-generated code.
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
- Existing copied standards should be replaced with central references or documented as controlled local copies.
