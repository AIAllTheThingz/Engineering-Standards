---
id: NET-HPE-AGENT-001
title: HPE Aruba Networking Agent Standard
version: 0.1.0
status: baseline
---

# HPE Aruba Networking Agent Standard

## Purpose

Define mandatory behavior for HPE Aruba Networking switching and management, centered on current AOS-CX environments while preserving explicit boundaries for other HPE and Aruba network operating systems.

## Product boundary

Resolve the actual product family from trusted hardware, software, and management facts.

- AOS-CX is distinct from AOS-Switch/ProVision and from HPE Comware/FlexNetwork.
- Aruba Central, a controller, an orchestrator, a configuration repository, or local configuration may be authoritative; determine which before writing.
- Similar commands or feature names do not prove compatible syntax, configuration semantics, images, upgrade paths, APIs, stacking, or high-availability behavior.
- Legacy or transferred products require current ownership, lifecycle, security, entitlement, and documentation verification.

## Mandatory behavior

- Record stable device identity, site, environment, owner, hardware, network OS, release, boot image, role, management authority, virtual context, VSX/VSF/stack relationship, lifecycle, entitlement, and acting identity.
- Discover Central/controller assignment, templates/groups, local overrides, checkpoints, configuration drift, interfaces, VLANs, VRFs, spanning tree, LAGs, routing, ACLs, QoS, AAA, certificates, telemetry, firmware, dependencies, and management paths.
- Preserve OOB, console, or alternate access before AAA, management VRF, routing, interface, certificate, ACL, firmware, VSX, or VSF change.
- Treat VSX peers, VSF members, stacks, redundant gateways, and uplinks as ordered failure domains; validate one side before the next.
- Verify exact switch series, module, optic, feature, license, AOS release, Central support, and upgrade path against current official information.
- Use supported AOS-CX APIs, structured data models, checkpoints, validation, and configuration workflows where available.
- Verify actual device/controller reconciliation and management, control, and data-plane behavior after execution.

## Product-specific rules

### NET-HPE-TARGET-001

**Requirement:** Resolve exact device, hardware series, network OS family and release, site, role, management authority, redundancy relationship, lifecycle, and acting identity before mutation.

**Expected evidence:** Trusted inventory, device facts, controller assignment, peer/member state, lifecycle source/date, and redacted identity class.

### NET-HPE-OSBOUND-002

**Requirement:** Treat AOS-CX, AOS-Switch/ProVision, and Comware/FlexNetwork as separate automation and lifecycle boundaries; fail closed on ambiguous platform detection.

**Expected evidence:** Platform fingerprint, selected command/API model, compatibility source, rendered artifact, and ambiguity disposition.

### NET-HPE-CENTRAL-003

**Requirement:** Identify whether Central, another controller, a repository, template/group, or local configuration owns each setting and reject conflicting writers or unexplained drift.

**Expected evidence:** Ownership map, template/group revision, local-override inventory, before/intended/actual reconciliation, and conflict disposition.

### NET-HPE-VSX-004

**Requirement:** Sequence VSX, VSF, stack, gateway, and uplink work to preserve redundancy and detect split-brain, peer, keepalive, synchronization, or forwarding failure before continuing.

**Expected evidence:** Peer/member health, consistency state, ordered plan, canary-side result, failure gates, and post-change redundancy tests.

### NET-HPE-MGMT-005

**Requirement:** Preserve tested console, OOB, or alternate access before changing AAA, certificates, management VRF, routing, ACLs, interfaces, DNS, NTP, or controller connectivity.

**Expected evidence:** Redacted alternate-access test, affected path map, required/denied management tests, rollback trigger, and post-change reachability.

### NET-HPE-UPGRADE-006

**Requirement:** Validate exact hardware, image, checksum/signature, release path, boot bank, modules, optics, features, controller, peer, configuration, capacity, and rollback before firmware change or reload.

**Expected evidence:** Official compatibility/lifecycle sources, staged result, image provenance, prechecks, peer/member order, reload observation, running image, and fallback evidence.

### NET-HPE-CONFIG-007

**Requirement:** Preview and validate exact configuration scope, use supported transactional/checkpoint behavior, and verify device plus controller actual state and forwarding outcomes.

**Expected evidence:** Validated diff, checkpoint or backup reference, lock/transaction record, per-device result, reconciliation, topology/policy tests, and residual drift.

## Automation and completion

Prefer supported AOS-CX REST APIs and structured automation, Aruba Central APIs when Central owns state, and vendor-supported modules or collections. Apply the actual Python, Ansible, Terraform/OpenTofu, or other language package. Keep secrets out of artifacts and use model/release capability checks rather than banner-only branching.

Completion requires device/controller agreement, preserved management, expected VSX/VSF/stack state, interfaces, VLAN/VRF, STP, LAG, routing, policy, AAA, telemetry, errors/discards, dependent-service acceptance, checks not run, and residual risk.

## Authoritative starting points

- [AOS-CX documentation portal](https://arubanetworking.hpe.com/techdocs/AOS-CX/help_portal/Content/home.htm)
- [HPE Networking Support Portal](https://networkingsupport.hpe.com/)
- [HPE security bulletin library](https://support.hpe.com/connect/s/securitybulletinlibrary?language=en_US)
