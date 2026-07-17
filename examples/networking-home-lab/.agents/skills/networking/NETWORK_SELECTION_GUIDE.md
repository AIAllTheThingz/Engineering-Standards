---
id: NET-SELECT-001
title: Network Package Selection Guide
version: 0.1.0
status: baseline
---

# Network Package Selection Guide

## Selection rule

Select by actual configuration and failure-domain ownership, not by logo, inherited terminology, CLI resemblance, or reseller name. Identify hardware, network OS, controller, source of truth, support owner, and operational authority from trusted facts.

## Routing table

| Observed boundary | Select | Important distinction |
|---|---|---|
| AOS-CX, Aruba Central, VSX, VSF, Aruba switching | [HPE Aruba Networking](hpe-aruba-networking/) | AOS-CX, AOS-Switch/ProVision, and Comware are different network-OS families |
| HPE FlexNetwork or Comware | [HPE Aruba Networking](hpe-aruba-networking/) | Verify actual current vendor support, commands, image, and lifecycle before work |
| IOS, IOS XE, Catalyst, Catalyst Center, StackWise, VSS | [Cisco networking](cisco-networking/) | IOS and IOS XE workflows and image models are not interchangeable |
| NX-OS, Nexus, vPC | [Cisco networking](cisco-networking/) | Validate feature, hardware, supervisor, vPC, and upgrade compatibility |
| IOS XR or service-provider routing | [Cisco networking](cisco-networking/) | Use IOS XR transactional and release-specific guidance |
| Junos OS, Junos OS Evolved, EX, QFX, MX, SRX routing/switching | [Juniper Networks](juniper-networks/) | Distinguish Junos variants, device roles, and configuration ownership |
| Mist- or Apstra-managed Juniper equipment | [Juniper Networks](juniper-networks/) | The controller or intent system may be authoritative over local configuration |
| Brocade Fabric OS, Fibre Channel switch/director, SANnav, zoning | [Brocade networking](brocade-networking/) | Treat redundant SAN fabrics as separate failure domains |
| Legacy Brocade ICX, VDX, MLX, CER/CES, SLX, or similar Ethernet/IP product | [Brocade networking](brocade-networking/) for ownership triage, then the current owner's package if present | Brocade Ethernet portfolios moved to different vendors; do not apply Fabric OS guidance |

## Cross-boundary composition

- Select source and destination vendor packages for migrations or replacements.
- Add virtualization and operating-system packages when hypervisor vSwitches, host NICs, bonds, multipathing, or guest networking change.
- Add storage packages when SAN zoning, array ports, initiators, multipathing, or replication paths change.
- Add cloud or platform packages when an SDN, fabric controller, managed service, or orchestration layer owns state.
- Add applicable language, infrastructure-as-code, testing, security, observability, SRE, CI/CD, and supply-chain standards.

## Ambiguity handling

Stop before mutation when vendor ownership, product family, controller authority, virtual context, configuration source, peer relationship, topology, or lifecycle is ambiguous. Record the competing interpretations and the evidence needed to resolve them. A reachable CLI is not sufficient ownership evidence.

## Current-fact requirement

Before live work, verify official documentation and lifecycle information for the exact hardware, network OS, release, controller, feature, API, entitlement, and upgrade path. Record the source and review date.
