---
id: NET-JUNIPER-README-001
title: Juniper Networks Standard
version: 0.1.0
status: baseline
---

# Juniper Networks Standard

## Applicability

Use for Junos OS and Junos OS Evolved routing and switching, Mist- or Apstra-managed networks, Virtual Chassis, Routing Engine redundancy, MC-LAG, EVPN/VXLAN, chassis clusters, software maintenance, and Juniper automation.

## Authority and boundaries

Determine whether Mist, Apstra, another controller/orchestrator, a repository, or local Junos is authoritative. Inspect configuration groups, inheritance, scripts, ephemeral state, and pending candidate changes. Treat Junos family, platform, logical context, and HA design as distinct compatibility and failure boundaries.

## Adoption

Record exact device IDs, models, serials, roles, sites/blueprints, Junos families/releases/packages, controllers, logical systems/routing instances, configuration ownership, HA relationships, topology, management paths, protocols, policies, licenses, lifecycle, support, rescue/rollback state, and recovery ownership. Apply [AGENTS.md](AGENTS.md), the [operational standard](standards/OPERATIONS_AND_AUTOMATION_STANDARD.md), and package templates.

## Lifecycle and compatibility

Revalidate platform, Routing Engines, FPCs/PICs, optics, Junos family/releases, packages, features, models/APIs, controller support, licenses, upgrade paths, security advisories, and lifecycle using current official Juniper sources.

## Validation and recovery

Use a private candidate configuration where appropriate; inspect inherited effective diffs; run commit validation; and use confirmed commit for access- or service-threatening changes. Validate topology, routing/policy semantics, HA state, lab/canary behavior, partial deployment, convergence, automatic rollback, reboot, and recovery. Rescue configuration and rollback files have limits and are not full service recovery alone.

## Failure modes

- writing locally to a Mist/Apstra/controller-owned object
- overlooking inherited groups, pending candidate state, or concurrent commits
- confirming a commit before management, protocol, policy, and path tests
- breaking VC, RE, MC-LAG, EVPN, cluster, or routing redundancy
- unsupported package, platform, FPC/PIC, optic, controller, or release hop
- accepting commit success without operational and forwarding verification

## Composition

Add relevant language and infrastructure-as-code packages plus security, testing, observability, SRE, CI/CD, supply-chain, documentation, and release standards. Select source/destination vendor packages for migrations.

## Limitations

This package does not provide local policy, approved releases, topology, entitlement, outage approval, or guaranteed nonstop upgrade/rollback. Exact Juniper product guidance and local authority control.
