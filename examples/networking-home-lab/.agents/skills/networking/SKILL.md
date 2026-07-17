---
name: networking
description: Review and analyze synthetic network-engineering scenarios using the copied HPE Aruba, Cisco, Juniper, and Brocade standards. Use for portfolio-grade home-lab planning, package selection, safety review, troubleshooting, and migration exercises. Do not use for production access, credential retrieval, live device changes, or external writes.
---

# Advanced Network Engineering

Treat a network as a shared, high-blast-radius control plane. A routine-looking interface, VLAN, routing, policy, firmware, fabric, or zoning action can remove management access, isolate workloads, create loops, or interrupt many dependent services.

## Demo Boundary

This copy is a portfolio-grade home-lab demonstration, not a production-certified Active skill. Use only synthetic inventories, configurations, identifiers, and scenarios committed beneath this example workspace. Treat every execution phase in the copied standards as design and review guidance only: do not connect to controllers or devices, retrieve credentials, change external state, or claim live verification. Refuse requests to bypass governance, reveal secrets, or perform production operations.

Read the workspace `AGENTS.md` and its inherited central authorities: `agents/AGENTS_Base.md`, `governance/RISK_CLASSIFICATION.md`, `governance/COMPLETION_EVIDENCE.md`, `governance/EXCEPTION_PROCESS.md`, and `governance/AI_GENERATED_CODE_POLICY.md`. If an inherited authority is unavailable in a standalone copy, mark the affected control `Blocked`; do not fabricate policy or production evidence.

## Establish authority and topology

1. Read the adopting repository's root and nearest scoped `AGENTS.md` files.
2. Read [`NETWORK_SELECTION_GUIDE.md`](NETWORK_SELECTION_GUIDE.md), [`SHARED_RESPONSIBILITY_MODEL.md`](SHARED_RESPONSIBILITY_MODEL.md), [`NETWORK_CHANGE_LIFECYCLE.md`](NETWORK_CHANGE_LIFECYCLE.md), and [`MIGRATION_AND_REFRESH_DECISION_MATRIX.md`](MIGRATION_AND_REFRESH_DECISION_MATRIX.md) as applicable.
3. Resolve the exact device, controller, site, tenant, fabric, virtual context, management authority, environment, owner, hardware, network OS, release, role, and acting identity.
4. Inventory topology, management paths, configuration ownership, adjacencies, loops and loop protection, link aggregation, redundancy, overlays, policy, AAA, certificates, licensing, software and hardware lifecycle, telemetry, backups, and recovery access.
5. Classify management-, control-, and data-plane impact plus availability, security, compatibility, support, and recovery risk.
6. Require explicit authorization for consequential execution.

Do not infer authorization from repository access, credentials, controller reachability, an automation account, or this skill.

## Select networking packages

Select every materially affected vendor and control boundary.

| Evidence | Package |
|---|---|
| HPE Aruba Networking; AOS-CX; Aruba Central; VSX or VSF; or explicitly identified AOS-Switch/ProVision or HPE Comware/FlexNetwork equipment | [`hpe-aruba-networking/`](hpe-aruba-networking/README.md) |
| Cisco IOS, IOS XE, NX-OS, or IOS XR; Catalyst Center; Meraki Dashboard; StackWise; VSS; or vPC | [`cisco-networking/`](cisco-networking/README.md) |
| Junos OS or Junos OS Evolved; Mist; Apstra; Virtual Chassis; MC-LAG; EVPN; or Juniper routing and switching | [`juniper-networks/`](juniper-networks/README.md) |
| Broadcom Brocade Fabric OS; Fibre Channel switches or directors; SANnav; zoning; ISLs; virtual fabrics; or a legacy Brocade Ethernet device requiring ownership triage | [`brocade-networking/`](brocade-networking/README.md) |

For each selected package:

1. Read its `README.md`, `AGENTS.md`, `MANIFEST.md`, and operational standard.
2. Apply the automation-language and infrastructure-as-code packages actually used.
3. Apply security, testing, observability, SRE, architecture, CI/CD, supply-chain, documentation, and release disciplines as needed.
4. Use package templates when adoption, review, or evidence records must be retained.
5. Treat examples as fictitious composition guidance only.

Verify the exact vendor, product family, hardware, network OS, release train, controller ownership, API/feature compatibility, entitlement, and support state against current authoritative sources before execution. Similar CLI syntax is not compatibility evidence.

## Work through safe phases

1. **Discover:** collect actual topology, target identity, current and intended owners, active changes, health, dependencies, configuration, and recovery paths without mutation.
2. **Validate:** verify authorization, privilege, lifecycle, compatibility, capacity, redundancy, management preservation, backups, rollback, observability, and prerequisites.
3. **Plan or preview:** render exact targets, ordered diffs, blast radius, convergence, maintenance impact, stop conditions, rollback, and evidence.
4. **Stage:** validate syntax and semantics in a lab or digital twin, then use representative canaries.
5. **Authorize:** obtain accountable approval for the reviewed target set and window.
6. **Execute:** use supported transactional interfaces, bounded concurrency, locks, health gates, and explicit stop conditions.
7. **Verify actual state:** query device and controller state plus management, control, and data-plane behavior.
8. **Observe and close:** monitor the defined period, retain redacted evidence, assign follow-up, and disclose residual risk.

## Engineer reliable automation

- Prefer supported APIs and data models such as NETCONF, RESTCONF, gNMI, YANG, vendor SDKs, and controller APIs over screen scraping.
- Use stable device IDs and verified controller, site, fabric, tenant, context, VRF, VLAN, interface, and policy scope; fail closed on ambiguity.
- Separate discovery, validation, planning, execution, verification, and reporting.
- Use candidate configuration, configuration locks, atomic commit, commit-confirmed, checkpoints, or rollback timers where supported.
- Make mutation opt-in and require confirmation for reload, firmware, configuration replacement, interface shutdown, routing, VLAN/VRF, ACL, QoS, AAA, certificate, HA, stack, fabric, zoning, or destructive actions.
- Preserve out-of-band, console, or alternate access before changing the primary management, identity, routing, policy, or transport path.
- Bound devices, fabrics, sites, batches, concurrency, retries, timeouts, convergence waits, and maintenance windows.
- Stop on management loss, failed adjacency, unexpected reachability, redundancy loss, loops, error/discard growth, policy violation, monitoring loss, or workload failure.
- Record before, intended, and actual state; tool versions; configuration owner; per-target outcomes; and correlation IDs.
- Redact credentials, secrets, private configuration, certificates, support bundles, addresses, topology, and sensitive inventory.
- Test partial fleets, partial fabrics, lock contention, stale inventory, controller conflicts, loss of access, failed convergence, rollback, recovery, and safe rerun.
- Do not copy configuration across vendors, network operating systems, hardware families, or release trains without current compatibility evidence.

## Validate and report

Report the selected package, vendor and platform boundary, configuration authority, target scope, lifecycle status, authorization state, before/intended/actual state, management/control/data-plane impact, security and recovery impact, validation results, checks not run, residual risk, owners, and required reviewers.

Distinguish planned, staged, implemented, executed, converged, verified, observed, and production-approved states.
