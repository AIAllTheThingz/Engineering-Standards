---
id: IAC-STD-004
title: Variables, Outputs, and Secrets Standard
version: 0.2.0
status: baseline
---
# Variables, Outputs, and Secrets Standard

## Purpose

Validate variables, minimize sensitive outputs, prevent secrets in source and logs, and define secure runtime inputs.

## Applicability

This standard applies when Terraform and OpenTofu work changes the boundary described by this document.

## Requirements

### IAC-04-001

**Requirement:** Define the affected platform boundary, owner, environment, and target identity before change.

**Expected evidence:** Scope and ownership record.

### IAC-04-002

**Requirement:** Validate variables, minimize sensitive outputs, prevent secrets in source and logs, and define secure runtime inputs.

**Expected evidence:** Reviewed design, configuration, plan, or decision record.

### IAC-04-003

**Requirement:** Apply least privilege, protect sensitive data, and make public or privileged behavior explicit.

**Expected evidence:** Security and access review.

### IAC-04-004

**Requirement:** Validate intended behavior, denied behavior, failure paths, and actual state using appropriate tools.

**Expected evidence:** Exact validation commands and results.

### IAC-04-005

**Requirement:** Define rollback, restore, failover, recreation, or accepted recovery limitations.

**Expected evidence:** Recovery plan and evidence.

### IAC-04-006

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
