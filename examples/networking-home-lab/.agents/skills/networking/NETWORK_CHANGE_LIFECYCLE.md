---
id: NET-LIFE-001
title: Network Change Lifecycle
version: 0.1.0
status: baseline
---

# Network Change Lifecycle

## 1. Discover

Resolve stable target identity, vendor, hardware, network OS, release, controller, site, fabric, tenant, context, role, owner, acting identity, configuration source, topology, links, adjacencies, redundancy, policy, active work, locks, telemetry, backup, and alternate access without mutation.

## 2. Validate

Verify authorization, lifecycle, entitlement, hardware/software/feature/controller/API compatibility, capacity, optics and modules, configuration provenance, dependency ownership, management preservation, redundancy, observability, backup, rollback, and prerequisites.

## 3. Plan

Produce an ordered before-to-after diff with exact targets and contexts. Model blast radius, transient states, protocol convergence, redundant-peer sequencing, maintenance impact, validation points, stop conditions, rollback triggers, recovery handoff, and evidence.

## 4. Stage

Validate schema and rendered syntax. Test semantic intent in a lab, emulator, digital twin, offline validator, or representative non-production topology. Exercise controller conflict, partial deployment, lost adjacency, lost access, rollback, and safe rerun. Use a bounded canary where risk remains.

## 5. Review and authorize

Obtain review from the network owner and affected security, platform, storage, application, and service owners. Authorization must identify exact scope, window, actor, plan revision, canary, stop/rollback authority, expected impact, observers, and acceptance criteria.

## 6. Execute

Reconfirm identity, scope, ownership, health, and active changes. Acquire supported locks. Apply the narrowest ordered transaction, one redundant side or fabric at a time, with bounded concurrency and live health gates. Stop on unmodeled state or threshold breach.

## 7. Verify

Query actual device and controller configuration. Verify primary and alternate management, AAA, time, logging, adjacencies, routes, spanning tree, link aggregation, HA, required/denied paths, MTU, errors/discards, QoS, telemetry, and dependent services as applicable.

## 8. Observe and close

Monitor through the defined convergence and business-observation window. Reconcile source of truth and backups, remove temporary access only after acceptance, retain redacted evidence, record deviations and follow-up owners, and disclose checks not run and residual risk.

## State language

- **Planned:** reviewed intent exists; nothing was changed.
- **Staged:** artifacts or topology were tested outside the target production scope.
- **Executed:** a change was submitted; convergence and outcomes may remain unknown.
- **Converged:** the network reached a stable observed state.
- **Verified:** defined management, control, data, security, and service checks passed.
- **Observed:** the required monitoring window completed without breaching gates.
- **Production-approved:** accountable owners accepted the verified result and residual risk.

Do not collapse these states into “done.”
