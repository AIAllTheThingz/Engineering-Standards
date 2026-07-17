---
id: NET-JUNIPER-AGENT-001
title: Juniper Networks Agent Standard
version: 0.1.0
status: baseline
---

# Juniper Networks Agent Standard

## Purpose

Define mandatory behavior for Juniper routing, switching, Junos configuration transactions, high availability, controller- or intent-managed networks, software lifecycle, and automation.

## Product boundary

Resolve actual platform and ownership from trusted facts.

- Junos OS and Junos OS Evolved are distinct release and platform boundaries even when configuration concepts overlap.
- Mist, Apstra, another controller or orchestrator, a source-of-truth repository, or local Junos configuration may be authoritative.
- Candidate configuration, configuration groups, inheritance, commit scripts, event automation, and ephemeral/configuration databases can affect effective state.
- Virtual Chassis, routing-engine redundancy, MC-LAG, EVPN multihoming, chassis clusters, and standalone systems require different sequencing and verification.

## Mandatory behavior

- Record stable device identity, environment, owner, platform/model, serial, Junos family/release, packages, role, controller/blueprint/site, logical system/routing instance, redundancy, licensing, lifecycle, and acting identity.
- Discover configuration ownership, candidate/committed state, groups/inheritance, pending commit/lock, rescue/rollback state, interfaces, VLAN/VRF, STP, LAG, routing/policy, EVPN/VXLAN, multicast, filters/policers, AAA/certificates, management instance, telemetry, dependencies, and recovery paths.
- Use `commit check` or equivalent validation and inspect the complete effective diff before commit.
- Use `commit confirmed` with a justified confirmation interval for changes that could remove access or service, unless an approved platform-specific recovery method is stronger.
- Preserve console/OOB/alternate access before management, authentication, routing, firewall filter, interface, certificate, software, chassis, or redundancy work.
- Verify exact hardware, Routing Engine, PIC/FPC, optics, features, packages, Junos release path, controller support, and recovery against current Juniper information.
- Verify committed and operational state, controller/intent reconciliation, and forwarding after execution.

## Product-specific rules

### NET-JUNIPER-TARGET-001

**Requirement:** Resolve exact device, platform, Junos OS or Junos OS Evolved release, role, controller, logical context, redundancy, lifecycle, and acting identity before mutation.

**Expected evidence:** Trusted inventory/device facts, management assignment, logical-system/routing-instance scope, peer/member state, lifecycle source/date, and redacted identity class.

### NET-JUNIPER-AUTHORITY-002

**Requirement:** Identify whether Mist, Apstra, another controller, a repository/automation system, or local Junos owns each state and reject conflicting writers or unexplained drift.

**Expected evidence:** Ownership map, site/blueprint/template revision, local and controller drift, before/intended/actual reconciliation, and conflict disposition.

### NET-JUNIPER-CANDIDATE-003

**Requirement:** Acquire supported configuration ownership, render the effective inherited diff, run `commit check` or equivalent validation, and reject unrelated or unmodeled candidate changes.

**Expected evidence:** Lock/session identity, base revision, full effective diff, validation output, concurrent-change check, and approved transaction scope.

### NET-JUNIPER-CONFIRM-004

**Requirement:** Use `commit confirmed` or an approved stronger recovery control for changes capable of losing management, adjacency, policy, redundancy, or forwarding; confirm only after required checks pass.

**Expected evidence:** Confirm interval rationale, rollback deadline, observer/owner, pre-confirm verification, confirmation record, and automatic-rollback test or limitation.

### NET-JUNIPER-HA-005

**Requirement:** Sequence Virtual Chassis, Routing Engine, MC-LAG, EVPN multihoming, chassis-cluster, gateway, and redundant-path changes to preserve quorum, synchronization, and forwarding.

**Expected evidence:** Roles and health, consistency/synchronization state, ordered plan, first-domain result, convergence gates, and failover/redundancy tests.

### NET-JUNIPER-UPGRADE-006

**Requirement:** Validate exact platform, Junos family, packages/image provenance, release path, storage, boot/recovery media, Routing Engines, FPC/PIC, optics, features, controller, peers, capacity, and rollback before software change or reboot.

**Expected evidence:** Official compatibility/lifecycle sources, staged prechecks, package hash/signature record, redundancy order, reboot observation, running version, and recovery evidence.

### NET-JUNIPER-VERIFY-007

**Requirement:** Verify committed, effective, operational, controller/intent, protocol, and forwarding state; a successful commit is not completion.

**Expected evidence:** Commit ID/time, configuration reconciliation, chassis/peer state, adjacencies/routes, path/policy tests, telemetry/counters, dependent-service acceptance, and residual drift.

## Automation and completion

Prefer NETCONF, gNMI, supported Junos APIs and PyEZ, controller/intent APIs when authoritative, and release-compatible YANG/data models. Apply relevant Python, Ansible, Terraform/OpenTofu, or other packages. Use private candidate configuration modes and confirmed commit controls deliberately; do not parse human output when a supported structured RPC exists.

Completion requires controller/source-of-truth reconciliation, committed/effective state, preserved management, expected chassis/VC/RE/MC-LAG/EVPN state, interfaces, VLAN/VRF, STP/LAG, routing/policy, filters/policers, AAA, telemetry, errors, service acceptance, checks not run, and residual risk.

## Authoritative starting points

- [Juniper documentation](https://www.juniper.net/documentation/)
- [Junos OS documentation](https://www.juniper.net/documentation/product/us/en/junos-os/)
- [Junos OS dates and milestones](https://support.juniper.net/support/eol/software/junos/)
