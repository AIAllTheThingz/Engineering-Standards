---
id: VIRT-VSPH-REVIEW-001
title: VMware vSphere and ESXi Review Checklist
version: 0.2.0
status: baseline
---

# VMware vSphere and ESXi Review Checklist

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

## PowerCLI review when applicable

- [ ] Approved `VCF.PowerCLI` or reviewed legacy `VMware.PowerCLI` distribution and compatible child-module versions
- [ ] No automatic module installation or upgrade during operational execution
- [ ] Certificate trust and endpoint identity are validated without ignore or bypass behavior
- [ ] Exact connection objects and explicit `-Server` or equivalent scope are used
- [ ] Ambient default connections, unrelated sessions, and persistent configuration cannot redirect or weaken the run
- [ ] Stable vSphere IDs, endpoint, parent scope, uniqueness, and immediate pre-change revalidation are enforced
- [ ] Wrapper-level `ShouldProcess` prevents mutation in `-WhatIf` and refusal paths
- [ ] Task IDs, deadlines, retry classification, partial or unknown outcomes, and post-state checks are retained
- [ ] Cleanup affects only sessions and temporary settings owned by the current execution
- [ ] Pester mocks isolate PowerCLI and tests cover wrong endpoint, invalid trust, ambiguity, timeout, partial failure, redaction, and state mismatch

## Completion

- [ ] Actual manager and workload state verified
- [ ] Network and storage paths verified
- [ ] Backup and monitoring verified
- [ ] Owner acceptance recorded
- [ ] Checks not run disclosed
- [ ] Residual risk and follow-up owned
- [ ] No claim exceeds evidence
