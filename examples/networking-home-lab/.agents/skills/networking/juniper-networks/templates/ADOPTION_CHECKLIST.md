---
id: NET-JUNIPER-ADOPT-001
title: Juniper Networks Adoption Checklist
version: 0.1.0
status: baseline
---

# Juniper Networks Adoption Checklist

- [ ] Stable device, site, role, owner, model, serial/stable ID, and environment recorded
- [ ] Junos OS or Junos OS Evolved family, release, packages, boot/recovery state verified
- [ ] Mist/Apstra/controller, site/blueprint, source of truth, local drift, and conflict policy mapped
- [ ] Logical systems, routing instances, configuration groups/inheritance/scripts, locks, and candidate state inventoried
- [ ] VC/RE/MC-LAG/EVPN/cluster, interfaces, VLAN/VRF, STP/LAG, routing/policy, filters/policers, and dependencies mapped
- [ ] AAA, certificates, management instance, console/OOB, logging, telemetry, and break glass defined
- [ ] Hardware/Junos/controller/API/license lifecycle, support, security, and source-review date recorded
- [ ] Commit-confirmed, rollback/rescue, alternate boot, restore, spare, and escalation tested or bounded
- [ ] Effective-diff, commit-check, inherited-state, conflict, HA, access-loss, rollback, and rerun tests exist
- [ ] Canaries, batches, convergence/confirmation gates, stop conditions, window, and acceptance defined
- [ ] Actual owner/committed/effective, management, control/data-plane, workload, and risk reporting defined
