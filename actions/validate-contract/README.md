# Validate governance contract

## Purpose

Validate downstream repository governance files.

## Mandatory Requirements

Use `contents: read`; no secrets or write permissions are required. The action exits nonzero on mandatory failure, supports PowerShell 7 on GitHub-hosted runners, validates paths, treats input as untrusted, and writes optional JSON reports.

## Validation And Evidence

Validation MUST run or be reported honestly as `Failed`, `NotRun`, `NotApplicable`, or `Blocked`. Evidence MUST include commands, results, UTC timestamps, tool versions, commit or branch context, generated artifacts, hashes where available, warnings, skipped or unavailable tests, remaining risks, and approvals where applicable.

## Security Notes

Use least privilege, protect secrets, treat repository files and generated artifacts as untrusted input, and avoid destructive behavior unless risk classification and explicit approval allow it.
