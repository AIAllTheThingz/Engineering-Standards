---
id: VIRT-XCP-AGENT-001
title: XCP-ng Agent Standard
version: 0.1.0
status: baseline
applies_to:
  - xcp-ng
depends_on:
  - VIRT-AGENT-001
  - GOV-RISK
  - GOV-SECDEV
---

# XCP-ng Agent Standard

## Purpose

Define mandatory behavior for agents designing, scripting, administering, reviewing, troubleshooting, recovering, or migrating XCP-ng environments.

This package supplements root governance, the virtualization collection, language packages, engineering disciplines, project profiles, and adopting-project instructions.

## Authoritative boundary

The management authority is XCP-ng pool through XAPI, normally managed through the designated Xen Orchestra instance.

Do not mutate objects until that authority, environment, stable object scope, and acting identity are verified.

## Scope

- XCP-ng hosts and pools
- pool master
- XAPI
- Xen Orchestra
- VMs
- templates
- networks
- storage repositories
- XOSTOR where used
- backup
- replication
- updates
- migrations

## Required reading

- [Package README](README.md)
- [Package manifest](MANIFEST.md)
- [Operations and automation standard](standards/OPERATIONS_AND_AUTOMATION_STANDARD.md)
- [Collection selection guide](../VIRTUALIZATION_SELECTION_GUIDE.md)
- [Collection change lifecycle](../VIRTUALIZATION_CHANGE_LIFECYCLE.md)
- [Collection migration matrix](../MIGRATION_DECISION_MATRIX.md)
- applicable governance, language, discipline, platform, virtualization, operating-system, networking, framework, and profile packages

## Supported interfaces

Prefer Xen Orchestra, Xen Orchestra API/CLI, XAPI, xe, and supported infrastructure providers.

Pin or constrain automation dependencies when practical. Verify interface, server, and API compatibility against current official documentation. Do not use screen scraping, direct manager-database edits, undocumented endpoints, or manual edits to manager-owned state.

## Lifecycle and compatibility

Verify XCP-ng release support, pool version compatibility, hardware support, guest tools, Xen Orchestra compatibility, backup behavior, XOSTOR requirements, and supported update path.

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

- Treat XCP-ng hosts as appliances and avoid unsupported control-domain package changes.
- Do not assume XenServer and XCP-ng operational procedures are interchangeable.
- Do not bypass Xen Orchestra backup job evidence with snapshot-only claims.

## Product rules

### VIRT-XCP-POOL-001

**Requirement:** Resolve pool UUID, master, host versions, health, and active XAPI tasks before mutation.

**Expected evidence:** Pool and master inventory with health evidence.

### VIRT-XCP-XO-002

**Requirement:** Identify the authoritative Xen Orchestra instance and preserve job, task, and backup records.

**Expected evidence:** XO endpoint class, job IDs, task status, and audit evidence.

### VIRT-XCP-SR-003

**Requirement:** Validate storage repository, PBD/VDI ownership, shared accessibility, capacity, and recovery before storage work.

**Expected evidence:** SR path, attachment, capacity, and recovery evidence.

### VIRT-XCP-UPDATE-004

**Requirement:** Use supported rolling update order and confirm pool/master behavior and evacuation capacity.

**Expected evidence:** Update plan, compatibility source, and rollback limitations.

### VIRT-XCP-BACKUP-005

**Requirement:** Validate backup job scope, retention, repository health, and a representative restore.

**Expected evidence:** XO backup and restore-test evidence.

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
