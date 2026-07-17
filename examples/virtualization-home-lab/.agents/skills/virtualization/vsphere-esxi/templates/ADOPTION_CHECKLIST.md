---
id: VIRT-VSPH-ADOPT-001
title: VMware vSphere and ESXi Adoption Checklist
version: 0.2.0
status: baseline
---

# VMware vSphere and ESXi Adoption Checklist

## Product and authority

- [ ] Product, edition, version, and lifecycle recorded
- [ ] Official sources and source-review date recorded
- [ ] Authoritative manager or host identified
- [ ] Environment, site, cluster or pool, and object scope identified
- [ ] Stable object identifiers selected
- [ ] Acting identity and least privilege defined
- [ ] Privileged and emergency access owned

## Safety and recovery

- [ ] Discovery is non-mutating
- [ ] Validation gates are explicit
- [ ] Plan or dry-run is available
- [ ] State-changing execution requires explicit enablement
- [ ] Confirmation semantics are defined
- [ ] Independent backup or export is verified
- [ ] Representative restore evidence is available
- [ ] Rollback, restore, failback, or rebuild is documented
- [ ] Stop conditions and manual handoff are documented
- [ ] Source-retention boundary is defined for migrations

## Engineering

- [ ] Supported interface and dependency versions are documented
- [ ] Structured configuration, input, logging, and reports are used
- [ ] Timeouts, retries, cancellation, polling, and concurrency are bounded
- [ ] Missing, duplicate, stale, denied, unhealthy, and disappearing objects are handled
- [ ] Positive, negative, partial-failure, and recovery tests exist
- [ ] Credentials and sensitive inventory are redacted
- [ ] Task and event identifiers are retained
- [ ] Actual-state and workload verification are defined

## PowerCLI automation when applicable

- [ ] PowerShell runtime, PowerCLI distribution, imported child modules, approved source, and tested version constraints are recorded
- [ ] Existing `VMware.PowerCLI` usage has a documented compatibility or migration decision; child `VMware.*` modules are not blindly renamed
- [ ] Endpoint identity, product/build, and certificate trust are validated before credential use
- [ ] Commands use an explicitly owned connection and pass the intended `-Server` or equivalent scope
- [ ] Ambiguous ambient default connections cause a closed failure
- [ ] Inventory is resolved by stable ID, expected parent scope, and endpoint, then rechecked before mutation
- [ ] Operational execution does not install or update modules or persistently weaken PowerCLI configuration
- [ ] State-changing wrappers implement `ShouldProcess` without assuming the underlying PowerCLI cmdlet honors `-WhatIf`
- [ ] Asynchronous tasks, polling, retries, concurrency, cancellation claims, and unknown outcomes are bounded and handled
- [ ] Pester tests isolate the PowerCLI boundary and cover preview, targeting, session ownership, task, partial-failure, cleanup, and redaction paths
- [ ] Structured evidence records dependency, connection, task, per-object outcome, and actual-state verification details

## Operations

- [ ] Network and storage owners reviewed affected paths
- [ ] Capacity and evacuation were validated
- [ ] Backup, replication, monitoring, and alerting owners are assigned
- [ ] Maintenance window and workload owners are recorded
- [ ] Licensing and support were reviewed
- [ ] Checks not run and residual risk will be reported
