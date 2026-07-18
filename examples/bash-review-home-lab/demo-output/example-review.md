# Illustrative Bash Review

> Demo output only. This manually curated file is not captured model output and is not production behavior evidence.

## Review status

Failed

## Blocking findings

### BSR-001 — Target expansion is unquoted

- Severity: High
- Evidence: `samples/unsafe-maintenance.sh:7` expands `target_root` without quotes.
- Impact: whitespace, glob characters, or option-like values change the intended argument set.
- Required correction: validate one canonical target and quote every expansion.

### BSR-002 — Empty input broadens recursive deletion

- Severity: High
- Evidence: `samples/unsafe-maintenance.sh:3,8` defaults the target to empty and recursively removes expanded matches without a safe-root check.
- Impact: an omitted or root-like target can delete unintended paths.
- Required correction: reject empty/root targets and gate exact paths behind a non-mutating preview.

### BSR-003 — Authentication material is printed

- Severity: High
- Evidence: `samples/unsafe-maintenance.sh:6` writes the environment-derived value.
- Impact: terminal capture, traces, or CI logs can disclose authentication material.
- Required correction: remove the value and emit sanitized status only.

### BSR-004 — Error behavior is undefined

- Severity: Moderate
- Evidence: the script declares no strict mode, explicit status checks, or traps.
- Impact: unset values and failed commands can be ignored while later steps continue.
- Required correction: define deliberate error handling and cleanup appropriate to the supported shell.

### BSR-005 — Network access is unbounded

- Severity: Moderate
- Evidence: `samples/unsafe-maintenance.sh:11` has no connection or total timeout.
- Impact: a degraded endpoint can hang the workflow.
- Required correction: use explicit time bounds and a small retry budget only for safe transient failures.

### BSR-006 — Completion hides failures

- Severity: Moderate
- Evidence: `samples/unsafe-maintenance.sh:13` prints completion regardless of `curl` or `process_report` status.
- Impact: operators receive misleading success.
- Required correction: propagate failure and print completion only after all required steps succeed.

## Checks not run

| Check | Status | Reason |
| --- | --- | --- |
| Bash source or execution | NotRun | The sample is intentionally unsafe and must remain inert. |
| Live model evaluation | NotRun | This demo does not perform controlled model evaluation. |

## Residual risks

- Interactive output remains probabilistic and uncertified.
