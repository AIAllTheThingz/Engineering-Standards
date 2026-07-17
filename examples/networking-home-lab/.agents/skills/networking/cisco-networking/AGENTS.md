---
id: NET-CISCO-AGENT-001
title: Cisco Networking Agent Standard
version: 0.1.0
status: baseline
---

# Cisco Networking Agent Standard

## Purpose

Define mandatory behavior for Cisco routing, switching, controller-managed networks, overlays, high availability, software lifecycle, and network automation.

## Product boundary

Identify the actual hardware, software family, mode, and management authority from trusted facts.

- Cisco IOS, IOS XE, NX-OS, and IOS XR are distinct operating and automation boundaries.
- Catalyst Center, Meraki Dashboard, a controller, an orchestrator, an intent repository, or local configuration may be authoritative.
- StackWise, VSS, StackWise Virtual, vPC, chassis redundancy, route processors, and standalone systems have different failure and upgrade behavior.
- Classic versus model-driven APIs, install versus bundle modes, and platform-specific syntax must be verified for the exact release.

## Mandatory behavior

- Record stable device identity, environment, owner, platform/PID, serial, software family/release, image/package mode, role, controller/site/fabric/virtual context, redundancy, licensing, lifecycle, and acting identity.
- Discover source-of-truth and controller ownership, configuration archive/checkpoints, interfaces, VLAN/VRF, STP, EtherChannel, first-hop redundancy, IGP/BGP, route policy, overlays, multicast, ACL/QoS, AAA/certificates, control-plane protection, telemetry, dependencies, and management paths.
- Preserve console, OOB, or alternate access before management, AAA, certificate, routing, VRF, ACL, interface, software, stack, VSS, vPC, or chassis work.
- Treat peers, supervisors, members, route processors, and redundant paths as ordered failure domains; validate state and convergence before continuing.
- Verify exact platform, ROMMON/bootloader, module, optic, feature, license, software train, controller, API/model, and upgrade path against current Cisco information.
- Prefer supported NETCONF, RESTCONF, gNMI/YANG, controller APIs, structured parsers, and configuration replace/rollback mechanisms when appropriate.
- Verify actual saved/running/controller state and forwarding behavior after execution.

## Product-specific rules

### NET-CISCO-TARGET-001

**Requirement:** Resolve exact device, PID/hardware, software family/release, operating mode, role, controller, virtual context, redundancy, lifecycle, and acting identity before mutation.

**Expected evidence:** Trusted inventory and device facts, management assignment, peer/member state, lifecycle source/date, and redacted identity class.

### NET-CISCO-OSBOUND-002

**Requirement:** Treat IOS, IOS XE, NX-OS, and IOS XR as separate syntax, API, transaction, image, upgrade, and recovery boundaries; fail closed on ambiguity.

**Expected evidence:** Platform fingerprint, selected driver/model, capability probe, rendered artifact, compatibility source, and ambiguity disposition.

### NET-CISCO-AUTHORITY-003

**Requirement:** Identify whether Catalyst Center, Meraki Dashboard, another controller, an intent repository, template, or local configuration owns each state and reject conflicting writers.

**Expected evidence:** Ownership map, controller/site/template revision, local drift inventory, before/intended/actual reconciliation, and conflict disposition.

### NET-CISCO-HA-004

**Requirement:** Sequence StackWise, VSS/StackWise Virtual, vPC, chassis, supervisor, route-processor, gateway, and redundant-path changes to preserve quorum, peer health, and forwarding.

**Expected evidence:** Role and peer/member state, consistency checks, ordered plan, first-side result, convergence gates, and post-change failover/redundancy tests.

### NET-CISCO-MGMT-005

**Requirement:** Preserve tested console/OOB/alternate access before changing AAA, certificates, management VRF, routing, ACLs, interfaces, DNS/NTP, control-plane protection, or controller connectivity.

**Expected evidence:** Redacted alternate-access test, path map, reviewed required/denied flows, rollback trigger, and post-change management verification.

### NET-CISCO-UPGRADE-006

**Requirement:** Validate exact platform, image/packages, provenance, release path, boot variables/mode, ROMMON, modules, optics, features, licenses, controller, peers, capacity, configuration, and rollback before software change or reload.

**Expected evidence:** Official compatibility/lifecycle sources, image hash/signature record, staged prechecks, install/bundle decision, peer/member order, reload observation, running version, and fallback evidence.

### NET-CISCO-CONFIG-007

**Requirement:** Generate and validate a bounded semantic diff, use supported transactions/checkpoints/replace controls for the platform, and verify actual controller, running, startup, protocol, and forwarding state.

**Expected evidence:** Parsed/validated diff, archive/checkpoint or recovery reference, transaction/job record, per-device outcome, state reconciliation, protocol/path tests, and residual drift.

## Automation and completion

Prefer supported model-driven telemetry and configuration interfaces, controller APIs, and release-compatible libraries. Apply relevant Python, Ansible, Terraform/OpenTofu, or other packages. Avoid unstructured CLI scraping when a supported structured interface exists; when CLI is unavoidable, use strict platform/release detection and parsers.

Completion requires controller/source-of-truth reconciliation, saved/running state, preserved management, expected stack/VSS/vPC/chassis state, interfaces, VLAN/VRF, STP, EtherChannel, gateways, routing/overlays, policy, AAA, telemetry, errors/discards, service acceptance, checks not run, and residual risk.

## Authoritative starting points

- [Cisco IOS and NX-OS software support](https://www.cisco.com/c/en/us/support/ios-nx-os-software/index.html)
- [Cisco IOS XE programmability](https://developer.cisco.com/iosxe/)
- [Cisco security advisories](https://sec.cloudapps.cisco.com/security/center/publicationListing.x)
