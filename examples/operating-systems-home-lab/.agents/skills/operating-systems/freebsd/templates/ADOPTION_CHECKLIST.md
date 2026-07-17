---
id: OS-FREEBSD-ADOPT-001
title: FreeBSD Adoption Checklist
version: 0.1.0
status: baseline
---

# FreeBSD Adoption Checklist

- [ ] Stable host, owner, release/branch/patch, kernel/world and architecture recorded
- [ ] Production/Legacy support, source-review date and upgrade owner recorded
- [ ] Update method, package ABI/repositories/signing, Ports/Poudriere and advisories inventoried
- [ ] Host/jails, rc services, loader and pending-reboot state inventoried
- [ ] Firewall, audit, identity/SSH, network and console access defined
- [ ] ZFS/UFS/GELI, boot environments, capacity, backup and recovery defined
- [ ] Base/package phases, config merges, canaries, reboots and stop conditions defined
- [ ] Supported upgrade sequence and jail compatibility verified
- [ ] Branch/ABI, repo, pkg lock, space, merge, firewall, boot and jail tests exist
- [ ] Actual kernel/world/package/jail/security/workload/backup/monitoring verification defined
- [ ] Checks not run and residual risk will be reported
