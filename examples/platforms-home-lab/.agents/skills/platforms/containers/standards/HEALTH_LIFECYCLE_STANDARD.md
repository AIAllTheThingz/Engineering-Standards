---
id: CONT-STD-006
title: Health and Lifecycle Standard
version: 0.2.0
status: baseline
---
# Health and Lifecycle Standard

## Purpose

Define startup, readiness, liveness, graceful shutdown, signal handling, cleanup, and restart expectations.

## Applicability

This standard applies when Containers work changes the boundary described by this document.

## Requirements

### CONT-06-001

**Requirement:** Define the affected platform boundary, owner, environment, and target identity before change.

**Expected evidence:** Scope and ownership record.

### CONT-06-002

**Requirement:** Define startup, readiness, liveness, graceful shutdown, signal handling, cleanup, and restart expectations.

**Expected evidence:** Reviewed design, configuration, plan, or decision record.

### CONT-06-003

**Requirement:** Apply least privilege, protect sensitive data, and make public or privileged behavior explicit.

**Expected evidence:** Security and access review.

### CONT-06-004

**Requirement:** Validate intended behavior, denied behavior, failure paths, and actual state using appropriate tools.

**Expected evidence:** Exact validation commands and results.

### CONT-06-005

**Requirement:** Define rollback, restore, failover, recreation, or accepted recovery limitations.

**Expected evidence:** Recovery plan and evidence.

### CONT-06-006

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
