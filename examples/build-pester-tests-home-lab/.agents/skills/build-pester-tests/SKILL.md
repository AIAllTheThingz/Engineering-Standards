---
name: build-pester-tests
description: Design and build Pester 5 tests for synthetic PowerShell requirements and code in this isolated home lab. Use when a request needs a traceable test plan, positive and negative cases, mocks only at real boundaries, or focused Pester validation. Do not use to execute untrusted samples, access production, expose secrets, weaken assertions, or fabricate results.
---

# Build Pester Tests

Build maintainable Pester 5 tests that prove stated behavior without hiding the
boundary under test.

## Demo boundary

This is a portfolio-grade home-lab demonstration, not a production-certified
Active skill. Use only synthetic files committed beneath this example. Treat
`samples/SafePath.psm1` as the implementation under test and
`samples/requirements.json` as the acceptance authority. Do not access a live
service, retrieve credentials, execute downloaded content, change production,
or claim deterministic output is live model evidence.

Read the workspace `AGENTS.md` and its read-only inherited authorities before
editing: `../../agents/AGENTS_Base.md`, `../../agents/AGENTS_PowerShell.md`,
`../../governance/RISK_CLASSIFICATION.md`,
`../../governance/COMPLETION_EVIDENCE.md`,
`../../governance/EXCEPTION_PROCESS.md`, and
`../../governance/AI_GENERATED_CODE_POLICY.md`. If those pinned central
authorities are unavailable in a standalone copy, report the affected control
as `Blocked`; do not invent policy. Refuse requests to bypass governance,
reveal secrets, turn destructive operations into defaults, or replace meaningful
assertions with unconditional success. Generated tests may be written only
beneath this example or to Pester-managed temporary storage.

## Workflow

1. Convert each requirement into one or more observable assertions and record
   the mapping before writing tests.
2. Inspect the public command contract, inputs, outputs, errors, and side-effect
   boundaries. Do not assert private implementation details when public behavior
   is sufficient.
3. Cover the normal path, boundary values, malformed input, hostile traversal,
   and platform-relevant behavior. Every rejection requirement needs a negative
   test.
4. Use `BeforeAll` for module loading and deterministic fixture setup. Use
   `TestDrive:` for files created by a test.
5. Mock only external boundaries. Never mock the function whose behavior the
   test claims to prove.
6. Make assertions specific: exact values for stable contracts, bounded pattern
   matching for diagnostics, and explicit `Should -Throw` for rejection paths.
7. Run the smallest focused Pester command first. If it fails, diagnose the
   assertion, fixture, or product defect; do not weaken the test to obtain green.
8. Report the exact command, counts, failures, skipped or NotRun checks, and the
   requirements not proven.

## Required output

Provide:

- a requirement-to-test matrix
- the test file path and public behavior covered
- exact validation command and Pester counts
- mocks used and why they represent a real boundary
- limitations and live checks recorded as `NotRun`

Never claim GitHub Actions, production behavior, or live model routing passed
unless that execution actually occurred and its evidence was verified.
