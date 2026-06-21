# AGENTS.md

## Inherited Standards

This repository inherits the central engineering standards:

- `AIAllTheThingz/Engineering-Standards/agents/AGENTS_Base.md@<immutable-reference>`
- `<technology-specific-standard>@<immutable-reference>`

Local instructions may strengthen these standards but MUST NOT weaken them.

## Repository Purpose

Describe what this repository builds, owns, deploys, or governs. Include production impact, data classification, and systems affected by agent changes.

## Ownership

- Primary owner: `<owner>`
- Review owner: `<review-owner>`
- Security escalation: `<security-contact>`

## Allowed Work

List the types of changes agents may make, such as documentation updates, tests, validators, application code, infrastructure plans, or generated artifacts.

## Restricted Work

List work that requires explicit approval, such as production deployments, destructive operations, schema migrations, authentication changes, cryptography, secret handling, or dependency changes.

## Commands

List real commands for setup, lint, build, test, governance validation, evidence generation, and cleanup.

```powershell
<validation-command>
```

## Evidence

Agents MUST update completion evidence when they perform substantive work. Evidence must distinguish `Passed`, `Failed`, `Blocked`, `NotRun`, and `NotApplicable` results.

## Exceptions

Agents MUST NOT create, renew, or rely on governance exceptions unless the user provides an approved `GOV-*` reference or explicitly asks to draft an exception request.

## Safety Notes

Do not expose secrets, paste production data into prompts, disable mandatory controls, rewrite protected history, or run destructive operations without explicit approval and rollback context.
