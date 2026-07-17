---
id: VIRT-VSPH-AGENT-001
title: VMware vSphere and ESXi Agent Standard
version: 0.2.0
status: baseline
applies_to:
  - vsphere-esxi
depends_on:
  - VIRT-AGENT-001
  - GOV-RISK
  - GOV-SECDEV
---

# VMware vSphere and ESXi Agent Standard

## Purpose

Define mandatory behavior for agents designing, scripting, administering, reviewing, troubleshooting, recovering, or migrating VMware vSphere and ESXi environments.

This package supplements root governance, the virtualization collection, language packages, engineering disciplines, project profiles, and adopting-project instructions.

## Authoritative boundary

The management authority is vCenter Server inventory when managed, or the exact standalone ESXi host when explicitly unmanaged.

Do not mutate objects until that authority, environment, stable object scope, and acting identity are verified.

## Scope

- vCenter
- ESXi
- datacenters
- clusters
- resource pools
- hosts
- VMs
- datastores
- standard and distributed switching
- HA
- DRS
- vMotion
- Lifecycle Manager
- content libraries

## Required reading

- [Package README](README.md)
- [Package manifest](MANIFEST.md)
- [Operations and automation standard](standards/OPERATIONS_AND_AUTOMATION_STANDARD.md)
- [VCF PowerCLI automation standard](standards/POWERCLI_AUTOMATION_STANDARD.md) when PowerCLI is used
- [Collection selection guide](../VIRTUALIZATION_SELECTION_GUIDE.md)
- [Collection change lifecycle](../VIRTUALIZATION_CHANGE_LIFECYCLE.md)
- [Collection migration matrix](../MIGRATION_DECISION_MATRIX.md)
- applicable governance, language, discipline, platform, virtualization, operating-system, networking, framework, and profile packages

## Supported interfaces

Prefer VCF PowerCLI (formerly distributed as VMware PowerCLI), supported vSphere APIs and SDKs, ESXCLI, and Lifecycle Manager.

Pin or constrain automation dependencies when practical. Verify interface, server, and API compatibility against current official documentation. Do not use screen scraping, direct manager-database edits, undocumented endpoints, or manual edits to manager-owned state.

## Lifecycle and compatibility

Verify vCenter/ESXi interoperability, hardware compatibility, firmware, drivers, add-ons, image profiles, guest OS support, VMware Tools, virtual hardware, backup integrations, licensing, and Broadcom support entitlements.

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

- Do not manage a vCenter-owned ESXi host as an independent source of truth.
- Do not enter maintenance mode until evacuation feasibility, pinned workloads, passthrough devices, admission control, and capacity are reviewed.
- Treat snapshots as short-lived operational state; validate consolidation risk and independent backup before removal.

## Product rules

### VIRT-VSPH-TARGET-001

**Requirement:** Resolve vCenter, datacenter, cluster, host, and object identity before mutation; reject duplicate name-only matches.

**Expected evidence:** Inventory IDs, parent scope, connected endpoint, and identity evidence.

### VIRT-VSPH-MAINT-002

**Requirement:** Validate evacuation, DRS behavior, passthrough constraints, capacity, HA admission control, and remediation baseline before host maintenance.

**Expected evidence:** Precheck and evacuation plan with blocked-workload disposition.

### VIRT-VSPH-NET-003

**Requirement:** Review distributed-switch or standard-switch changes across port groups, VLANs, uplinks, management, vMotion, storage, and recovery access.

**Expected evidence:** Before/after topology and required/denied path tests.

### VIRT-VSPH-STOR-004

**Requirement:** Validate datastore accessibility, multipathing, capacity, latency, storage policy, backup, and disk ownership before storage mutation.

**Expected evidence:** Storage health, path, capacity, policy, and recovery evidence.

### VIRT-VSPH-TASK-005

**Requirement:** Preserve vCenter task/event IDs and verify actual object state after PowerCLI or API completion.

**Expected evidence:** Task records plus post-change inventory and workload verification.

### VIRT-VSPH-PCLI-006

**Requirement:** PowerCLI automation must bind operations to an explicitly validated connection, pass the intended server scope, and reject ambiguous ambient default connections.

**Expected evidence:** Redacted endpoint and certificate validation, owned connection, explicit server propagation, and session cleanup.

### VIRT-VSPH-PCLI-007

**Requirement:** PowerCLI dependencies must come from an approved constrained source, and automation must not bypass certificate validation, silently install or update modules, or persistently weaken configuration.

**Expected evidence:** Distribution, child-module and runtime versions, approved source, certificate result, configuration scope, and dependency change record.

### VIRT-VSPH-PCLI-008

**Requirement:** PowerCLI state changes must honor wrapper-level `ShouldProcess`, bound asynchronous tasks and retries, preserve task IDs, distinguish unknown outcomes, and verify actual state.

**Expected evidence:** Preview tests, deadlines, per-object task outcomes, retry decisions, and post-state verification.

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
