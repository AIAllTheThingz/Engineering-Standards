---
id: OS-WINSRV-ADOPT-001
title: Windows Server Adoption Checklist
version: 0.1.0
status: baseline
---

# Windows Server Adoption Checklist

## Inventory and lifecycle

- [ ] Server identity, environment, owner, domain, edition, release, build and installation option recorded
- [ ] Roles, features, cluster membership, applications and dependencies inventoried
- [ ] Microsoft lifecycle source, phase and review date recorded
- [ ] Migration owner and target date recorded for legacy or extended-support systems
- [ ] Update, policy and management authorities identified

## Safety and security

- [ ] Acting identity, least privilege and approvals defined
- [ ] Console or alternate access tested
- [ ] Role-aware backup and representative recovery evidence available
- [ ] Defender, firewall, Secure Boot, BitLocker, audit and baseline states recorded
- [ ] Canaries, batches, restart domains, success gates and stop conditions defined
- [ ] Rollback, restore, rebuild and manual handoff documented

## Engineering and completion

- [ ] Supported interfaces and PowerShell requirements documented
- [ ] Discovery and preview are non-mutating
- [ ] Update source, artifacts, signatures, component health and free space validated
- [ ] Wrong-target, denied, partial-update, failed-restart, role, cluster and recovery tests exist
- [ ] Structured redacted logs and per-target evidence retained
- [ ] Actual OS, role, workload, access, security, backup and monitoring verification defined
- [ ] Checks not run and residual risk will be reported
