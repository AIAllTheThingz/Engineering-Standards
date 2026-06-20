# AGENTS .NET Standard

| Field | Value |
| --- | --- |
| Status | Active |
| Version | 1.1.0 |
| Owner role | Engineering Standards Maintainers |
| Last reviewed | 2026-06-20 |
| Changelog | See [../CHANGELOG.md](../CHANGELOG.md). |

## Purpose

This document defines enforceable enterprise requirements for AI agents creating or modifying .NET applications, services, libraries, tests, build tooling, release tooling, and deployment assets. It inherits [AGENTS_Base.md](AGENTS_Base.md), the repository-root [../AGENTS.md](../AGENTS.md), and the governance documents. It adds .NET-specific controls for runtime support, architecture, configuration, security, authentication, authorization, data access, hosting, packaging, validation, and completion evidence.

This standard avoids vague best-practice language. When it says a control is required, downstream agents MUST either implement the control, prove it already exists, or record a valid `NotApplicable`, `NotRun`, `Blocked`, or approved exception.

## Applicability And Inheritance

This standard applies to:

- ASP.NET Core APIs, MVC, Razor Pages, Blazor-hosted server components, and Minimal APIs.
- Worker Services, Windows Services, queue consumers, hosted services, scheduled jobs, and long-running daemons.
- Console applications, class libraries, shared packages, analyzers, generators, test projects, and CLI tools.
- EF Core data access, migrations, seed data, migration bundles, and database deployment tooling.
- Identity, authentication, JWT issuance or validation, authorization policy, and session handling.
- IIS-hosted applications, containerized applications, static files served by ASP.NET Core, upload and download workflows, SMTP/email, external API clients, and CI/CD commands that restore, build, test, package, publish, deploy, or validate .NET artifacts.

When work crosses boundaries, agents MUST also apply the specialized standard:

- Database schema, data repair, migration, seed, and query work MUST apply [AGENTS_Database.md](AGENTS_Database.md).
- Background job, queue, schedule, idempotency, retry, and daemon lifecycle work MUST apply [AGENTS_WorkerService.md](AGENTS_WorkerService.md).
- External API, SMTP, webhook, file-transfer, vendor SDK, contract, and credential-flow work MUST apply [AGENTS_Integration.md](AGENTS_Integration.md).
- Static HTML, CSS, JavaScript, TypeScript, browser storage, CSP, source maps, and frontend build work served by ASP.NET Core MUST apply [AGENTS_WebFrontend.md](AGENTS_WebFrontend.md).

Local instructions MAY strengthen this standard and MUST NOT weaken root, base, security, review, validation, evidence, or exception controls.

## Normative Terminology

`MUST` and `MUST NOT` are mandatory requirements. `SHOULD` and `SHOULD NOT` are expected requirements that require a recorded rationale when omitted. `MAY` is optional. `NotApplicable` means the validation category does not apply to the change. `NotRun` means the validation did not execute. `Blocked` means the validation could not complete because an external dependency, approval, credential, service, feed, browser, IIS host, container runtime, database, or environment was unavailable.

Agents MUST NOT convert unavailable SDKs, feeds, browsers, IIS hosts, containers, credentials, deployment targets, package audits, databases, or GitHub Actions into `Passed`.

## Required Discovery

Before editing .NET files, agents MUST inspect and record the relevant subset of:

- Solution, project, test, package, and folder layout.
- Target framework monikers, supported runtime versions, supported operating systems, runtime identifiers, hosting model, deployment model, and LTS versus STS support policy.
- Installed and selected SDK information from `dotnet --info` when the SDK is available.
- `global.json`, SDK `rollForward` behavior, `Directory.Build.props`, `Directory.Packages.props`, `NuGet.config`, lockfiles, private feeds, package source mapping, and central package management.
- Nullable, warnings-as-errors, analyzers, `.editorconfig`, formatting, deterministic build, SourceLink, symbols, signing, and package metadata.
- Configuration providers, options binding, options validation, secret sources, certificates, keys, Data Protection, environment names, and deployment configuration.
- ASP.NET Core middleware order, routing, authentication, authorization, Identity, JWT, CORS, CSRF, HTTPS/HSTS, cookies, rate limiting, static files, OpenAPI, health checks, logging, telemetry, and error handling.
- Data access technology, EF Core DbContext lifetime, migrations, seed data, query patterns, transaction boundaries, retries, command timeouts, and rollback or mitigation path.
- Worker lifecycle, hosted services, cancellation, retry, idempotency, leases, concurrency, poison handling, and readiness.
- External APIs, SMTP, webhooks, TLS behavior, typed clients, retry safety, sandbox availability, and contract tests.
- IIS hosting, container image, deployment artifact, runtime bundle, app pool identity, web.config, probes, ports, writable paths, and rollback behavior where applicable.
- Unit, integration, authorization, JWT, browser, Playwright, migration, upload, logging-redaction, package-audit, build, and deployment validation commands.

