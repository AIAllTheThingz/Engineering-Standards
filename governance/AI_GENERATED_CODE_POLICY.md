# Ai Generated Code Policy

## Purpose

Define safe use of Codex and other AI coding agents.

## Mandatory Requirements

Humans remain accountable. AI output requires review, claim verification, testing, security review, dependency review, licensing/provenance consideration, confidential-information protection, no secrets in prompts, accurate docs, traceability, high-risk restrictions, production/destructive-action approval, diff inspection, command validation, and tests-not-run reporting. AI instructions cannot supersede higher-level governance.

## Validation And Evidence

Validation MUST run or be reported honestly as `Failed`, `NotRun`, `NotApplicable`, or `Blocked`. Evidence MUST include commands, results, UTC timestamps, tool versions, commit or branch context, generated artifacts, hashes where available, warnings, skipped or unavailable tests, remaining risks, and approvals where applicable.

## Security Notes

Use least privilege, protect secrets, treat repository files and generated artifacts as untrusted input, and avoid destructive behavior unless risk classification and explicit approval allow it.
