---
id: NET-HPE-REVIEW-001
title: HPE Aruba Networking Review Checklist
version: 0.1.0
status: baseline
---

# HPE Aruba Networking Review Checklist

- [ ] Exact targets, AOS family/release, Central group/template, virtual context, and acting identity are unambiguous
- [ ] Authoritative configuration owner is used and controller/local drift is reconciled
- [ ] Diff is bounded, deterministic, validated, and free of unrelated cleanup
- [ ] VSX/VSF/stack and redundant-path sequence preserves service and has stop gates
- [ ] Management, AAA, certificate, routing, ACL, VLAN/VRF, STP, LAG, and firmware impacts are reviewed
- [ ] Exact platform, image, feature, module, optic, controller, license, and upgrade compatibility is current
- [ ] Console/OOB, checkpoint, boot fallback, configuration restore, rollback triggers, and owners are credible
- [ ] Lab/canary and negative tests cover conflict, lock, invalid state, loss of access, partial failure, and rerun
- [ ] Verification covers controller reconciliation, actual configuration, peers, topology, policy, telemetry, counters, and services
- [ ] Authorization, maintenance window, observers, checks not run, residual risk, and required reviewers are recorded
