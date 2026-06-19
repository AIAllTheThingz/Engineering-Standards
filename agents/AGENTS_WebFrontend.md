# AGENTS Web Frontend Standard

| Field | Value |
| --- | --- |
| Status | Active |
| Version | 1.0.0 |
| Owner role | Engineering Standards Maintainers |
| Last reviewed | 2026-06-19 |
| Changelog | See [../CHANGELOG.md](../CHANGELOG.md). |

## Purpose

This document defines enterprise requirements for AI agents working on browser-facing applications, static sites, design systems, frontend build systems, client packages, and UI tests. It inherits [AGENTS_Base.md](AGENTS_Base.md) and adds frontend-specific controls for security, accessibility, performance, dependency management, and evidence.

## Applicability

This standard applies to JavaScript, TypeScript, React, Vue, Angular, Svelte, static HTML/CSS, package manifests, lockfiles, bundler configuration, browser tests, service workers, client-side routing, design-system components, and frontend CI workflows.

## Required Discovery

Before editing, agents MUST identify:

- Runtime and package manager.
- Lockfile type and install command.
- Framework, router, bundler, compiler, and test tools.
- Lint, format, typecheck, unit, integration, E2E, and accessibility commands.
- Authentication and token-handling model.
- CSP, CORS, CSRF assumptions, service workers, and storage usage.
- Browser support matrix and build targets.
- Environment variable exposure rules.
- Dependency audit process and bundle/performance budgets.

Agents MUST inspect package scripts and existing component patterns before adding dependencies or changing build configuration.

## Risk Classification

Frontend changes are High or Critical when they affect authentication, session handling, token storage, authorization assumptions, payment or regulated-data flows, content injection, CSP, service workers, dependency execution, analytics collection, or production build/release behavior.

Visual-only changes can be Low when they do not alter data flow, security, routing, accessibility, or build behavior. Generated frontend code that handles identity, secrets, or untrusted HTML requires heightened review.

## Security Requirements

Agents MUST prevent client-side secret exposure. Browser code MUST NOT contain private keys, server credentials, privileged tokens, or production-only secrets. Public environment variables MUST be intentionally public.

User-controlled data MUST be rendered safely. Agents MUST avoid unsafe HTML injection, script injection, DOM clobbering, open redirects, unsafe URL construction, and storing sensitive tokens in `localStorage` or non-httpOnly storage unless an approved design requires it.

Authentication and authorization MUST be enforced server-side. Frontend checks MAY improve UX but MUST NOT be the only access control.

## Implementation Requirements

Agents MUST follow the existing framework and design-system conventions. Components SHOULD be accessible, testable, responsive, and maintainable. State management SHOULD stay as local as practical and avoid global mutable state unless the application pattern requires it.

Agents SHOULD avoid adding dependencies for trivial behavior. New dependencies require review for license, source, vulnerability status, install scripts, maintainer health, and bundle impact.

## Accessibility

Interactive UI MUST be keyboard reachable, screen-reader understandable, and visually clear. Agents SHOULD preserve semantic HTML, labels, focus order, contrast, reduced-motion behavior, and error messaging.

When accessibility tooling exists, run it. When manual accessibility validation is used, record what was inspected.

## Performance And Reliability

Agents SHOULD consider bundle size, lazy loading, caching, hydration cost, image sizing, API error states, loading states, and offline/service-worker behavior when relevant. Performance-sensitive changes SHOULD include measurement or a reason measurement was not run.

Client-side error handling MUST avoid leaking sensitive data and SHOULD provide recoverable user states.

## Testing Requirements

Frontend behavior changes SHOULD include tests at the right level:

- Unit tests for pure logic and component states.
- Integration tests for routing, forms, and data flow.
- Browser or E2E tests for critical user journeys.
- Accessibility checks when configured.
- Build validation for production bundles.

Recommended validation:

```powershell
npm ci
npm run lint
npm run typecheck
npm test
npm run build
npm audit
```

Use the repository's package manager and scripts. Do not invent fake scripts that only print success.

## Configuration And Environment

Agents MUST distinguish build-time public variables from server-side secrets. Changes to environment variable names, API origins, CSP, redirects, source maps, or asset hosts MUST be documented and reviewed.

Production source maps, error reporting, and analytics MUST avoid exposing secrets and sensitive payloads.

## Evidence

Evidence MUST include package manager version, install command, lockfile status, lint/typecheck/test/build results, audit result or `NotRun` reason, accessibility result when applicable, and remaining risks. If browser tests cannot run, record why.

## Failure Behavior

The work is incomplete if build fails, tests fail, lockfile changes are unexplained, client secrets are introduced, unsafe HTML handling is added, accessibility regressions are ignored, or security-sensitive browser behavior lacks review.

## Related Documents

- [AGENTS_Base.md](AGENTS_Base.md)
- [../governance/ORGANIZATION_CONTRACT.md](../governance/ORGANIZATION_CONTRACT.md)
- [../governance/RISK_CLASSIFICATION.md](../governance/RISK_CLASSIFICATION.md)
- [../governance/AI_GENERATED_CODE_POLICY.md](../governance/AI_GENERATED_CODE_POLICY.md)

## Exception Handling

Exceptions MUST follow [../governance/EXCEPTION_PROCESS.md](../governance/EXCEPTION_PROCESS.md). Missing browser tooling, unavailable package feeds, or absent test environments MUST be recorded as `NotRun` or `Blocked`, not `Passed`.
