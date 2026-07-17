---
id: OS-AGENT-001
title: Operating-System Standards Agent Instructions
version: 0.1.0
status: baseline
---

# Operating-System Standards Agent Instructions

## Purpose

These instructions govern agents that provision, configure, harden, patch, automate, administer, troubleshoot, upgrade, migrate, recover, or decommission operating systems under this directory.

Operating-system work routinely crosses root or administrator privilege, identity, boot, kernel, package, service, network, storage, encryption, endpoint-security, and recovery boundaries. Treat every fleet, host, image, device, and policy change as operationally consequential.

## Scope

These instructions apply to:

- physical, virtual, cloud, desktop, laptop, and image-based operating systems
- installation, imaging, enrollment, bootstrap, and configuration management
- versions, editions, servicing channels, repositories, subscriptions, and lifecycle
- kernels, drivers, firmware interfaces, bootloaders, Secure Boot, and restart orchestration
- packages, applications, services, daemons, scheduled tasks, and startup behavior
- local and directory-backed identity, privilege, remote access, certificates, and secrets
- host networking, DNS, time, proxies, firewalls, and management connectivity
- filesystems, volumes, mounts, encryption, quotas, snapshots, and backup agents
- logging, auditing, endpoint protection, vulnerability management, and compliance controls
- update, upgrade, rollback, restore, rebuild, wipe, retirement, and evidence
- PowerShell, shell, Python, Ansible, DSC, MDM, configuration management, and orchestration

## Instruction precedence

1. Applicable governance, legal, contractual, safety, privacy, and security obligations
2. Explicit authorized user requirements
3. The nearest more-specific `AGENTS.md`
4. This collection `AGENTS.md`
5. The selected operating-system package `AGENTS.md`
6. Applicable platform, virtualization, networking, language, discipline, framework, and profile standards
7. Repository conventions
8. General agent preferences

More-specific instructions may strengthen or specialize requirements. They must not silently weaken authorization, target verification, lifecycle, access preservation, backup, recovery, security, evidence, or production-readiness controls.

## Required reading

Before operating-system work, read:

- [README.md](README.md)
- [MANIFEST.md](MANIFEST.md)
- [OS_SELECTION_GUIDE.md](OS_SELECTION_GUIDE.md)
- [SHARED_RESPONSIBILITY_MODEL.md](SHARED_RESPONSIBILITY_MODEL.md)
- [OS_CHANGE_LIFECYCLE.md](OS_CHANGE_LIFECYCLE.md)
- [UPGRADE_MIGRATION_DECISION_MATRIX.md](UPGRADE_MIGRATION_DECISION_MATRIX.md)
- the selected package's instructions, standard, templates, and example

Read applicable governance and the relevant security, architecture, testing, observability, SRE, CI/CD, supply-chain, documentation, and release-engineering standards.

## Non-negotiable behavior

- Identify the exact device or host, environment, owner, management authority, OS vendor, edition, version, build or kernel, architecture, role, and acting identity before mutation.
- Confirm that the target is not a similarly named lab, disaster-recovery, retired, unmanaged, or production system.
- Discover current state, policy source, health, active work, pending restart, update status, dependencies, backup, and management access before change.
- Verify the exact release and installed components remain supported for the required workload, hardware, repositories, management tooling, and subscription or entitlement.
- Require explicit authorization for install, reimage, wipe, upgrade, package, kernel, driver, boot, reboot, service, identity, privilege, remote-access, firewall, network, storage, encryption, endpoint-control, or fleet changes.
- Preserve a tested recovery route and alternate administrative access before changing the primary management, identity, network, firewall, boot, or encryption path.
- Use vendor-supported repositories and management interfaces. Do not mix package sources or copy configuration across distributions or editions without compatibility evidence.
- Verify signatures, checksums, repository identity, policy provenance, and artifact source.
- Preserve mandatory security controls. Do not disable them as a troubleshooting shortcut.
- Stage broad changes through representative tests and canary rings with health gates and stop conditions.
- Make custom automation idempotent where feasible, bounded, observable, cancellable where practical, and safe to resume or rerun after partial failure.
- Record actual state after execution; command success alone is insufficient.
- Do not expose credentials, recovery keys, tokens, certificates, user data, configuration secrets, support bundles, or sensitive inventory.
- Do not claim compatibility, recoverability, compliance, zero downtime, or production readiness without direct evidence.

## Required working method

1. **Discover:** resolve target identity, ownership, management source, OS facts, configuration, health, dependencies, active work, pending restart, and current state without mutation.
2. **Validate:** verify authorization, privileges, support, repositories, compatibility, package provenance, backup, recovery, alternate access, capacity, and prerequisites.
3. **Plan:** render exact targets, intended transitions, dependency order, batches, reboots, user or workload impact, stop conditions, rollback, and evidence.
4. **Stage:** validate on representative systems and a bounded canary ring.
5. **Review:** identify security, access, identity, boot, network, storage, application, availability, privacy, licensing, and support effects.
6. **Authorize:** obtain accountable approval for the exact reviewed target set and window.
7. **Execute:** use the narrowest supported interface and bounded rollout.
8. **Verify:** query actual system, management, security, network, storage, service, backup, monitoring, and workload state.
9. **Observe and close:** monitor, retain evidence, document deviations, assign follow-up, and disclose residual risk.

## Automation quality

Operating-system automation must:

- use stable target identity and expected management scope
- reject missing, duplicate, stale, unreachable, or unexpectedly unmanaged targets
- separate read-only discovery from state-changing execution
- provide check, diff, audit, plan, `-WhatIf`, or equivalent preview when available
- require explicit execution enablement for consequential changes
- validate structured inputs and emit structured redacted results
- use bounded batches, concurrency, polling, retries, timeouts, and reboots
- define canary success, rollout pause, stop, rollback, and manual-handoff criteria
- distinguish no-change, changed, restart-required, retryable, failed, rolled-back, and operator-required states
- record source versions, policy origin, before/after state, per-target outcomes, and restart evidence
- test access denied, unavailable repository, signature failure, stale metadata, lock contention, low space, dependency conflict, partial update, failed boot, and recovery
- avoid self-modifying or dynamically downloaded unverified code
- document supported OS, edition, architecture, management, and privilege assumptions

## Lifecycle and current-release policy

“Current” means within an authoritative support and security-maintenance window at the time of adoption. It does not mean “latest package available somewhere.”

- Record the source-review date and exact lifecycle source.
- Prefer vendor-recommended production or long-term channels for new production systems.
- Treat extended, legacy, LTSC, ESU, ELS, ESM, ELTS, or similar coverage as explicit entitlement and risk decisions.
- Do not treat sustaining support, archived repositories, vaults, community availability, or downloadable media as proof of security-update coverage.
- Separate upgrade acceptance from source retirement and destructive cleanup.

## Completion boundary

Completion requires actual-state evidence, required reboot evidence, service and workload health, security-control status, management reachability, backup and monitoring status, owner acceptance where applicable, explicit checks not run, and residual risk. A successful installer, package transaction, policy deployment, MDM command, or configuration-management run is not sufficient by itself.
