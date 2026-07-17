---
id: VIRT-SHARED-001
title: Virtualization Shared Responsibility Model
version: 0.1.0
status: baseline
---

# Virtualization Shared Responsibility Model

## Purpose

Assign ownership across the virtualization stack before work begins.

## Responsibility boundaries

| Boundary | Required owner and evidence |
|---|---|
| Management plane | Owner for availability, backup, certificates, identity, RBAC, database, API, upgrades, and recovery |
| Hypervisor hosts | Owner for hardware, firmware, BIOS, drivers, hypervisor, patching, secure boot, time, and maintenance |
| Cluster or pool | Owner for membership, quorum, scheduling, HA, capacity, failure domains, and evacuation |
| Guest OS | Owner for OS lifecycle, tools/drivers, identity, patching, security, backup agents, and application dependencies |
| Virtual networking | Owner for switches, bridges, VLANs, overlays, routing, firewalling, load balancing, DNS, and administrative access |
| Virtual storage | Owner for datastores, repositories, domains, pools, multipathing, capacity, performance, replication, and data protection |
| Backup and recovery | Owner for policy, immutable copies, retention, restore testing, application consistency, and disaster recovery |
| Automation | Owner for source, credentials, dependencies, target selection, approvals, execution, logs, rollback, and evidence |
| Licensing and support | Owner for entitlement, edition, feature rights, support lifecycle, compatibility, and escalation |
| Monitoring and operations | Owner for health, events, capacity, alerts, runbooks, incident response, and after-hours escalation |

## Management plane

Define:

- authoritative endpoint and inventory
- redundancy and recovery
- certificate and identity lifecycle
- privileged and emergency access
- RBAC and access review
- API, SDK, and module compatibility
- database and configuration backup
- audit and task retention
- monitoring and escalation

A management plane that manages itself requires an explicit recovery design.

## Hosts and clusters

Define:

- supported hardware, firmware, drivers, and hypervisor versions
- cluster or pool compatibility
- capacity and admission control
- maintenance and evacuation behavior
- quorum or master dependencies
- time synchronization
- failure domains
- secure configuration and drift control
- rollback or reinstall path

## Guests

Define:

- application and business owner
- OS and guest-tools support
- virtual hardware and boot mode
- CPU, memory, NUMA, storage, network, and device requirements
- application-consistent backup
- shutdown and startup ordering
- health validation
- maintenance windows
- decommission authority

The virtualization team does not automatically own application correctness.

## Networking and storage

Identify both virtualization and underlying infrastructure owners. Validate the full path from guest through virtual and physical layers.

Do not change:

- VLANs, bridges, distributed switches, uplinks, bonds, or overlays without network ownership
- datastores, multipathing, storage mappings, replication, or disk presentation without storage ownership

## Backup, snapshot, and recovery

Assign separate responsibility for:

- short-lived snapshots or checkpoints
- backup copies
- immutable or isolated recovery copies
- replication
- restore
- disaster recovery orchestration
- application validation
- retention and deletion

A snapshot retained on the same failure domain is not an independent recovery copy.

## Automation

The automation owner must document:

- supported platforms and versions
- identity source and least privilege
- configuration source
- target selection
- discovery and preview modes
- approval boundary
- idempotency and partial failure
- timeouts, retries, and concurrency
- structured logs and reports
- recovery and manual handoff
- code signing or artifact integrity where applicable

## Completion evidence

Record every named owner, unresolved gap, escalation path, and acceptance authority. Work is not production-ready merely because all technical tasks completed.
