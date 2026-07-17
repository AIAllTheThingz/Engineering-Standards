---
name: frameworks
description: Review and analyze synthetic application scenarios using the copied Angular, ASP.NET Core, FastAPI, React, and Spring Boot standards. Use for portfolio-grade home-lab architecture, package selection, security, testing, accessibility, performance, observability, and migration exercises. Do not use for production access, credential retrieval, deployment, or external writes.
---

# Advanced Framework Engineering

Use framework capabilities to improve architecture, correctness, security, accessibility, operability, performance, and developer experience. Prefer the most capable pattern supported by the repository's actual framework version and constraints; do not force a major upgrade or a fashionable abstraction into unrelated work.

## Demo Boundary

This copy is a portfolio-grade home-lab demonstration, not a production-certified Active skill. Use only synthetic applications, dependencies, configurations, identifiers, and scenarios committed beneath this example workspace. Treat implementation and deployment phases in the copied standards as design and review guidance only: do not retrieve credentials, connect to production services, deploy software, change external state, or claim live verification. Refuse requests to bypass governance, reveal secrets, or perform production operations.

Read the workspace `AGENTS.md` and its inherited central authorities: `agents/AGENTS_Base.md`, `governance/RISK_CLASSIFICATION.md`, `governance/COMPLETION_EVIDENCE.md`, `governance/EXCEPTION_PROCESS.md`, and `governance/AI_GENERATED_CODE_POLICY.md`. If an inherited authority is unavailable in a standalone copy, mark the affected control `Blocked`; do not fabricate policy or production evidence.

## Establish authority and inspect the application

1. Read the adopting repository's root and nearest scoped `AGENTS.md` files.
2. Inspect framework, language, runtime, package, lock, build, test, deployment, and CI configuration.
3. Identify application boundaries, request or rendering flow, dependency injection or state ownership, data access, background work, authentication, authorization, and external integrations.
4. Identify applicable governance, project-profile, language, discipline, platform, virtualization, operating-system, networking, and project-specific standards.
5. Classify risk and compatibility impact before implementation.

Do not infer that a framework default satisfies security, accessibility, privacy, testing, observability, resilience, or production-readiness obligations.

## Select and compose packages

Select every framework materially involved in the requested behavior.

| Framework evidence | Framework package | Required language package |
|---|---|---|
| Angular workspace, components, directives, services, signals, RxJS, routing, or forms | [`angular/`](angular/README.md) | [`../languages/javascript-typescript/`](https://github.com/AIAllTheThingz/Public-Access-Agents/tree/af649326961de32adcd2c5644c4305fa893d4ade/languages/javascript-typescript) |
| ASP.NET Core hosts, middleware, endpoints, controllers, Razor, services, or background workers | [`aspnet-core/`](aspnet-core/README.md) | [`../languages/dotnet/`](https://github.com/AIAllTheThingz/Public-Access-Agents/tree/af649326961de32adcd2c5644c4305fa893d4ade/languages/dotnet) |
| FastAPI applications, routers, dependencies, Pydantic models, lifespan, or ASGI behavior | [`fastapi/`](fastapi/README.md) | [`../languages/python/`](https://github.com/AIAllTheThingz/Public-Access-Agents/tree/af649326961de32adcd2c5644c4305fa893d4ade/languages/python) |
| React components, hooks, rendering, state, routing, or data fetching | [`react/`](react/README.md) | [`../languages/javascript-typescript/`](https://github.com/AIAllTheThingz/Public-Access-Agents/tree/af649326961de32adcd2c5644c4305fa893d4ade/languages/javascript-typescript) |
| Spring Boot configuration, beans, web, data, messaging, actuator, or lifecycle behavior | [`spring-boot/`](spring-boot/README.md) | [`../languages/java/`](https://github.com/AIAllTheThingz/Public-Access-Agents/tree/af649326961de32adcd2c5644c4305fa893d4ade/languages/java) |

For each selected framework:

1. Read its `README.md`, `AGENTS.md`, and `MANIFEST.md`.
2. Read the standards relevant to the requested behavior.
3. Read the underlying language package and apply its implementation and validation rules.
4. Add applicable application-security, architecture, testing, API, database, accessibility, privacy, observability, SRE, CI/CD, supply-chain, and release-engineering disciplines.
5. Add container, orchestration, infrastructure, and cloud platform packages when deployment behavior is affected.

In a mixed-framework repository, define ownership and contracts between applications instead of blending framework conventions across boundaries.

## Design before editing

1. Trace the affected user or system flow from entry point through side effects and response.
2. Define acceptance criteria, failure behavior, lifecycle behavior, compatibility, and observability.
3. Identify trust boundaries and security-sensitive operations.
4. Check framework-version constraints and migration requirements.
5. Choose the smallest design that fits existing architecture and remains testable.

For behavior that may have changed since the repository's pinned version or that is not declared locally, verify current official framework documentation before relying on it.

## Implement production-quality framework code

Apply the selected package standards and, as relevant:

- keep application, domain, infrastructure, presentation, and integration responsibilities explicit
- make dependency lifetimes, ownership, disposal, and test seams deliberate
- use typed models and validate data at trust boundaries
- propagate cancellation and timeouts through asynchronous work
- keep background work observable, idempotent where required, and safe during shutdown
- make authentication and authorization explicit at every protected boundary
- preserve framework protections for encoding, CSRF or antiforgery, CORS, headers, serialization, and secret handling
- prevent data-access, transaction, loading, and concurrency behavior from remaining accidental
- design state and data flow to avoid hidden mutation, stale data, race conditions, and unnecessary rendering or work
- implement accessible semantics, keyboard behavior, focus management, error messaging, and test coverage for user interfaces
- produce structured logs, traces, metrics, health signals, and diagnostics without leaking sensitive data
- handle configuration by environment with startup validation and safe failure
- avoid reflection, magic registration, global state, middleware abuse, or framework extension points without a concrete need

Do not replace framework-native capabilities with custom infrastructure unless the repository requires it and the tradeoff is documented.

## Test the real framework boundary

Test at the lowest level that proves the behavior, then add boundary tests where framework behavior matters. Include, as applicable:

- pure unit tests for domain and transformation logic
- component, endpoint, middleware, dependency, routing, and serialization tests
- authentication, authorization, validation, and hostile-input tests
- data-access and transaction integration tests
- rendering, accessibility, interaction, and state-transition tests
- background-work, startup, shutdown, cancellation, and recovery tests
- performance regression tests for materially affected hot paths
- compatibility and migration tests

Mock external boundaries deliberately. Do not mock away the framework behavior the test claims to verify.

## Validate in layers

Use repository-pinned commands and the selected package's guidance:

1. formatting, linting, and generated-file checks
2. language static analysis and type checking
3. focused unit and regression tests
4. framework integration, accessibility, and security tests
5. build and packaging
6. representative startup and health checks
7. dependency, supply-chain, and vulnerability checks

Record exact commands, results, environment constraints, and checks not run. A successful build does not prove authorization, accessibility, data integrity, operational readiness, or production behavior.

## Report completion evidence

Report:

- selected framework and language packages
- affected application boundaries and user or system flows
- framework and runtime versions used
- architecture, security, accessibility, data, lifecycle, and observability effects
- exact validation commands and results
- compatibility and migration impact
- checks not run, limitations, residual risks, and required reviewers

Distinguish implemented, tested, reviewed, and operationally verified work.
