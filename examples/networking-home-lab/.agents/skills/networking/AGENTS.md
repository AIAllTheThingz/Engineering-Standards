---
id: NET-AGENT-001
title: Networking Standards Agent Instructions
version: 0.1.0
status: baseline
---

# Networking Standards Agent Instructions

## Purpose

These instructions govern agents that discover, design, configure, automate, operate, troubleshoot, upgrade, migrate, recover, or decommission network infrastructure under this directory.

Networking work crosses shared management, control, and data planes. Treat each device, controller, site, tenant, virtual context, routing domain, fabric, and policy change as operationally consequential.

## Scope

These instructions apply to:

- physical and virtual switches, routers, controllers, directors, and appliances
- management networks, out-of-band paths, consoles, AAA, roles, certificates, and secrets
- interfaces, transceivers, cabling, VLANs, VRFs, trunks, link aggregation, stacking, chassis, and multi-chassis systems
- spanning tree, loop protection, first-hop redundancy, routing, multicast, overlays, EVPN/VXLAN, and convergence
- ACLs, segmentation, QoS, control-plane protection, telemetry, logging, and compliance controls
- Fibre Channel fabrics, ISLs, zoning, virtual fabrics, directors, and SAN management
- configuration ownership, templates, intent systems, controllers, APIs, CLIs, and infrastructure as code
- software, firmware, boot images, hardware lifecycle, entitlements, compatibility, upgrades, replacement, and recovery

## Instruction precedence

1. Applicable governance, legal, contractual, safety, privacy, and security obligations
2. Explicit authorized user requirements
3. The nearest more-specific `AGENTS.md`
4. This collection `AGENTS.md`
5. The selected vendor package `AGENTS.md`
6. Applicable platform, virtualization, operating-system, language, discipline, framework, and profile standards
7. Repository conventions
8. General agent preferences

More-specific instructions may strengthen or specialize requirements. They must not silently weaken authorization, target verification, lifecycle, access preservation, topology safety, recovery, security, evidence, or production-readiness controls.

## Required reading

Before networking work, read:

- [README.md](README.md)
- [MANIFEST.md](MANIFEST.md)
- [NETWORK_SELECTION_GUIDE.md](NETWORK_SELECTION_GUIDE.md)
- [SHARED_RESPONSIBILITY_MODEL.md](SHARED_RESPONSIBILITY_MODEL.md)
- [NETWORK_CHANGE_LIFECYCLE.md](NETWORK_CHANGE_LIFECYCLE.md)
- [MIGRATION_AND_REFRESH_DECISION_MATRIX.md](MIGRATION_AND_REFRESH_DECISION_MATRIX.md)
- the selected package's instructions, standard, templates, and example

Read applicable governance and security, architecture, testing, observability, SRE, CI/CD, supply-chain, documentation, and release-engineering standards.

## Non-negotiable behavior

- Identify exact device IDs, controller or manager, site, fabric, tenant, virtual context, environment, owner, vendor, hardware, network OS, release, role, configuration authority, and acting identity before mutation.
- Confirm the target is not a similarly named lab, disaster-recovery, retired, unmanaged, or production object.
- Discover current topology, configuration source, health, active changes, locks, dependencies, redundancy, backup, and management access without mutation.
- Separate management-, control-, and data-plane expectations and validation.
- Verify the exact hardware, software, features, optics, controllers, licenses, and upgrade path remain supported together.
- Require explicit authorization for reload, firmware, configuration replacement, interface, VLAN, VRF, routing, spanning-tree, link aggregation, overlay, ACL, QoS, AAA, certificate, stack, chassis, fabric, zoning, and destructive changes.
- Preserve tested out-of-band, console, alternate-path, or break-glass access before changing the primary management, identity, routing, transport, policy, or certificate path.
- Use the authoritative configuration owner and supported interface. Detect controller/device drift and reject conflicting writers.
- Use locks, candidate configurations, validation, atomic commits, commit-confirmed, checkpoints, or rollback timers where supported.
- Stage broad changes through syntax/semantic validation, representative labs, and canaries with health gates and stop conditions.
- Record actual state after convergence; a successful command, API response, job, or commit is insufficient.
- Do not expose credentials, secrets, private configuration, certificates, addresses, topology, support bundles, or sensitive inventory.
- Do not claim compatibility, recoverability, compliance, zero loss, zero downtime, or production readiness without direct evidence.

## Required working method

1. **Discover:** resolve targets and ownership; collect actual topology, state, health, active work, locks, dependencies, redundancy, and recovery paths without mutation.
2. **Validate:** verify authorization, privileges, lifecycle, compatibility, capacity, configuration provenance, management preservation, backups, rollback, observability, and prerequisites.
3. **Plan:** render exact targets and ordered diffs, dependency and convergence behavior, blast radius, batches, maintenance impact, stop conditions, rollback, and evidence.
4. **Stage:** lint and validate artifacts, test representative topology and failure paths, then use a bounded canary.
5. **Review:** identify access, security, routing, loop, redundancy, application, availability, privacy, licensing, and support effects.
6. **Authorize:** obtain accountable approval for the exact reviewed scope and window.
7. **Execute:** use the narrowest supported transactional interface and bounded rollout.
8. **Verify:** query actual device/controller configuration and management, control, and data-plane behavior.
9. **Observe and close:** monitor, retain evidence, document deviations, assign follow-up, and disclose residual risk.

## Automation quality

Networking automation must:

- use stable target identity and expected controller, site, fabric, tenant, context, VRF, VLAN, interface, and policy scope
- reject missing, duplicate, stale, unreachable, unexpectedly unmanaged, or conflicting targets
- separate read-only discovery from state-changing execution
- provide diff, audit, plan, candidate configuration, or equivalent preview
- require explicit execution enablement for consequential changes
- validate structured inputs and device-rendered syntax; emit structured redacted results
- bound targets, fabrics, batches, concurrency, polling, retries, timeouts, convergence, and reloads
- define canary success, pause, stop, rollback, and manual-handoff criteria
- distinguish no-change, changed, pending, converging, failed, rolled-back, and operator-required states
- record source versions, configuration owner, before/intended/actual state, per-target outcomes, and convergence evidence
- test access denied, lock contention, stale topology, bad syntax, unsupported feature, controller conflict, partial deployment, adjacency loss, loop, rollback, and safe rerun
- avoid self-modifying or dynamically downloaded unverified code
- document supported vendor, hardware, network OS, release, controller, API, and privilege assumptions

## Completion boundary

Completion requires actual-state evidence, preserved management access, expected adjacencies and topology, reachability, redundancy, policy, interface and error health, logging and monitoring, dependent-service acceptance, checks not run, and residual risk. A successful push, commit, controller job, firmware install, or reload is not sufficient by itself.