Agents MUST inspect existing project files before adding packages, changing target frameworks, altering build behavior, or modifying deployment assets.

## Risk Classification

.NET changes MUST be classified using [../governance/RISK_CLASSIFICATION.md](../governance/RISK_CLASSIFICATION.md). The change is High or Critical when it affects authentication, authorization, token validation, Identity, cryptography, secrets, certificates, dependency execution, public API behavior, production configuration, persistence, migrations, data protection, package signing, deployment, IIS, containers, payment flows, regulated data, or release automation.

Automatic escalation applies:

- Authorization, token validation, identity issuance, cryptography, key handling, certificate validation, production migration, and regulated-data export changes are Critical unless an accountable reviewer documents a lower classification.
- New packages, build execution changes, CI permission changes, container base image changes, IIS deployment changes, and generated code in security-sensitive areas are at least High until reviewed.
- Purely cosmetic refactors MAY be Low only when behavior, dependencies, public contracts, runtime support, deployment, and tests are unchanged.

Risk MUST be reclassified when scope expands, validation fails, an exception is requested, or previously unknown production/security/data impact is discovered.

## Supported .NET And SDK Versions

Every .NET project or service touched by an agent MUST declare:

- Target framework monikers such as `net8.0` or another supported TFM.
- Supported runtime versions and whether each is LTS or STS.
- Supported operating systems and any OS-specific APIs.
- Hosting and deployment model, such as Kestrel, IIS, Windows Service, container, console, library, Azure App Service, or job host.
- Runtime identifiers where self-contained, native AOT, platform-specific, or RID-specific publishing applies.
- SDK policy, including whether the repository uses `global.json`.
- `rollForward` behavior when SDK or runtime roll-forward can affect reproducibility or hosting compatibility.

Agents MUST NOT silently retarget frameworks. Framework upgrades MUST include package compatibility, hosting compatibility, deployment impact, CI impact, runtime availability, analyzer impact, rollback plan, and evidence. Agents MUST NOT introduce new end-of-support frameworks. Existing unsupported frameworks MUST be identified as risk, and untested compatibility MUST be recorded as `NotRun`, not `Passed`.

When reproducible SDK selection is required, repositories SHOULD use `global.json` and document intentional `rollForward` behavior. If `global.json` is absent, agents MUST state whether the repository intentionally floats to installed SDKs or whether SDK pinning is a gap.

## Solution And Project Architecture

Agents MUST preserve clear boundaries and dependency direction. Application, domain, API, infrastructure, persistence, integration, and test projects SHOULD be separated when the system size or risk justifies it. Small applications MAY remain simple, but simplicity MUST NOT become hidden coupling.

Agents MUST NOT introduce:

- Circular project references.
- Service locator patterns.
- Hidden static mutable state.
- Business logic embedded in controllers, endpoint lambdas, Razor Pages, adapters, hosted-service loops, middleware, or EF migrations when it belongs in reusable services.
- Giant `Common`, `Shared`, or `Utilities` dumping grounds without an explicit contract.
- Speculative layers, abstractions, factories, or generic frameworks that do not remove real complexity.

Architecture changes MUST include rationale, migration impact, tests, rollback or revert path, and compatibility notes. Public libraries MUST preserve source and binary compatibility unless a breaking change is intentional, versioned, and documented.

## Reproducible Builds

.NET repositories MUST support a clean-checkout build using documented commands. Builds SHOULD be deterministic where supported and MUST use explicit configuration such as `Release` or `Debug` rather than hidden defaults when evidence or CI depends on the result.

Agents MUST enforce:

- Locked restore where lockfiles are used.
- No floating or wildcard production package versions.
- No unapproved preview SDKs, runtimes, packages, templates, or workloads.
- No developer-machine-only dependencies.
- No remote download-and-execute build steps.
- Alignment between local and CI restore/build/test commands.
- Exclusion of `bin/`, `obj/`, coverage output, test results, package caches, and generated publish output from source control.
- SourceLink, symbol, and deterministic path policy where packages or release artifacts are produced.

If a build requires private feeds, workloads, native dependencies, certificates, or environment services, evidence MUST record the requirement and the command status honestly.

## Configuration And Options Validation

