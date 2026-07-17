---
id: NET-HPE-EXAMPLE-001
title: Fictitious HPE Aruba Networking Adoption Example
version: 0.1.0
status: baseline
---

# Fictitious HPE Aruba Networking Adoption Example

This non-production example contains invented names and documentation addresses.

## Scope

The fictitious `LAB-NORTH` site has two AOS-CX access switches, `lab-cx-a` and `lab-cx-b`, managed by an approved Central test group. They form a VSX pair. Management uses the documentation subnet `192.0.2.0/24`; no credential or real configuration is shown.

## Adoption decision

- Select the HPE Aruba Networking package plus Python, testing, security, observability, and release-engineering standards.
- Treat the Central group template as authoritative and reject direct local writes.
- Record exact test hardware, AOS-CX release, VSX roles, controller compatibility, license, lifecycle source, and review date.
- Validate the proposed VLAN/LAG template in an isolated lab, then apply to `lab-cx-a` only as the canary-side step.
- Stop on Central drift, VSX inconsistency, management loss, unexpected STP/LAG state, error growth, or failed synthetic paths.
- Verify controller reconciliation, peer state, actual VLAN/LAG configuration, required and denied paths, telemetry, and a fictitious test workload before the second peer.

## Recovery and evidence

The reviewer requires a configuration checkpoint, tested console access, a reviewed rollback template revision, per-device results, and an observation window. The record explicitly states that production, physical optic failure, and hardware replacement were not tested and therefore no production-readiness claim is made.
