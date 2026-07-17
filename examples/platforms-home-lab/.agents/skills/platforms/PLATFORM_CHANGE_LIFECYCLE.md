---
id: PLAT-LIFECYCLE-001
title: Platform Change Lifecycle
version: 0.2.0
status: baseline
---
# Platform Change Lifecycle

## Purpose

Defines the required lifecycle for consequential platform and infrastructure changes.

## Lifecycle

```text
request
  -> identify target and authority
  -> discover current state
  -> classify risk
  -> define desired state and acceptance criteria
  -> identify destructive and replacement actions
  -> define validation and recovery
  -> review plan or rendered configuration
  -> authorize execution
  -> apply in controlled phases
  -> verify actual state
  -> observe
  -> close or remediate
```

## Discovery

Before change:

- confirm account, subscription, project, cluster, workspace, registry, backend, or target identity
- inspect current configuration and drift
- identify dependencies and ownership
- identify secrets, data, certificates, keys, and state
- identify public exposure and privilege
- identify quotas, limits, budgets, and capacity
- identify existing incidents, changes, locks, or maintenance windows

## Planning

The plan must show:

- resources created, changed, replaced, or destroyed
- identity and policy changes
- network-path changes
- data and migration impact
- downtime or availability impact
- expected cost and quota impact
- validation
- stop criteria
- rollback, roll-forward, restore, or recreation
- approvers and operators

## Execution

Consequential execution requires:

- explicit authorization
- narrow target scope
- approved identity
- controlled environment
- traceable artifact or configuration
- bounded time and concurrency
- progress and failure visibility
- stop criteria

## Verification

Verify actual state, not only tool exit status:

- intended resources and settings exist
- denied access remains denied
- required paths work
- logs and alerts arrive
- health and readiness are correct
- data and secrets are protected
- recovery assumptions remain valid
- drift and unintended changes are absent
- cost and quota expectations remain plausible

## Closure

Record:

- artifact, commit, plan, or deployment
- actor and target
- validation results
- checks not run
- incidents or deviations
- rollback or remediation
- residual risk
- operational owner
- follow-up dates