Configuration contracts MUST be explicit. New or changed configuration SHOULD use strongly typed options classes with startup validation through `ValidateOnStart`, `IValidateOptions<T>`, data annotations, custom validators, or equivalent fail-fast checks.

Agents MUST ensure:

- Missing critical configuration fails startup or validation before unsafe behavior occurs.
- Production behavior does not depend on hidden defaults.
- Configuration precedence is documented for `appsettings.json`, environment-specific files, environment variables, user secrets, command-line arguments, vaults, deployment settings, and CI variables.
- Environment names are validated and cannot silently select production behavior from a misspelling.
- Critical unknown or misspelled configuration keys are detected where practical.
- Sensitive configuration is redacted from logs, traces, exceptions, screenshots, and evidence.
- Synthetic example configuration exists for public keys and safe placeholders only.
- README, runbooks, deployment docs, and options classes remain synchronized.

Safe pattern:

```csharp
builder.Services
    .AddOptions<ExternalApiOptions>()
    .Bind(builder.Configuration.GetSection("ExternalApi"))
    .ValidateDataAnnotations()
    .Validate(options => options.TimeoutSeconds > 0, "TimeoutSeconds must be positive.")
    .ValidateOnStart();
```

Agents MUST NOT add production connection strings, tokens, private keys, certificate passwords, or live endpoint credentials to appsettings, launch profiles, examples, tests, logs, or evidence.

## Secrets, Keys, And Certificates

Secrets MUST come from approved secret stores, managed identity, certificate authentication, environment injection, or deployment vaults. `dotnet user-secrets` MAY be used only for local development and MUST NOT be treated as deployment configuration.

Agents MUST NOT place secrets in source, `appsettings*.json`, `launchSettings.json`, Dockerfiles, tests, fixtures, samples, logs, screenshots, generated evidence, CI output, OpenAPI examples, exception messages, comments, or documentation. This includes tokens, authorization headers, API keys, connection strings, private keys, credential objects, certificate passwords, SMTP passwords, and real thumbprints tied to private assets.

Certificate and key handling MUST include explicit selection, validation, expiration handling, rotation behavior, private-key storage protection, least privilege, and failure behavior. TLS certificate validation MUST NOT be bypassed. Suspected secret exposure MUST stop normal completion claims and trigger remediation and rotation guidance.

## Dependency Injection And Service Lifetimes

Constructor injection is the default for application services. Agents MUST declare and review service lifetimes explicitly. They MUST NOT introduce captive dependencies, resolve scoped services from singletons without an explicit scope, use `IServiceProvider` as ordinary application service locator, perform async work in constructors, or perform hidden network/database calls during service registration.

Container-owned disposables SHOULD be disposed by the container. External clients SHOULD use `IHttpClientFactory` or an approved equivalent. External systems SHOULD use typed or named clients with explicit timeouts and policies. Retry policies MUST account for operation idempotency and MUST NOT retry unsafe mutations by default.

## API Design And Compatibility

APIs MUST use explicit request and response DTOs. Agents MUST NOT accidentally expose EF entities, internal models, secret fields, stack traces, raw exception messages, internal routes, privileged operations, or environment details through API responses or OpenAPI.

API changes MUST define:

- Intentional route shape, HTTP methods, status codes, content types, and authorization behavior.
- `ProblemDetails` or another stable error contract.
- API versioning and breaking-change policy.
- Stable serialization settings, date/time handling, enum representation, null behavior, and casing.
- Pagination, filtering, sorting, and request limits for unbounded collections.
- Correlation IDs for supportable requests.
- Idempotency keys or duplicate detection for retry-sensitive mutations where appropriate.
- OpenAPI generation and validation when the project exposes OpenAPI.

Controllers, Razor handlers, Minimal API endpoint lambdas, and middleware SHOULD stay thin and delegate business behavior to tested services.

## Authentication And Authorization

Authentication and authorization are separate controls and MUST be reviewed separately. Protected resources MUST enforce server-side authorization and SHOULD be deny-by-default. Client-side checks MAY improve user experience but MUST NOT be the only access control.

Agents MUST require:

- Policy-based authorization where appropriate.
- Resource ownership and tenant boundary checks.
- Explicit elevated policies for administrative routes.
- Centralized role, claim, scope, and permission names where magic strings would create drift.
- Authorization failures that avoid leaking resource existence when that matters.
- Negative authorization tests for security-sensitive changes, including denied user, wrong tenant or owner, missing claim or scope, and anonymous access where relevant.

Changes that broaden access, weaken policy, alter claims, change resource checks, or move authorization later in the call path are High or Critical and require security-focused evidence.

