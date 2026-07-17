---
id: IAC-STD-003
title: Provider and Module Dependency Standard
version: 0.2.0
status: baseline
---
# Provider and Module Dependency Standard

## Purpose

Declare compatible versions, pin reviewed dependencies, verify sources, use lockfiles, and control upgrades.

## Applicability

This standard applies when Terraform and OpenTofu work changes the boundary described by this document.

## Requirements

### IAC-03-001

**Requirement:** Define the affected platform boundary, owner, environment, and target identity before change.

**Expected evidence:** Scope and ownership record.

### IAC-03-002

**Requirement:** Declare compatible versions, pin reviewed dependencies, verify sources, use lockfiles, and control upgrades.

**Expected evidence:** Reviewed design, configuration, plan, or decision record.

### IAC-03-003

**Requirement:** Apply least privilege, protect sensitive data, and make public or privileged behavior explicit.

**Expected evidence:** Security and access review.

### IAC-03-004

**Requirement:** Validate intended behavior, denied behavior, failure paths, and actual state using appropriate tools.

**Expected evidence:** Exact validation commands and results.

### IAC-03-005

**Requirement:** Define rollback, restore, failover, recreation, or accepted recovery limitations.

**Expected evidence:** Recovery plan and evidence.

### IAC-03-006

**Requirement:** Record checks not run, limitations, residual risk, owners, and re-review triggers.

**Expected evidence:** Completion evidence linked to the affected artifact or environment.

## Prohibited shortcuts

- Do not rely on undocumented defaults.
- Do not invent target or provider facts.
- Do not hide failed or unavailable validation.
- Do not use examples as production evidence.
- Do not bypass authorization for consequential actions.

## Review triggers

Re-review when target, identity, network, data, privilege, provider behavior, version, region, recovery, cost, quota, artifact, or assumptions change materially.

## Completion boundary

The control is incomplete until applicable implementation, validation, evidence, ownership, and limitations are recorded.
