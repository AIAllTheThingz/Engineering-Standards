# Illustrative Python Review

> Demo output only. This manually curated file is not captured model output and is not production behavior evidence.

## Review status

Failed

## Scope

- Comparison: synthetic added-file diff
- Reviewed: `samples/unsafe-maintenance.diff` and `samples/unsafe_maintenance.py`
- Authority: example instructions and demo skill contract
- Risk: Moderate demonstration data; no Python execution

## Blocking findings

### PYR-001 — Shell execution permits command injection

- Severity: High
- Evidence: `samples/unsafe_maintenance.py:10` passes caller-controlled text to `subprocess.run` with `shell=True`.
- Impact: shell metacharacters can execute unintended commands.
- Required correction: use a fixed executable and validated argument list without a shell.

### PYR-002 — Authentication material is printed

- Severity: High
- Evidence: `samples/unsafe_maintenance.py:9` writes the environment-derived value to output.
- Impact: logs and transcripts can disclose authentication material.
- Required correction: remove the value and report sanitized authentication status only.

### PYR-003 — Recursive deletion trusts an arbitrary path

- Severity: High
- Evidence: `samples/unsafe_maintenance.py:13` deletes `target_root` without canonicalization, safe-root enforcement, or an explicit execute gate.
- Impact: an empty, broad, linked, or unexpected target can remove unintended data.
- Required correction: canonicalize beneath an allowlisted root, reject unsafe targets, and require a previewed execution mode.

### PYR-004 — Network access has no bound

- Severity: Moderate
- Evidence: `samples/unsafe_maintenance.py:11` supplies no timeout or response-size policy.
- Impact: the process can hang or consume unbounded response data.
- Required correction: set explicit connection/read bounds and close the response deterministically.

### PYR-005 — Deletion failure is reported as success

- Severity: Moderate
- Evidence: `samples/unsafe_maintenance.py:14-15` catches every exception and returns `True`.
- Impact: callers cannot distinguish a completed operation from a failed deletion.
- Required correction: catch expected exceptions narrowly and propagate a truthful failure result.

### PYR-006 — Negative-path tests are absent

- Severity: Moderate
- Evidence: the added-file diff contains no tests for injection, unsafe roots, timeout, redaction, or deletion failure.
- Impact: unsafe behavior and misleading status can regress undetected.
- Required correction: add isolated tests using mocks and temporary paths without importing this unsafe demonstration file.

## Checks not run

| Check | Status | Reason |
| --- | --- | --- |
| Python sample import or execution | NotRun | The sample is intentionally unsafe and must remain inert. |
| Live model evaluation | NotRun | This zero-cost demo does not perform controlled model evaluation. |

## Residual risks

- Interactive output is probabilistic and is not certified by deterministic checks.
