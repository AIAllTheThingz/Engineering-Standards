---
id: NET-BROCADE-README-001
title: Brocade Networking Standard
version: 0.1.0
status: baseline
---

# Brocade Networking Standard

## Applicability

Use primarily for current Broadcom Brocade Fabric OS Fibre Channel switches/directors, SANnav, fabrics, ISLs, zoning, logical switches, MAPS, firmware, and automation. Use only the ownership-triage controls for legacy Brocade Ethernet/IP devices until the actual current vendor and platform package is selected.

## Authority and boundaries

Determine whether SANnav, another management platform, an automation repository, or direct Fabric OS configuration owns state. Identify the exact fabric and FID. Treat A and B fabrics as separate failure domains. Do not confuse FOS with legacy ICX, VDX, MLX, CER/CES, SLX, or other transferred Ethernet/IP portfolios.

## Adoption

Record switch/director IDs, models, serials/WWNs, FOS releases, fabric names/WWNs, domain IDs, FIDs, principal behavior, SANnav ownership, ISLs/trunks, ports/optics, zoning/effective configuration, aliases, logins, host/array paths, MAPS, licenses, lifecycle, support, backup, and recovery. Apply [AGENTS.md](AGENTS.md), the [operational standard](standards/OPERATIONS_AND_AUTOMATION_STANDARD.md), and package templates.

## Lifecycle and compatibility

Revalidate switch/director and blade models, optics, FOS/SANnav releases, firmware hops, features, licenses, interoperability matrices, host bus adapters, array support, security notices, and lifecycle using current Broadcom and endpoint-vendor sources.

## Validation and recovery

Validate zoning transaction scope, aliases and WWPN ownership, FID, principal/domain behavior, fabric consistency, firmware path, lab/canary evidence, first-fabric path health, partial failure, rollback, and recovery. Test serial/console and multipath behavior. A configuration upload, `supportsave`, or director HA claim is not by itself full service recovery evidence.

## Failure modes

- applying FOS guidance to a legacy Ethernet/IP product
- editing the wrong fabric, FID, logical switch, or effective zone configuration
- broad or multi-initiator zoning that exposes unintended targets
- changing both redundant fabrics or all endpoint paths before validation
- domain/principal/ISL/trunk disruption or director blade/HA incompatibility
- unsupported FOS hop, SANnav pairing, optic, license, HBA, array, or feature
- exposing WWPNs, zoning, topology, configuration, or support bundles

## Composition

Add storage, operating-system, and virtualization packages for array ports, initiators, multipathing, and workload validation; add automation, security, testing, observability, SRE, CI/CD, supply-chain, documentation, and release standards. Select current-owner networking packages for legacy Ethernet work.

## Limitations

This package does not define storage zoning policy, interoperability approval, supported firmware, maintenance windows, vendor ownership for every historical product, or guaranteed nondisruptive upgrade/recovery. Current official matrices and local SAN/storage authority control.
