---
id: NET-HPE-README-001
title: HPE Aruba Networking Standard
version: 0.1.0
status: baseline
---

# HPE Aruba Networking Standard

## Applicability

Use for HPE Aruba Networking switching and management, including AOS-CX, Aruba Central, VSX, VSF, and explicitly identified legacy AOS-Switch/ProVision or HPE Comware/FlexNetwork environments.

## Authority and boundaries

Determine whether Central, another controller, an intent/configuration repository, a template/group, or local device configuration is authoritative. Do not allow two writers to manage the same state. Treat AOS-CX, AOS-Switch/ProVision, and Comware as separate network-OS families.

## Adoption

Record exact device IDs, series, roles, sites, AOS family/releases, boot images, Central/controller assignment, templates, virtual contexts, VSX/VSF/stack relationships, topology, management paths, protocols, policies, licenses, lifecycle, support, backup, and recovery ownership. Apply [AGENTS.md](AGENTS.md), the [operational standard](standards/OPERATIONS_AND_AUTOMATION_STANDARD.md), and the package templates.

## Lifecycle and compatibility

Revalidate exact hardware, modules, optics, features, releases, upgrade path, controller support, entitlement, security notices, and end-of-support status against official HPE sources at each live use. A downloadable image or similar CLI is not support evidence.

## Validation and recovery

Validate generated syntax and API schema, configuration diffs, VSX/VSF consistency, topology and policy semantics, firmware paths, lab behavior, canaries, partial failure, reload, rollback, and recovery. Preserve an approved checkpoint/configuration backup plus console/OOB access; prove that the selected recovery mechanism works for the exact platform.

## Failure modes

- misidentifying the AOS family or device generation
- Central/template overwrite of a local change
- VSX/VSF/stack loss or split-brain during peer work
- management loss after AAA, VRF, ACL, route, certificate, or interface change
- unsupported image, module, optic, feature, or upgrade hop
- accepting configuration success without forwarding, peer, or controller reconciliation

## Composition

Add the relevant automation-language and infrastructure-as-code packages plus security, testing, observability, SRE, CI/CD, supply-chain, documentation, and release standards. Add source/destination vendor packages for migrations.

## Limitations

This package does not provide site addressing, feature parity, approved versions, entitlement, topology design, outage authorization, or guaranteed rollback. Product terminology and ownership evolve; authoritative current sources and local policy control.
