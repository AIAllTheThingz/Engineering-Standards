---
id: ASPNET-PKG-001
title: ASP.NET Core Framework Package
version: 0.1.0
status: baseline
---

# ASP.NET Core Framework Package

## Purpose

Build secure, testable, observable ASP.NET Core web applications, APIs, background services, and middleware pipelines.

This package is a project-agnostic framework overlay. It specializes the [.NET language package](https://github.com/AIAllTheThingz/Public-Access-Agents/tree/af649326961de32adcd2c5644c4305fa893d4ade/languages/dotnet) and relevant discipline standards for ASP.NET Core projects.

Status: **baseline**

A baseline package is usable for adoption and review but should continue to mature through real project feedback, compatibility review, and specialist scrutiny.

## When to adopt this package

Adopt this package when:

- the project hosts HTTP endpoints with ASP.NET Core
- middleware, routing, endpoint filters, controllers, minimal APIs, or hosted services change
- authentication, authorization, rate limiting, antiforgery, or error handling is configured
- dependency injection, options, data access, health checks, or application lifetime behavior changes

Do not omit it merely because the framework appears familiar. Familiarity is not a substitute for declaring how the project uses configuration, security, lifecycle, tests, and operational behavior.

## What this package does not replace

This package does not replace:

- the .NET language package
- application security, API engineering, testing, observability, database, privacy, or SRE disciplines
- deployment-platform guidance for containers, Kubernetes, or cloud services

It also does not select framework extensions, libraries, hosting models, cloud services, or organizational controls for an adopting project.

## Package structure

```text
frameworks/aspnet-core/
├── AGENTS.md
├── README.md
├── MANIFEST.md
├── standards/
├── templates/
│   ├── ADOPTION_CHECKLIST.md
│   ├── REVIEW_CHECKLIST.md
│   └── EVIDENCE_RECORD_TEMPLATE.md
└── examples/
    └── ADOPTION_EXAMPLE.md
```

## Normative entry point

Start with [`AGENTS.md`](AGENTS.md). It preserves the framework's mandatory rule identifiers, defines instruction precedence, and points to the supporting standards.

[`MANIFEST.md`](MANIFEST.md) defines required files and package acceptance checks.

## Supporting standards

| Standard | Purpose |
|---|---|
| [`Application Model Standard`](standards/APPLICATION_MODEL_STANDARD.md) | Define the hosting model, request pipeline, endpoint style, background work, startup behavior, and shutdown expectations before implementation. |
| [`Configuration and Options Standard`](standards/CONFIGURATION_OPTIONS_STANDARD.md) | Use strongly typed options, validate required values at startup, separate secrets from committed settings, and document precedence and reload behavior. |
| [`Security and Authorization Standard`](standards/SECURITY_AUTHORIZATION_STANDARD.md) | Configure authentication, authorization, antiforgery, CORS, HTTPS, rate limiting, and security headers explicitly and test denied access. |
| [`HTTP and Middleware Standard`](standards/HTTP_MIDDLEWARE_STANDARD.md) | Keep middleware order deliberate, use consistent errors, bound request sizes and timeouts, preserve cancellation, and avoid leaking implementation details. |
| [`Dependency Injection and Lifetimes Standard`](standards/DEPENDENCY_INJECTION_LIFETIMES_STANDARD.md) | Choose service lifetimes deliberately, avoid captive dependencies and service location, and keep initialization and disposal behavior explicit. |
| [`Data Access and Background Work Standard`](standards/DATA_BACKGROUND_WORK_STANDARD.md) | Scope data contexts correctly, use transactions intentionally, avoid blocking request threads, and make background work durable or explicitly best-effort. |
| [`Observability and Health Standard`](standards/OBSERVABILITY_HEALTH_STANDARD.md) | Define safe logs, metrics, traces, health checks, correlation, dependency visibility, and operational ownership. |
| [`Testing Standard`](standards/TESTING_STANDARD.md) | Use unit, integration, contract, authorization, middleware, startup, and failure-path tests proportionate to risk. |
| [`ASP.NET Core Completion Evidence`](standards/COMPLETION_EVIDENCE.md) | Record configuration validation, endpoint and authorization behavior, middleware order, dependency lifetimes, tests, telemetry, compatibility, and remaining limitations. |

## Adoption workflow

1. Read the root governance standards.
2. Select the project profile.
3. Adopt the [.NET language package](https://github.com/AIAllTheThingz/Public-Access-Agents/tree/af649326961de32adcd2c5644c4305fa893d4ade/languages/dotnet).
4. Confirm this framework package applies.
5. Select relevant disciplines, platforms, virtualization systems, operating systems, and networking systems.
6. Copy or compose the complete package.
7. Preserve stable identifiers.
8. Declare exact supported framework, language, runtime, build, and deployment constraints.
9. Complete the adoption checklist.
10. Define project-specific validation commands.
11. Review compatibility and migration implications.
12. Obtain accountable review.

## Project tailoring checklist

Before adoption, define:

- exact supported framework and language versions
- application architecture and framework extension points
- configuration sources and precedence
- secrets and identity integration
- request, rendering, routing, or message boundaries
- dependency injection, state, session, or provider ownership
- data access and transaction behavior
- async, concurrency, cancellation, and background-work behavior
- error contracts and diagnostic boundaries
- health, telemetry, and operational ownership
- build, packaging, deployment, and migration constraints
- test layers and representative environments
- compatibility commitments
- evidence location and reviewers

## Security expectations

- Treat all external input and client state as untrusted.
- Enforce authorization at the protected server-side operation.
- Keep secrets out of client bundles, committed settings, logs, errors, and examples.
- Review framework bypass APIs and unsafe escape hatches.
- Bound input sizes, timeouts, retries, resource use, and diagnostic exposure.
- Use approved cryptography and identity integrations.
- Test denied, invalid, boundary, timeout, and failure behavior.
- Do not infer security from framework popularity. Popular software can still be configured by humans.

## Lifecycle and concurrency expectations

The project must define:

- startup and initialization behavior
- readiness and dependency checks
- request or render cancellation
- background and asynchronous work ownership
- connection, session, subscription, or resource cleanup
- graceful shutdown
- retry and idempotency behavior
- worker, process, thread, event-loop, or browser assumptions
- failure and recovery behavior

## Testing expectations

Framework tests should cover:

- configuration validation
- application startup
- public contracts and user-visible behavior
- negative authorization and invalid input
- lifecycle and cleanup
- integration with representative dependencies
- framework middleware, routing, rendering, or dependency behavior
- errors and failure paths
- compatibility and migration-sensitive behavior
- accessibility where a user interface exists
- build and packaging behavior

Do not replace meaningful tests with a successful application startup and a hopeful expression.

## Suggested validation

Use repository-defined commands. Typical checks include:

- `dotnet restore`
- `dotnet format --verify-no-changes`
- `dotnet build --no-restore`
- `dotnet test --no-build`
- framework integration tests using the repository's selected hosting approach

Record commands exactly and distinguish passed, failed, and not-run checks.

## Completion evidence

Use [`templates/EVIDENCE_RECORD_TEMPLATE.md`](templates/EVIDENCE_RECORD_TEMPLATE.md) and [`standards/COMPLETION_EVIDENCE.md`](standards/COMPLETION_EVIDENCE.md).

Evidence should include:

- changed files
- framework and language versions
- affected boundaries and contracts
- security and configuration effects
- lifecycle and concurrency effects
- exact validation commands and results
- representative environment details
- compatibility and migration impact
- checks not run
- limitations and residual risks
- reviewer identity or role

## Common failure modes

- registering scoped services in singletons
- trusting client-side authorization
- returning raw exceptions
- placing secrets in appsettings files
- starting untracked background work from request handlers
- exposing unrestricted health or diagnostic endpoints

Other recurring failures include copying example configuration into production, assuming defaults remain unchanged across versions, ignoring project-specific deployment behavior, and reporting completion without evidence.

## Companion packages

This framework commonly composes with:

- [Application Security](https://github.com/AIAllTheThingz/Public-Access-Agents/tree/af649326961de32adcd2c5644c4305fa893d4ade/disciplines/application-security)
- [API Engineering](https://github.com/AIAllTheThingz/Public-Access-Agents/tree/af649326961de32adcd2c5644c4305fa893d4ade/disciplines/api-engineering)
- [Testing and Quality Engineering](https://github.com/AIAllTheThingz/Public-Access-Agents/tree/af649326961de32adcd2c5644c4305fa893d4ade/disciplines/testing)
- [Observability](https://github.com/AIAllTheThingz/Public-Access-Agents/tree/af649326961de32adcd2c5644c4305fa893d4ade/disciplines/observability)
- [Database Engineering](https://github.com/AIAllTheThingz/Public-Access-Agents/tree/af649326961de32adcd2c5644c4305fa893d4ade/disciplines/database)
- [Containers](https://github.com/AIAllTheThingz/Public-Access-Agents/tree/af649326961de32adcd2c5644c4305fa893d4ade/platforms/containers)

Companion packages supplement this framework overlay. They do not replace its applicable rules.

## Templates and example

- [`ADOPTION_CHECKLIST.md`](templates/ADOPTION_CHECKLIST.md)
- [`REVIEW_CHECKLIST.md`](templates/REVIEW_CHECKLIST.md)
- [`EVIDENCE_RECORD_TEMPLATE.md`](templates/EVIDENCE_RECORD_TEMPLATE.md)
- [`ADOPTION_EXAMPLE.md`](examples/ADOPTION_EXAMPLE.md)

Templates are starting points. Replace fictitious values with reviewed project facts and never insert production secrets.

## Maintaining the package

Changes must:

- preserve stable identifiers unless a breaking change is approved
- update README, manifest, standards, templates, and examples together
- state supported-version and migration impact
- keep requirements specific and testable
- validate links and identifiers
- disclose checks not run
- avoid unsupported claims about framework defaults

## Completion boundary

Adopting this package does not prove that an ASP.NET Core application is secure, accessible, reliable, compatible, tested, or production-ready. Completion requires implementation, evidence, and accountable review.
