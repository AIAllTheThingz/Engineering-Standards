---
id: NET-JUNIPER-EXAMPLE-001
title: Fictitious Juniper Networks Adoption Example
version: 0.1.0
status: baseline
---

# Fictitious Juniper Networks Adoption Example

This non-production example contains invented names and documentation addresses.

## Scope

The fictitious `LAB-EAST` topology has two Junos OS test switches, `lab-junos-a` and `lab-junos-b`, represented in an isolated Apstra test blueprint. Management uses `203.0.113.0/24`; no credentials or real configuration are shown.

## Adoption decision

- Select the Juniper package plus Python, testing, security, observability, and release-engineering standards.
- Treat the test blueprint as authoritative and reject local unmanaged writes.
- Record exact test models, Junos releases, logical contexts, EVPN multihoming roles, controller compatibility, lifecycle source, and review date.
- Render and inspect the complete inherited candidate diff, run commit validation, and use a short reviewed confirmed-commit interval on the canary device.
- Stop before confirmation on controller drift, peer inconsistency, management loss, adjacency or route change, error growth, or failed required/denied path tests.
- Confirm only after owner/committed/effective reconciliation, operational state, telemetry, and a fictitious service check pass.

## Recovery and evidence

The reviewer requires tested console access, automatic confirmed-commit rollback evidence, a rescue/rollback limitation statement, per-device results, and an observation window. Production, physical optic failure, and package rollback were not tested; production readiness is not claimed.
