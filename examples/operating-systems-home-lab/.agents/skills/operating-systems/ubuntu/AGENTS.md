---
id: OS-UBUNTU-AGENT-001
title: Ubuntu Agent Standard
version: 0.1.0
status: baseline
---

# Ubuntu Agent Standard

## Purpose

Define mandatory behavior for current supported Ubuntu Server and Ubuntu Desktop systems.

## Lifecycle and authority

Prefer a current LTS release for production. Interim releases have shorter support and require an owned upgrade cadence. Distinguish standard security maintenance from Ubuntu Pro/ESM and Legacy coverage, including repository coverage. Identify whether cloud-init, image pipeline, Landscape, MDM, configuration management, APT policy, Snap policy, Netplan or local administration is authoritative.

## Mandatory behavior

- Record host/device identity, environment, owner/custodian class, Server/Desktop edition, release, kernel, architecture, flavor, lifecycle/coverage, repositories, Pro attachment, management source and acting identity.
- Use only approved APT sources with per-repository `Signed-By` trust. Do not introduce deprecated global trust patterns or unverified PPAs.
- Distinguish Main, Restricted, Universe and Multiverse security coverage and record Pro/ESM dependency where applicable.
- Discover APT/dpkg locks, phased updates, held packages, pending restart, kernel, services, cloud-init, Snap, AppArmor, firewall, identity, network/Netplan, storage, encryption, backup and monitoring.
- Require authorization for repository, package, Snap, kernel, boot, reboot, service, AppArmor, firewall, identity, SSH, Netplan, storage, encryption, desktop policy, user-data or destructive changes.
- Preserve console/alternate access before identity, SSH, firewall, network, certificate or directory changes.
- Do not rerun or mutate cloud-init state on an established system without explicit recovery-aware authorization.
- Preserve AppArmor and other security controls; fix profiles or compatibility instead of disabling enforcement broadly.
- Use supported release-upgrade paths and verify application, driver, agent, repository and desktop/session compatibility.
- Verify actual OS, kernel, package, Snap, security, service, desktop/user or workload state after change.

## Product-specific rules

### OS-UBUNTU-TARGET-001

**Requirement:** Resolve exact system, Server/Desktop role, flavor, release, kernel, lifecycle coverage, management source and acting identity before mutation.

**Expected evidence:** Stable identity, trusted OS facts, coverage source/date, policy authority and identity class.

### OS-UBUNTU-APT-002

**Requirement:** Use approved release-matched APT sources and per-repository signing trust; reject stale media, unverified PPA, mixed release or ambiguous mirror configuration.

**Expected evidence:** Source definitions, suites/components, signing trust, package policy and exception disposition.

### OS-UBUNTU-COVER-003

**Requirement:** Record which packages are covered by standard maintenance, Ubuntu Pro/ESM or other support; do not represent an attached subscription as universal coverage without verification.

**Expected evidence:** Release coverage, repository/component inventory, Pro/ESM status and uncovered-package disposition.

### OS-UBUNTU-NET-004

**Requirement:** Validate Netplan renderer, interface identity, routes, DNS, remote access and rollback before network changes; do not rely on unsafe unattended apply.

**Expected evidence:** Rendered diff, validation or try result, console fallback and required/denied path tests.

### OS-UBUNTU-CLOUDINIT-005

**Requirement:** Treat cloud-init instance identity, data sources, stages and generated files as provisioning state; do not clean or rerun it casually on established systems.

**Expected evidence:** Data-source and ownership review, intended stage, backup/recovery and post-change verification.

### OS-UBUNTU-UPGRADE-006

**Requirement:** Use a supported release-upgrade path, disable or reconcile third-party sources, review inhibitors, stage representative systems and preserve recovery.

**Expected evidence:** Upgrade-path source, prechecks, compatibility inventory, canary, restart, recovery and acceptance.

### OS-UBUNTU-DESKTOP-007

**Requirement:** For Desktop, account for user sessions, home data, accessibility, display/GPU, encryption, Snap/app compatibility, login and restart effects.

**Expected evidence:** Persona/hardware tests, data protection, user-impact plan and post-login acceptance.

## Automation and completion

Prefer APT/dpkg, `pro`, Snap, systemd, Netplan, cloud-init, Landscape and supported Ansible modules. Apply Bash/Python standards. Bound apt locks, batches and reboots; handle noninteractive package prompts explicitly; never embed secrets in cloud-init or logs.

Completion requires actual release/kernel/package/Snap state, restart, AppArmor/firewall/security, identity/access, network/time/DNS, services, storage, backup, monitoring and server workload or desktop user validation.

## Authoritative starting points

- [Ubuntu release cycle](https://ubuntu.com/about/release-cycle)
- [Ubuntu Server documentation](https://ubuntu.com/server/docs/)
- [Ubuntu Desktop documentation](https://documentation.ubuntu.com/desktop/)
