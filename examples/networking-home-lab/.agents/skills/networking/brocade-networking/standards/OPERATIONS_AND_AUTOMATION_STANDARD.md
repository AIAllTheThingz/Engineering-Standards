---
id: NET-BROCADE-OPS-001
title: Brocade Networking Operations and Automation Standard
version: 0.1.0
status: baseline
---

# Brocade Networking Operations and Automation Standard

## Applicability

Applies to current Broadcom Brocade Fabric OS Fibre Channel fabrics, directors, SANnav management, zoning, firmware, and automation. Legacy Brocade Ethernet/IP equipment remains out of operational scope until current ownership and platform guidance are identified.

## Discovery

Collect stable identity, model/serial/switch WWN, site/role/owner, FOS release/boot state, lifecycle/license, SANnav/automation/source-of-truth ownership, fabric name/WWN, domain/principal role, virtual-fabric/FID/logical-switch context, switches/directors/blades, ISLs/trunks, ports/optics/speed/fill words/errors, zoning transaction/current/effective configurations, aliases/zones, peer zoning if used, name server/device logins, redacted initiator/target ownership, host/array multipaths, MAPS/health/bottlenecks, time, AAA/certificates, management, logging/telemetry, backups, support-data policy, active transactions, dependencies, and serial/console plus alternate fabric paths.

## Validation and planning

Validate exact fabric/FID/device identity, current configuration owner, transaction lock/state, WWPN ownership, least-connectivity policy, host/array/HBA/switch interoperability, model/FOS/SANnav/feature/license compatibility, firmware hop, director/blade behavior, capacity, principal/domain/ISL topology, A/B path health, management preservation, backup/recovery, monitoring, and workload tests.

Plan an exact alias/zone or device diff, transaction order, principal/domain implications, one-fabric-at-a-time sequence, endpoint path migration, canary, convergence gates, stop conditions, rollback/recovery, evidence, and storage/OS owner handoff. Stage representative zoning, firmware, path loss, and rollback cases.

## Zoning and execution

Use stable WWPNs with independently verified endpoint ownership. Prefer single-initiator zones and only necessary target ports. Reject duplicate, unknown, stale, orphaned, overly broad, wrong-fabric, or wrong-FID membership. Preserve the existing effective configuration unless the approved plan explicitly changes it.

Reconfirm fabric/FID, health, ownership, and transaction state; serialize conflicting changes; capture an approved backup; apply the bounded transaction; validate before enablement; and change one fabric/path at a time. Stop on fabric segmentation, domain conflict, ISL/trunk degradation, unexpected login loss, path loss, MAPS alert, error growth, management loss, or workload failure.

Verify current and effective zoning, aliases, name-server logins, initiator/target visibility, host and array multipathing, A/B path health, fabric/principal/domain/ISL/trunk state, MAPS, ports/counters, SANnav reconciliation, telemetry, and dependent-service acceptance.

## Firmware and recovery

Verify exact model/director/blade, FOS and SANnav compatibility, required firmware hops, image provenance/checksum/signature, storage, licenses, optics, features, interoperability matrices, HBA/array support, director HA behavior, and rollback limits. Validate the first switch/director or fabric and observation gates before continuing.

Define serial/console entry, configuration restore, firmware fallback limits, director/blade recovery, replacement/spares, fabric rejoin, zoning restoration, alternate endpoint paths, support escalation, timing, and service acceptance. Handle `supportsave` and backups as sensitive artifacts; collection requires authorization and approved secure storage.

## Security

Use AAA, least privilege, secure management protocols, approved cryptography, certificate validation, management segmentation, secure logging, and least-connectivity zoning. Do not weaken authentication, TLS, segmentation, zoning, or audit controls to make work succeed.

## Automation and testing

Use supported FOS/SANnav interfaces and structured responses where available. Fail closed on model/FOS/fabric/FID/WWPN ambiguity; separate discover/plan/transact/enable/verify; constrain fabrics and targets; serialize zoning; redact; and preserve per-fabric/device/endpoint outcomes.

Test legacy-Ethernet misclassification, wrong fabric/FID, duplicate or stale WWPN, unknown endpoint, broad zone, concurrent transaction, invalid configuration, principal/domain/ISL change, one-path loss, management loss, incompatible FOS hop, partial rollout, rollback, and safe rerun.

## Completion

Transaction, zone enable, firmware, or SANnav job success is insufficient without effective configuration, fabric health, logins, A/B multipaths, MAPS/counters, management, telemetry, workload, checks-not-run, and residual-risk evidence.
