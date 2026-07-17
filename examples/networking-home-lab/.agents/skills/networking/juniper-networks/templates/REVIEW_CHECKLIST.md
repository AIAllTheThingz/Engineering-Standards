---
id: NET-JUNIPER-REVIEW-001
title: Juniper Networks Review Checklist
version: 0.1.0
status: baseline
---

# Juniper Networks Review Checklist

- [ ] Exact targets, model, Junos family/release, controller/blueprint/context, and acting identity are unambiguous
- [ ] Authoritative owner is used; controller/local/ephemeral state and pending candidates are reconciled
- [ ] Full inherited effective diff is bounded, deterministic, validated, and free of unrelated changes
- [ ] Commit check, confirmed interval, confirmation owner, stop/rollback triggers, and evidence are credible
- [ ] VC/RE/MC-LAG/EVPN/cluster and redundant-path sequence preserves health and forwarding
- [ ] AAA, certificate, management, routing/policy, filter, VLAN/VRF, STP/LAG, and software impacts are reviewed
- [ ] Platform, packages, FPC/PIC, optic, controller, API/model, license, and upgrade compatibility is current
- [ ] Lab/canary tests cover conflict, inheritance, invalid candidate, timeout, access loss, partial failure, and rerun
- [ ] Verification covers owner/committed/effective state, HA, topology, routing/policy, telemetry, counters, and services before confirmation
- [ ] Authorization, window, observers, checks not run, residual risk, and required reviewers are recorded
