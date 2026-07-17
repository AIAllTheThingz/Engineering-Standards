---
id: PLAT-SHARED-001
title: Platform Shared Responsibility Model
version: 0.2.0
status: baseline
---
# Platform Shared Responsibility Model

## Purpose

Defines how platform responsibilities are divided among providers, platform teams, application teams, security teams, operators, and accountable owners.

## Responsibility categories

For each platform boundary, assign ownership for:

- account, tenant, subscription, project, cluster, or registry structure
- identity federation, credentials, roles, and privileged access
- network routing, public exposure, DNS, ingress, egress, and inspection
- images, packages, providers, modules, and dependencies
- configuration, secrets, keys, certificates, and rotation
- data classification, encryption, backup, retention, and deletion
- policy, admission, guardrails, exceptions, and drift
- logs, metrics, traces, alerts, dashboards, and retention
- capacity, quotas, limits, scaling, budgets, and cost anomalies
- deployment, migration, rollback, failover, restore, and incident response
- vulnerability remediation and unsupported components
- evidence retention and production approval

## Required record

A project should maintain a responsibility table:

| Boundary | Provider or platform | Application team | Security or specialist | Operator | Accountable owner |
|---|---|---|---|---|---|
| Identity | | | | | |
| Network | | | | | |
| Data | | | | | |
| Secrets and keys | | | | | |
| Logging and monitoring | | | | | |
| Recovery | | | | | |
| Cost and quota | | | | | |

## Managed service warning

“Managed” describes who operates part of a service. It does not mean:

- secure configuration is automatic
- access is least privilege
- data classification is complete
- backups are restorable
- logging reaches an owned destination
- quotas match workload needs
- cost is controlled
- the provider accepts application risk
- production readiness has been approved

## Handoff requirements

A responsibility handoff must identify:

- scope
- effective date
- owner
- evidence
- interfaces
- escalation
- support hours
- recovery expectations
- unresolved gaps
- re-review trigger

## Completion boundary

Shared responsibility is not established by naming teams in a diagram. Each material control must have an owner, an implementation boundary, evidence, and an escalation path.
