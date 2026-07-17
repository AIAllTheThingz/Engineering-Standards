---
id: VIRT-PVE-AGENT-001
title: Proxmox VE Agent Standard
version: 0.1.0
status: baseline
applies_to:
  - proxmox-ve
depends_on:
  - VIRT-AGENT-001
  - GOV-RISK
  - GOV-SECDEV
---

# Proxmox VE Agent Standard

## Purpose

Define mandatory behavior for agents designing, scripting, administering, reviewing, troubleshooting, recovering, or migrating Proxmox VE environments.

This package supplements root governance, the virtualization collection, language packages, engineering disciplines, project profiles, and adopting-project instructions.

## Authoritative boundary

The management authority is Proxmox VE cluster API and node membership, or the exact standalone PVE node.

Do not mutate objects until that authority, environment, stable object scope, and acting identity are verified.

## Scope

- PVE nodes and clusters
- Corosync quorum
- QEMU VMs
- LXC containers
- storage
- Ceph
- bridges
- bonds
- VLANs
- firewall
- HA
- backup
- replication
- API tasks
- package repositories

## Required reading

- [Package README](README.md)
- [Package manifest](MANIFEST.md)
- [Operations and automation standard](standards/OPERATIONS_AND_AUTOMATION_STANDARD.md)
- [Collection selection guide](../VIRTUALIZATION_SELECTION_GUIDE.md)
- [Collection change lifecycle](../VIRTUALIZATION_CHANGE_LIFECYCLE.md)
- [Collection migration matrix](../MIGRATION_DECISION_MATRIX.md)
- applicable governance, language, discipline, platform, virtualization, operating-system, networking, framework, and profile packages

## Supported interfaces

Prefer Proxmox VE API, pvesh, supported CLI utilities, Ansible, Terraform providers, and Proxmox Backup Server interfaces.

Pin or constrain automation dependencies when practical. Verify interface, server, and API compatibility against current official documentation. Do not use screen scraping, direct manager-database edits, undocumented endpoints, or manual edits to manager-owned state.

## Lifecycle and compatibility

Verify PVE release and repository support, Debian base compatibility, Corosync, Ceph, QEMU, LXC, kernel, firmware, guest support, backup compatibility, subscription repository, and upgrade path.

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

- Do not change cluster membership, Corosync, or quorum-sensitive state without a tested recovery path.
- Do not edit pmxcfs-managed cluster configuration as ordinary local files.
- Do not combine Ceph, network, cluster, and hypervisor upgrades into an unbounded single change.

## Product rules

### VIRT-PVE-QUORUM-001

**Requirement:** Verify cluster membership, votes, quorum, communication health, and expected node state before cluster mutation.

**Expected evidence:** pvecm/corosync health and recovery plan.

### VIRT-PVE-TASK-002

**Requirement:** Capture Proxmox task UPIDs and poll bounded task status rather than assuming submission equals completion.

**Expected evidence:** UPID, terminal status, logs, and post-state evidence.

### VIRT-PVE-STOR-003

**Requirement:** Validate storage definition, scope, content types, availability, capacity, replication, and ownership before mutation.

**Expected evidence:** Storage configuration, health, capacity, and backup evidence.

### VIRT-PVE-CEPH-004

**Requirement:** Separate Ceph health, capacity, recovery, and failure-domain review from ordinary VM operations.

**Expected evidence:** Ceph health and recovery status with stop conditions.

### VIRT-PVE-BACKUP-005

**Requirement:** Verify independent backup policy and restore evidence; do not treat snapshots or replication as sufficient backup.

**Expected evidence:** PBS/vzdump policy and representative restore evidence.

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
