---
id: NET-MIGRATE-001
title: Network Migration and Refresh Decision Matrix
version: 0.1.0
status: baseline
---

# Network Migration and Refresh Decision Matrix

## Decision matrix

| Condition | Preferred path | Required evidence | Avoid |
|---|---|---|---|
| Supported platform, low drift, supported direct upgrade path, tested rollback | In-place software upgrade | Exact compatibility matrix, staged image, checksum/signature, config backup, boot/rollback test, peer order, canary, acceptance | Skipping required intermediate releases or upgrading both peers together |
| Supported hardware but major network-OS, controller, or configuration-model change | Parallel control-plane or device migration | Translation review, feature parity, lab topology, coexistence, state ownership, cutover/rollback, required/denied path tests | Blind syntax conversion or two active configuration authorities |
| End-of-support hardware, insufficient capacity, incompatible modules, or unreliable recovery | Hardware refresh with parallel build | Lifecycle evidence, bill of materials, optics/line-card compatibility, staged burn-in, spare plan, cabling map, cutover/rollback | Extending risk because an image remains downloadable |
| Multi-vendor replacement | Source-and-destination package composition | Semantic policy mapping, routing/HA behavior, telemetry equivalence, migration waves, rollback and acceptance | Assuming VLAN, QoS, ACL, LAG, route-policy, or HA semantics match by name |
| Controller or intent-system adoption | Reconcile and migrate source of truth first | Authoritative inventory, import behavior, drift policy, ownership transition, template validation, rollback | Enrolling devices while local automation continues to write |
| Layer 2 redesign or overlay migration | Parallel segment/fabric with bounded migration | Loop-free topology, gateway ownership, MTU, endpoint learning, convergence, failure tests, workload acceptance | Big-bang domain merge or untested dual attachment |
| Fibre Channel fabric refresh | Build and validate a separate fabric, then migrate paths incrementally | HBA/array/switch compatibility, zoning translation, domain/FID plan, ISL design, multipath health, one-path-at-a-time migration | Changing both redundant fabrics or all initiator paths together |
| Unsupported or ownership-ambiguous legacy Brocade Ethernet | Identify current vendor/support owner, then replace or use current-owner guidance | Hardware and software identity, acquisition lineage, support status, export, migration and rollback plan | Applying Fabric OS or historical Brocade commands to an Ethernet product |

## Decision controls

- Record why the chosen path is safer and more supportable than the feasible alternatives.
- Treat support entitlement, feature parity, management ownership, observability, spares, staff competency, and recovery time as decision inputs.
- Validate source and destination simultaneously until acceptance is complete.
- Do not remove the source, old path, temporary route, rollback image, or recovery access until the observation window and accountable acceptance complete.
- Reassess when authoritative lifecycle, security, compatibility, or incident information changes.
