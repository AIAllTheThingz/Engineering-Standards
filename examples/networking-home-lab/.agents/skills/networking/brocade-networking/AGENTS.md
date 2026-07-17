---
id: NET-BROCADE-AGENT-001
title: Brocade Networking Agent Standard
version: 0.1.0
status: baseline
---

# Brocade Networking Agent Standard

## Purpose

Define mandatory behavior for current Broadcom Brocade Fabric OS Fibre Channel switches, directors, fabrics, SANnav management, zoning, software lifecycle, and automation, with an explicit ownership quarantine for legacy Brocade Ethernet/IP product lines.

## Product and ownership boundary

Resolve actual hardware, software, protocol, and current support owner before applying guidance.

- The primary active scope is Broadcom Brocade Fabric OS (FOS) Fibre Channel switching/directors and SANnav.
- Legacy Brocade Ethernet/IP lines such as ICX, VDX, MLX, CER/CES, and SLX were transferred or evolved under different vendors and portfolios. Determine the exact current owner, product, network OS, lifecycle, and documentation.
- Do not apply Fabric OS commands, zoning rules, firmware, or recovery behavior to an Ethernet/IP product.
- Treat redundant Fibre Channel fabrics as independent failure domains and preserve host/array multipathing throughout work.

## Mandatory behavior

- Record stable switch/director identity, environment, owner, model, serial/WWN, FOS release, role, fabric name/WWN, domain ID, FID/virtual-fabric context, SANnav authority, licensing, lifecycle, and acting identity.
- Discover fabric membership, principal selection, switches/directors, logical switches/FIDs, ISLs/trunks, ports/optics/speed/errors, zoning database and effective configuration, aliases, peer zoning if used, name server, device logins, host/array paths, MAPS/health policy, bottlenecks, time, AAA/certificates, telemetry, backups, `supportsave` policy, active transactions, and recovery access.
- Use single-initiator zoning unless an approved storage architecture explicitly requires another model; preserve least connectivity and exact initiator/target identity.
- Make zoning changes in the correct FID/fabric, validate the complete transaction, and verify effective zoning plus host/array multipath behavior.
- Change one redundant fabric or one host/array path at a time; stop before touching the peer fabric when path, login, error, or workload health is degraded.
- Verify exact switch/director, blade, optic, license, FOS/SANnav release, interoperability matrix, supported firmware path, and upgrade order using current official Broadcom information.
- Preserve serial/console and alternate SAN paths before firmware, domain, fabric, ISL, logical-switch, zoning, AAA, certificate, or management changes.

## Product-specific rules

### NET-BROCADE-TARGET-001

**Requirement:** Resolve exact device, model, serial/WWN, FOS or legacy Ethernet software family, current vendor/support owner, fabric/FID/domain/role, manager, lifecycle, and acting identity before mutation.

**Expected evidence:** Trusted device facts, protocol/product classification, ownership source, fabric and logical-switch inventory, lifecycle source/date, and redacted identity class.

### NET-BROCADE-BOUNDARY-002

**Requirement:** Quarantine legacy Ethernet/IP products from Fabric OS guidance and route work to the current product owner's standards only after positive hardware/software ownership identification.

**Expected evidence:** Model and network-OS fingerprint, acquisition/ownership mapping, current official documentation, selected package or documented gap, and rejected FOS assumptions.

### NET-BROCADE-FABRIC-003

**Requirement:** Treat fabrics, FIDs, domain IDs, principal behavior, ISLs/trunks, and redundant A/B designs as explicit failure domains; never modify both redundant fabrics before first-fabric path acceptance.

**Expected evidence:** Fabric/WWN/FID/domain map, principal and ISL health, A/B path inventory, ordered plan, first-fabric validation, and peer-fabric hold point.

### NET-BROCADE-ZONE-004

**Requirement:** Use stable WWPN identity, least-connectivity zoning, approved single-initiator design by default, complete transaction validation, and effective-configuration plus endpoint-path verification.

**Expected evidence:** Redacted initiator/target ownership, aliases and proposed zone diff, current/effective zone configuration, validation output, login/multipath tests, and orphan/overexposure review.

### NET-BROCADE-MGMT-005

**Requirement:** Preserve tested serial/console, management, SANnav, and alternate data paths before changing AAA, certificates, IP management, fabric services, ISLs, logical switches, zoning, firmware, or directors.

**Expected evidence:** Redacted alternate-access and alternate-path tests, affected path map, rollback trigger, escalation contacts, and post-change reachability/path state.

### NET-BROCADE-UPGRADE-006

**Requirement:** Validate exact hardware/blades, FOS/SANnav releases, supported firmware hops, image provenance, storage, licenses, optics, fabrics, features, interoperability, host/array support, director sequencing, and recovery before firmware change or hareboot/reboot.

**Expected evidence:** Current official release/interoperability sources, firmware path, checksum/signature record, staged prechecks, first-domain outcome, running version, HA/reload evidence, and recovery plan.

### NET-BROCADE-EVIDENCE-007

**Requirement:** Capture redacted configuration and health evidence, including an approved backup and support-data procedure, and verify actual fabric, zoning, login, path, MAPS, error, telemetry, and workload state after execution.

**Expected evidence:** Backup reference, redacted `supportsave` handling record when authorized, transaction/result IDs, before/intended/actual state, health/path tests, checks not run, and residual risk.

## Automation and completion

Use supported Fabric OS/SANnav interfaces and release-compatible management libraries. Apply relevant Python, Ansible, or other automation standards. Treat zoning as a transaction, fail closed on fabric/FID ambiguity, serialize conflicting changes, validate WWPN ownership, and redact configuration/support data.

Completion requires SANnav/device reconciliation where applicable, correct FOS/configuration, preserved management and A/B paths, expected fabric/principal/domain/ISL/trunk state, effective zoning, device logins, multipathing, MAPS, port/errors, telemetry, workload acceptance, checks not run, and residual risk.

## Authoritative starting points

- [Broadcom Fabric Operating System](https://www.broadcom.com/products/fibre-channel-networking/software/fabric-operating-system)
- [Broadcom SANnav Management Portal](https://www.broadcom.com/products/fibre-channel-networking/software/sannav-management-portal)
- [Broadcom Fabric OS technical documentation](https://techdocs.broadcom.com/us/en/fibre-channel-networking/fabric-os.html)
