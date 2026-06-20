# Changelog

All notable changes to the Engineering Standards repository are recorded here. This project follows [Versioning](docs/VERSIONING.md) and the release process in [Release Process](docs/RELEASE_PROCESS.md).

## [Unreleased]

### Changed

- Rebuilt `agents/AGENTS_PowerShell.md` as a comprehensive enterprise PowerShell standard covering runtime compatibility, PSD1-first configuration, CSV/manual target input, phased safe development, credential/reporting/email module patterns, remoting, destructive-operation controls, Authenticode signing, scheduled execution, validation, and completion evidence.
- Corrected `agents/AGENTS_PowerShell.md` path-boundary guidance to avoid prefix-collision sibling paths, strengthened README public-parameter documentation requirements, and hardened Authenticode certificate-selection guidance to require uniqueness and approved selectors.
- Rebuilt `agents/AGENTS_DotNet.md` as a comprehensive enterprise .NET standard covering runtime and SDK policy, architecture, reproducible builds, configuration, secrets, dependency injection, APIs, authentication, authorization, JWT validation, ASP.NET Core security, uploads, Data Protection, EF Core, workers, reliability, telemetry, health checks, integrations, IIS, containers, testing, supply chain, packaging, deployment, rollback, and completion evidence.

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
