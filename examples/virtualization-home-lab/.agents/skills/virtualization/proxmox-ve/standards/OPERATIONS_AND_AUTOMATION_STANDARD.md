---
id: VIRT-PVE-OPS-001
title: Proxmox VE Operations and Automation Standard
version: 0.1.0
status: baseline
---

# Proxmox VE Operations and Automation Standard

## Purpose

Define the detailed operating and automation contract for Proxmox VE work.

## Applicability

This standard applies to PVE nodes and clusters, Corosync quorum, QEMU VMs, LXC containers, storage, Ceph, bridges, bonds, VLANs, firewall, HA, backup, replication, API tasks, and package repositories.

## Authority and identity

- Connect only to Proxmox VE cluster API and node membership, or the exact standalone PVE node.
- Record endpoint class, environment, stable object IDs, and acting identity.
- Verify certificate and endpoint identity before credential use.
- Use least privilege and separate read-only discovery from state-changing execution.
- Do not let automation approve its own consequential action.
- Reject ambiguous selection.

## Discovery

Collect:

- product, edition, version, build, hardware, firmware, drivers, guest tools, API, SDK, module, and lifecycle
- management, cluster or pool, host, VM, network, and storage topology
- health, alarms, events, active tasks, maintenance state, backup, replication, and monitoring
- owners, dependencies, maintenance windows, recovery objectives, and acceptance tests
- CPU, memory, storage, network, admission-control, and temporary migration capacity
- security, licensing, entitlement, and support constraints

Discovery must not change state.

## Validation

Validate:

- target and identity
- permissions
- manager and cluster health
- compatibility and support
- capacity and evacuation
- network and storage paths
- independent backup and recovery
- active conflicting tasks
- workload-owner authorization
- monitoring and escalation
- rollback, restore, failback, or rebuild

Stop on an unmet prerequisite.

## Plan and dry-run

The plan must show:

- exact stable object identifiers
- intended before-to-after transitions
- ordered actions
- power and availability impact
- network and storage impact
- destructive or irreversible steps
- concurrency and timeouts
- stop conditions
- expected task identifiers and completion states
- recovery and validation
- evidence captured

## Execution

- Require explicit enablement.
- Use supported interfaces only.
- Bound concurrent operations.
- Apply timeouts and cancellable polling where practical.
- Preserve task, job, and event identifiers.
- Stop on defined terminal failures.
- Do not silently continue past partial failure.
- Avoid unrelated cleanup.
- Preserve recovery options until verification and acceptance.
- Record manual intervention.

## Verification

Verify:

- manager and inventory state
- cluster or pool and host health
- VM configuration and power state
- guest OS, tools, devices, time, and application health
- required and denied network paths
- storage accessibility, capacity, performance, and integrity
- HA, replication, backup, and restore coverage
- monitoring, alerts, events, and audit
- absence of unexpected snapshots, orphaned disks, duplicate identities, or stale state

## Product-specific rules

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

## Product-specific cautions

- Do not change cluster membership, Corosync, or quorum-sensitive state without a tested recovery path.
- Do not edit pmxcfs-managed cluster configuration as ordinary local files.
- Do not combine Ceph, network, cluster, and hypervisor upgrades into an unbounded single change.

## Automation implementation

Automation must:

- use structured configuration and input validation
- separate discovery, validation, plan, report, execute, and verify code paths
- provide preview semantics when supported
- confirm target identity again immediately before mutation
- use stable IDs and expected parent scope
- redact sensitive values
- use structured logs and reports
- preserve correlation with manager tasks
- handle stale inventory and disappearing objects
- classify retryable, terminal, and operator-required failures
- use bounded exponential polling rather than unbounded loops
- provide safe rerun or recovery behavior
- avoid self-modifying or dynamically downloaded unverified code
- pin or constrain dependencies where practical
- document supported versions
- include unit tests and mocked interface tests
- include negative and partial-failure tests

## Testing

Test:

- successful read-only discovery
- missing and duplicate targets
- wrong parent scope
- access denied
- disconnected or unhealthy manager/host
- compatibility failure
- capacity failure
- active conflicting task
- dry-run with no mutation
- confirmation refusal
- asynchronous task success and failure
- timeout and cancellation
- partial batch failure
- log redaction
- actual-state mismatch
- rollback or manual handoff
- idempotent rerun

Do not use production as the first test environment.

## Observability

Capture:

- start/end timestamps
- tool and dependency versions
- endpoint and object scope in redacted form
- acting identity class
- change or approval reference
- manager task/job/event identifiers
- per-object outcomes
- retries, timeouts, cancellations, and interventions
- before and after state
- validation and workload health
- recovery status
- residual risk

## Recovery

Recovery must be independent from the path being changed where practical. Define what happens if the manager, host, network, storage, VM, guest, automation runner, or backup system fails mid-change.

Do not remove the source, disk, snapshot, checkpoint, or recovery copy until the authorized acceptance and retention boundary is satisfied.

## Completion

Completion requires exact evidence, owner acceptance where applicable, operational observation, explicit checks not run, and disclosed residual risk. Tool success alone is insufficient.

## Current source boundary

Verify PVE release and repository support, Debian base compatibility, Corosync, Ceph, QEMU, LXC, kernel, firmware, guest support, backup compatibility, subscription repository, and upgrade path.

Verify current behavior with [Proxmox VE administration documentation](https://pve.proxmox.com/pve-docs/pve-admin-guide.html) and other official compatibility, security, lifecycle, and release documentation before execution.
