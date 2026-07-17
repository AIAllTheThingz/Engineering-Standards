---
id: VIRT-KVM-OPS-001
title: KVM and libvirt Operations and Automation Standard
version: 0.1.0
status: baseline
---

# KVM and libvirt Operations and Automation Standard

## Purpose

Define the detailed operating and automation contract for KVM and libvirt work.

## Applicability

This standard applies to Linux KVM, QEMU, libvirt daemons and connections, domains, XML, storage pools and volumes, virtual networks, bridges, migration, cgroups, sVirt/SELinux, VFIO, device assignment, and guest agents.

## Authority and identity

- Connect only to the exact libvirt connection URI and host or manager that owns the target domains, networks, and storage pools.
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

### VIRT-KVM-URI-001

**Requirement:** Record and validate the exact libvirt URI, transport, identity, host, and domain UUID before mutation.

**Expected evidence:** URI, host identity, domain UUID, and privilege evidence.

### VIRT-KVM-XML-002

**Requirement:** Review persistent and live configuration separately and use supported libvirt operations.

**Expected evidence:** Before/after persistent and live XML plus reconciliation evidence.

### VIRT-KVM-SEC-003

**Requirement:** Preserve SELinux/sVirt, DAC, cgroup, namespace, and device isolation; do not disable controls to make a VM start.

**Expected evidence:** Policy state, labels, denials, and least-privilege evidence.

### VIRT-KVM-MIG-004

**Requirement:** Validate CPU, machine type, QEMU/libvirt, storage, network, firmware, and device compatibility before migration.

**Expected evidence:** Migration compatibility and rollback plan.

### VIRT-KVM-VOL-005

**Requirement:** Prove storage-volume ownership and independent backup before delete, resize, convert, or rebase operations.

**Expected evidence:** Volume mapping, chain, backup, and integrity evidence.

## Product-specific cautions

- Do not assume qemu:///system and qemu:///session have the same inventory or privilege boundary.
- Do not edit manager-owned domain XML or runtime QEMU commands outside supported libvirt interfaces.
- Treat VFIO and device assignment as host security, isolation, recovery, and migration constraints.

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

Verify distribution, kernel, QEMU, libvirt, machine type, firmware, CPU model, guest support, storage, networking, security policy, migration compatibility, and management-tool support.

Verify current behavior with [Linux kernel KVM documentation](https://docs.kernel.org/virt/kvm/index.html) and other official compatibility, security, lifecycle, and release documentation before execution.
