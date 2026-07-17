---
id: OS-WINCLI-EXAMPLE-001
title: Windows Client Adoption Example
version: 0.1.0
status: baseline
---

# Windows Client Adoption Example

## Fictitious boundary

- Group: `win11-canary-lab`
- Devices: five non-production virtual test endpoints
- Release: organization-approved supported Windows 11 release
- Management: training MDM tenant
- Mode: inventory, compatibility and assignment preview only
- Feature update, restart, reset or wipe: not authorized

The workflow verifies stable managed-device IDs, release and lifecycle, enrollment, policy authority, BitLocker escrow state without retrieving keys, security controls, applications, drivers, disk space, restart state and user-impact settings.

It stops on Windows 10 without valid coverage, wrong tenant/group, stale or duplicate inventory, missing escrow, safeguard hold, application incompatibility, absent recovery or approval. Output contains target counts, exclusions, intended ring, health gates, stop conditions and checks not run; it changes no device.
