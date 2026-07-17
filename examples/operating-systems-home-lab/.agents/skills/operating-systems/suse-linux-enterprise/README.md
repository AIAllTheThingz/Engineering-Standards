---
id: OS-SUSE-README-001
title: SUSE Linux Enterprise Package
version: 0.1.0
status: baseline
---

# SUSE Linux Enterprise Package

## Scope

Current supported SUSE Linux Enterprise Server and Desktop releases, service packs, modules, extensions and explicitly approved LTSS operation.

## Covered areas

Lifecycle/registration; SCC/RMT/SUSE management; Zypper/RPM; products/modules/extensions/patterns; service-pack migration; kernel/boot; systemd; AppArmor/firewall/audit; identity/SSH; network; Btrfs/Snapper/LVM/encryption; backup, automation and recovery.

## Adoption

Inventory exact products, service packs, modules, registration and repositories; complete checklists; validate solver and snapshot space; stage representative roles; preserve access/recovery; define batches and stop conditions; retain evidence.

## Package contents

- [Agent instructions](AGENTS.md)
- [Operations and automation standard](standards/OPERATIONS_AND_AUTOMATION_STANDARD.md)
- [Adoption checklist](templates/ADOPTION_CHECKLIST.md)
- [Review checklist](templates/REVIEW_CHECKLIST.md)
- [Evidence template](templates/EVIDENCE_RECORD_TEMPLATE.md)
- [Fictitious example](examples/ADOPTION_EXAMPLE.md)
- [Manifest](MANIFEST.md)

## Limitations

This package does not prove subscription/LTSS eligibility, certify an extension or repository, provide SAP/HA application procedures, make snapshots independent backups, or guarantee service-pack rollback.
