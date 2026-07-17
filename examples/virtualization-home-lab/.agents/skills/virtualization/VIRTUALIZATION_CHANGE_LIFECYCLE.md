---
id: VIRT-LIFECYCLE-001
title: Virtualization Change Lifecycle
version: 0.1.0
status: baseline
---

# Virtualization Change Lifecycle

## Purpose

Provide a common safe sequence for virtualization changes and automation.

## 1. Discover

Gather without mutation:

- management endpoint, environment, site, cluster or pool, host, VM, network, and storage identity
- product, edition, build, firmware, driver, guest-tool, API, SDK, and module versions
- health, alarms, events, active jobs, maintenance state, and replication
- workload dependencies, owners, SLAs, recovery objectives, and maintenance windows
- resource allocation, reservations, limits, overcommit, admission control, and capacity
- backup policy, last successful backup, recovery copy location, and restore-test evidence
- licensing, support, lifecycle, and hardware compatibility

Use stable object IDs where available.

## 2. Validate

Verify:

- target and acting identity
- least required privilege
- product and mixed-version compatibility
- manager, host, cluster, network, storage, backup, and monitoring health
- capacity for evacuation, migration, failover, snapshots, and temporary duplicate workloads
- change-window and owner approval
- recovery and stop conditions
- absence of conflicting operations

Stop on ambiguity or unmet prerequisites.

## 3. Plan or dry-run

Produce a reviewable record of:

- exact selected objects
- ordered actions
- expected tasks and state transitions
- power and availability effects
- storage and network effects
- temporary capacity
- destructive or irreversible steps
- concurrency and timing
- stop conditions
- rollback, restore, failback, or rebuild
- validation and evidence collection

## 4. Assess and authorize

Classify:

- blast radius
- privilege
- public or administrative exposure
- data movement or deletion
- downtime and workload risk
- recovery confidence
- compatibility and support
- licensing impact
- security impact

Obtain accountable authorization for the exact reviewed target and scope.

## 5. Execute

- use supported interfaces
- preserve task and correlation IDs
- bound concurrency
- enforce timeouts
- poll with backoff and cancellation
- stop on defined failure conditions
- do not silently skip failed objects
- avoid mixing unrelated changes
- preserve before-state evidence
- record operator interventions

## 6. Verify actual state

Verify:

- intended manager, host, cluster, VM, network, and storage state
- workload boot and application health
- allowed and denied network paths
- storage availability and data integrity
- guest tools and device health
- HA, replication, backup, and monitoring
- absence of unexpected snapshots, checkpoints, orphaned disks, duplicate identities, or stale inventory
- task completion and alarms

## 7. Observe

Monitor for an interval proportionate to risk:

- workload availability
- host and cluster health
- resource pressure
- storage latency and errors
- network drops and reachability
- backup and replication
- alerts and events
- business-service health

## 8. Close

Record:

- planned versus actual change
- task and job results
- validation
- deviations
- rollback or recovery readiness
- checks not run
- residual risks
- owner acceptance
- follow-up and decommission holds

## Emergency handling

Emergency access does not remove the need to identify target, minimize scope, preserve evidence, validate actual state, and perform retrospective review. Follow repository governance.
