---
id: OS-DEBIAN-OPS-001
title: Debian Operations and Automation Standard
version: 0.1.0
status: baseline
---

# Debian Operations and Automation Standard

## Applicability

Applies to Debian stable and explicitly approved supported oldstable, LTS or ELTS systems.

## Discovery and validation

Collect identity/authority, release/codename/suite/kernel/architecture/lifecycle, APT sources/keys/preferences/holds/locks, packages/firmware, boot, services/timers, identity/sudo/SSH/certificates, AppArmor/firewall/audit, network/DNS/time/proxy, filesystems/LVM/ZFS/encryption/capacity, backup, monitoring, vulnerabilities, workloads, owners and pending restart.

Validate suite and security coverage, repository/signature trust, transaction simulation, essential packages, conffile behavior, free space, kernel/firmware/agent/application compatibility, security controls, alternate access, service/reboot impact, backup/restore or rebuild, canary and authorization.

## Planning, execution and verification

Plan exact systems, sources/packages/configuration, ordered transaction, service restarts, kernels, reboots, batches, gates, rollback/recovery and evidence. Stage representative roles and hardware.

Use supported tools, reconfirm sources/suite, serialize dpkg, preserve access, handle prompts explicitly, stop on trust/dependency/space/security/access/boot/service/workload failure and record per-host state.

Verify release/suite/sources, package integrity, running/default kernel, restart, boot, services/timers, identity/access, security, network/time/DNS, storage/encryption, backup, monitoring, vulnerabilities and workload acceptance.

## Upgrade and recovery

Read both releases' notes. Follow supported sequential upgrades; update package state before changing sources; review third-party repositories, firmware, obsolete packages, merged-/usr or other transition requirements, service downtime and config prompts. Prefer parallel replacement when drift or rollback is uncertain.

Do not treat APT history, filesystem snapshots or ZFS boot environments as independent backup by default. Define boot fallback, config/data restore, rebuild and manual handoff.

## Automation and testing

Use codenames for pinned production boundaries, structured inventory, simulated transactions, serialized package management, explicit `DEBIAN_FRONTEND`/conffile behavior, bounded locks/retries/reboots, redaction and per-host results.

Test wrong suite, mixed sources, bad signature, unavailable mirror, dpkg lock/interruption, held/essential package, low space, conffile conflict, AppArmor/firewall/access loss, failed boot, partial batch, upgrade inhibitor, rollback and safe rerun.

## Completion

APT or configuration-management success is insufficient without actual-state, security, access, workload, backup and monitoring evidence.
