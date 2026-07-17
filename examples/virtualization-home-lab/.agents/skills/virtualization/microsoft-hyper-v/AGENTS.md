---
id: VIRT-HV-AGENT-001
title: Microsoft Hyper-V Agent Standard
version: 0.1.0
status: baseline
applies_to:
  - microsoft-hyper-v
depends_on:
  - VIRT-AGENT-001
  - GOV-RISK
  - GOV-SECDEV
---

# Microsoft Hyper-V Agent Standard

## Purpose

Define mandatory behavior for agents designing, scripting, administering, reviewing, troubleshooting, recovering, or migrating Microsoft Hyper-V environments.

This package supplements root governance, the virtualization collection, language packages, engineering disciplines, project profiles, and adopting-project instructions.

## Authoritative boundary

The management authority is Windows Server Failover Cluster, SCVMM fabric, or exact standalone Hyper-V host.

Do not mutate objects until that authority, environment, stable object scope, and acting identity are verified.

## Scope

- Windows Server Hyper-V hosts and clusters
- Failover Clustering
- Cluster Shared Volumes
- VMs
- checkpoints
- virtual switches
- live and storage migration
- Hyper-V Replica
- shielded VMs
- WAC
- SCVMM
- PowerShell

## Required reading

- [Package README](README.md)
- [Package manifest](MANIFEST.md)
- [Operations and automation standard](standards/OPERATIONS_AND_AUTOMATION_STANDARD.md)
- [Collection selection guide](../VIRTUALIZATION_SELECTION_GUIDE.md)
- [Collection change lifecycle](../VIRTUALIZATION_CHANGE_LIFECYCLE.md)
- [Collection migration matrix](../MIGRATION_DECISION_MATRIX.md)
- applicable governance, language, discipline, platform, virtualization, operating-system, networking, framework, and profile packages

## Supported interfaces

Prefer Hyper-V and FailoverClusters PowerShell modules, Windows Admin Center, SCVMM, WMI/CIM, and supported Microsoft APIs.

Pin or constrain automation dependencies when practical. Verify interface, server, and API compatibility against current official documentation. Do not use screen scraping, direct manager-database edits, undocumented endpoints, or manual edits to manager-owned state.

## Lifecycle and compatibility

Verify Windows Server version and servicing, cluster functional level, hardware and firmware, guest support, VM configuration version, integration services, backup, storage, network, SCVMM/WAC, PowerShell, and licensing.

Record the exact versions and source-review date. Do not rely on remembered compatibility, feature, licensing, or support claims.

## Non-negotiable behavior

- Discover inventory, versions, health, alarms, events, tasks, capacity, backup, and dependencies before mutation.
- Resolve stable IDs and parent scope; reject ambiguous name-only matches.
- Separate discovery, validation, preview, reporting, execution, verification, and recovery.
- Require explicit authorization for power, deletion, disk, snapshot, checkpoint, network, storage, host, cluster, failover, replication, or migration changes.
- Verify independent backup or export and recovery readiness before destructive or high-blast-radius work.
- Treat snapshots and checkpoints as short-lived operational mechanisms, not backups by default.
- Bound concurrency, polling, retries, and timeouts.
- Preserve task, event, audit, and correlation identifiers.
- Redact credentials, tokens, certificates, console data, support bundles, and sensitive inventory.
- Verify actual platform and workload state after task completion.
- Record checks not run, limitations, operator interventions, and residual risk.
- Do not claim zero downtime, recoverability, compatibility, supportability, or production readiness without evidence.

## Product-specific cautions

- Do not change a cluster-owned VM through a standalone-host assumption.
- Do not use standard checkpoints as backup or assume production checkpoints are application-consistent recovery copies.
- Do not modify CSV, live-migration, virtual-switch, constrained-delegation, or cluster networking without end-to-end ownership and validation.

## Product rules

### VIRT-HV-SCOPE-001

**Requirement:** Resolve SCVMM, cluster, or standalone-host authority plus VM ID before mutation.

**Expected evidence:** Manager/cluster identity, VM ID, owner node, and acting identity.

### VIRT-HV-CLUSTER-002

**Requirement:** Run applicable cluster validation and review quorum, CSV, networks, capacity, roles, and active operations before cluster changes.

**Expected evidence:** Cluster validation and health evidence.

### VIRT-HV-WHATIF-003

**Requirement:** PowerShell automation must support ShouldProcess and WhatIf where applicable, plus explicit execution enablement for consequential actions.

**Expected evidence:** Help, parameter, WhatIf, confirmation, and negative-path tests.

### VIRT-HV-CHECKPOINT-004

**Requirement:** Classify checkpoint type, age, chain, merge risk, application impact, and backup coverage before checkpoint operations.

**Expected evidence:** Checkpoint chain and independent backup evidence.

### VIRT-HV-VERIFY-005

**Requirement:** Verify cluster group, VM, storage, network, replication, guest, and application state after tasks complete.

**Expected evidence:** Before/after state and workload validation.

## Required working method

1. Identify authority, target, versions, owners, and current state without mutation.
2. Validate health, privileges, compatibility, capacity, backup, recovery, and maintenance window.
3. Produce an exact plan or dry-run with selected object IDs and ordered actions.
4. Review power, deletion, privilege, network, storage, availability, licensing, and support effects.
5. Obtain accountable authorization for the exact plan and target.
6. Execute through supported interfaces with bounded concurrency and stop conditions.
7. Verify manager, host, VM, guest, network, storage, backup, and monitoring state.
8. Observe outcomes for a risk-proportionate interval.
9. Preserve evidence and disclose deviations and residual risk.

## Automation requirements

Custom automation must:

- default to non-mutating discovery
- provide validation and dry-run or plan behavior
- require explicit execution enablement
- support confirmation semantics when the language and interface permit
- use structured configuration, input, logging, and reports
- handle missing, duplicate, stale, disconnected, unauthorized, unhealthy, and disappearing objects
- classify retryable and terminal failures
- be safe to rerun or clearly document manual recovery
- test positive, negative, partial-failure, and recovery paths
- document exact supported product and interface versions

## Decision gates

Stop when target identity, authority, health, compatibility, capacity, backup, recovery, support, or authorization is unresolved.

## Completion evidence

Record:

- selected package and exact product boundary
- endpoint and object scope without sensitive identifiers
- acting identity class and authorization
- versions, edition, lifecycle, and sources checked
- before, intended, and actual state
- task and event identifiers
- power, network, storage, availability, licensing, and recovery impact
- exact validation and results
- actual-state and workload verification
- rollback, restore, failback, or rebuild readiness
- checks not run, limitations, owners, reviewers, and residual risk
