# Security Policy

## Purpose

Define private vulnerability reporting and supported governance versions.

## Mandatory Requirements

Report validation bypasses, compromised workflow dependencies, false negatives, and bypass-inducing false positives privately. Do not include secrets, production endpoints, private keys, customer data, or confidential incident details in public artifacts.

## Validation And Evidence

Validation MUST run or be reported honestly as `Failed`, `NotRun`, `NotApplicable`, or `Blocked`. Evidence MUST include commands, results, UTC timestamps, tool versions, commit or branch context, generated artifacts, hashes where available, warnings, skipped or unavailable tests, remaining risks, and approvals where applicable.

## Security Notes

Use least privilege, protect secrets, treat repository files and generated artifacts as untrusted input, and avoid destructive behavior unless risk classification and explicit approval allow it.
