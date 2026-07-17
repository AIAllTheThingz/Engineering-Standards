---
id: OS-WINCLI-AGENT-001
title: Windows Client Agent Standard
version: 0.1.0
status: baseline
---

# Windows Client Agent Standard

## Purpose

Define mandatory behavior for managed Windows 10 and Windows 11 endpoint provisioning, configuration, security, servicing, automation, recovery, migration, wipe, and retirement.

## Authority and lifecycle

Identify the exact device and its authoritative management sources: Microsoft Intune or another MDM, Configuration Manager, Group Policy, Windows Autopilot, endpoint-security management, update policy, local administration, or co-management.

General Windows 10 support ended on 2025-10-14. Treat Windows 10 as exception-only: an eligible LTSC release, active ESU coverage, or an explicitly approved isolated case with compensating controls and a migration date. Normal new deployment targets a currently serviced Windows 11 feature release and eligible hardware.

## Mandatory behavior

- Record stable device ID, serial or management ID in protected evidence, owner/custodian class, environment, edition, feature release, build, architecture, hardware eligibility, enrollment, join state, policy authorities, update ring and lifecycle.
- Resolve co-management and policy precedence before changing settings.
- Discover pending restart, update holds, BitLocker, recovery-key escrow status, Secure Boot, TPM, Defender, firewall, local admin, Windows LAPS, certificates, apps, drivers, user data, backup/sync and management health.
- Require explicit authorization for enrollment, reset, wipe, reimage, feature update, restart, local-admin, BitLocker, recovery-key, Defender, firewall, certificate, VPN, identity, application, driver, policy or remote-support changes.
- Preserve user data according to policy and distinguish retire, wipe, fresh start, reset and Autopilot reset semantics.
- Never expose BitLocker recovery keys, user content, tokens, certificates or device identifiers in logs.
- Stage applications, drivers, security policy and feature updates through representative hardware and deployment rings.
- Respect user-impact, accessibility, restart, deadline, legal hold and privacy requirements.
- Verify actual device compliance, encryption, security, enrollment, applications, access, backup/sync and user/workload health.

## Product-specific rules

### OS-WINCLI-TARGET-001

**Requirement:** Resolve stable device identity, user/custodian class, join and enrollment state, management authority, edition, release and update ring before mutation.

**Expected evidence:** Redacted management/device identifiers, policy sources, OS facts, ring and acting identity.

### OS-WINCLI-W10-002

**Requirement:** Permit Windows 10 operation only with verified LTSC lifecycle, active ESU coverage, or a time-bounded approved exception and owned migration plan.

**Expected evidence:** Edition/release, coverage or entitlement, lifecycle source/date, compensating controls and migration milestone.

### OS-WINCLI-W11-003

**Requirement:** Verify Windows 11 feature-release servicing, edition-specific end date, hardware eligibility and application/driver/security-tool compatibility before deployment or upgrade.

**Expected evidence:** Release-health review, hardware and compatibility results, ring plan and rollback/recovery decision.

### OS-WINCLI-ENC-004

**Requirement:** Verify BitLocker protection and authorized recovery-key escrow before encryption, firmware, TPM, feature-update, reset or wipe operations.

**Expected evidence:** Protection and escrow status without recording the key, suspension rationale and post-change protection state.

### OS-WINCLI-PRIV-005

**Requirement:** Control local administration through approved privilege management and Windows LAPS or equivalent; do not create shared or persistent unmanaged admin credentials.

**Expected evidence:** Policy assignment, account state, credential rotation status and exception record where applicable.

### OS-WINCLI-WIPE-006

**Requirement:** Distinguish reset, wipe, retire, fresh start and reimage effects; verify data retention, legal hold, Activation Lock-equivalent ownership constraints, enrollment and recovery before destructive action.

**Expected evidence:** Authorized action type, data disposition, custodian/owner approval, recovery and completion record.

### OS-WINCLI-RING-007

**Requirement:** Deploy feature, quality, driver, application and security-policy changes through bounded rings with user-impact, accessibility, health, pause and rollback gates.

**Expected evidence:** Ring membership, canary results, deployment metrics, pause/stop decisions and final compliance.

## Automation and completion

Prefer supported MDM/Graph, Configuration Manager, PowerShell, CSP, Group Policy and Windows management interfaces. Apply the PowerShell package where scripts are used. Automation must handle offline devices, stale inventory, co-management, user deferral, restart, partial assignment, supersedence and device replacement.

Completion requires actual feature/build and policy state, restart completion, MDM check-in, encryption, endpoint security, application/driver health, user data, network/VPN, backup/sync, monitoring, owner acceptance, checks not run and residual risk.

## Authoritative starting points

- [Windows client documentation](https://learn.microsoft.com/en-us/windows/)
- [Windows 10 Home and Pro lifecycle](https://learn.microsoft.com/en-us/lifecycle/products/windows-10-home-and-pro)
- [Windows 11 release information](https://learn.microsoft.com/en-us/windows/release-health/windows11-release-information)
- [Windows deployment documentation](https://learn.microsoft.com/en-us/windows/deployment/)
