---
id: IAC-STD-007
title: Destructive Change Standard
version: 0.2.0
status: baseline
---
# Destructive Change Standard

## Purpose

Identify replacement and deletion, require explicit authorization, protect critical resources, and define recovery and stop criteria.

## Applicability

This standard applies when Terraform and OpenTofu work changes the boundary described by this document.

## Requirements

### IAC-07-001

**Requirement:** Define the affected platform boundary, owner, environment, and target identity before change.

**Expected evidence:** Scope and ownership record.

### IAC-07-002

**Requirement:** Identify replacement and deletion, require explicit authorization, protect critical resources, and define recovery and stop criteria.

**Expected evidence:** Reviewed design, configuration, plan, or decision record.

### IAC-07-003

**Requirement:** Apply least privilege, protect sensitive data, and make public or privileged behavior explicit.

**Expected evidence:** Security and access review.

### IAC-07-004

**Requirement:** Validate intended behavior, denied behavior, failure paths, and actual state using appropriate tools.

**Expected evidence:** Exact validation commands and results.

### IAC-07-005

**Requirement:** Define rollback, restore, failover, recreation, or accepted recovery limitations.

**Expected evidence:** Recovery plan and evidence.

### IAC-07-006

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
