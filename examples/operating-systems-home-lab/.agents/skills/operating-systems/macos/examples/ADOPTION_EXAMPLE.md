---
id: OS-MACOS-EXAMPLE-001
title: macOS Adoption Example
version: 0.1.0
status: baseline
---

# macOS Adoption Example

## Fictitious boundary

- Group: `mac-canary-lab`
- Devices: non-production virtual/test Mac computers
- Release: current Apple security-updated macOS
- Management: training MDM tenant
- Mode: inventory and assignment preview only
- Update, restart, lock or erase: not authorized

The workflow verifies redacted managed identity, hardware/release eligibility, MDM state, FileVault escrow without keys, token status, platform security, apps/extensions, privacy payloads, backup and user-impact settings. It fails closed on wrong tenant, unsupported hardware, missing escrow/token, untrusted artifact, privacy overreach, absent recovery or approval and changes no device.
