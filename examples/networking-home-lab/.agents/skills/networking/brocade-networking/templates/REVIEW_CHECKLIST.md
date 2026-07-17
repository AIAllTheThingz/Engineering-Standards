---
id: NET-BROCADE-REVIEW-001
title: Brocade Networking Review Checklist
version: 0.1.0
status: baseline
---

# Brocade Networking Review Checklist

- [ ] Exact model, FOS/current owner, fabric/WWN/FID/domain/role, manager, and acting identity are unambiguous
- [ ] Legacy Ethernet/IP devices are quarantined from FOS guidance until current ownership is verified
- [ ] Configuration owner and transaction state are known; diff is bounded and has no unrelated changes
- [ ] WWPN ownership, single-initiator/least-connectivity policy, aliases, zones, and effective configuration are reviewed
- [ ] Principal/domain/ISL/trunk, director, A/B fabric, and endpoint-path sequence preserves service
- [ ] FOS/SANnav, switch/blade, optic, license, HBA, array, feature, firmware-hop, and lifecycle compatibility is current
- [ ] Management/serial access, backup, support-data handling, fallback, restore, rollback triggers, spares, and owners are credible
- [ ] Lab/canary tests cover wrong scope, bad zone, concurrency, domain/ISL, access/path loss, partial failure, and rerun
- [ ] Verification covers effective zoning, logins, multipaths, fabric/ISL/MAPS health, counters, telemetry, and workloads
- [ ] Authorization, storage/OS observers, window, checks not run, residual risk, and required reviewers are recorded
