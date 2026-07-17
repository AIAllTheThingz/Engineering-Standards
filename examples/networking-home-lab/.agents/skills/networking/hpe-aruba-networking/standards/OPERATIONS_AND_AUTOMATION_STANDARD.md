---
id: NET-HPE-OPS-001
title: HPE Aruba Networking Operations and Automation Standard
version: 0.1.0
status: baseline
---

# HPE Aruba Networking Operations and Automation Standard

## Applicability

Applies to HPE Aruba Networking switching and management. AOS-CX is the primary current scope. Other families require their own verified commands, data models, images, lifecycle, and recovery behavior.

## Discovery

Collect stable identity, hardware/serial, site/role/owner, AOS family/release/build/boot image, lifecycle/entitlement, controller/Central group/template, source of truth, local overrides/drift, virtual context, VSX/VSF/stack/peer state, topology, LLDP, interfaces/transceivers/counters, VLAN/VRF, STP, LAG, gateways, routing/adjacencies, overlays, multicast, ACL/QoS, AAA/certificates, management VRF/routes/DNS/NTP, logging/telemetry, licenses, capacity, backups/checkpoints, active sessions/jobs/locks, dependencies, and console/OOB access.

## Validation and planning

Validate device and controller identity, write authority, exact platform/release/API support, feature and hardware compatibility, controller/template behavior, syntax/schema, resource capacity, topology safety, peer/member health, maintenance effect, backup/rollback, alternate access, monitoring, and dependent-service tests.

Plan ordered per-device diffs, redundant-side sequence, transient STP/LAG/routing/gateway behavior, canary, convergence gates, stop conditions, rollback trigger, evidence, and manual handoff. Stage rendered artifacts and failure cases on representative topology.

## Execution and verification

Use the authoritative supported API or management interface. Reconfirm health and scope; acquire supported locks; create an approved checkpoint; bound concurrency; change one redundant side at a time; and stop on management, peer, synchronization, adjacency, loop, reachability, policy, error, monitoring, or workload failure.

Verify device/controller reconciliation, saved and running state, management and AAA, VSX/VSF/stack, interfaces/transceivers, VLAN/VRF, STP, LAG, gateways, routes/adjacencies, ACL/QoS, logging/telemetry, errors/discards, required and denied paths, and dependent-service acceptance.

## Firmware and recovery

Verify official upgrade path, image provenance, checksum/signature, storage, boot bank, config compatibility, modules, optics, peers, controller, licenses, and rollback. Stage the image and reload behavior. Do not upgrade all members, peers, or redundant paths before validating the first failure domain.

A checkpoint or exported configuration is not a complete recovery guarantee. Define console/OOB entry, boot-image fallback, configuration restore, replacement/spare procedure, controller resynchronization, service recovery, timing, and escalation. Test the feasible path.

## Security

Use AAA and least privilege, protected management transport, approved cryptography, certificate validation, control-plane protection, management segmentation, secure logging, and reviewed ACLs. Do not weaken authentication, TLS, segmentation, loop protection, or control-plane safeguards to make automation pass.

## Automation and testing

Prefer structured APIs and data models; pin and validate modules; fail closed on OS-family mismatch; separate read/plan/apply/verify; make intended state explicit; constrain targets and concurrency; use deterministic ordering; redact secrets and private topology; and preserve per-device results.

Test wrong family, wrong Central group, duplicate/stale inventory, local/controller conflict, API mismatch, invalid syntax, lock contention, VSX/VSF member loss, STP or LAG change, adjacency failure, management loss, image incompatibility, partial rollout, rollback, and safe rerun.

## Completion

API, job, or CLI success is insufficient without actual configuration ownership, convergence, management, redundancy, topology, policy, telemetry, errors, workload, checks-not-run, and residual-risk evidence.