## JWT And Token Validation

JWT validation MUST validate signature, issuer, audience, lifetime, expiration, not-before, signing algorithm, signing key source, key rotation, clock skew, required claims, and token type where applicable. Token validation MUST fail closed.

Agents MUST NOT introduce unsigned tokens, arbitrary algorithms, disabled issuer or audience validation without an approved active exception, hard-coded long-lived signing keys, token contents in logs, or refresh-token storage without reuse detection and revocation behavior.

JWT work MUST document key source, key entropy, key rotation, managed or asymmetric signing where appropriate, claim mapping, accepted audiences, accepted issuers, allowed algorithms, clock skew rationale, refresh-token storage controls, and negative tests. Required negative tests include invalid signature, issuer, audience, expiration, not-before, missing required claims, wrong algorithm, and wrong token type where applicable.

## ASP.NET Core Security

ASP.NET Core applications MUST use security middleware and hosting configuration intentionally. Agents MUST review middleware order whenever authentication, authorization, CORS, forwarded headers, static files, error handling, rate limiting, Swagger UI, routing, or endpoint mapping changes.

Agents MUST require as applicable:

- HTTPS and HSTS appropriate to deployment.
- Secure cookies, intentional `SameSite`, `HttpOnly`, expiration, sliding-expiration, and consent behavior.
- CSRF protection for cookie-authenticated mutations.
- CORS allowlists and no wildcard-with-credentials configuration.
- Rate limiting when abuse is plausible.
- Request and upload size limits.
- Security headers where appropriate.
- Trusted proxy and forwarded-header configuration for reverse proxies and IIS.
- No detailed exception pages, directory browsing, or verbose diagnostics in production.
- Explicit static-file roots.
- Environment-controlled Swagger UI and diagnostics.
- No unsafe certificate-validation callbacks.
- Minimized server disclosure and diagnostics.

Security changes MUST include tests or documented manual validation proving both allowed and denied paths.

## Input Validation And Model Binding

All untrusted input MUST be validated at trust boundaries. This includes body, query, route, form, header, cookie, claim, file, external payload, queue message, configuration, environment variable, and command-line input.

Agents MUST use explicit DTOs to prevent overposting and MUST validate identifiers, lengths, ranges, formats, collections, collection sizes, allowed values, external targets, command names, configurable actions, and normalized values. Agents MUST NOT trust filenames, MIME types, extensions, route values, headers, claims, serialized type names, or client-provided IDs.

Validation errors MUST avoid sensitive raw model-binding details. Normalization rules for casing, whitespace, Unicode, file paths, culture, time zones, and identifiers MUST be explicit where they affect security or persistence.

## File Upload And Download Safety

Upload and download workflows are security-sensitive. Agents MUST enforce:

- Size limits at server, endpoint, form, reverse proxy, and hosting layers where applicable.
- Extension allowlists and content/MIME validation.
- Randomized server-side names and no trust in client filenames.
- Path normalization and approved-root boundary checks before read or write.
- Storage outside executable or static roots unless intentionally published.
- Malware scanning where required by data classification or business policy.
- No execution or dynamic loading of uploaded content.
- Zip-slip prevention and archive limits for file count, total size, recursion, and compression ratio.
- Safe duplicate handling and temporary-file cleanup.
- Download authorization and safe `Content-Disposition`.
- No arbitrary local file reads.
- Audit records for sensitive transfers.

Tests MUST cover traversal, oversized content, disallowed type, malformed archive, unauthorized download, and boundary conditions when upload or download behavior changes.

## Data Protection And Cryptography

ASP.NET Core Data Protection MUST be configured for the hosting model. IIS, web farms, containers, multiple instances, and rolling deployments require persistent key rings with protected storage, correct permissions, rotation behavior, restore behavior, and no accidental exposure through static files or published artifacts.

Agents MUST NOT rely on unintended ephemeral production keys. Purpose strings MUST be stable, specific, and documented. Key rings MUST never be served as static content. Crypto failures MUST fail closed.

Agents MUST NOT implement custom cryptography. Use approved platform algorithms, authenticated encryption where encryption is required, approved password hashing, secure random generation, and vetted libraries. Documentation MUST describe signing and encryption accurately; neither signing nor encryption makes unsafe code safe.

## Data Access And EF Core

Data access work MUST also apply [AGENTS_Database.md](AGENTS_Database.md). EF Core `DbContext` instances MUST be scoped to the unit of work and MUST NOT be singleton or held in unrelated long-lived services. Hosted services that need a DbContext MUST create a scope per operation.

