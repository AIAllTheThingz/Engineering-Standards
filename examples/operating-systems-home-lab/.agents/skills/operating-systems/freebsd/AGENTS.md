---
id: OS-FREEBSD-AGENT-001
title: FreeBSD Agent Standard
version: 0.1.0
status: baseline
---

# FreeBSD Agent Standard

## Purpose

Define mandatory behavior for current supported FreeBSD production releases and explicitly approved supported legacy branches.

## Release and authority

Prefer the current Production Release. A Legacy Release must still be on the supported-release list and have an owned upgrade date. Distinguish base system, kernel/world, binary update, source-built update, packages, Ports, jails and appliances. Identify whether image pipeline, configuration management, `freebsd-update`, source build, `pkg`, Poudriere, jail manager or local administration is authoritative.

## Mandatory behavior

- Record host identity, environment, owner, release/branch/patch level, kernel/world, architecture, boot mode, lifecycle, package repository, Ports tree or Poudriere source, jails, management source and acting identity.
- Keep kernel and world compatible and follow the required install/reboot sequence for updates and upgrades.
- Use signed official or approved package repositories; do not mix quarterly/latest/custom ABI repositories without review.
- Distinguish base-system security advisories and errata from third-party package vulnerabilities and updates.
- Discover update state, `pkg` locks/audit, configuration drift, boot environments, ZFS/UFS, jails, services, firewall, audit, identity/SSH, network, storage, encryption, backup and monitoring.
- Require authorization for base/kernel/world, repository/package/Ports, boot, reboot, service, jail, firewall, identity, network, ZFS/storage, encryption and destructive changes.
- Preserve console/alternate access before SSH, PAM, firewall, network, loader or boot changes.
- Choose one authoritative host firewall design and validate syntax/rollback before activation.
- Use `etcupdate`, supported merge processes or reviewed equivalents for configuration transitions; do not overwrite `/etc` blindly.
- Treat ZFS snapshots and boot environments as local rollback mechanisms, not independent backups.
- Verify actual kernel/world/package/jail/security/service and workload state.

## Product-specific rules

### OS-FREEBSD-TARGET-001

**Requirement:** Resolve exact host, release/branch/patch, kernel/world, architecture, package ABI/repository, jails, lifecycle and management authority before mutation.

**Expected evidence:** Trusted OS facts, repo/ABI inventory, supported-release source/date, jail scope and identity class.

### OS-FREEBSD-BASE-002

**Requirement:** Keep base system, kernel and world compatible and use the documented update/upgrade sequence, including required intermediate reboot and install steps.

**Expected evidence:** Before/after kernel/world versions, command phases, reboots, boot validation and configuration merge.

### OS-FREEBSD-PKG-003

**Requirement:** Use approved signed ABI-matched package repositories and review `pkg` solver/audit results; separate base and package remediation.

**Expected evidence:** Repository/ABI, signatures, dry-run, audit, package provenance and final state.

### OS-FREEBSD-ZFS-004

**Requirement:** Validate pool health, boot environment, dataset/mount/encryption effects, space and rollback limits before ZFS or upgrade work.

**Expected evidence:** Pool/dataset/boot-environment state, capacity, rollback test and independent backup.

### OS-FREEBSD-FW-005

**Requirement:** Validate PF, IPFW or IPFilter syntax and required/denied paths with console fallback before firewall activation; avoid conflicting authoritative firewalls.

**Expected evidence:** Selected firewall authority, validated rules, rollback timer/path and network tests.

### OS-FREEBSD-JAIL-006

**Requirement:** Treat host and jail release, package, network, storage and restart scopes separately and verify jail compatibility during host upgrades.

**Expected evidence:** Jail inventory, release/ABI, dependency and restart plan, per-jail results and workload tests.

### OS-FREEBSD-PORTS-007

**Requirement:** Build custom Ports packages in a controlled reproducible environment such as Poudriere rather than compiling unreviewed production-local state.

**Expected evidence:** Ports tree/commit, options, builder, signed repository/artifacts, tests and rollout.

## Automation and completion

Prefer `freebsd-update` where supported, documented source build procedures, `pkg`, Poudriere, `etcupdate`, `service`, `sysrc`, ZFS tools and supported jail management. Apply Bash/Python guidance as applicable. Bound package locks, jails, batches and reboots.

Completion requires actual release/kernel/world/package/jail/restart, firewall/audit/security, identity/access, services, network, storage/ZFS/encryption, backup, monitoring, vulnerabilities and workload evidence.

## Authoritative starting points

- [FreeBSD release information](https://www.freebsd.org/releases/)
- [FreeBSD Security Information](https://www.freebsd.org/security/)
- [FreeBSD Handbook](https://docs.freebsd.org/en/books/handbook/)
