# Contributing

## Purpose

This document defines how contributors change this repository safely. Contributions MUST preserve governance controls, evidence integrity, branch protection, and security requirements.

## Local Setup

Install required tools:

```powershell
<setup-command>
```

Use sanitized local data. Do not use production secrets, customer data, or private credentials for local testing.

## Branching

Create a short-lived branch from the protected branch. Use a descriptive name such as `feature/<scope>`, `fix/<scope>`, or `governance/<scope>`.

Do not push directly to protected branches except through the documented emergency process.

## Change Requirements

Every pull request MUST include a summary, reason for change, risk classification, security impact, data impact, validation results, evidence link, rollback plan, and active exceptions.

Changes that affect production behavior, workflows, schemas, secrets, infrastructure, database migrations, authentication, authorization, or destructive operations require heightened review.

## Validation

Run the project validation commands before requesting review:

```powershell
<lint-command>
<build-command>
<test-command>
<governance-validation-command>
```

Record skipped or unavailable checks honestly as `Skipped`, `NotRun`, or `Blocked`.

## Evidence

Completion evidence must be generated after validation and stored at the path declared in `project-manifest.json`.

Evidence must include commands, exit codes, timestamps, warnings, artifacts, reviewer approvals when required, and limitations.

## Exceptions

Exceptions require an approved `GOV-*` record with owner, scope, reason, expiration, compensating control, and remediation plan.

Missing validation, false evidence, unresolved secrets, or absent ownership are not valid exceptions.

## Review

Reviewers MUST verify that the change matches the stated risk, evidence is credible, secrets are not exposed, and rollback is realistic.

Do not approve contradictory evidence or disabled mandatory controls without an approved exception.
