---
id: OS-RHEL-README-001
title: RHEL Family Package
version: 0.1.0
status: baseline
---

# RHEL Family Package

## Scope

Standards for current supported Red Hat Enterprise Linux, Rocky Linux, AlmaLinux and explicitly approved CentOS Stream systems.

## Critical boundary

The family shares technologies but not repositories, signing keys, support contracts, minor-release policy or upgrade guarantees. Detect and manage the actual distribution. Oracle Linux has its own package.

## Covered areas

- lifecycle, subscriptions/support and repositories
- RPM, DNF, advisory and module-stream changes
- kernel, kABI, drivers, boot, Secure Boot and restart
- systemd services/timers and journald
- SELinux, crypto policy, firewalld and audit
- authselect, PAM, SSSD, SSH, sudo and certificates
- NetworkManager, DNS, time, storage, LVM and encryption
- Ansible/shell/Python automation, backup, recovery and upgrades

## Adoption

Inventory actual distributions and repositories, record lifecycle and support, complete the checklists, preserve alternate access, validate canaries and recovery, use distribution-supported tooling, and retain evidence.

## Package contents

- [Agent instructions](AGENTS.md)
- [Operations and automation standard](standards/OPERATIONS_AND_AUTOMATION_STANDARD.md)
- [Adoption checklist](templates/ADOPTION_CHECKLIST.md)
- [Review checklist](templates/REVIEW_CHECKLIST.md)
- [Evidence template](templates/EVIDENCE_RECORD_TEMPLATE.md)
- [Fictitious example](examples/ADOPTION_EXAMPLE.md)
- [Manifest](MANIFEST.md)

## Limitations

This package does not transfer RHEL support to derivatives, certify a repository or package, provide organization-specific SELinux/firewall/crypto baselines, guarantee in-place major upgrades, or authorize live changes.
