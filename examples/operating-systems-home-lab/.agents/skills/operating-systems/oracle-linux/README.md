---
id: OS-OL-README-001
title: Oracle Linux Package
version: 0.1.0
status: baseline
---

# Oracle Linux Package

## Scope

Current Oracle Linux releases with explicit Premier/Extended/Sustaining support boundaries, ULN/yum channels, UEK/RHCK, Ksplice, security, automation, upgrade and recovery.

## Critical boundaries

- Oracle Linux has its own repositories, signing, support and kernel choices; do not treat it as interchangeable with other Enterprise Linux distributions.
- UEK and RHCK can have different hardware, driver, application and support compatibility.
- Ksplice does not automatically eliminate every reboot or prove complete patch compliance.
- Sustaining Support does not imply the same new-fix coverage as Premier or Extended Support.

## Adoption

Inventory release/kernel/channels/support/Ksplice and workload certification, complete checklists, stage representative systems, preserve access/recovery, define batches and stop conditions, and retain evidence.

## Package contents

- [Agent instructions](AGENTS.md)
- [Operations and automation standard](standards/OPERATIONS_AND_AUTOMATION_STANDARD.md)
- [Adoption checklist](templates/ADOPTION_CHECKLIST.md)
- [Review checklist](templates/REVIEW_CHECKLIST.md)
- [Evidence template](templates/EVIDENCE_RECORD_TEMPLATE.md)
- [Fictitious example](examples/ADOPTION_EXAMPLE.md)
- [Manifest](MANIFEST.md)

## Limitations

This package does not establish Oracle support entitlement, certify Oracle applications or databases, approve a kernel family, guarantee Ksplice applicability, or authorize live changes.
