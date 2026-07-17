---
id: VIRT-MIGRATION-001
title: Virtualization Migration Decision Matrix
version: 0.1.0
status: baseline
---

# Virtualization Migration Decision Matrix

## Purpose

Guide review of same-platform and cross-platform VM migrations.

## Migration modes

| Mode | Typical use | Primary risk |
|---|---|---|
| Live migration | Host or storage maintenance within a compatible platform | Hidden compatibility, network, storage, or capacity dependency |
| Cold migration | Planned relocation or conversion with downtime | Extended outage and boot failure |
| Replication and failover | Site migration or disaster recovery | Data currency, split brain, failback, and orchestration |
| Export and import | Portable or offline transfer | Format, disk, firmware, metadata, and identity loss |
| Backup and restore | Recovery-led migration | Restore compatibility, application consistency, and elapsed time |
| Rebuild and data migration | Modernization or unsupported conversion | Configuration drift and application validation |
| Conversion tooling | Cross-hypervisor disk and metadata conversion | Driver, controller, boot, tools, licensing, and rollback failure |

## Decision questions

Before selecting a mode, determine:

- source and destination products, versions, editions, and support
- acceptable downtime and data loss
- synchronization requirement
- workload and dependency complexity
- application-consistency requirement
- disk size, change rate, transfer bandwidth, and cutover duration
- boot mode, partitioning, controllers, drivers, virtual hardware, and CPU compatibility
- network identity, MAC, IP, DNS, firewall, load balancer, and certificate effects
- passthrough, GPU, SR-IOV, TPM, Secure Boot, encryption, and nested virtualization
- backup and rollback capability
- licensing and activation
- validation and business acceptance
- source retention and decommission date

## Mandatory gates

Do not cut over until:

- destination capacity and compatibility are verified
- a restorable source recovery point exists
- conversion and boot were tested on a representative copy where feasible
- source and destination network identities cannot conflict
- guest tools and drivers are staged
- owners approve downtime and validation
- rollback or failback criteria are explicit
- backup, monitoring, and security controls exist at the destination
- source deletion is separated from migration acceptance

## Validation layers

1. Disk and conversion integrity
2. Firmware and boot
3. Guest OS and tools
4. Device, CPU, memory, and time
5. Network and name resolution
6. Storage and data integrity
7. Application and dependency health
8. Backup and restore
9. Monitoring and alerting
10. Performance and capacity
11. Security and access
12. Business-owner acceptance

## Decommission hold

After acceptance:

- retain the source in a safe powered-off or protected state for the approved hold period when feasible
- prevent duplicate network identity
- preserve rollback evidence
- confirm destination backup
- remove source only under separate authorization
- update inventory, licensing, monitoring, documentation, and ownership

## Evidence

Record source/destination IDs, conversion method, timestamps, data currency, validation, owner acceptance, rollback window, source disposition, and checks not run. Redact sensitive details.
