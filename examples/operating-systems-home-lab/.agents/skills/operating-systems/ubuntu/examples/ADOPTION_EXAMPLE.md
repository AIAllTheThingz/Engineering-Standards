---
id: OS-UBUNTU-EXAMPLE-001
title: Ubuntu Adoption Example
version: 0.1.0
status: baseline
---

# Ubuntu Adoption Example

## Fictitious boundary

- System: `ubuntu-lab-01.example.invalid`
- Edition: current supported Ubuntu Server LTS
- Role: non-production API canary
- Mode: discovery and APT simulation only
- Package change or reboot: not authorized

The workflow verifies OS/lifecycle facts, APT suites/components/signing, coverage, locks, holds, kernel and space, cloud-init authority, AppArmor, access, Netplan, services, backup and monitoring. It fails closed on mixed sources, untrusted keys, uncovered required packages, access/recovery risk or missing approval. It reports the simulated transaction and changes no state.
