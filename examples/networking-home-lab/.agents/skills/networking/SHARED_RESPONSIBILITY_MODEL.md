---
id: NET-SRM-001
title: Network Shared Responsibility Model
version: 0.1.0
status: baseline
---

# Network Shared Responsibility Model

## Purpose

Make ownership explicit when device configuration, controllers, automation, physical infrastructure, security policy, service dependencies, and vendor support are split among teams or providers.

## Responsibility matrix

| Boundary | Accountable owner must define | Automation may do after authorization | Evidence |
|---|---|---|---|
| Inventory and topology | Stable IDs, sites, fabrics, contexts, roles, links, peers, dependencies, and source of truth | Discover and reconcile within approved scope | Timestamped inventory and discrepancy disposition |
| Configuration authority | Controller, intent system, repository, template, local CLI, and conflict policy | Read, validate, plan, and apply through the authoritative interface | Ownership map, revision, diff, actor, and job or commit ID |
| Identity and access | AAA, roles, service identities, break glass, certificates, and key rotation | Use approved least-privilege identity and redact outputs | Identity class, authorization, access test, and secret-handling record |
| Management plane | OOB network, console, DNS, NTP, telemetry, logging, and management VRF | Validate and preserve approved access paths | Primary and alternate path health |
| Control plane | Adjacencies, protocols, convergence, route policy, loop controls, and HA | Change the authorized scope with protocol gates | Before/after adjacency, route, STP, HA, and convergence evidence |
| Data plane | Required and denied flows, MTU, loss, latency, errors, QoS, and dependent services | Run approved synthetic and service tests | Path, counters, telemetry, and workload acceptance |
| Security policy | Segmentation, ACLs, control-plane protection, cryptography, logging, and exceptions | Render and deploy reviewed policy without bypass | Policy source, review, diff, required/denied path tests |
| Software and hardware | Approved releases, compatibility, entitlement, lifecycle, spares, and vendor escalation | Assess, stage, upgrade, and verify approved targets | Compatibility matrix, vendor sources, staged and production results |
| Recovery | Backups, checkpoints, rollback limits, console, spares, restore, and incident command | Capture approved state and execute reviewed recovery steps | Restore/rollback test, recovery timing, owner acceptance |
| Change acceptance | Window, blast radius, canaries, stop conditions, rollback authority, and observers | Execute only the approved plan | Approval, timeline, per-target outcomes, checks not run, residual risk |

## Boundary rules

- Shared responsibility is not unowned responsibility. Assign one accountable owner for every row.
- A managed service or controller does not remove the adopter's responsibility for identity, policy intent, validation, backup, monitoring, and acceptance.
- Local device access does not authorize bypassing controller or source-of-truth ownership.
- Vendor support does not replace a tested recovery route, exact target verification, or accountable change approval.
- Network automation must not silently assume authority over hypervisors, hosts, storage arrays, firewalls, cloud networking, DNS, identity, or applications.

## Required handoffs

Record owner, approved scope, expected input/output, timing, validation, escalation, and rollback authority at every cross-team boundary. Block execution when a required owner, dependency, observer, or acceptance criterion is absent.
