---
id: VIRT-AHV-OPS-001
title: Nutanix AHV Operations and Automation Standard
version: 0.1.0
status: baseline
---

# Nutanix AHV Operations and Automation Standard

## Purpose

Define the detailed operating and automation contract for Nutanix AHV work.

## Applicability

This standard applies to AHV and AOS clusters, Prism Central, Prism Element, hosts, CVMs, VMs, images, storage containers, networks and subnets, categories, policies, protection domains, recovery, lifecycle, NCC, and APIs.

## Authority and identity

- Connect only to Prism Central or Prism Element scope that owns the AHV cluster and objects.
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

## Product-specific cautions

- Do not treat CVMs as ordinary guest VMs or alter them outside supported Nutanix procedures.
- Do not run broad aCLI or nCLI mutations without cluster and Prism scope verification.
- Do not claim protection-domain or snapshot configuration proves recoverability without restore or failover evidence.

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

Verify AOS, AHV, Prism Central, firmware, Foundation, LCM, hardware model, guest tools, backup, replication, API, licensing, and Nutanix interoperability before relying on a feature.

Verify current behavior with [Nutanix product documentation portal](https://portal.nutanix.com/page/documents/list?type=software) and other official compatibility, security, lifecycle, and release documentation before execution.
