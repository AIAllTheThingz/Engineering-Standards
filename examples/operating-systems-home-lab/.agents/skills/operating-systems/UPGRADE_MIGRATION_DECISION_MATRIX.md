---
id: OS-UPGRADE-001
title: Operating-System Upgrade and Migration Decision Matrix
version: 0.1.0
status: baseline
---

# Operating-System Upgrade and Migration Decision Matrix

## Purpose

Guide selection and review of patching, in-place upgrades, replacement builds, reimaging, and cross-platform migrations.

## Change modes

| Mode | Typical use | Primary risk |
|---|---|---|
| Routine update | Security and defect remediation within a supported release | Restart, regression, dependency, and partial-fleet state |
| Minor or service-pack update | Supported release maintenance | Repository, kernel, driver, module, and application compatibility |
| In-place major upgrade | Preserve system identity and installed state | Accumulated drift, unsupported paths, extended outage, and failed boot |
| Parallel replacement | Build a clean target and migrate workload/data | Configuration parity, identity collision, cutover, and missed dependencies |
| Reimage | Return a managed endpoint or immutable node to baseline | Local data loss, key/identity loss, and incomplete re-enrollment |
| Restore or bare-metal recovery | Recover failed or corrupted systems | Backup currency, hardware compatibility, secrets, and recovery time |
| Cross-OS migration | Modernize or change vendor/family | Application, filesystem, identity, tooling, packaging, and operational differences |
| Retirement | Remove unsupported or unused systems | Data retention, credentials, DNS, licenses, backups, and asset-record gaps |

## Decision questions

Determine:

- source and destination OS, edition, release, architecture, hardware, and support
- vendor-supported upgrade path and required intermediate releases
- acceptable downtime, data loss, rollback time, and maintenance window
- installed roles, packages, repositories, modules, drivers, agents, extensions, and local changes
- application, identity, certificate, name, address, firewall, DNS, scheduler, and integration dependencies
- boot, encryption, key, storage, filesystem, ACL, extended-attribute, case-sensitivity, and data-format differences
- management, monitoring, backup, security, licensing, and support readiness at destination
- source retention, duplicate-identity prevention, acceptance, and decommission timing

## Prefer parallel replacement when

- the in-place path is unsupported or crosses too many intermediate releases
- current state is poorly understood or materially drifted
- immutable or image-based operation is intended
- rollback speed and source preservation matter
- architecture, boot, filesystem, encryption, or management model changes materially
- a clean security baseline is safer than carrying forward legacy state

## Mandatory gates

Do not cut over until:

- source and destination inventory and support are verified
- a restorable independent recovery point exists
- the intended path was tested on representative systems
- identity, DNS, IP, certificates, keys, and management enrollment cannot conflict
- required packages, drivers, agents, repositories, and security controls are available
- application owners approve downtime and acceptance tests
- rollback or failback criteria and time limits are explicit
- destination backup, monitoring, logging, access, and vulnerability management work
- source deletion or wipe is a separate authorized step after acceptance

## Validation layers

1. Hardware, firmware, boot, and architecture
2. Kernel, drivers, base system, and package integrity
3. Identity, privilege, certificates, and remote access
4. Network, DNS, time, proxy, and firewall
5. Storage, encryption, ACLs, data, and mounts
6. Services, schedules, roles, and applications
7. Endpoint controls, audit, vulnerability, and policy compliance
8. Backup, restore, rebuild, and recovery time
9. Monitoring, alerting, performance, and capacity
10. Management enrollment, inventory, licensing, and owner acceptance

## Decommission hold

Prevent duplicate identity, retain the source in a safe state for the approved hold period where feasible, confirm destination backup and acceptance, revoke obsolete credentials and certificates, remove from management and monitoring only at the authorized point, sanitize storage according to policy, and update asset, licensing, DNS, recovery, and ownership records.

## Evidence

Record source/destination identity, path, artifacts, timestamps, validation, reboots, data currency, owner acceptance, rollback window, source disposition, checks not run, and residual risk. Do not record secrets or recovery keys.
