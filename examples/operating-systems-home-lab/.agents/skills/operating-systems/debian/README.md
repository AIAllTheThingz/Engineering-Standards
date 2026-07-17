---
id: OS-DEBIAN-README-001
title: Debian Package
version: 0.1.0
status: baseline
---

# Debian Package

## Scope

Current Debian stable plus explicitly approved supported oldstable, LTS or ELTS operation. Testing and unstable are development streams and require deliberate non-production or exceptional use.

## Covered areas

Lifecycle and package coverage; APT/dpkg sources, signing, pinning and transactions; kernel/firmware/boot; systemd; identity/SSH; AppArmor/firewall/audit; network/storage/encryption; backup/recovery; automation and release upgrades.

## Adoption

Inventory exact release/codename/suite and sources, record coverage, complete checklists, preserve alternate access, stage transactions/upgrades, define canaries and recovery, and retain evidence.

## Package contents

- [Agent instructions](AGENTS.md)
- [Operations and automation standard](standards/OPERATIONS_AND_AUTOMATION_STANDARD.md)
- [Adoption checklist](templates/ADOPTION_CHECKLIST.md)
- [Review checklist](templates/REVIEW_CHECKLIST.md)
- [Evidence template](templates/EVIDENCE_RECORD_TEMPLATE.md)
- [Fictitious example](examples/ADOPTION_EXAMPLE.md)
- [Manifest](MANIFEST.md)

## Limitations

This package does not prove LTS/ELTS coverage for a package, approve testing/unstable for production, certify third-party repositories, provide site-specific security policy, or guarantee major-upgrade rollback.
