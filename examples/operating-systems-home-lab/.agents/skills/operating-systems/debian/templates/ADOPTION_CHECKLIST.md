---
id: OS-DEBIAN-ADOPT-001
title: Debian Adoption Checklist
version: 0.1.0
status: baseline
---

# Debian Adoption Checklist

- [ ] Stable host, owner, release/codename/suite, kernel and architecture recorded
- [ ] Lifecycle/security/LTS/ELTS coverage, source-review date and migration owner recorded
- [ ] APT sources, suites/components, signing, pinning, holds and third-party repositories inventoried
- [ ] Package, firmware, boot, service and pending-restart state inventoried
- [ ] Security, identity/SSH, alternate access, network, storage, encryption, backup and monitoring defined
- [ ] Transaction simulation, canaries, batches, reboots, stop conditions and recovery defined
- [ ] Release notes and sequential path reviewed for upgrades
- [ ] Mixed-source, signature, dpkg lock, essential-package, conffile, space, access and boot tests exist
- [ ] Actual package/kernel/security/service/workload/backup/monitoring verification defined
- [ ] Checks not run and residual risk will be reported
