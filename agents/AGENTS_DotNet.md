# AGENTS .NET Standard

| Field | Value |
| --- | --- |
| Status | Active |
| Version | 1.0.0 |
| Owner role | Engineering Standards Maintainers |
| Last reviewed | 2026-06-19 |
| Changelog | See [../CHANGELOG.md](../CHANGELOG.md). |

## Purpose

This document defines enterprise requirements for AI agents working on .NET applications, services, libraries, APIs, command-line tools, background workers, and test projects. It inherits [AGENTS_Base.md](AGENTS_Base.md) and adds .NET-specific controls for architecture, security, dependency management, validation, deployment, and evidence.

## Applicability

This standard applies to `.sln`, `.csproj`, `.fsproj`, `.vbproj`, source files, test projects, package configuration, NuGet lockfiles, ASP.NET Core services, worker services, shared libraries, analyzers, source generators, EF Core migrations, Dockerfiles that build .NET apps, and CI workflows that restore, build, test, package, or publish .NET artifacts.

## Required Discovery

Before editing, agents MUST identify:

- Solution and project layout.
- Target frameworks and supported runtime versions.
- Nullable reference type settings.
- Warnings-as-errors and analyzer configuration.
- Package references, central package management, lockfiles, and private feeds.
- Configuration providers and secret handling.
- Authentication, authorization, identity, cryptography, logging, and telemetry.
- EF Core or other migration tooling.
- Test projects, integration-test dependencies, and CI commands.
- Deployment model, containers, health checks, and rollback expectations.

Agents MUST inspect relevant project files before adding packages or changing build behavior.

## Risk Classification

.NET changes are High or Critical when they affect authentication, authorization, token validation, cryptography, secrets, dependency execution, production configuration, data access, migrations, payment flows, identity, public APIs, or release packaging. Generated .NET code in these areas requires heightened review under [../governance/AI_GENERATED_CODE_POLICY.md](../governance/AI_GENERATED_CODE_POLICY.md).

Low-risk cosmetic refactors can remain Low only when tests and behavior are unchanged. Any change to service behavior, persistence, external contracts, or deployment should be at least Moderate.

## Implementation Requirements

Agents MUST follow existing architecture and framework patterns. New code SHOULD use dependency injection, options binding with validation, nullable reference types, asynchronous APIs where appropriate, cancellation tokens for I/O, structured logging, and explicit error handling.

Agents MUST NOT introduce service locators, hidden static mutable state, synchronous-over-async blocking, broad exception swallowing, plaintext secrets, or configuration defaults that connect to production.

Public APIs and controllers MUST validate inputs, enforce authorization server-side, avoid overposting, return intentional status codes, and avoid leaking sensitive exception details. Libraries SHOULD preserve binary and source compatibility unless a breaking change is intentional and documented.

## Configuration And Secrets

Secrets MUST come from approved configuration providers, secret stores, managed identity, or deployment environment. Agents MUST NOT commit real values in `appsettings*.json`, user secrets files, launch profiles, Dockerfiles, test fixtures, or evidence.

Configuration changes SHOULD include validation through `IValidateOptions<T>`, data annotations, startup checks, or equivalent. Sensitive configuration MUST be redacted from logs.

## Dependency And Supply Chain

Agents MUST review new or upgraded NuGet packages for purpose, license, source, vulnerability status, transitive dependencies, and runtime behavior. Projects using lockfiles SHOULD restore with locked mode in CI.

Package additions MUST be justified by real need. Do not add a large framework or helper library for trivial behavior that the platform already supports.

## Data Access And EF Core

Data access code MUST use parameterized queries or safe ORM APIs. EF Core migrations MUST include forward behavior, rollback or mitigation notes, data classification, and production-impact assessment.

Agents MUST consider transaction boundaries, locking, query performance, indexes, N+1 behavior, and data retention. Destructive migrations are Critical by default.

## Observability

.NET services SHOULD provide structured logs, health checks, metrics, and correlation identifiers. Logs MUST NOT include secrets, tokens, raw regulated data, or full sensitive payloads. Exception handling SHOULD preserve diagnostic context without exposing internal details to users.

## Testing Requirements

Behavior changes SHOULD include unit tests. API, data access, authorization, serialization, configuration, and integration behavior SHOULD have targeted tests. Security-sensitive changes MUST include negative tests where feasible.

Recommended validation:

```powershell
dotnet restore --locked-mode
dotnet format --verify-no-changes
dotnet build -warnaserror
dotnet test --no-build
dotnet list package --vulnerable
```

If lockfiles, format tools, or vulnerability feeds are unavailable, record `NotRun` or `Blocked` with the reason.

## Deployment And Release

Packaging and publishing changes MUST identify artifact type, versioning, signing, container base image, runtime environment, and rollback. Production configuration and deployment changes require completion evidence and approval appropriate to risk.

## Evidence

Evidence MUST include executed `dotnet` commands, SDK version, target frameworks affected, test counts, package audit result or `NotRun` reason, migration validation when applicable, and remaining risks. Evidence MUST NOT claim `Passed` when build, test, restore, audit, or migration validation did not run.

## Failure Behavior

The work is incomplete if build fails, tests fail, nullable or analyzer warnings are hidden, migrations lack rollback analysis, secrets are introduced, authorization tests are missing for authorization changes, or package risks are unreviewed.

## Related Documents

- [AGENTS_Base.md](AGENTS_Base.md)
- [AGENTS_WorkerService.md](AGENTS_WorkerService.md)
- [AGENTS_Database.md](AGENTS_Database.md)
- [../governance/ORGANIZATION_CONTRACT.md](../governance/ORGANIZATION_CONTRACT.md)
- [../governance/COMPLETION_EVIDENCE.md](../governance/COMPLETION_EVIDENCE.md)

## Exception Handling

Exceptions MUST follow [../governance/EXCEPTION_PROCESS.md](../governance/EXCEPTION_PROCESS.md). Missing SDKs, unavailable package feeds, or absent integration environments MUST be recorded honestly and MUST NOT be converted into success.
