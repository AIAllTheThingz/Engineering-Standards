---
id: OS-OL-OPS-001
title: Oracle Linux Operations and Automation Standard
version: 0.1.0
status: baseline
---

# Oracle Linux Operations and Automation Standard

## Applicability

Applies to current Oracle Linux releases under verified security/support coverage, with UEK or RHCK and optional Ksplice.

## Discovery and validation

Collect identity/authority, release/update/kernel-family/version/architecture/lifecycle/support, ULN/yum channels/repos/keys/modules/packages/locks, Ksplice/effective kernel, boot/Secure Boot, services, identity/sudo/SSH/certificates, SELinux/firewall/audit, network/DNS/time/proxy, filesystems/LVM/encryption/capacity, backup, monitoring, vulnerabilities, Oracle and other workloads, owners and pending restart.

Validate support/security phase, repository trust, DNF preview, UEK/RHCK and Ksplice eligibility, driver/agent/application/Oracle certification, free space, boot, security and alternate access, service/reboot impact, backup/restore or rebuild, canary, management-agent compatibility and authorization.

## Planning, execution and verification

Plan exact systems, channels/repos, packages/modules/configuration, kernel family and default, Ksplice versus reboot, services, batches, gates, recovery and evidence. Stage representative hardware, Oracle workloads and kernel families.

Use supported tools, reconfirm release/kernel/repos/support, bound batches, preserve access/recovery, stop on trust/dependency/space/Ksplice/security/access/boot/service/workload failure and record per-host results.

Verify release/channels/packages, installed/running/default/effective kernel, Ksplice, restart/boot, services, identity/access, SELinux/firewall/audit, network/time/DNS, storage/encryption, backup, monitoring, vulnerabilities and workload acceptance.

## Kernel and live patching

Do not switch UEK/RHCK without certification. Ksplice may reduce immediate reboot requirements but does not replace validation of user-space packages, services, firmware, agents, bootability or eventual lifecycle. Record the effective kernel and remaining restart debt.

## Upgrade and recovery

Use Oracle-supported tooling and paths. Validate Oracle application/database certification separately. Prefer parallel replacement when drift, kernel-family change or rollback risk is material.

Snapshots are not independent backups by default. Define prior kernel boot, package/config rollback limits, restore/rebuild, database/application recovery and manual handoff.

## Automation and testing

Use structured inventory, DNF preview, serialized package management, explicit kernel-family logic, bounded locks/retries/reboots, redaction and per-host results.

Test wrong distribution, mixed repo, bad signature, ULN/subscription failure, DNF lock/conflict, low `/boot`, unsupported kernel/driver, Ksplice ineligible/failure, SELinux denial, access loss, boot failure, partial batch, upgrade inhibitor and recovery.

## Completion

DNF, Ksplice or management-platform success is insufficient without actual running/effective state and workload evidence.
