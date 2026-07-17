---
id: OS-FREEBSD-README-001
title: FreeBSD Package
version: 0.1.0
status: baseline
---

# FreeBSD Package

## Scope

Current supported FreeBSD Production Releases and explicitly approved supported Legacy Releases, covering base/kernel/world, packages/Ports, jails, ZFS, security, automation, upgrade and recovery.

## Critical boundaries

- Base system and third-party packages have separate update and advisory paths.
- Kernel and world must remain compatible.
- Package repositories must match ABI and policy.
- Host and jail scopes must be inventoried separately.
- Boot environments and ZFS snapshots are not independent backups.

## Adoption

Inventory release/branch/kernel/world/ABI/repos/jails/storage; complete checklists; preserve console/boot/recovery; stage representative systems; define update phases, reboots and gates; retain evidence.

## Package contents

- [Agent instructions](AGENTS.md)
- [Operations and automation standard](standards/OPERATIONS_AND_AUTOMATION_STANDARD.md)
- [Adoption checklist](templates/ADOPTION_CHECKLIST.md)
- [Review checklist](templates/REVIEW_CHECKLIST.md)
- [Evidence template](templates/EVIDENCE_RECORD_TEMPLATE.md)
- [Fictitious example](examples/ADOPTION_EXAMPLE.md)
- [Manifest](MANIFEST.md)

## Limitations

This package does not certify hardware or an appliance, approve a custom kernel/Ports tree/package repository, select an organization firewall, make ZFS snapshots backups, or guarantee binary/source upgrade rollback.
