---
id: OS-RHEL-MANIFEST-001
title: RHEL Family Package Manifest
version: 0.1.0
status: baseline
---

# RHEL Family Package Manifest

## Required files

- `AGENTS.md`
- `README.md`
- `MANIFEST.md`
- `standards/OPERATIONS_AND_AUTOMATION_STANDARD.md`
- `templates/ADOPTION_CHECKLIST.md`
- `templates/REVIEW_CHECKLIST.md`
- `templates/EVIDENCE_RECORD_TEMPLATE.md`
- `examples/ADOPTION_EXAMPLE.md`

## Acceptance checks

- RHEL, Rocky, AlmaLinux and CentOS Stream boundaries are explicit.
- Distribution-matched repositories, lifecycle, security, identity, kernel, upgrade, recovery and evidence are covered.
- SELinux is not disabled as a shortcut.
- Stable rules, official source revalidation and fictitious examples are present.
- Repository validation passes.
