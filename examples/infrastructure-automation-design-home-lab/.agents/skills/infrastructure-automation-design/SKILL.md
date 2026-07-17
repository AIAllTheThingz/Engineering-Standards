---
name: infrastructure-automation-design
description: Design secure infrastructure automation architectures for synthetic home-lab requirements. Use for trust boundaries, identity, state, dependency pinning, rollout, recovery, observability, failure containment, and validation planning before implementation. Do not use to access cloud accounts, retrieve secrets, deploy resources, weaken approvals, choose destructive defaults, or claim an unbuilt design is operational.
---

# Infrastructure Automation Design

Turn requirements into a reviewable automation architecture before code or
deployment begins.

## Demo boundary

This is a portfolio-grade home-lab demonstration, not a production-certified
Active skill. Use only the fictional requirements committed beneath this
example. Produce design artifacts only. Do not authenticate to platforms,
provision resources, change DNS or networks, retrieve secrets, or run a plan
against live state.

Read `AGENTS.md` and the read-only authorities
`../../agents/AGENTS_Base.md`, `../../agents/AGENTS_Infrastructure.md`,
`../../agents/AGENTS_Integration.md`,
`../../governance/RISK_CLASSIFICATION.md`,
`../../governance/COMPLETION_EVIDENCE.md`,
`../../governance/EXCEPTION_PROCESS.md`, and
`../../governance/AI_GENERATED_CODE_POLICY.md`. If those pinned central
authorities are unavailable in a standalone copy, report the affected control
as `Blocked`; do not invent policy.

## Workflow

1. Record functional requirements, service objectives, constraints, risk, data
   classification, ownership, environments, and explicit non-goals.
2. Draw trust zones and data or control flows. Identify human, workload, CI,
   state-backend, artifact, secret-provider, and target-platform identities.
3. Separate candidate infrastructure definitions from trusted orchestration.
   Candidate pull requests must not receive production secrets or execute
   privileged apply operations.
4. Define least-privilege roles, short-lived authentication, approval ownership,
   environment protection, state locking, encryption, and audit attribution.
5. Pin actions, modules, providers, images, and reusable workflows immutably.
   Define update, vulnerability response, provenance, and rollback processes.
6. Design `Validate`, `Plan`, `Approve`, `Apply`, `Verify`, and `Recover` stages.
   Bound concurrency, target selection, timeout, retry, and blast radius.
7. Define observability and failure signals before rollout: structured events,
   metrics, alerts, drift, cost, capacity, health, and recovery objectives.
8. Validate with schema, policy, lint, unit, integration, negative authorization,
   plan review, idempotency, drift, interruption, and recovery tests.
9. Report tradeoffs, assumptions, residual risks, decisions requiring owners,
   exact checks run, and deployment or live verification as `NotRun`.

Never present a diagram or passing static test as proof that infrastructure is
secure, recoverable, or operational.
