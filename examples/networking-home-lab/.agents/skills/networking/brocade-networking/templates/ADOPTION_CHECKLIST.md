---
id: NET-BROCADE-ADOPT-001
title: Brocade Networking Adoption Checklist
version: 0.1.0
status: baseline
---

# Brocade Networking Adoption Checklist

- [ ] Hardware/software classified as current FOS or legacy Ethernet/IP with current vendor owner verified
- [ ] Stable model, serial/switch WWN, site, role, owner, FOS release, fabric/FID/domain, and environment recorded
- [ ] SANnav/automation/source-of-truth ownership, transaction policy, local drift, and conflicts mapped
- [ ] Fabric A/B, principals, domains, switches/directors/blades, ISLs/trunks, ports/optics, and redundancy inventoried
- [ ] Zoning database/effective configuration, aliases, redacted WWPN ownership, logins, and least-connectivity policy mapped
- [ ] Host/array/HBA multipaths, endpoint owners, maintenance observers, and acceptance tests defined
- [ ] AAA, certificates, management, serial/console, logging, MAPS, telemetry, backup, and support-data handling defined
- [ ] Hardware/FOS/SANnav/HBA/array/license lifecycle, interoperability, security, and review date recorded
- [ ] Firmware path, configuration restore, fallback limits, spares, rollback, and escalation tested or bounded
- [ ] Wrong-fabric/FID, zoning, transaction, domain/ISL, path-loss, partial rollout, rollback, and rerun tests exist
- [ ] One-fabric sequence, convergence gates, stop conditions, window, actual-state checks, and residual-risk reporting defined
