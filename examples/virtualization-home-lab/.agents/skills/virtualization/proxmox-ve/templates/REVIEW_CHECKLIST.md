---
id: VIRT-PVE-REVIEW-001
title: Proxmox VE Review Checklist
version: 0.1.0
status: baseline
---

# Proxmox VE Review Checklist

## Scope and authority

- [ ] Correct manager, host, environment, and stable object IDs
- [ ] Correct product, edition, version, lifecycle, and supported interface
- [ ] Explicit authorization for the exact change
- [ ] No ambiguous display-name-only selection
- [ ] No unrelated mutation

## Risk

- [ ] Power and availability impact
- [ ] Privilege and management-plane exposure
- [ ] Network and administrative access
- [ ] Storage, disks, snapshots, checkpoints, and data integrity
- [ ] Capacity, admission control, and failure domains
- [ ] Backup, restore, rollback, failback, and rebuild
- [ ] Compatibility, licensing, entitlement, and support
- [ ] Migration and decommission hold where applicable

## Automation

- [ ] Read-only discovery and validation
- [ ] Plan, dry-run, or WhatIf evidence
- [ ] Explicit execution enablement and confirmation
- [ ] Stable identifiers and parent-scope checks
- [ ] Bounded concurrency, polling, retries, and timeouts
- [ ] Partial failure and safe rerun
- [ ] Structured redacted logs and reports
- [ ] Task/job correlation
- [ ] Tests cover denied and failure paths

## Completion

- [ ] Actual manager and workload state verified
- [ ] Network and storage paths verified
- [ ] Backup and monitoring verified
- [ ] Owner acceptance recorded
- [ ] Checks not run disclosed
- [ ] Residual risk and follow-up owned
- [ ] No claim exceeds evidence
