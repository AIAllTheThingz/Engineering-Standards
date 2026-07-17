---
id: VIRT-XENS-AGENT-001
title: XenServer and Citrix Hypervisor Agent Standard
version: 0.1.0
status: baseline
applies_to:
  - xenserver-citrix-hypervisor
depends_on:
  - VIRT-AGENT-001
  - GOV-RISK
  - GOV-SECDEV
---

# XenServer and Citrix Hypervisor Agent Standard

## Purpose

Define mandatory behavior for agents designing, scripting, administering, reviewing, troubleshooting, recovering, or migrating XenServer and Citrix Hypervisor environments.

This package supplements root governance, the virtualization collection, language packages, engineering disciplines, project profiles, and adopting-project instructions.

## Authoritative boundary

The management authority is XenServer resource pool and its pool coordinator, or the exact standalone host.

Do not mutate objects until that authority, environment, stable object scope, and acting identity are verified.

## Scope

- XenServer/Citrix Hypervisor hosts
- pools
- pool coordination
- VMs
- templates
- networks
- physical interfaces
- bonds
- storage repositories
- HA
- updates
- XenCenter
- xe
- XAPI

## Required reading

- [Package README](README.md)
- [Package manifest](MANIFEST.md)
- [Operations and automation standard](standards/OPERATIONS_AND_AUTOMATION_STANDARD.md)
- [Collection selection guide](../VIRTUALIZATION_SELECTION_GUIDE.md)
- [Collection change lifecycle](../VIRTUALIZATION_CHANGE_LIFECYCLE.md)
- [Collection migration matrix](../MIGRATION_DECISION_MATRIX.md)
- applicable governance, language, discipline, platform, virtualization, operating-system, networking, framework, and profile packages

## Supported interfaces

Prefer XenCenter, the supported xe CLI, XAPI, and supported XenServer SDKs.

Pin or constrain automation dependencies when practical. Verify interface, server, and API compatibility against current official documentation. Do not use screen scraping, direct manager-database edits, undocumented endpoints, or manual edits to manager-owned state.

## Lifecycle and compatibility

Use current XenServer branding and documentation while recording Citrix Hypervisor or older XenServer names when they identify the installed product. Verify upgrade paths, pool compatibility, hardware compatibility, guest support, tools, licensing, and support lifecycle.

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

- Do not assume the current pool coordinator remains fixed during failure or maintenance.
- Do not perform unsupported package changes in the control domain.
- Do not remove or forget a storage repository until VM and disk ownership is proven.

## Product rules

### VIRT-XENS-POOL-001

**Requirement:** Resolve pool UUID, coordinator, member health, versions, and active tasks before pool or host mutation.

**Expected evidence:** Pool inventory, UUIDs, coordinator, health, and task evidence.

### VIRT-XENS-UPDATE-002

**Requirement:** Use supported update and upgrade sequencing with mixed-version and pool restrictions reviewed.

**Expected evidence:** Vendor-supported sequence, compatibility review, and rollback limits.

### VIRT-XENS-SR-003

**Requirement:** Validate storage-repository type, shared state, paths, capacity, PBD attachments, and VDI ownership before mutation.

**Expected evidence:** SR/PBD/VDI inventory and recovery evidence.

### VIRT-XENS-NET-004

**Requirement:** Map networks, PIFs, bonds, VLANs, management access, and VM interfaces before network changes.

**Expected evidence:** Topology and connectivity validation including recovery access.

### VIRT-XENS-XAPI-005

**Requirement:** Use supported XAPI, SDK, or xe operations and preserve task/event identifiers.

**Expected evidence:** Interface version, task records, and actual-state verification.

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
