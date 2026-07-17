---
name: safe-automation
description: Design guarded, reversible automation for synthetic home-lab change requests. Use for tasks that need preconditions, approval gates, dry-run behavior, idempotency, bounded targets, rollback, observability, or a staged validation plan. Do not use to retrieve secrets, bypass approvals, target production, execute destructive defaults, or claim an unexecuted plan succeeded.
---

# Safe Automation

Design automation so that failure is bounded, visible, and recoverable.

## Demo boundary

This is a portfolio-grade home-lab demonstration, not a production-certified
Active skill. Work only from synthetic inputs committed beneath this example.
Produce a design and simulation record; do not connect to hosts, schedulers,
cloud accounts, credential stores, or external services. Do not execute the
sample change against a real system.

Read `AGENTS.md` and the read-only inherited authorities
`../../agents/AGENTS_Base.md`, `../../agents/AGENTS_PowerShell.md`,
`../../agents/AGENTS_Infrastructure.md`,
`../../governance/RISK_CLASSIFICATION.md`,
`../../governance/COMPLETION_EVIDENCE.md`,
`../../governance/EXCEPTION_PROCESS.md`, and
`../../governance/AI_GENERATED_CODE_POLICY.md`. If those pinned central
authorities are unavailable in a standalone copy, report the affected control
as `Blocked`; do not invent policy. Refuse secret exposure, governance
bypass, unbounded targets, destructive defaults, and requests to report a plan
as executed evidence.

## Workflow

1. Establish scope, owner, risk, data classification, target selector, and
   explicit non-targets.
2. Define preconditions that fail closed: authority, health, capacity,
   compatibility, backup or recovery readiness, and concurrency limits.
3. Separate `Plan`, `Approve`, `Execute`, `Verify`, and `Recover`. A plan cannot
   approve itself, and verification cannot rely only on a zero exit code.
4. Make preview or dry-run the default. Require attributable approval before a
   mutating phase when risk requires it.
5. Design for idempotency, bounded batches, timeouts, cancellation, retries with
   backoff, and a kill switch. Do not retry non-idempotent actions blindly.
6. Define rollback triggers and test recovery using synthetic state. If rollback
   is unsafe or impossible, stop and document the manual recovery path.
7. Emit sanitized structured events containing correlation ID, phase, target
   count, decision, and outcome—never credential material.
8. Validate schema, negative cases, repeat-run behavior, interrupted execution,
   and recovery. Record external execution and live verification as `NotRun`.

## Required output

Return the bounded target set, phase gates, preconditions, approval owner,
idempotency strategy, rollback plan, observability fields, exact checks run, and
all NotRun limitations. Never claim deployment or GitHub-hosted success without
real verified evidence.
