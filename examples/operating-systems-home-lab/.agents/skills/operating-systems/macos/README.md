---
id: OS-MACOS-README-001
title: macOS Package
version: 0.1.0
status: baseline
---

# macOS Package

## Scope

Current security-updated macOS on compatible Apple hardware, with emphasis on managed organizational deployment, security, privacy, applications, servicing, recovery and retirement.

## Current-release policy

Verify Apple security releases for the exact macOS version and hardware model at execution time. Do not assume a fixed enterprise support window where Apple has not published one.

## Covered areas

Apple Business/School Manager, ADE, MDM/declarative management, software updates, FileVault/escrow, secure/bootstrap tokens, Platform SSO, certificates, PPPC/TCC, system extensions, SIP/startup security/Gatekeeper/XProtect, apps/packages/notarization, privacy, user data, backup, erase and Return to Service.

## Adoption

Inventory ownership/enrollment/hardware/release/security; map policy authorities; complete checklists; validate escrow/tokens without keys; stage representative users/hardware; define rings and user/privacy controls; test recovery/re-enrollment; retain redacted evidence.

## Package contents

- [Agent instructions](AGENTS.md)
- [Operations and automation standard](standards/OPERATIONS_AND_AUTOMATION_STANDARD.md)
- [Adoption checklist](templates/ADOPTION_CHECKLIST.md)
- [Review checklist](templates/REVIEW_CHECKLIST.md)
- [Evidence template](templates/EVIDENCE_RECORD_TEMPLATE.md)
- [Fictitious example](examples/ADOPTION_EXAMPLE.md)
- [Manifest](MANIFEST.md)

## Limitations

This package does not define Apple lifecycle beyond published evidence, authorize employee monitoring or erase, provide MDM-specific payloads, retrieve recovery keys, certify applications/extensions, or guarantee downgrade and rollback.
