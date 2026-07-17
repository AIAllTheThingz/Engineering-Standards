---
id: VIRT-AGENT-001
title: Virtualization Standards Agent Instructions
version: 0.1.0
status: baseline
---

# Virtualization Standards Agent Instructions

## Purpose

These instructions govern agents that create, modify, review, automate, migrate, or document hypervisor, virtualization-management, cluster, host, virtual-machine, virtual-network, and virtual-storage work under this directory.

Virtualization changes can stop many workloads at once, alter network identity, corrupt or strand storage, weaken isolation, invalidate backups, break licensing or support, and remove recovery paths. Treat every host, cluster, pool, manager, storage, and migration change as operationally consequential.

## Scope

These instructions apply to:

- hypervisor hosts and management planes
- clusters, pools, resource groups, availability, and scheduling
- virtual machines, templates, images, snapshots, checkpoints, and clones
- virtual networking, switching, segmentation, and administrative paths
- datastores, storage repositories, storage domains, volumes, and replication
- backup, restore, disaster recovery, export, import, and migration
- GPU, PCI, SR-IOV, nested virtualization, and other device assignment
- APIs, SDKs, CLIs, PowerShell, Ansible, Terraform, and orchestration code
- lifecycle, patching, upgrade, compatibility, licensing, and support boundaries

## Instruction precedence

1. Applicable governance, legal, contractual, safety, and security obligations
2. Explicit authorized user requirements
3. The nearest more-specific `AGENTS.md`
4. This collection `AGENTS.md`
5. The selected virtualization package `AGENTS.md`
6. Applicable platform, operating-system, networking, language, discipline, framework, and profile standards
7. Repository conventions
8. General agent preferences

More-specific instructions may strengthen or specialize requirements. They must not silently weaken authorization, target verification, backup, recovery, security, evidence, or production-readiness controls.

## Required reading

Before virtualization work, read:

- [README.md](README.md)
- [MANIFEST.md](MANIFEST.md)
- [VIRTUALIZATION_SELECTION_GUIDE.md](VIRTUALIZATION_SELECTION_GUIDE.md)
- [SHARED_RESPONSIBILITY_MODEL.md](SHARED_RESPONSIBILITY_MODEL.md)
- [VIRTUALIZATION_CHANGE_LIFECYCLE.md](VIRTUALIZATION_CHANGE_LIFECYCLE.md)
- [MIGRATION_DECISION_MATRIX.md](MIGRATION_DECISION_MATRIX.md)
- the selected package's `AGENTS.md`, README, manifest, standard, templates, and example

Read applicable governance plus architecture, application-security, testing, observability, SRE, CI/CD, supply-chain, documentation, and release-engineering standards.

## Non-negotiable behavior

- Identify the authoritative management endpoint, environment, site, cluster or pool, host, datastore, network, and acting identity before mutation.
- Confirm that the selected endpoint is not a similarly named lab, disaster-recovery, retired, or production environment.
- Discover current state and active tasks before creating, moving, deleting, reconfiguring, patching, evacuating, restarting, or placing a host into maintenance mode.
- Treat snapshots and checkpoints as short-lived operational mechanisms, not backups, unless the platform's documented backup architecture explicitly establishes otherwise.
- Verify restorable backup or export coverage before destructive, migration, upgrade, storage, or high-blast-radius work.
- Review compatibility across management plane, hypervisor, hardware, firmware, guest tools, virtual hardware, storage, networking, backup, and automation clients.
- Require explicit authorization for power operations, deletion, disk removal, snapshot consolidation, host maintenance, cluster membership, networking, storage, failover, migration, or security-boundary changes.
- Prefer supported APIs, SDKs, modules, and CLIs over screen scraping, database edits, undocumented endpoints, or direct modification of manager-owned files.
- Make automation idempotent, bounded, cancellable where practical, and safe to rerun after partial failure.
- Default custom automation to discovery, validation, plan or dry-run, report, and explicitly enabled execution phases.
- Preserve task, job, event, audit, and correlation identifiers as evidence.
- Verify actual state after changes; a successful command exit is not sufficient.
- Do not expose credentials, tokens, certificates, inventory details, VM console data, support bundles, or production identifiers.
- Do not claim zero downtime, recoverability, compatibility, or production readiness without direct evidence.

## Required working method

1. **Discover:** resolve target identity, topology, ownership, versions, health, active jobs, dependencies, and current state without mutation.
2. **Validate:** verify authorization, privileges, compatibility, capacity, backup, recovery, maintenance windows, and prerequisites.
3. **Plan:** render exact intended changes, selected objects, dependency order, stop conditions, rollback, and evidence.
4. **Review:** identify power, deletion, storage, network, privilege, availability, licensing, and support effects.
5. **Authorize:** obtain accountable approval for the exact target and planned change.
6. **Execute:** use the narrowest supported interface with bounded concurrency and observable progress.
7. **Verify:** query actual host, cluster, VM, network, storage, backup, and monitoring state.
8. **Observe:** monitor health, performance, events, alerts, replication, backup, and workload behavior.
9. **Close:** preserve evidence, document deviations, assign follow-up, and disclose residual risk.

## Automation quality

Virtualization automation must:

- use explicit object identity rather than display-name-only matching when stable IDs exist
- reject ambiguous, missing, disconnected, unhealthy, or multiply matched targets
- separate read-only discovery from state-changing functions
- support preview semantics such as `-WhatIf`, dry-run, plan, or equivalent when the interface permits
- make confirmation and execution opt-in for destructive or availability-affecting actions
- use structured input and output
- use timeouts, cancellation, retry classification, and bounded polling
- distinguish transient, partial, terminal, and operator-intervention states
- avoid unbounded parallel operations against managers, clusters, hosts, or datastores
- record before and after state
- redact sensitive values
- test denied, missing, stale, partial-failure, and recovery paths
- document supported product, module, API, and guest compatibility

## Decision gates

Stop when:

- the target or acting identity is ambiguous
- required privileges or authorization are absent
- the management plane is unhealthy or has unresolved critical alarms
- another conflicting job is active
- backup or recovery evidence is missing
- capacity or compatibility is unverified
- a host cannot be evacuated safely
- storage or network reachability is uncertain
- a migration lacks rollback or a tested cutover plan
- the platform is unsupported and no approved containment or migration path exists
- actual state cannot be verified after the change

## Validation

Run from the repository root:

```bash
python tools/validate-standards/validate_repository.py
python tools/check-links/check_links.py
python tools/validate-skills/validate_skills.py
```

Also review terminology, versions, support lifecycle, destructive-action boundaries, rollback, source currency, and fictitious example data manually.

## Completion gate

Work under `virtualization/` is incomplete until:

- the correct package and target boundary are recorded
- source, desired, and actual state are distinguished
- compatibility and support lifecycle are verified
- required authorization and review are recorded
- backup, recovery, rollback, or migration limits are explicit
- exact validation and actual-state verification are recorded
- monitoring and operational ownership are assigned
- checks not run and residual risk are disclosed
- package manifests, links, IDs, examples, and templates remain synchronized
