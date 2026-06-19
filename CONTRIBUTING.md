# Contributing

## Purpose

Define contribution expectations for governance changes.

## Mandatory Requirements

Preserve the authority hierarchy, inspect existing standards before editing, update schemas and fixtures together, add tests for validation behavior, classify risk, record validation honestly, and never add secrets or production-specific values.

## Validation And Evidence

Validation MUST run or be reported honestly as `Failed`, `NotRun`, `NotApplicable`, or `Blocked`. Evidence MUST include commands, results, UTC timestamps, tool versions, commit or branch context, generated artifacts, hashes where available, warnings, skipped or unavailable tests, remaining risks, and approvals where applicable.

## Security Notes

Use least privilege, protect secrets, treat repository files and generated artifacts as untrusted input, and avoid destructive behavior unless risk classification and explicit approval allow it.
