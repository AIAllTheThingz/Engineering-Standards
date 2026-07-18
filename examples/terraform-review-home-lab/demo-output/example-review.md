# Illustrative Terraform Review

> Demo output only. This manually curated file is not captured model output and is not production behavior evidence.

## Review status

Failed

## Blocking findings

### TFR-001 — Public ingress is unrestricted

- Severity: High
- Evidence: `samples/main.tf:19-23` allows every protocol from `0.0.0.0/0`.
- Impact: any attached workload can become internet-reachable beyond least privilege.
- Required correction: restrict sources, protocols, and ports to an approved network contract.

### TFR-002 — Persistent data has no deletion protection

- Severity: High
- Evidence: `samples/main.tf:27-30` explicitly allows destruction.
- Impact: replacement or destroy can remove persistent data without a recovery boundary.
- Required correction: enable appropriate protection and document backup, recovery, and approved destructive change handling.

### TFR-003 — Authentication material is a public output

- Severity: High
- Evidence: `samples/main.tf:33-35` exposes the value with `sensitive = false`.
- Impact: console, plan, automation, and state consumers can disclose the value.
- Required correction: remove the output or mark and handle it as sensitive while reviewing state exposure.

### TFR-004 — Provider version is not safely constrained

- Severity: Moderate
- Evidence: `samples/main.tf:5` accepts every later major version.
- Impact: a restore can select unreviewed breaking behavior.
- Required correction: use a reviewed bounded constraint and commit the generated dependency lock from an approved workflow.

### TFR-005 — Backend boundary is unsafe

- Severity: Moderate
- Evidence: `samples/main.tf:8-10` stores state in a relative local path.
- Impact: state can be misplaced, shared without locking, or exposed outside protected environment controls.
- Required correction: define an approved isolated backend with encryption, locking, least privilege, retention, and recovery.

### TFR-006 — Validation and plan evidence are absent

- Severity: Moderate
- Evidence: the added-file diff contains no static, policy, or saved-plan evidence.
- Impact: reviewers cannot assess resolved providers, replacements, deletes, or environment-specific actions.
- Required correction: produce authoritative validation and commit-bound plan evidence in an approved environment; do not run it in this demo.

## Checks not run

| Check | Status | Reason |
| --- | --- | --- |
| Terraform init, validate, plan, or apply | NotRun | Terraform is intentionally absent and the sample must remain inert. |
| Provider, backend, state, or cloud access | NotRun | This demo permits no external access. |
| Live model evaluation | NotRun | Controlled model evaluation is outside this zero-cost demo. |

## Residual risks

- Static review cannot prove authoritative state, plan, policy, cost, drift, or runtime behavior.
