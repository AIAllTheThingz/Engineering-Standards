---
id: VIRT-KVM-AGENT-001
title: KVM and libvirt Agent Standard
version: 0.1.0
status: baseline
applies_to:
  - kvm-libvirt
depends_on:
  - VIRT-AGENT-001
  - GOV-RISK
  - GOV-SECDEV
---

# KVM and libvirt Agent Standard

## Purpose

Define mandatory behavior for agents designing, scripting, administering, reviewing, troubleshooting, recovering, or migrating KVM and libvirt environments.

This package supplements root governance, the virtualization collection, language packages, engineering disciplines, project profiles, and adopting-project instructions.

## Authoritative boundary

The management authority is the exact libvirt connection URI and host or manager that owns the target domains, networks, and storage pools.

Do not mutate objects until that authority, environment, stable object scope, and acting identity are verified.

## Scope

- Linux KVM
- QEMU
- libvirt daemons and connections
- domains
- XML
- storage pools and volumes
- virtual networks
- bridges
- migration
- cgroups
- sVirt/SELinux
- VFIO
- device assignment
- guest agents

## Required reading

- [Package README](README.md)
- [Package manifest](MANIFEST.md)
- [Operations and automation standard](standards/OPERATIONS_AND_AUTOMATION_STANDARD.md)
- [Collection selection guide](../VIRTUALIZATION_SELECTION_GUIDE.md)
- [Collection change lifecycle](../VIRTUALIZATION_CHANGE_LIFECYCLE.md)
- [Collection migration matrix](../MIGRATION_DECISION_MATRIX.md)
- applicable governance, language, discipline, platform, virtualization, operating-system, networking, framework, and profile packages

## Supported interfaces

Prefer libvirt APIs, virsh, virt-install, virt-admin, QEMU tooling, supported language bindings, Ansible, and distribution-supported management.

Pin or constrain automation dependencies when practical. Verify interface, server, and API compatibility against current official documentation. Do not use screen scraping, direct manager-database edits, undocumented endpoints, or manual edits to manager-owned state.

## Lifecycle and compatibility

Verify distribution, kernel, QEMU, libvirt, machine type, firmware, CPU model, guest support, storage, networking, security policy, migration compatibility, and management-tool support.

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

- Do not assume qemu:///system and qemu:///session have the same inventory or privilege boundary.
- Do not edit manager-owned domain XML or runtime QEMU commands outside supported libvirt interfaces.
- Treat VFIO and device assignment as host security, isolation, recovery, and migration constraints.

## Product rules

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