Agents MUST use async database APIs and propagate `CancellationToken` for I/O. LINQ and raw SQL MUST be parameterized. String-built SQL from untrusted input is prohibited. High-impact queries SHOULD include generated SQL review, query-plan or performance review, N+1 detection, projection review, and indexing consideration.

Agents MUST use projections for API responses, `AsNoTracking` for read-only queries where appropriate, explicit transactions for multi-write invariants, concurrency tokens where required, pagination for unbounded sets, intentional command timeouts, and transient-only retries with idempotency analysis.

Automatic production migration-on-startup is prohibited unless explicitly approved and recorded. Controlled deployment migrations or migration bundles are preferred. Migrations MUST include forward behavior, rollback or mitigation, data classification, runtime/lock risk, seed-data safety, and evidence. Migrations and fixtures MUST NOT contain sensitive data.

## Background Workers And Hosted Services

Worker and hosted-service work MUST also apply [AGENTS_WorkerService.md](AGENTS_WorkerService.md). Agents MUST enforce cancellation, graceful shutdown, observed exceptions, durable state where restart survival is required, explicit polling intervals, bounded concurrency, backpressure, retry with backoff and jitter, poison-job handling, job IDs, correlation IDs, leases or locking for multi-instance work, duplicate detection, and readiness that reflects required dependencies.

Agents MUST NOT add unbounded loops without delay and cancellation, fire-and-forget tasks, silent worker death, hidden partial failure, unbounded retries, or side effects that can repeat unsafely. State-changing workers SHOULD be idempotent. When idempotency is impossible, evidence MUST document duplicate risk and compensating controls.

## Reliability, Cancellation, Retries, And Timeouts

.NET code that performs external I/O MUST propagate cancellation where practical and define explicit timeouts. Agents MUST avoid infinite loops, retry storms, and blocking async paths with `.Result` or `.Wait()` unless a documented technical reason exists and deadlock risk is controlled.

Retries MUST target transient failures only, include limits, exponential backoff and jitter where appropriate, respect `Retry-After`, and consider idempotency before mutation retry. Circuit breakers, bulkheads, rate limits, and graceful degradation SHOULD be used where failure isolation matters. Graceful degradation MUST NOT appear as full success when required work failed.

Partial failures MUST be surfaced through result contracts, logs, metrics, events, health checks, or evidence as appropriate.

## Error Handling

Applications MUST have central exception boundaries appropriate to their host, such as ASP.NET Core exception middleware, worker loop exception handling, CLI top-level handling, or library-specific contracts. APIs MUST return `ProblemDetails` or stable error contracts without raw stack traces.

Agents MUST preserve diagnostic context in sanitized logs and use clear categories for validation, authentication, authorization, conflict, timeout, dependency, concurrency, cancellation, and internal failures. Correct status codes MUST be returned for APIs.

Agents MUST NOT use broad catch-and-ignore, exceptions as normal control flow, hidden fallback to production, success after failed persistence, or unobserved background exceptions. Cleanup MUST use `finally`, `using`, or `await using` where appropriate.

## Logging, Telemetry, And Auditability

Logging MUST be structured and use message templates. Logs SHOULD include correlation/request/job IDs, version, environment, service name, operation name, safe user or subject identifiers, and dependency context.

Logs, traces, metrics, audit records, and evidence MUST NOT include secrets, tokens, authorization headers, connection strings, private keys, raw regulated data, full sensitive payloads, or full request/response bodies by default. PII MUST be minimized and redacted.

Security audit events SHOULD record who, what, when, target, result, and correlation ID for access changes, privileged operations, sensitive downloads, authentication events, authorization denials, data export, and destructive actions. Metrics SHOULD cover latency, errors, throughput, queue depth, retries, dependency health, and saturation where applicable. OpenTelemetry or an approved equivalent SHOULD be used where distributed traces, metrics, or log correlation are required. Telemetry failure MUST NOT break the core operation unless telemetry is itself the required output.

## Health Checks And Operational Readiness

Health checks MUST distinguish liveness and readiness. Readiness MUST reflect required dependencies such as database, queue, cache, key ring, external critical dependency, migration state, or configuration readiness. Liveness MUST NOT fail solely because an optional dependency is unavailable.

Health endpoints MUST avoid secrets, stack traces, connection strings, internal topology, and raw exception messages. Access controls or network restrictions SHOULD protect detailed health information. Checks MUST have timeouts and MUST NOT create side effects or heavy load. Startup, warm-up, IIS probe, container probe, and rolling deployment behavior MUST be documented where applicable.

## Caching And State

