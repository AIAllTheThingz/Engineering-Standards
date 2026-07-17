---
id: NET-README-001
title: Network Engineering Standards
version: 0.1.0
status: baseline
---

# Network Engineering Standards

## Purpose

Provide composable standards for safe, secure, supportable, testable, recoverable, and evidence-based network engineering and automation.

## Package catalog

| Package | Scope |
|---|---|
| [HPE Aruba Networking](hpe-aruba-networking/) | AOS-CX and Aruba-managed switching, with explicit boundaries for AOS-Switch/ProVision and HPE Comware/FlexNetwork |
| [Cisco networking](cisco-networking/) | IOS, IOS XE, NX-OS, IOS XR, controller-managed networks, routing, switching, overlays, and high availability |
| [Juniper Networks](juniper-networks/) | Junos OS and Junos OS Evolved, Mist or Apstra authority, routing, switching, EVPN/VXLAN, and transactional commits |
| [Brocade networking](brocade-networking/) | Current Broadcom Brocade Fabric OS Fibre Channel fabrics and SANnav, plus ownership triage for legacy Brocade Ethernet lines |

## Product and lifecycle policy

The collection does not permanently designate a release train as current. Before adoption or execution, record:

- actual vendor, product family, hardware model, serial or stable ID, and role
- network OS, release, boot image, patch or maintenance level, and feature set
- controller, manager, source-of-truth, template, or local configuration ownership
- support phase, security-update coverage, entitlement, and source-review date
- hardware, optics, line-card, module, license, API, controller, and upgrade-path compatibility
- end-of-sale, end-of-support, successor, migration, and spare strategy

The initial source review was performed on 2026-07-14. Every live use must revalidate current facts.

## Common control model

All packages require:

- authoritative target, topology, scope, and configuration-owner verification
- separate management-, control-, and data-plane expectations
- non-mutating discovery before change
- explicit diff or plan and accountable authorization
- syntax, semantic, lab, and canary validation for consequential changes
- preserved out-of-band, console, or alternate access
- transactional configuration and rollback controls where supported
- bounded targets, batches, concurrency, retries, convergence waits, and reloads
- actual-state, reachability, adjacency, redundancy, policy, error, telemetry, and workload verification
- redacted evidence and honest disclosure of checks not run

## Selection and composition

Start with [NETWORK_SELECTION_GUIDE.md](NETWORK_SELECTION_GUIDE.md). Add the language or infrastructure-as-code package used by the automation; relevant operating-system, cloud, container, virtualization, storage, and platform packages; and applicable security, testing, observability, SRE, CI/CD, supply-chain, documentation, and release disciplines.

Select every package that owns a materially affected control boundary. Multi-vendor paths, fabric-to-LAN dependencies, or migrations usually require more than one package.

## Adoption

1. Identify exact devices, controllers, sites, tenants, contexts, routing domains, fabrics, and configuration owners.
2. Select the smallest complete package set.
3. Record platform, release, lifecycle, topology, policy, management paths, dependencies, backup, and ownership.
4. Tailor without weakening authorization, topology safety, lifecycle, security, access preservation, recovery, testing, or evidence.
5. Complete adoption and review checklists.
6. Test automation and recovery against representative non-production topology.
7. Define canaries, stop conditions, maintenance windows, convergence gates, and acceptance.
8. Preserve redacted evidence using the package template.

## Validation

Validate schema, syntax, model and API compatibility, generated diff, policy, topology, lab behavior, unit tests, mocks, isolated integration tests, canary results, negative cases, partial failure, convergence, rollback, and recovery as applicable.

Never use production as the first syntax, topology, API, firmware, or rollback test.

## Known failure modes

- targeting the wrong device, site, fabric, tenant, context, VRF, VLAN, interface, zone, or policy
- trusting display names, stale inventory, LLDP/CDP alone, or a controller cache without corroboration
- writing locally to a controller-owned device and creating drift or overwrite
- losing management access through AAA, certificate, routing, VRF, interface, ACL, or firmware changes
- creating a Layer 2 loop, asymmetric routing, black hole, duplicate gateway, or split-brain pair
- accepting a job or commit as proof of convergence and forwarding behavior
- applying configuration or an image to an incompatible hardware or network-OS family
- treating configuration export, checkpoint, or single-device backup as complete service recovery
- upgrading without optics, line-card, controller, license, peer, protocol, or feature compatibility
- changing both redundant peers or fabrics before validating the first side
- exposing secrets, private configuration, topology, addresses, certificates, or support bundles

## Limitations

These packages do not certify a network, replace vendor support, supply organization-specific addressing or policy, authorize live execution, guarantee convergence or recovery, or prove compliance. Adopters must define inventory, source of truth, topology, ownership, risk tolerance, regulatory controls, maintenance windows, approved versions, identity architecture, backup, spares, and incident response.
