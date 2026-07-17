---
id: NET-CISCO-REVIEW-001
title: Cisco Networking Review Checklist
version: 0.1.0
status: baseline
---

# Cisco Networking Review Checklist

- [ ] Exact targets, PID, OS family/release/mode, controller/site/context, and acting identity are unambiguous
- [ ] Authoritative configuration owner is used and controller/local drift is reconciled
- [ ] Semantic diff is bounded, deterministic, validated, and free of unrelated cleanup
- [ ] StackWise/VSS/vPC/chassis/route-processor and redundant-path sequence has health and stop gates
- [ ] AAA, certificate, management, routing, ACL, VLAN/VRF, STP, EtherChannel, QoS/CoPP, and software impacts are reviewed
- [ ] Platform, ROMMON, image/packages, feature, module, optic, controller, API/model, license, and path compatibility is current
- [ ] Console/OOB, archive/checkpoint, boot fallback, restore, rollback triggers, and owners are credible
- [ ] Lab/canary and negative tests cover conflict, lock, invalid state, access loss, partial failure, and rerun
- [ ] Verification covers owner/startup/running reconciliation, HA, topology, routing, policy, telemetry, counters, and services
- [ ] Authorization, window, observers, checks not run, residual risk, and required reviewers are recorded
