---
id: FW-REACT
title: React Agent Standard
version: 0.1.0
status: baseline
applies_to:
  - react
depends_on:
  - GOV-WORK
  - GOV-SECDEV
  - DISC-TEST
---

# React Agent Standard

## Purpose

This file defines mandatory rules for agents creating, modifying, reviewing, testing, securing, or documenting React work.

The framework package supplements the [JavaScript and TypeScript language package](https://github.com/AIAllTheThingz/Public-Access-Agents/tree/af649326961de32adcd2c5644c4305fa893d4ade/languages/javascript-typescript) and applicable governance, discipline, platform, virtualization, operating-system, networking, profile, and project-specific standards.

> Make the smallest safe, maintainable, testable, observable, and well-documented framework change that satisfies the requirement.

## Scope

This standard applies to framework configuration, architecture, application lifecycle, framework integrations, framework-specific security, tests, build behavior, compatibility, and documentation.

## Instruction precedence

1. Explicit user requirements
2. The nearest more-specific `AGENTS.md`
3. This framework `AGENTS.md`
4. Referenced language, discipline, platform, virtualization, operating-system, networking, profile, and governance standards
5. Repository conventions
6. General agent preferences

Report material conflicts instead of silently choosing the convenient interpretation.

## Required supporting standards

Read every applicable supporting standard before implementation:

- `standards/COMPONENT_ARCHITECTURE_STANDARD.md`
- `standards/STATE_DATA_FLOW_STANDARD.md`
- `standards/ACCESSIBILITY_STANDARD.md`
- `standards/SECURITY_STANDARD.md`
- `standards/ROUTING_DATA_FETCHING_STANDARD.md`
- `standards/PERFORMANCE_STANDARD.md`
- `standards/TESTING_STANDARD.md`
- `standards/COMPLETION_EVIDENCE.md`

## Non-negotiable behavior

- Inspect the current application structure, framework configuration, tests, dependencies, and conventions before changing anything.
- Preserve public contracts unless change is explicitly authorized.
- Do not invent runtime versions, endpoints, identities, credentials, data stores, infrastructure, or deployment assumptions.
- Validate external input and trust-boundary data.
- Keep secrets out of source, tests, logs, errors, examples, and committed configuration.
- Do not weaken framework security controls to make a change succeed.
- Use framework extension points deliberately and avoid bypassing built-in safety mechanisms without documented justification.
- Preserve cancellation, cleanup, disposal, teardown, and graceful shutdown behavior.
- Define background and asynchronous work semantics explicitly.
- Add or update tests and documentation with behavior changes.
- State compatibility and migration effects.
- Never claim a test or build passed unless it was run successfully.

## Required working method

1. Discover the current framework, language, runtime, build, deployment, and supported-version constraints.
2. Identify affected framework boundaries and companion disciplines.
3. Classify risk and define acceptance criteria.
4. Review framework defaults and project overrides.
5. Implement the smallest coherent change.
6. Add or update tests, configuration validation, and documentation.
7. Run framework and repository validation.
8. Review the diff for unrelated changes, unsafe defaults, secrets, compatibility regressions, and unresolved placeholders.
9. Record exact evidence, limitations, and checks not run.

## Preserved mandatory rules

### REACT-STATE-001

**Requirement:** Keep state ownership clear and avoid duplicating derived state.

**Evidence:** Project-specific review and validation demonstrating the requirement.
### REACT-A11Y-002

**Requirement:** Use semantic HTML and verify keyboard, focus, labels, and announcements.

**Evidence:** Project-specific review and validation demonstrating the requirement.
### REACT-SEC-003

**Requirement:** Do not inject untrusted HTML; treat client-side checks as usability only.

**Evidence:** Project-specific review and validation demonstrating the requirement.
### REACT-PERF-004

**Requirement:** Measure before adding memoization or complex performance patterns.

**Evidence:** Project-specific review and validation demonstrating the requirement.
### REACT-TEST-005

**Requirement:** Test user-observable behavior rather than implementation details.

**Evidence:** Project-specific review and validation demonstrating the requirement.

## Completion evidence

Record:

- framework and language versions
- changed files and affected application boundaries
- configuration and security effects
- lifecycle, concurrency, and cleanup effects
- exact validation commands and outcomes
- compatibility and migration impact
- checks not run
- residual risk and limitations
- accountable review

Do not report framework work complete until applicable evidence is recorded and remaining limitations are explicit.
