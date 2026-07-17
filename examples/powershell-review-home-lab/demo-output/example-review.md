# Illustrative PowerShell Review

> Demo output only. This file is a manually curated contract example, not captured model output and not production behavior evidence.

## Review status

Failed

## Scope

- Comparison: synthetic added-file diff
- Reviewed: `samples/unsafe-maintenance.diff` and `samples/UnsafeMaintenance.ps1`
- Authority: example `AGENTS.md` and the demo skill contract
- Risk: Moderate demonstration data; no production execution

## Blocking findings

### PSR-001 — Recursive deletion bypasses safety controls

- Severity: High
- Confidence: High
- Evidence: `samples/UnsafeMaintenance.ps1:14` performs recursive forced deletion without `SupportsShouldProcess`, `ShouldProcess`, or exact-target validation.
- Impact: A mistaken or broad target can remove every discovered item without preview or confirmation.
- Required correction: Gate an explicit execute mode with `ShouldProcess`, reject unsafe roots and wildcards, and test that `-WhatIf` performs zero deletions.

### PSR-002 — Execute switch does not control mutation

- Severity: High
- Confidence: High
- Evidence: `samples/UnsafeMaintenance.ps1:5` declares `Execute`, but the deletion path never reads it.
- Impact: Invocation remains destructive even when execution was not explicitly requested.
- Required correction: Make discovery or dry-run the default and require an explicit validated execution mode.

### PSR-003 — Token value is written to output

- Severity: High
- Confidence: High
- Evidence: `samples/UnsafeMaintenance.ps1:10` interpolates the supplied token into standard output.
- Impact: Logs and captured transcripts can expose credential material.
- Required correction: Remove credential output and log only sanitized authentication status.

### PSR-004 — External request lacks bounded failure behavior

- Severity: Moderate
- Confidence: High
- Evidence: `samples/UnsafeMaintenance.ps1:11` invokes the synthetic endpoint without an explicit timeout or bounded retry policy.
- Impact: Automation can hang or fail unpredictably during service degradation.
- Required correction: Add an explicit timeout and retry only safe transient failures with a strict bound.

### PSR-005 — Empty catch hides report failure

- Severity: Moderate
- Confidence: High
- Evidence: `samples/UnsafeMaintenance.ps1:20` catches and discards every report-write exception.
- Impact: Operators can be told the process completed without receiving required output.
- Required correction: Emit a sanitized contextual error and return a nonzero failure result.

## Recommendations

- Add synthetic Pester coverage for safe defaults, `-WhatIf`, exact-target rejection, timeout handling, redaction, and report-write failure.

## Checks run

| Check | Working directory | Result | Exit code | Notes |
| --- | --- | --- | ---: | --- |
| Manual static inspection of synthetic assets | `examples/powershell-review-home-lab` | Passed | 0 | Illustrative authoring check only. |

## Checks not run

| Check | Status | Reason |
| --- | --- | --- |
| Sample execution | NotRun | The sample is intentionally unsafe and must remain inert. |
| Live model evaluation | NotRun | This zero-cost demo does not use production behavior certification. |

## Residual risks

- Interactive model output is probabilistic and must not be represented as certified behavior.