Cache keys MUST include tenant, user, authorization, data classification, and versioning dimensions where applicable. Sensitive responses MUST NOT be publicly cached. Secrets MUST NOT be cached without explicit protection, expiration, and review.

Agents MUST define expiration, invalidation, consistency, stampede protection, distributed-cache contract versioning, serialization, and failure behavior for stateful caches. Authoritative state MUST NOT be corrupted by cache failure. Session-state choices MUST document scale-out, affinity, security, expiration, and data classification implications.

## Email And External Integrations

External integration work MUST also apply [AGENTS_Integration.md](AGENTS_Integration.md). Agents MUST use typed clients or explicit interfaces, approved secret sources, TLS certificate validation, explicit timeouts, cancellation, safe retries, API version handling, contract tests where applicable, and sandbox or mock validation when available.

SMTP settings MUST be externalized and secrets protected. Notification failure MUST be separated from core-operation failure unless notification is required for the operation. Agents MUST avoid sensitive subject lines, validate attachments, encode templates, and prevent header injection.

Webhook handlers MUST validate signatures or authenticity where the provider supports it, reject replayed events where possible, and test malformed, unauthorized, duplicate, and replayed payloads.

## Static Files And Frontend Integration

When ASP.NET Core serves HTML, CSS, JavaScript, images, downloads, SPA assets, source maps, or static documentation, agents MUST also apply [AGENTS_WebFrontend.md](AGENTS_WebFrontend.md).

Agents MUST enforce safe static-file roots, output encoding, cache-control, asset hashing or versioning where appropriate, no inline secrets, no accidental production source maps or diagnostics, and CSP consideration for public applications. Browser code MUST NOT be trusted for authorization decisions. Authentication state MUST NOT be stored insecurely in browser storage without explicit risk analysis and approval.

## IIS Hosting

IIS-hosted .NET applications MUST document and validate:

- Hosting Bundle or runtime version.
- In-process versus out-of-process hosting.
- App pool identity and least-privilege filesystem, certificate, key-ring, log, and content access.
- Physical path and application path.
- `web.config` generation, transformation, preservation, and rollback.
- Environment variables and protected configuration.
- ASP.NET Core Module behavior, stdout logging, log cleanup, startup failure diagnosis, and request limits.
- Health endpoint, app pool recycling, startup behavior, deployment locking, file replacement, rollback, TLS bindings, and forwarded headers.

Agents MUST NOT grant broad Modify rights to IIS identities, silently overwrite production configuration, claim IIS validation without an IIS host, or place plaintext secrets in `web.config` unless protected by an approved mechanism. IIS deployment evidence MUST be explicit or recorded as `NotRun` or `NotApplicable`.

## Container Security

Containerized .NET applications MUST use approved supported base images, no `latest` production tags, multi-stage builds, explicit ports, no secrets in layers, reviewed users and permissions, non-root execution where feasible, documented writable paths, health checks, graceful shutdown, and resource-limit consideration.

Final images SHOULD exclude package caches, SDKs when runtime-only is sufficient, source code not required at runtime, test artifacts, and build credentials. Agents MUST consider read-only filesystems, Data Protection key persistence, certificate access, environment injection, vulnerability scanning, SBOM, provenance, signing, and artifact hashes where policy requires.

Container build, scan, and run validation MUST be recorded as `Passed`, `Failed`, `NotRun`, `Blocked`, or `NotApplicable`; it MUST NOT be implied by a successful `dotnet build`.

## Testing

Behavior changes MUST include tests unless a valid `NotApplicable`, `NotRun`, or `Blocked` reason exists. Tests MUST use synthetic data, safe targets, no real credentials, no production calls, isolated integration dependencies, and approved ephemeral infrastructure when required.

The applicable test set includes:

- Unit behavior and boundary tests.
- Configuration/options validation and fail-fast tests.
- Authentication tests.
- Authorization allow and deny tests, including ownership and tenant boundaries.
- JWT invalid signature, issuer, audience, expiration, not-before, claim, algorithm, and token-type tests.
- API status code, serialization, `ProblemDetails`, overposting, request limit, and pagination tests.
- Upload traversal, size, type, archive, duplicate, cleanup, and unauthorized download tests.
- EF Core query, transaction, concurrency, timeout, migration, and rollback or mitigation validation.
- Worker cancellation, retry, timeout, poison handling, idempotency, duplicate, and partial failure tests.
- Health check readiness and liveness tests.
- Logging redaction and telemetry behavior.
- Data Protection key persistence and purpose behavior.
- External client, webhook, SMTP, and notification failure tests.
- IIS and container configuration validation when deployment assets change.

