---
id: OS-MACOS-AGENT-001
title: macOS Agent Standard
version: 0.1.0
status: baseline
---

# macOS Agent Standard

## Purpose

Define mandatory behavior for current security-updated macOS systems on compatible Apple hardware, especially organization-managed Mac fleets.

## Authority and lifecycle

Identify the exact Mac and authoritative boundaries: Apple Business Manager or Apple School Manager, Automated Device Enrollment, MDM or declarative device management, identity platform, endpoint security, application distribution, software-update policy, local administration and backup.

Apple security-update publication and hardware compatibility are the current-release evidence. Do not rely on an assumed “N minus” lifecycle rule without verifying that the exact release and model receive applicable security updates.

## Mandatory behavior

- Record protected stable device/management identity, ownership and enrollment class, hardware model/chip, architecture, macOS release/build, security-update availability, MDM state, bootstrap/secure token state, FileVault/escrow state, Activation Lock ownership, policy authorities and acting identity.
- Use MDM/declarative management and supported Apple interfaces rather than direct database edits or unmanaged preference-file replacement.
- Discover pending updates, deferrals, restart, FileVault, escrow without reading keys, Secure Boot/startup security, system/data volumes, endpoint security, firewall, Gatekeeper, XProtect, PPPC/TCC, system extensions, certificates, Platform SSO, apps, profiles, backups and user data.
- Require authorization for enrollment, erase, lock, Activation Lock, FileVault/recovery, token, account, identity, profile, PPPC, system extension, certificate, network/VPN, firewall, app, update, restart, bootstrap, recovery or destructive action.
- Minimize user/device data and respect privacy, labor, accessibility, notification, legal-hold and data-retention requirements.
- Preserve bootstrap/secure token ownership, authorized FileVault escrow, recovery access and enrollment before update, migration, erase or re-provision.
- Do not disable System Integrity Protection, Secure Boot, Gatekeeper, XProtect, FileVault, endpoint security, PPPC/TCC or code-signing/notarization merely for compatibility.
- Stage updates, profiles, extensions, certificates and applications across representative Apple silicon/Intel models where still supported, user personas and workflows.
- Verify actual device-side update, profile, security, encryption, identity, app, network, backup and user/workload state.

## Product-specific rules

### OS-MACOS-TARGET-001

**Requirement:** Resolve exact Mac, hardware/chip, ownership/enrollment, MDM authority, release/build, update eligibility and acting identity before mutation.

**Expected evidence:** Redacted device/management identity, hardware and OS facts, enrollment/policy source and identity class.

### OS-MACOS-CURRENT-002

**Requirement:** Verify the exact macOS release and hardware model receive applicable Apple security updates and remain compatible with required management, security and applications.

**Expected evidence:** Apple security-release review/date, hardware compatibility and tool/application test results.

### OS-MACOS-FV-003

**Requirement:** Verify FileVault protection, authorized recovery-key escrow and secure/bootstrap token ownership before update, account, encryption, migration, erase or recovery work.

**Expected evidence:** Protection/escrow/token status without keys, owner, recovery test and post-change state.

### OS-MACOS-MDM-004

**Requirement:** Resolve MDM and declarative policy ownership and avoid local changes that fight or bypass managed configuration.

**Expected evidence:** Enrollment, declarations/profiles, command/status correlation, precedence and actual device state.

### OS-MACOS-PRIVACY-005

**Requirement:** Treat PPPC/TCC, user data, inventory, remote support, screen capture and telemetry as privacy-sensitive and collect or grant only authorized minimum scope.

**Expected evidence:** Purpose, approved payload/entitlement, data minimization, retention and user-impact review.

### OS-MACOS-EXT-006

**Requirement:** Validate developer/team identifiers, signing, notarization, entitlements, OS/hardware compatibility and removal path before deploying apps, packages or system extensions.

**Expected evidence:** Provenance, signature/notarization verification, representative tests and rollback/removal.

### OS-MACOS-ERASE-007

**Requirement:** Verify ownership, legal hold, user-data disposition, backup, Activation Lock, enrollment and recovery before erase, return-to-service or retirement.

**Expected evidence:** Authorized action, custody/data decision, backup or approved loss, lock/enrollment state and completion.

## Automation and completion

Prefer MDM/declarative management, Apple Business Manager, supported configuration profiles and documented Apple tools. Shell scripts must follow Bash guidance and avoid parsing unstable UI or undocumented databases. Bound commands, device rings, retries and restarts; handle offline devices and asynchronous MDM state.

Completion requires actual macOS build/security update, restart, enrollment, profiles/declarations, FileVault/escrow/token state, platform/endpoint security, identity, apps/extensions, network, backup and user/workload evidence.

## Authoritative starting points

- [Apple Platform Deployment](https://support.apple.com/guide/deployment/welcome/web)
- [Apple Platform Security](https://support.apple.com/guide/security/welcome/web)
- [Apple security releases](https://support.apple.com/en-us/100100)
