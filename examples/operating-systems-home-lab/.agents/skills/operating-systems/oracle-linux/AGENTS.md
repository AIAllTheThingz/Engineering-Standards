---
id: OS-OL-AGENT-001
title: Oracle Linux Agent Standard
version: 0.1.0
status: baseline
---

# Oracle Linux Agent Standard

## Purpose

Define mandatory behavior for current supported Oracle Linux systems, including Unbreakable Enterprise Kernel and Red Hat Compatible Kernel boundaries.

## Authority and lifecycle

Identify exact Oracle Linux release, update level, UEK or RHCK release, architecture, ULN or yum repository source, Premier/Extended/Sustaining phase, support subscription, Ksplice state and management authority such as OS Management Hub, Oracle Linux Automation Manager, cloud management, image pipeline or local administration.

Sustaining Support availability does not by itself mean new security fixes. Record the actual support phase and coverage.

## Mandatory behavior

- Record system identity, environment, owner, release, kernel family/version, architecture, boot, lifecycle/support, repositories/channels, management source and acting identity.
- Do not mix Oracle Linux, RHEL, Rocky, AlmaLinux, CentOS or unapproved repositories.
- Validate UEK/RHCK, Ksplice, driver, kABI, application and Oracle workload certification before kernel changes.
- Discover DNF/RPM locks, channels, modules, Ksplice updates, pending restart, services, SELinux, firewall, audit, identity, network, storage, encryption, backup and monitoring.
- Require authorization for channel/repository, package, module, kernel-family switch, Ksplice, boot, reboot, service, SELinux, firewall, identity, network, storage, encryption and destructive changes.
- Preserve alternate access before identity, SSH, firewall, network or certificate changes.
- Keep SELinux enforcing and security controls active; remediate policy or application behavior instead of broad disablement.
- Use Oracle-supported upgrade/migration paths and verify Oracle application/database certification independently.
- Verify actual package, running/default kernel, Ksplice, security, service and workload state.

## Product-specific rules

### OS-OL-TARGET-001

**Requirement:** Resolve exact Oracle Linux release, kernel family, architecture, repositories/channels, support phase and management authority before mutation.

**Expected evidence:** Trusted OS/kernel facts, channel inventory, lifecycle source/date and identity class.

### OS-OL-KERNEL-002

**Requirement:** Treat UEK and RHCK as distinct compatibility boundaries and validate boot, driver, Secure Boot, Ksplice, application and support effects before switching or updating.

**Expected evidence:** Kernel-family/version inventory, certification review, boot/default selection, restart/live-patch evidence and fallback.

### OS-OL-REPO-003

**Requirement:** Use approved Oracle Linux release-matched ULN or yum channels and verified signing trust; reject mixed Enterprise Linux sources.

**Expected evidence:** Enabled channels/repos, signing trust, package provenance and exception disposition.

### OS-OL-KSPLICE-004

**Requirement:** Verify Ksplice eligibility, applied effective-kernel state, limitations and remaining reboot requirement; do not equate a live update with complete patch compliance automatically.

**Expected evidence:** Client/subscription state, applied updates, effective kernel, deferred reboot decision and verification.

### OS-OL-SUPPORT-005

**Requirement:** Distinguish Premier, Extended and Sustaining support and document the security-fix implications for the exact release.

**Expected evidence:** Support policy/date, entitlement, coverage decision and migration owner.

### OS-OL-SELINUX-006

**Requirement:** Keep SELinux enforcing and remediate labeling/policy/application issues instead of disabling enforcement.

**Expected evidence:** Enforcement state, denials, reviewed remediation and tests.

### OS-OL-UPGRADE-007

**Requirement:** Use an Oracle-supported upgrade path and validate kernel, repositories, management agents, Oracle workloads, backup and recovery on representative systems.

**Expected evidence:** Supported path, prechecks, certification, canary, restart, recovery and acceptance.

## Automation and completion

Prefer DNF/RPM, ULN/yum tooling, Ksplice, systemd, firewalld, SELinux tools, OS Management Hub and supported Ansible/Oracle automation. Apply Bash/Python standards; bound transactions, batches and reboots.

Completion requires actual release/channel/package/running kernel/Ksplice/restart, security, identity/access, services, network, storage, backup, monitoring, vulnerabilities and workload evidence.

## Authoritative starting points

- [Oracle Linux documentation](https://docs.oracle.com/en/operating-systems/oracle-linux/)
- [Oracle Open Source Lifetime Support Policy](https://www.oracle.com/a/ocom/docs/elsp-lifetime-069338.pdf)