Agents MUST NOT hide flaky tests with retries, assert only absence of exceptions, or skip security-negative tests without a recorded reason.

## Playwright And End-To-End Testing

Browser behavior MUST use Playwright or an approved equivalent when the change affects login, authorization boundaries, navigation, forms, upload flows, download flows, error states, critical responsive behavior, accessibility basics, or server-hosted frontend integration.

E2E tests MUST use synthetic accounts and data, no production target without approval, sanitized traces and screenshots, stable accessible selectors or test IDs, and no embedded credentials. If a browser, test server, account, or environment is unavailable, evidence MUST record `NotRun` or `Blocked` with the exact reason.

## Dependency And Software Supply Chain

Package changes MUST include justification, trusted feeds, vulnerability review, license review, transitive dependency review, deprecated package review, maintenance review, runtime behavior review, and compatibility with target frameworks. Multiple feeds SHOULD use NuGet package source mapping. Central Package Management and lockfiles SHOULD be used where appropriate for the repository.

Agents MUST NOT add floating or wildcard production versions, unreviewed prerelease packages, untrusted mirrors, package sources with leaked credentials, build hooks that download and execute remote content, or dependencies for trivial platform behavior. Vulnerability audit MUST use the repository-supported command when available. SBOM, provenance, signing, and artifact hashes MUST be produced where policy requires.

## Code Quality, Analyzers, And Formatting

New .NET projects SHOULD enable nullable reference types unless a documented compatibility constraint prevents it. Warnings SHOULD be governed as errors for product code. Roslyn analyzers, `.editorconfig`, deterministic formatting, async naming conventions, cancellation conventions, disposal correctness, culture-aware parsing, and UTC persisted/cross-system timestamps SHOULD be enforced.

Agents MUST NOT add blanket `NoWarn`, broad analyzer suppression, dead code, fake success paths, swallowed exceptions, unexplained constants, synchronous blocking in async paths, or performance claims without measurement. Suppressions MUST be scoped, justified, and reviewed.

## Documentation

README, runbooks, OpenAPI descriptions, XML docs, and ADRs MUST remain synchronized with implementation. When applicable, documentation MUST cover prerequisites, SDK and runtime, build and test commands, every public configuration key, secret providers, authentication, authorization, database and migrations, uploads, workers, email and integrations, health checks, IIS, containers, deployment, rollback, troubleshooting, security considerations, known limitations, public endpoints, CLI arguments, environment variables, and operational modes.

Documentation examples MUST be synthetic and safe. Agents MUST NOT document fake commands as validation, hide required configuration, or claim support for frameworks, operating systems, deployment targets, package feeds, browsers, databases, IIS, or containers that were not tested or explicitly declared.

## Packaging, Versioning, Signing, And Publishing

Packages and release artifacts MUST use semantic versioning, explicit package metadata, license and repository information, reproducible contents, and reviewed file inclusion. Symbols and SourceLink SHOULD be configured where appropriate. Strong-name signing, Authenticode signing, and NuGet signing MUST follow policy when required and MUST document their security limits.

Publishing MUST identify artifact type, publish destination, configuration, runtime identifier, framework, self-contained or framework-dependent mode, trimming/AOT implications, signing, hashes, release notes, and breaking changes. Agents MUST NOT publish from a dirty tree, publish implicitly to production, or include secrets/configuration leakage in artifacts.

## Deployment And Rollback

Deployment changes MUST declare deployment model, artifact, environment separation, migration order, rolling-deployment compatibility, smoke tests, post-deployment health checks, rollback, and data mitigation. Build success MUST NOT be confused with deployment success.

Agents MUST NOT assume production credentials or access. Automatic production deployment, silent production migration-on-startup, broad IIS overwrite, and uncontrolled container rollout require explicit approval. Blue/green, slot, canary, maintenance-window, or coordinated downtime strategy SHOULD be documented where appropriate.

Rollback MUST identify what can be reverted by code, package, container, IIS file replacement, configuration, database migration, feature flag, or data mitigation. Irreversible changes MUST be called out and approved.

## Completion Evidence

Completion evidence MUST align with [../governance/COMPLETION_EVIDENCE.md](../governance/COMPLETION_EVIDENCE.md) and root [../AGENTS.md](../AGENTS.md). Evidence for .NET work MUST include:

