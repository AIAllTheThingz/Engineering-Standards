---
id: OS-DEBIAN-EXAMPLE-001
title: Debian Adoption Example
version: 0.1.0
status: baseline
---

# Debian Adoption Example

## Fictitious boundary

- Host: `debian-lab-01.example.invalid`
- Release: current Debian stable, pinned by codename
- Role: non-production utility server
- Mode: inventory and APT simulation only
- Package change or reboot: not authorized

The workflow verifies stable identity, sources/signing/pinning, security coverage, locks, holds, essential packages, kernel and space, security, access, services, backup and monitoring. It fails closed on testing/unstable, mixed sources, untrusted signing, absent coverage/recovery or missing approval and changes no state.
