# Completion Evidence

## Purpose

Define evidence required before work can be declared complete.

## Mandatory Requirements

Evidence MUST include test command, result, UTC timestamp, tool/runtime versions, commit SHA, branch or PR, generated artifacts, hashes, warnings, skipped tests, tests not run, remaining risks, manual validation, approvals, and rollback validation where applicable. Allowed statuses are `Passed`, `Failed`, `NotRun`, `NotApplicable`, and `Blocked`; `NotRun`, `Blocked`, and `NotApplicable` MUST NOT be represented as `Passed`.

## Validation And Evidence

Validation MUST run or be reported honestly as `Failed`, `NotRun`, `NotApplicable`, or `Blocked`. Evidence MUST include commands, results, UTC timestamps, tool versions, commit or branch context, generated artifacts, hashes where available, warnings, skipped or unavailable tests, remaining risks, and approvals where applicable.

## Security Notes

Use least privilege, protect secrets, treat repository files and generated artifacts as untrusted input, and avoid destructive behavior unless risk classification and explicit approval allow it.