- Exact files changed.
- Exact commands and exit codes.
- `dotnet --info` result or `NotRun` reason.
- SDK, target frameworks, runtime versions, operating systems, hosting model, deployment model, and RIDs affected.
- Restore, locked restore, build, test, test counts, format, analyzer, and vulnerability-audit results or justified statuses.
- OpenAPI validation when APIs expose OpenAPI.
- Migration validation and rollback or mitigation evidence when data access changes.
- Authorization and JWT negative tests when security behavior changes.
- Browser/Playwright results when browser behavior changes.
- IIS validation, container build/scan/run validation, deployment result, GitHub Actions status, artifact verification, and rollback status where applicable.
- Remaining risks, skipped tests, blocked environments, exceptions, approvals, and reviewers.

Permitted statuses are `Passed`, `Failed`, `Blocked`, `NotRun`, and `NotApplicable`. Evidence MUST NOT label unexecuted restore, build, tests, audit, migration, IIS, container, browser, deployment, or GitHub Actions validation as `Passed`.

## Failure Behavior

The work is incomplete when:

- Restore, build, format, analyzer, tests, or required validation fail.
- Security-negative tests are missing for authentication, authorization, JWT, upload, webhook, or cryptography changes without an approved reason.
- Authorization changes lack denial tests.
- Warnings are hidden or analyzer suppressions are broad.
- Secrets, tokens, connection strings, private keys, or credential-shaped examples are introduced.
- Package risks are unreviewed.
- Migration rollback or mitigation is absent.
- Production migrations auto-run without approval.
- JWT validation is weakened.
- Upload paths are unsafe.
- Data Protection keys are unintentionally ephemeral in production.
- Workers ignore cancellation or fail silently.
- External calls lack timeout.
- Deployment, IIS, container, GitHub Actions, or artifact success is claimed without evidence.
- Breaking API, package, configuration, or deployment changes are undocumented.

Agents MUST downgrade completion status to `Failed`, `Blocked`, or `NotRun` as required by the evidence.

## Exception Handling

Exceptions MUST follow [../governance/EXCEPTION_PROCESS.md](../governance/EXCEPTION_PROCESS.md). Approved exceptions MUST be active, scoped, time-bounded, risk-classified, reviewed by the accountable owner, and recorded in completion evidence.

Missing SDKs, private feeds, browsers, databases, IIS hosts, container runtimes, deployment targets, credentials, or package-audit services are not exceptions by themselves. They MUST be recorded as `NotRun` or `Blocked` unless an approved exception changes the required gate.

Exceptions MUST NOT allow plaintext secrets, fabricated evidence, disabled issuer/audience validation without compensating controls, unsafe upload paths, unreviewed cryptography, hidden production deployment, or silent migration risk.

## Related Documents

- [AGENTS_Base.md](AGENTS_Base.md)
- [AGENTS_Database.md](AGENTS_Database.md)
- [AGENTS_WorkerService.md](AGENTS_WorkerService.md)
- [AGENTS_Integration.md](AGENTS_Integration.md)
- [AGENTS_WebFrontend.md](AGENTS_WebFrontend.md)
- [../AGENTS.md](../AGENTS.md)
- [../governance/ORGANIZATION_CONTRACT.md](../governance/ORGANIZATION_CONTRACT.md)
- [../governance/COMPLETION_EVIDENCE.md](../governance/COMPLETION_EVIDENCE.md)
- [../governance/RISK_CLASSIFICATION.md](../governance/RISK_CLASSIFICATION.md)
- [../governance/EXCEPTION_PROCESS.md](../governance/EXCEPTION_PROCESS.md)
- [../governance/AI_GENERATED_CODE_POLICY.md](../governance/AI_GENERATED_CODE_POLICY.md)
- [../docs/ADOPTION_GUIDE.md](../docs/ADOPTION_GUIDE.md)
- [../docs/DOWNSTREAM_CONFIGURATION.md](../docs/DOWNSTREAM_CONFIGURATION.md)
- [../docs/ACTION_SECURITY.md](../docs/ACTION_SECURITY.md)
- [../docs/TROUBLESHOOTING.md](../docs/TROUBLESHOOTING.md)

## Revision History

- 1.1.0: Rebuilt as a comprehensive enterprise .NET standard covering runtime policy, architecture, reproducible builds, configuration, secrets, DI, APIs, authentication, authorization, JWT, ASP.NET Core security, validation, uploads, Data Protection, EF Core, workers, reliability, logging, health, caching, integrations, static files, IIS, containers, testing, Playwright, supply chain, code quality, documentation, packaging, deployment, rollback, evidence, failures, and exceptions.
- 1.0.0: Initial .NET agent standard with baseline requirements for discovery, risk, configuration, dependencies, EF Core, observability, testing, deployment, and evidence.
