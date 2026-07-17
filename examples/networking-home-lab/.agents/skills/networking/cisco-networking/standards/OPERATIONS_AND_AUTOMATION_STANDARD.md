---
id: NET-CISCO-OPS-001
title: Cisco Networking Operations and Automation Standard
version: 0.1.0
status: baseline
---

# Cisco Networking Operations and Automation Standard

## Applicability

Applies to Cisco routing, switching, controller management, high availability, overlays, software maintenance, and automation. Actual software family, platform, mode, and controller ownership determine behavior.

## Discovery

Collect stable identity, PID/serial, site/role/owner, software family/release/boot image/packages/install mode/ROMMON, lifecycle/license, controller/site/fabric/template/source of truth, virtual context, local drift, StackWise/VSS/vPC/chassis/supervisor/route-processor state, topology, CDP/LLDP, interfaces/transceivers/counters, VLAN/VRF, STP, EtherChannel, gateway protocols, IGP/BGP/route policy, EVPN/VXLAN/overlays, multicast, ACL/QoS/CoPP, AAA/certificates, management VRF/routes/DNS/NTP, logging/telemetry, capacity, configuration archive/checkpoints, active sessions/jobs/locks, dependencies, and console/OOB access.

## Validation and planning

Validate target/controller identity, write authority, platform/release/API/YANG capability, image/install mode/ROMMON path, feature/hardware/license/controller compatibility, syntax and semantic diff, capacity, topology safety, peer/member health, maintenance effect, archive/rollback, alternate access, monitoring, and service tests.

Plan ordered per-device transactions, redundant-side sequence, transient STP/EtherChannel/routing/gateway/overlay behavior, canary, convergence gates, stop conditions, rollback trigger, evidence, and manual handoff. Stage artifacts and failure cases on representative topology.

## Execution and verification

Use the authoritative supported model-driven interface, controller, or CLI. Reconfirm scope and health; acquire supported locks; capture an approved archive/checkpoint; bound concurrency; change one redundancy domain at a time; and stop on management, peer, synchronization, adjacency, loop, reachability, policy, counter, telemetry, or workload failure.

Verify controller/source-of-truth reconciliation, running and startup state, management/AAA, HA/stack/vPC/chassis roles, interfaces/transceivers, VLAN/VRF, STP, EtherChannel, gateways, routes/adjacencies/overlays, ACL/QoS/CoPP, logging/telemetry, errors/discards, required and denied paths, and dependent services.

## Software and recovery

Verify exact Cisco release guidance, platform/PID, package/image provenance, checksums/signatures, storage, boot variables, install/bundle mode, ROMMON, configuration register where applicable, modules, optics, peers, controller, feature licenses, and rollback. Test the upgrade path and reload on representative equipment. Do not update all members, supervisors, peers, or paths before first-domain validation.

Define console/OOB entry, alternate boot, package rollback limits, configuration replace/restore, chassis/member recovery, replacement/spare procedure, source-of-truth reconciliation, service recovery, timing, and escalation. Test the feasible path.

## Security

Use AAA, least privilege, secure management protocols, approved cryptography, certificate validation, management segmentation, CoPP/control-plane safeguards, secure logging, and reviewed ACLs. Do not disable AAA, TLS validation, segmentation, STP protections, or CoPP merely to pass a change.

## Automation and testing

Prefer NETCONF, RESTCONF, gNMI/YANG, model-driven telemetry, controller APIs, and strict structured parsers. Pin dependencies; capability-probe the actual device; separate read/plan/apply/verify; constrain scope and concurrency; use deterministic ordering; redact; and preserve per-target results.

Test wrong OS family, wrong virtual context/controller site, stale inventory, controller/local conflict, unsupported YANG/API, invalid syntax, lock contention, HA member failure, STP/EtherChannel/route change, management loss, image/ROMMON incompatibility, partial rollout, rollback, and safe rerun.

## Completion

API, controller job, commit, copy, or reload success is insufficient without startup/running/owner reconciliation, convergence, management, redundancy, topology, routing, policy, telemetry, counters, services, checks-not-run, and residual-risk evidence.
