---
id: FW-INDEX-001
title: Framework Standards
version: 0.1.0
status: baseline
---

# Framework Standards

Use [`SKILL.md`](SKILL.md) when an agent must select and apply these framework packages during implementation, review, testing, security, performance, accessibility, observability, or migration work.

## Purpose

Framework packages specialize the repository's language and discipline standards for a particular application framework. They define framework-specific architecture, configuration, lifecycle, security, testing, observability, compatibility, and completion expectations without pretending that a framework replaces engineering judgment.

A framework package is an overlay. It must be composed with:

1. root governance standards
2. the applicable project profile
3. the underlying language package
4. all relevant discipline packages
5. platform standards when deployment or infrastructure behavior matters
6. project-specific root and nested `AGENTS.md` instructions

Selecting a framework package does not automatically select every discipline needed by the project. A web framework can make route registration easy. It cannot make authorization, accessibility, privacy, recovery, or evidence appear by moral force.

## Framework catalog

| Framework | Primary language | Purpose |
|---|---|---|
| [ASP.NET Core](aspnet-core/) | .NET | Build secure, testable, observable ASP.NET Core web applications, APIs, background services, and middleware pipelines. |
| [React](react/) | JavaScript and TypeScript | Build accessible, secure, maintainable React interfaces with explicit state, data flow, rendering, and testing boundaries. |
| [Angular](angular/) | JavaScript and TypeScript | Build structured, accessible, secure Angular applications with clear feature boundaries, reactive behavior, routing, forms, and test coverage. |
| [Spring Boot](spring-boot/) | Java | Build secure, observable, testable Spring Boot services with explicit configuration, dependency injection, data access, web, and operational behavior. |
| [FastAPI](fastapi/) | Python | Build secure, typed, asynchronous FastAPI services with explicit models, dependencies, authorization, lifecycle, errors, and tests. |

## What a complete framework package contains

```text
framework/
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

- `AGENTS.md` is the normative framework entry point.
- `README.md` explains scope, adoption, tailoring, companion packages, validation, failure modes, and limitations.
- `MANIFEST.md` defines required files and package acceptance checks.
- `standards/` contains detailed framework-specific requirements.
- `templates/` supports repeatable adoption, review, and evidence capture.
- `examples/` demonstrates composition without inventing production facts.

## When to select a framework package

Select a framework package when the repository contains, introduces, or materially changes that framework's:

- application structure
- request, rendering, routing, or message pipeline
- dependency injection or state model
- configuration and environment behavior
- authentication or authorization integration
- data access or transaction behavior
- background, lifecycle, or concurrency behavior
- testing infrastructure
- observability and health behavior
- packaging, build, compatibility, or migration model

Do not select a framework package merely because one transitive dependency happens to mention the framework. Do not omit it when the framework controls material application behavior.

## Composition model

A typical web API composition might be:

```text
governance
+ WEB_API profile
+ language package
+ framework package
+ application-security discipline
+ architecture discipline
+ testing discipline
+ api-engineering discipline
+ observability discipline
+ deployment platform
+ project-specific instructions
```

A browser application normally adds accessibility, privacy, API engineering, testing, documentation, CI/CD, supply-chain, and release-engineering disciplines.

## Adoption procedure

1. Read the root `AGENTS.md` and governance standards.
2. Select the project profile.
3. Select the underlying language package.
4. Confirm the framework package applies.
5. Select relevant discipline, platform, virtualization, operating-system, and networking packages.
6. Copy or compose the complete framework package.
7. Preserve stable identifiers and the package manifest.
8. Declare the exact supported framework, language, runtime, build, and deployment constraints.
9. Complete the adoption checklist.
10. Define executable project validation.
11. Obtain accountable review.
12. Record limitations and exceptions.

## Tailoring rules

Tailoring may:

- declare exact supported versions and compatibility ranges
- identify architectural patterns used by the project
- specify approved libraries and extension points
- add stricter security, testing, observability, and deployment controls
- define project-specific commands and evidence
- mark requirements inapplicable with justification
- add nested framework instructions for local scopes

Tailoring must not:

- weaken parent governance or language controls silently
- remove security, testing, accessibility, privacy, or operational work merely because a framework offers defaults
- rely on undocumented framework magic
- invent production endpoints, identities, credentials, data stores, or infrastructure
- claim compatibility or production readiness without evidence

## Framework defaults

Framework defaults are implementation choices, not proof. Projects must review:

- authentication and authorization defaults
- serialization and validation behavior
- exception and error responses
- CORS, CSRF, antiforgery, and security-header behavior
- dependency injection lifetimes or provider scopes
- concurrency, cancellation, and background-work semantics
- health and management endpoints
- client bundle contents
- development-only diagnostics
- migration behavior between framework versions

## Evidence model

Framework completion evidence should identify:

- framework and language versions
- changed application boundaries
- configuration and environment effects
- security and authorization effects
- lifecycle, concurrency, and cleanup behavior
- test commands and results
- build and packaging results
- compatibility and migration impact
- checks not run
- limitations, residual risks, and follow-up actions
- accountable reviewers

Evidence must distinguish planned, implemented, tested, reviewed, and operationally verified work.

## Validation

From the repository root:

```bash
python tools/validate-standards/validate_repository.py
python tools/check-links/check_links.py
```

An adopting project must also run framework, language, security, testing, build, and deployment validation appropriate to its real repository.

## Maturity

All framework packages are currently `baseline`.

- `baseline`: usable minimum package requiring continued review and refinement
- `stable`: mature and broadly reviewed
- `draft`: usable for review but expected to change materially
- `planned`: catalog entry only
- `deprecated`: retained for migration guidance

## Maintaining framework packages

A framework-package change must:

- preserve stable IDs unless a breaking change is approved
- update `AGENTS.md`, README, manifest, standards, templates, and examples together
- disclose framework-version and migration implications
- keep links and identifiers valid
- separate normative requirements from examples
- avoid unsupported compatibility claims
- state checks not run

## Non-production boundary

These packages are reusable standards overlays. They do not configure a production application, choose organization-specific libraries, grant security approval, or replace accountable architecture, accessibility, security, privacy, data, operations, and release review.
