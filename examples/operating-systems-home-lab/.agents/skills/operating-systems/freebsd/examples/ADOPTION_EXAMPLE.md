---
id: OS-FREEBSD-EXAMPLE-001
title: FreeBSD Adoption Example
version: 0.1.0
status: baseline
---

# FreeBSD Adoption Example

## Fictitious boundary

- Host: `freebsd-lab-01.example.invalid`
- Release: current supported Production Release
- Storage: training ZFS pool with a test boot environment
- Jails: one non-production test jail
- Mode: inventory and package/update preview only
- Base update, package change, reboot or rollback: not authorized

The workflow verifies support, kernel/world, ABI/repository trust, advisories, `pkg` audit, jail scope, ZFS/boot-environment space, firewall/access, backup and monitoring. It fails closed on unsupported release, ABI mismatch, low space, absent console/recovery or missing approval and changes no state.
