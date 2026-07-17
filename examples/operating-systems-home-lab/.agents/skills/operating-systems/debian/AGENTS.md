---
id: OS-DEBIAN-AGENT-001
title: Debian Agent Standard
version: 0.1.0
status: baseline
---

# Debian Agent Standard

## Purpose

Define mandatory behavior for current Debian stable and explicitly approved supported oldstable/LTS systems.

## Lifecycle and release boundary

Debian stable is the default production target. Testing and unstable are development streams, not production substitutes. Oldstable, LTS and ELTS require exact coverage review, package-scope understanding and an owned migration date.

## Mandatory behavior

- Record host identity, owner, release number/codename, suite, kernel, architecture, lifecycle phase, repositories, pinning, management source and acting identity.
- Use codenames rather than moving suite aliases in production source definitions when deterministic release boundaries are required.
- Use approved Debian repositories and per-source signing trust; reject mixed releases, stale media and unverified third-party sources.
- Verify Debian Security and LTS/ELTS package coverage; do not infer that every package in an old release remains covered.
- Discover APT/dpkg locks, holds, pinning, pending restart, kernels, services, AppArmor/firewall/audit, identity/SSH, network, storage, encryption, backup and monitoring.
- Require authorization for repository, package, kernel, boot, reboot, service, security, identity, network, storage, encryption and destructive changes.
- Preserve alternate access and recovery before identity, SSH, firewall, network, boot or encryption changes.
- Follow release notes for major upgrades and review removed/obsolete packages, configuration prompts, firmware and repository changes.
- Verify actual package, kernel, security, service and workload state.

## Product-specific rules

### OS-DEBIAN-TARGET-001

**Requirement:** Resolve exact system, release/codename/suite, kernel, architecture, lifecycle, sources and management authority before mutation.

**Expected evidence:** Trusted OS facts, source definitions, lifecycle source/date, management scope and identity class.

### OS-DEBIAN-SUITE-002

**Requirement:** Default production systems to stable and prohibit testing/unstable without an explicit non-production or exceptional risk decision.

**Expected evidence:** Suite classification, use-case approval, support expectation and upgrade owner.

### OS-DEBIAN-APT-003

**Requirement:** Use release-matched approved sources and per-source signing trust; preview transactions and reject mixed suites or unowned pinning.

**Expected evidence:** Sources, preferences, signing trust, package policy and simulated transaction.

### OS-DEBIAN-COVER-004

**Requirement:** Verify security, LTS or ELTS coverage for the exact release and required packages.

**Expected evidence:** Coverage sources, package inventory, uncovered-package disposition and migration date.

### OS-DEBIAN-UPGRADE-005

**Requirement:** Read the source and destination release notes, use the supported sequential path, stage representative systems and resolve obsolete packages and configuration changes before cutover.

**Expected evidence:** Release-note review, prechecks, transaction plan, canary, reboot, recovery and acceptance.

### OS-DEBIAN-ACCESS-006

**Requirement:** Preserve tested console or local recovery access before PAM, NSS, sudo, SSH, firewall, network, certificate or directory changes.

**Expected evidence:** Redacted alternate-access test, validated configuration and rollback trigger.

### OS-DEBIAN-BASE-007

**Requirement:** Keep base-system, kernel, firmware and package state internally consistent; do not bypass dpkg dependencies or force-remove essential packages.

**Expected evidence:** Package audit, transaction result, essential-package protection and boot/service verification.

## Automation and completion

Prefer APT/dpkg, systemd, supported network/firewall tools and configuration management. Apply Bash/Python standards. Serialize package operations, define conffile policy, bound batches and reboots, and retain redacted results.

Completion requires actual release, sources, package/kernel/restart, security, access, services, network, storage, backup, monitoring, vulnerabilities and workload evidence.

## Authoritative starting points

- [Debian releases](https://www.debian.org/releases/)
- [Debian security](https://www.debian.org/security/)
- [Debian Administrator's Handbook](https://www.debian.org/doc/manuals/debian-handbook/)
