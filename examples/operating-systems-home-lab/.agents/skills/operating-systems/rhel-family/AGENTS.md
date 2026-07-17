---
id: OS-RHEL-AGENT-001
title: RHEL Family Agent Standard
version: 0.1.0
status: baseline
---

# RHEL Family Agent Standard

## Purpose

Define mandatory behavior for Red Hat Enterprise Linux and related Enterprise Linux distributions, including Rocky Linux, AlmaLinux and CentOS Stream.

## Distribution boundary

Identify the actual distribution from trusted system facts. Similar RPM/DNF behavior does not make distributions operationally or contractually interchangeable.

- RHEL uses Red Hat lifecycle, subscription, repositories, errata and support.
- Rocky Linux and AlmaLinux use their own release, repository, signature and support policies.
- CentOS Stream is a continuously delivered upstream development stream, not a drop-in production support entitlement for RHEL.
- Oracle Linux is covered by the separate Oracle Linux package.

## Mandatory behavior

- Record stable host identity, environment, owner, distribution, major/minor release, kernel, architecture, boot mode, roles, lifecycle, repositories, modules, subscription or support source and acting identity.
- Do not mix RHEL, Rocky, AlmaLinux, CentOS Stream, Oracle Linux, vault, archive or unapproved third-party repositories.
- Verify that the exact minor release and repository set receive security updates; a supported major version alone is insufficient for distributions that retire older minors.
- Preserve SELinux enforcement, system crypto policy, firewalld or approved firewall, audit, Secure Boot and least privilege.
- Discover DNF/RPM state, locks, pending restart, kernel, services, authselect/SSSD, storage, LVM, encryption, network, time, backup, monitoring and vulnerabilities.
- Require authorization for repository, package, module stream, kernel, boot, reboot, SELinux, firewall, identity, systemd, network, storage, encryption and destructive actions.
- Preserve console or alternate access before authselect, SSSD, PAM, SSH, firewall, network, certificate or directory changes.
- Use vendor-supported upgrade paths and tools for the exact distribution. Do not assume a RHEL Leapp path applies unchanged to derivatives.
- Verify actual package, kernel, security, service and workload state after execution.

## Product-specific rules

### OS-RHEL-DISTRO-001

**Requirement:** Resolve the actual distribution, release, kernel, architecture, repositories, subscription/support source and management authority before mutation.

**Expected evidence:** Trusted OS facts, repository list, lifecycle source/date, management scope and identity class.

### OS-RHEL-REPO-002

**Requirement:** Use only approved distribution-matched repositories and verified signing keys; reject cross-distribution, vault, duplicate or unowned sources.

**Expected evidence:** Repository origin, enabled set, key fingerprints or trust record, package provenance and exception disposition.

### OS-RHEL-SELINUX-003

**Requirement:** Keep SELinux enforcing and fix policy, labeling or application compatibility rather than disabling enforcement.

**Expected evidence:** Enforcement state, relevant denials, reviewed policy or labeling change, tests and post-change state.

### OS-RHEL-PATCH-004

**Requirement:** Preview DNF transactions and validate errata, module streams, dependencies, space, kernel/restart impact, canaries and recovery before update.

**Expected evidence:** Transaction preview, advisory scope, staged result, kernel/restart decision and actual-state verification.

### OS-RHEL-IDENT-005

**Requirement:** Preserve tested local break-glass access before authselect, PAM, SSSD, SSH, sudo, certificate or directory-integration changes.

**Expected evidence:** Redacted alternate-access test, configuration diff, identity tests and rollback trigger.

### OS-RHEL-UPGRADE-006

**Requirement:** Use only an upgrade path supported by the actual distribution and release; otherwise prefer a parallel replacement with explicit data and identity migration.

**Expected evidence:** Vendor guidance, pre-upgrade analysis, inhibitors, representative test, rollback/rebuild and acceptance.

### OS-RHEL-KERNEL-007

**Requirement:** Validate kernel, kABI/driver, Secure Boot, live-patch, bootloader, initramfs and reboot behavior before kernel change.

**Expected evidence:** Compatibility review, installed/default kernel, boot test, restart evidence and fallback plan.

## Automation and completion

Prefer DNF/RPM, subscription-manager on RHEL, systemd, nmstate or NetworkManager tooling, firewalld, semanage and supported Ansible collections. Apply Bash or Python guidance. Automation must be distribution-aware, idempotent, check-mode capable where supported, bounded and tested for partial transactions and reboots.

Completion requires package and kernel state, restart, SELinux/firewall/audit/crypto policy, identity/access, services, network, storage, backup, monitoring, vulnerabilities, workload acceptance, checks not run and residual risk.

## Authoritative starting points

- [RHEL lifecycle](https://access.redhat.com/support/policy/updates/errata)
- [RHEL documentation](https://docs.redhat.com/en/documentation/red_hat_enterprise_linux/)
- [Rocky Linux release guide](https://wiki.rockylinux.org/rocky/version/)
- [AlmaLinux release notes](https://wiki.almalinux.org/release-notes/)
- [CentOS Stream](https://www.centos.org/centos-stream/)
