---
id: PLAT-MATRIX-001
title: Platform Decision Matrix
version: 0.2.0
status: baseline
---
# Platform Decision Matrix

## Purpose

Provides a starting point for scaling platform controls by risk. Governance remains authoritative.

| Control | Low | Moderate | High | Critical |
|---|---|---|---|---|
| Target identity | confirmed | confirmed and recorded | independently verified | independently verified with change freeze awareness |
| Plan or rendered diff | focused | required | independently reviewed | formally approved |
| Destructive review | if present | required | independent approval | highest applicable authority |
| Identity review | if changed | required | specialist review | independent specialist review |
| Network review | if changed | required | tested allowed and denied paths | staged with explicit stop criteria |
| Data and secret review | if present | required | specialist and recovery review | formal risk decision |
| Recovery | proportionate | defined | tested where practical | rehearsed or explicitly risk-accepted |
| Observability | basic | required | alerts and runbooks reviewed | operational go/no-go |
| Cost and quota | plausibility | reviewed | budget and capacity evidence | explicit owner acceptance |
| Rollout | normal | monitored | staged | staged with rapid stop and recovery |
| Evidence retention | normal | traceable | durable | durable and auditable |

## Escalation triggers

Escalate risk when:

- target identity is ambiguous
- privilege expands
- public exposure increases
- data sensitivity or residency changes
- resources will be replaced or destroyed
- rollback or restore is uncertain
- a shared account, cluster, network, or state backend is affected
- multiple environments are changed
- quota or cost impact is uncertain
- a vulnerability or incident is involved
- current state differs from declared state
- the operator cannot observe or recover the change

## Decision rule

When risk or blast radius is uncertain, use the higher plausible class until evidence supports reduction.
