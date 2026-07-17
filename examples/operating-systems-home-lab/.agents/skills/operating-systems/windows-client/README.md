---
id: OS-WINCLI-README-001
title: Windows Client Package
version: 0.1.0
status: baseline
---

# Windows Client Package

## Scope

Standards for managed Windows 10 and Windows 11 endpoints, including deployment, enrollment, configuration, applications, security, servicing, recovery, migration, wipe and retirement.

## Lifecycle posture

Windows 11 on a currently serviced feature release is the normal target. General Windows 10 support ended on 2025-10-14. Keep Windows 10 only when an exact LTSC lifecycle or active ESU entitlement applies, or under a time-bounded approved exception with migration ownership.

## Management boundary

Use this package with Intune or another MDM, Configuration Manager, Group Policy, Windows Autopilot, endpoint-security tooling, update rings and supported Windows APIs. Identify co-management and policy precedence explicitly.

## Core controls

- stable device and management identity
- feature-release and edition-specific lifecycle verification
- representative hardware/application/driver testing
- ring-based update and policy deployment
- BitLocker with authorized recovery-key escrow
- Secure Boot, TPM, Defender, firewall and baseline preservation
- Windows LAPS or approved privilege management
- user-impact, accessibility, privacy and data-protection handling
- distinct authorization for reset, wipe, retire and reimage
- actual device-side verification

## Adoption

Inventory devices and policy authorities, classify Windows 10 exceptions, define approved Windows 11 releases, complete the checklists, test representative models and personas, define rollout rings and stop conditions, verify recovery and data handling, and retain redacted evidence.

## Package contents

- [Agent instructions](AGENTS.md)
- [Operations and automation standard](standards/OPERATIONS_AND_AUTOMATION_STANDARD.md)
- [Adoption checklist](templates/ADOPTION_CHECKLIST.md)
- [Review checklist](templates/REVIEW_CHECKLIST.md)
- [Evidence template](templates/EVIDENCE_RECORD_TEMPLATE.md)
- [Fictitious example](examples/ADOPTION_EXAMPLE.md)
- [Manifest](MANIFEST.md)

## Limitations

This package does not provide tenant-specific Intune policy, certify applications or hardware, authorize collection of employee data, decide legal hold, supply recovery keys, or guarantee update rollback or user experience.
