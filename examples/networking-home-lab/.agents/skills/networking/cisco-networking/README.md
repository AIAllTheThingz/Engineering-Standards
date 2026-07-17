---
id: NET-CISCO-README-001
title: Cisco Networking Standard
version: 0.1.0
status: baseline
---

# Cisco Networking Standard

## Applicability

Use for Cisco IOS, IOS XE, NX-OS, and IOS XR routing and switching; Catalyst Center or other controller management; Meraki-managed network equipment; StackWise, VSS/StackWise Virtual, vPC, chassis, overlays, and related automation.

## Authority and boundaries

Determine whether a controller, Dashboard, source-of-truth repository, template, orchestrator, or local configuration is authoritative. Do not allow competing writers. Treat each software family, hardware family, virtual context, operating mode, and high-availability design as a distinct compatibility and failure boundary.

## Adoption

Record exact device IDs, PID/hardware, serials, roles, sites/fabrics, software families/releases, image modes, boot variables, controllers, templates, virtual contexts, HA relationships, topology, management paths, protocols, policies, licenses, lifecycle, support, backup, and recovery ownership. Apply [AGENTS.md](AGENTS.md), the [operational standard](standards/OPERATIONS_AND_AUTOMATION_STANDARD.md), and package templates.

## Lifecycle and compatibility

Revalidate hardware, supervisors, modules, optics, ROMMON, software trains, features, APIs/models, controller compatibility, licenses, upgrade paths, security advisories, and lifecycle against current Cisco sources for every live use.

## Validation and recovery

Validate schemas/models, rendered syntax, semantic diffs, platform parsers, topology, route and policy behavior, HA consistency, software install mode/path, lab and canary outcomes, partial deployment, convergence, reload, rollback, and recovery. A startup-config copy, archive, or checkpoint is not by itself a complete recovery plan.

## Failure modes

- selecting the wrong IOS/IOS XE/NX-OS/IOS XR driver or image workflow
- controller or template overwriting a local change
- breaking StackWise, VSS, vPC, chassis, or routing redundancy
- losing access through AAA, VRF, route, ACL, certificate, CoPP, or interface changes
- unsupported software, ROMMON, module, optic, API/model, license, or upgrade hop
- accepting a job or command without startup/running/controller reconciliation and path tests

## Composition

Add relevant automation-language and infrastructure-as-code packages plus security, testing, observability, SRE, CI/CD, supply-chain, documentation, and release standards. Select source and destination vendor packages for migrations.

## Limitations

This package does not define local addressing, routing policy, approved software, feature licenses, topology, outage approval, or guaranteed ISSU/rollback. Current Cisco documentation, contract entitlements, and local policy control.
