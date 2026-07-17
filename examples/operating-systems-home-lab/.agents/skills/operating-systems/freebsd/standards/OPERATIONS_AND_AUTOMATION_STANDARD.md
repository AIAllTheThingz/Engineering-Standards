---
id: OS-FREEBSD-OPS-001
title: FreeBSD Operations and Automation Standard
version: 0.1.0
status: baseline
---

# FreeBSD Operations and Automation Standard

## Applicability

Applies to current supported FreeBSD RELEASE branches and explicitly approved supported Legacy Releases.

## Discovery and validation

Collect identity/authority, release/branch/patch/kernel/world/architecture/lifecycle, update method, package ABI/repos/locks/audit, Ports/Poudriere, boot/loader/boot environments, jails, services/rc configuration, identity/sudo/doas/SSH/certificates, PF/IPFW/IPFilter/audit, network/DNS/time/proxy, ZFS/UFS/GELI/capacity, backup, monitoring, vulnerabilities, workloads, owners and pending reboot.

Validate supported branch, update path, kernel/world and jail compatibility, package repository ABI/signatures and solver, base/package advisories, `/boot` and pool/filesystem capacity, configuration merge, firewall/access, boot environment and console, service/reboot impact, backup/restore or rebuild, canary and authorization.

## Planning, execution and verification

Plan exact hosts/jails, base and package phases, source/patch/artifacts, configuration merges, boot environments, services, reboots, batches, gates, recovery and evidence. Stage representative hardware, storage and jails.

Use supported methods, reconfirm branch/repo/ABI, preserve console/boot environment/backup, bound batches, stop on trust/merge/space/firewall/access/boot/jail/service/workload failure and record every phase/reboot.

Verify release/patch, running kernel and world, package ABI/repos/audit, restart/boot, configuration merges, jails, services, identity/access, firewall/audit, network/time/DNS, ZFS/UFS/encryption, backup, monitoring, vulnerabilities and workload acceptance.

## Upgrade and recovery

Follow the documented upgrade sequence; account for repeated install phases and reboots, `etcupdate` merges, bootloader needs, ZFS feature compatibility and jail upgrades. Prefer parallel replacement when source-built/custom state or rollback uncertainty is material.

Boot environments and ZFS snapshots are local rollback aids, not independent backups. Define loader/single-user/console access, prior boot environment, config/data restore, rebuild and manual handoff.

## Automation and testing

Use structured host/jail inventory, update/package dry-run where available, serialized package operations, validated rc/firewall/loader configuration, bounded jails/batches/reboots, redaction and per-scope results.

Test wrong branch/ABI, unsupported release, bad repository/signature, pkg lock/solver/audit, low boot/pool space, kernel/world mismatch, merge conflict, firewall access loss, boot failure, jail incompatibility, partial batch, boot-environment rollback and restore.

## Completion

`freebsd-update`, source build or `pkg` success is insufficient without actual base/kernel/world/jail/security/workload evidence.
