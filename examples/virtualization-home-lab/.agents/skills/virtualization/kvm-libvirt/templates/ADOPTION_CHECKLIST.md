---
id: VIRT-KVM-ADOPT-001
title: KVM and libvirt Adoption Checklist
version: 0.1.0
status: baseline
---

# KVM and libvirt Adoption Checklist

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

## Operations

- [ ] Network and storage owners reviewed affected paths
- [ ] Capacity and evacuation were validated
- [ ] Backup, replication, monitoring, and alerting owners are assigned
- [ ] Maintenance window and workload owners are recorded
- [ ] Licensing and support were reviewed
- [ ] Checks not run and residual risk will be reported
