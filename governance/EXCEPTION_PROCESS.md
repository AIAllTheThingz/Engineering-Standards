# Exception Process

## Purpose

Define formal, time-bounded governance exceptions.

## Mandatory Requirements

Each exception MUST include identifier, requestor, date, repository/control, justification, risk assessment, compensating controls, scope, start date, expiration date, owner, approvers, review schedule, and closure criteria. Exceptions expire automatically unless renewed and must remain discoverable. Example identifier: `GOV-EXAMPLE-2026-001`.

## Validation And Evidence

Validation MUST run or be reported honestly as `Failed`, `NotRun`, `NotApplicable`, or `Blocked`. Evidence MUST include commands, results, UTC timestamps, tool versions, commit or branch context, generated artifacts, hashes where available, warnings, skipped or unavailable tests, remaining risks, and approvals where applicable.

## Security Notes

Use least privilege, protect secrets, treat repository files and generated artifacts as untrusted input, and avoid destructive behavior unless risk classification and explicit approval allow it.
