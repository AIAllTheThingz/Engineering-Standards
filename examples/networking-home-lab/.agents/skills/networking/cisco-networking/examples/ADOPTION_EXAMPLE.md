---
id: NET-CISCO-EXAMPLE-001
title: Fictitious Cisco Networking Adoption Example
version: 0.1.0
status: baseline
---

# Fictitious Cisco Networking Adoption Example

This non-production example contains invented names and documentation addresses.

## Scope

The fictitious `LAB-WEST` site has two IOS XE test switches, `lab-cat-a` and `lab-cat-b`, in an isolated StackWise test system managed by a test Catalyst Center site. Management uses `198.51.100.0/24`; no credentials or real configuration are shown.

## Adoption decision

- Select the Cisco package plus Python, testing, security, observability, and release-engineering standards.
- Treat the test controller template as authoritative and reject local configuration writes.
- Record exact test PID, IOS XE release and install mode, controller compatibility, member roles, boot variables, license, lifecycle source, and review date.
- Validate a model-driven access-policy diff in an isolated lab and apply only to a dedicated test interface as the canary.
- Stop on controller drift, stack health change, management loss, unexpected STP/EtherChannel/routing state, error growth, or failed synthetic paths.
- Verify controller/startup/running reconciliation, stack state, actual policy, required and denied paths, telemetry, and a fictitious test service.

## Recovery and evidence

The reviewer requires a configuration archive, tested console path, reviewed rollback job, per-member and per-interface results, and an observation window. The record states that production, a supervisor failure, and a full software rollback were not tested, so production readiness is not claimed.
