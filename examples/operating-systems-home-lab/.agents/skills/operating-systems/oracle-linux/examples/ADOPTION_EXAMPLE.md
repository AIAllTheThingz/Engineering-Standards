---
id: OS-OL-EXAMPLE-001
title: Oracle Linux Adoption Example
version: 0.1.0
status: baseline
---

# Oracle Linux Adoption Example

## Fictitious boundary

- Host: `ol-lab-01.example.invalid`
- Release: current supported Oracle Linux
- Kernel: supported UEK release
- Role: non-production middleware canary
- Mode: inventory and DNF/Ksplice applicability report only
- Patch, live update or reboot: not authorized

The workflow verifies lifecycle/support, channels/signing, UEK and Ksplice state, DNF transaction, boot fallback, SELinux, access, backup and workload compatibility. It fails closed on mixed repositories, unsupported kernel, absent certification/recovery or approval and changes no state.
