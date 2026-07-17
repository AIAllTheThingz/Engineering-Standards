---
id: VIRT-AHV-AGENT-001
title: Nutanix AHV Agent Standard
version: 0.1.0
status: baseline
applies_to:
  - nutanix-ahv
depends_on:
  - VIRT-AGENT-001
  - GOV-RISK
  - GOV-SECDEV
---

# Nutanix AHV Agent Standard

## Purpose

Define mandatory behavior for agents designing, scripting, administering, reviewing, troubleshooting, recovering, or migrating Nutanix AHV environments.

This package supplements root governance, the virtualization collection, language packages, engineering disciplines, project profiles, and adopting-project instructions.

## Authoritative boundary

The management authority is Prism Central or Prism Element scope that owns the AHV cluster and objects.

Do not mutate objects until that authority, environment, stable object scope, and acting identity are verified.

## Scope

- AHV and AOS clusters
- Prism Central
- Prism Element
- hosts
- CVMs
- VMs
- images
- storage containers
- networks and subnets
- categories
- policies
- protection domains
- recovery
- lifecycle
- NCC
- APIs

## Required reading

- [Package README](README.md)
- [Package manifest](MANIFEST.md)
- [Operations and automation standard](standards/OPERATIONS_AND_AUTOMATION_STANDARD.md)
- [Collection selection guide](../VIRTUALIZATION_SELECTION_GUIDE.md)
- [Collection change lifecycle](../VIRTUALIZATION_CHANGE_LIFECYCLE.md)
- [Collection migration matrix](../MIGRATION_DECISION_MATRIX.md)
- applicable governance, language, discipline, platform, virtualization, operating-system, networking, framework, and profile packages

## Supported interfaces

Prefer Prism Central and Element APIs, supported Nutanix SDKs, aCLI, nCLI, lifecycle tooling, and supported automation providers.

Pin or constrain automation dependencies when practical. Verify interface, server, and API compatibility against current official documentation. Do not use screen scraping, direct manager-database edits, undocumented endpoints, or manual edits to manager-owned state.

## Lifecycle and compatibility

Verify AOS, AHV, Prism Central, firmware, Foundation, LCM, hardware model, guest tools, backup, replication, API, licensing, and Nutanix interoperability before relying on a feature.

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

- Do not treat CVMs as ordinary guest VMs or alter them outside supported Nutanix procedures.
- Do not run broad aCLI or nCLI mutations without cluster and Prism scope verification.
- Do not claim protection-domain or snapshot configuration proves recoverability without restore or failover evidence.

## Product rules

### VIRT-AHV-PRISM-001

**Requirement:** Resolve Prism Central versus Element authority, cluster UUID, object UUIDs, and acting identity before mutation.

**Expected evidence:** Prism scope, cluster/object UUIDs, and identity evidence.

### VIRT-AHV-HEALTH-002

**Requirement:** Review NCC, cluster services, CVM health, resilience, capacity, and active tasks before lifecycle or host work.

**Expected evidence:** NCC/health results and stop conditions.

### VIRT-AHV-LCM-003

**Requirement:** Use supported LCM sequencing and verify compatibility, prechecks, capacity, and recovery.

**Expected evidence:** LCM inventory, precheck, plan, and post-check evidence.

### VIRT-AHV-STOR-004

**Requirement:** Validate storage-container, replication, capacity, data-resiliency, and workload ownership before storage changes.

**Expected evidence:** Container and resiliency evidence plus backup status.

### VIRT-AHV-TASK-005

**Requirement:** Preserve Prism task UUIDs and verify actual cluster and workload state after completion.

**Expected evidence:** Task records and post-change verification.

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
