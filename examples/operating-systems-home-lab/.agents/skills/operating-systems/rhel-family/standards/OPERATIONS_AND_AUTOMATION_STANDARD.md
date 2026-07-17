---
id: OS-RHEL-OPS-001
title: RHEL Family Operations and Automation Standard
version: 0.1.0
status: baseline
---

# RHEL Family Operations and Automation Standard

## Applicability

Applies to current supported RHEL, Rocky Linux, AlmaLinux and explicitly approved CentOS Stream systems. Distribution-specific policy overrides family resemblance.

## Discovery

Collect machine and management identity, distribution/release/kernel/architecture, lifecycle/support/subscription, repositories/keys/modules/packages/locks, hardware/firmware/boot/Secure Boot, services/timers, identities/sudo/authselect/SSSD/SSH/certificates, SELinux/crypto/firewall/audit, network/DNS/time/proxy, filesystems/LVM/encryption/mounts/capacity, backup/recovery, monitoring/logging/vulnerabilities, roles/workloads/owners and pending restart.

## Validation and planning

Validate exact distribution support, repository trust and compatibility, package transaction preview, module streams, disk and boot capacity, kernel/driver/agent/application compatibility, SELinux policy, identity/access preservation, service restart/reboot impact, backup/restore or rebuild, canary and monitoring.

Plan exact hosts and packages/configuration, transaction and dependency effects, service restarts, kernel selection, reboot order, batches, success/stop gates, rollback/recovery and evidence. Stage representative roles, architectures and repository paths.

## Execution and verification

Use distribution-supported interfaces. Reconfirm release and repositories, bound batches, preserve alternate access, retain transaction and journal evidence, stop on trust/dependency/space/access/security/boot/service/workload failure, and avoid unrelated cleanup.

Verify release, packages, repositories, running/default kernel, restart state, boot, services/timers, identity/sudo/SSH, SELinux, crypto, firewall, audit, network/time/DNS, storage/encryption, backup, monitoring, vulnerabilities and workload acceptance.

## Repository and package rules

- Reject unsigned, unowned, cross-distribution, duplicate, vault or stale repositories unless an approved exception defines containment.
- Use `dnf` transaction preview and preserve history where applicable.
- Review module-stream changes as compatibility changes.
- Do not use `rpm --force`, dependency bypass or manual RPM database edits as routine remediation.
- Resolve package-manager locks by identifying the owner; do not delete locks blindly.

## Security and identity

Keep SELinux enforcing, preserve system crypto policy, use least privilege, validate sudoers before deployment, preserve local recovery access, and test SSSD/directory behavior including offline and expired-credential cases. Do not open firewall paths without required/denied path tests.

## Upgrade and recovery

Use the exact distribution's supported major-upgrade guidance. For RHEL, review Leapp reports and inhibitors when applicable. For derivatives, use their stated policy; do not assume formal support. Prefer parallel replacement when the path, drift or rollback is uncertain.

Snapshots or LVM snapshots are not independent backups by default. Define boot fallback, package/config rollback limits, restore/rebuild, data recovery and manual handoff.

## Automation and testing

Make distribution detection fail closed; use structured inventory; separate check and execution; constrain Ansible collections and dependencies; validate YAML/shell/Python; bound forks, serial batches, retries and reboot waits; redact; and record per-host outcomes.

Test wrong distro, mixed repo, bad signature, unavailable repo, DNF lock, dependency/module conflict, low `/boot`, SELinux denial, sudoers error, SSSD outage, firewall access loss, kernel boot failure, partial batch, rollback and safe rerun.

## Completion

Tool success or a zero DNF exit status is insufficient without actual running state, security, access, services, workload, backup and monitoring evidence.
