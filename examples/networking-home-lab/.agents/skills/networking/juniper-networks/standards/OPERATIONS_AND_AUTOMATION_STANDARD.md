---
id: NET-JUNIPER-OPS-001
title: Juniper Networks Operations and Automation Standard
version: 0.1.0
status: baseline
---

# Juniper Networks Operations and Automation Standard

## Applicability

Applies to Juniper routing, switching, controller/intent management, high availability, overlays, software maintenance, and automation. Actual Junos family, platform, context, and authority determine behavior.

## Discovery

Collect stable identity, model/serial, site/role/owner, Junos family/release/packages/boot media, lifecycle/license, Mist site or Apstra blueprint/controller/source of truth, logical systems/routing instances, committed/candidate/ephemeral state, configuration groups/inheritance/scripts, commit history/locks/rescue/rollback, Virtual Chassis/RE/MC-LAG/EVPN/chassis-cluster state, topology/LLDP, interfaces/transceivers/counters, VLAN/VRF, STP/LAG, gateways, IGP/BGP/route policy, overlays/multicast, firewall filters/policers/control-plane protection, AAA/certificates, management instance/routes/DNS/NTP, logging/telemetry, capacity, active work, dependencies, and console/OOB access.

## Validation and planning

Validate target and controller identity, write authority, clean/private candidate base, full inherited effective diff, exact platform/release/RPC/YANG capability, feature/hardware/license/controller compatibility, `commit check`, capacity, topology safety, HA synchronization, maintenance effect, rollback/confirmed-commit behavior, alternate access, monitoring, and service tests.

Plan an ordered transaction with exact hierarchy/context, transient protocol/gateway/overlay effects, HA sequence, canary, convergence gates, confirmation deadline, stop conditions, rollback/recovery, evidence, and manual handoff. Stage artifacts and failure cases against representative topology.

## Execution and verification

Use the authoritative supported NETCONF/RPC/controller interface. Reconfirm base revision, ownership, scope, and health; acquire a private/exclusive lock appropriate to policy; load and compare the bounded candidate; validate; commit confirmed when required; and change one redundancy domain at a time. Stop on unexpected diff, management, peer, synchronization, adjacency, loop, reachability, policy, counter, telemetry, or workload failure.

Before confirmation, verify controller/source-of-truth reconciliation, committed/effective configuration, management/AAA, chassis/VC/RE/MC-LAG/EVPN/cluster state, interfaces, VLAN/VRF, STP/LAG, gateways, routes/adjacencies/policy, filters/policers, logging/telemetry, errors, required/denied paths, and dependent services.

## Software and recovery

Verify official release guidance, exact model and Junos family, package provenance/checksum/signature, storage, boot and recovery media, dual RE behavior, FPC/PIC/optic compatibility, controller/feature/license support, required intermediate releases, and rollback. Test representative install and reboot behavior. Do not update all REs, members, peers, or paths without validated sequencing.

Define automatic confirmed-commit rollback, rollback-file limits, rescue configuration, console/OOB entry, alternate boot/package rollback, configuration restore, replacement/spares, controller resynchronization, service recovery, timing, and escalation. Test the feasible recovery path.

## Security

Use AAA, least privilege, secure management protocols, approved cryptography, certificate validation, management segmentation, control-plane protection, secure logging, and reviewed firewall filters. Do not bypass authentication, certificate validation, segmentation, loop safeguards, or control-plane protection.

## Automation and testing

Prefer NETCONF, structured RPCs, gNMI/YANG, Junos PyEZ, and authoritative controller APIs. Pin dependencies; capability-probe; use private candidates; separate read/plan/apply/confirm/verify; constrain scope/time/concurrency; redact; and retain commit plus per-device results.

Test wrong Junos family/context/blueprint, stale base revision, inherited surprise, concurrent commit, invalid candidate, failed commit check, confirmation timeout, HA member failure, route/policy change, management loss, incompatible package, partial rollout, rollback, and safe rerun.

## Completion

A successful commit or confirmation is insufficient without owner/committed/effective reconciliation, operational convergence, management, HA, routing, policy, telemetry, counters, services, checks-not-run, and residual-risk evidence.
