---
id: OS-SUSE-AGENT-001
title: SUSE Linux Enterprise Agent Standard
version: 0.1.0
status: baseline
---

# SUSE Linux Enterprise Agent Standard

## Purpose

Define mandatory behavior for current supported SUSE Linux Enterprise Server and Desktop systems, modules, extensions and service packs.

## Authority and lifecycle

Identify the exact SLES/SLED product, major version, service pack, modules/extensions, architecture, registration, support phase and management authority such as SUSE Customer Center, Repository Mirroring Tool, SUSE Multi-Linux Manager, image pipeline, configuration management, YaST or local administration.

## Mandatory behavior

- Record system identity, environment, owner, product, release/service pack, kernel, architecture, lifecycle/LTSS, registration, modules/extensions, repositories, management source and acting identity.
- Use only product-, service-pack-, module- and architecture-matched repositories with verified signatures.
- Discover Zypper/RPM locks, patches, products, patterns, packages, pending reboot, kernel, services, AppArmor, firewall, audit, identity, network, Btrfs/Snapper/LVM/encryption, backup and monitoring.
- Require authorization for registration, repository, product/module/extension, package, patch, service-pack migration, kernel, boot, reboot, service, AppArmor, firewall, identity, network, storage, snapshot, encryption and destructive changes.
- Preserve console or alternate access before identity, SSH, firewall, network, certificate or directory changes.
- Preserve AppArmor and other security controls; do not use broad disablement as remediation.
- Validate Btrfs/Snapper configuration and space before relying on transactional or filesystem rollback. Snapshots are not independent backups.
- Use SUSE-supported service-pack migration and major-upgrade paths for the exact installed products, modules and extensions.
- For SAP or HA roles, compose role/platform guidance and validate cluster/resource sequencing separately.
- Verify actual product, repository, package, kernel, security, service and workload state.

## Product-specific rules

### OS-SUSE-TARGET-001

**Requirement:** Resolve product, service pack, kernel, architecture, registration, modules/extensions, repositories, lifecycle and management authority before mutation.

**Expected evidence:** Trusted product facts, registration/repository inventory, lifecycle source/date and identity class.

### OS-SUSE-REPO-002

**Requirement:** Use only approved service-pack-, product-, module- and architecture-matched repositories with verified signing trust.

**Expected evidence:** Product/module/repository mapping, enabled services, signature trust and package provenance.

### OS-SUSE-MIGRATE-003

**Requirement:** Validate supported source/destination service-pack or major migration, registered extensions, product dependencies, rollback/rebuild and representative tests before migration.

**Expected evidence:** Migration precheck, supported path, extension compatibility, canary, restart and recovery.

### OS-SUSE-SNAP-004

**Requirement:** Validate Snapper/Btrfs layout, exclusions, capacity, cleanup, bootloader integration and rollback limits before using snapshots operationally.

**Expected evidence:** Filesystem/snapshot state, space, rollback test and independent backup evidence.

### OS-SUSE-APPARMOR-005

**Requirement:** Keep AppArmor enforcement where configured and remediate profiles or application behavior rather than disabling protection broadly.

**Expected evidence:** Profile state, denials, reviewed change, tests and post-change enforcement.

### OS-SUSE-PATCH-006

**Requirement:** Preview Zypper transactions and patch categories, validate solver changes, services, kernel/restart, canaries and recovery before patching.

**Expected evidence:** Dry-run/solver result, patch scope, staged result, reboot decision and actual state.

### OS-SUSE-ACCESS-007

**Requirement:** Preserve tested local/console recovery access before PAM, SSSD, sudo, SSH, firewall, network or certificate changes.

**Expected evidence:** Redacted access test, validated configuration and rollback trigger.

## Automation and completion

Prefer Zypper/RPM, SUSEConnect, SUSE management tooling, YaST where supported, Snapper, systemd and supported Ansible/Salt interfaces. Bound solver/lock waits, batches and reboots; record transactional/reboot state; apply Bash/Python standards.

Completion requires actual product/repository/package/kernel/restart, AppArmor/firewall/audit, identity/access, services, network, storage/snapshot, backup, monitoring, vulnerabilities and workload evidence.

## Authoritative starting points

- [SUSE product lifecycle](https://www.suse.com/lifecycle/)
- [SUSE Linux Enterprise Server documentation](https://documentation.suse.com/sles/)
