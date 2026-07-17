---
id: VIRT-VSPH-EXAMPLE-001
title: VMware vSphere and ESXi Adoption Example
version: 0.2.0
status: baseline
---

# VMware vSphere and ESXi Adoption Example

## Boundary

This fictitious example demonstrates adoption structure only.

- Manager: `virt-mgr.example.invalid`
- Environment: `training-lab`
- Cluster or pool: `cluster-lab-01`
- Host: `hv-lab-01.example.invalid`
- Workload: `vm-sample-01`
- Change: validate a planned host-maintenance workflow
- Mode: discovery, validation, and dry-run only
- Live execution: not authorized
- Automation: PowerShell 7 with a project-pinned compatible VCF PowerCLI version
- Dependency status: fictitious example only; no version or live compatibility is certified

## Selected standards

- root governance
- virtualization collection guidance
- VMware vSphere and ESXi package
- VCF PowerCLI automation standard
- PowerShell language package
- testing, application-security, observability, SRE, documentation, and internal-automation guidance

## Discovery evidence

The fictitious automation records the manager class, cluster and host stable IDs, product versions, health, active tasks, guest ownership, backup status, capacity, network/storage dependencies, and maintenance blockers.

The fictitious connection is created only for `virt-mgr.example.invalid`, the endpoint certificate must chain to the training trust policy, and every query receives the owned VIServer connection explicitly. Ambient default connections cause the workflow to stop. The workflow records module versions and disconnects only the session it created.

No module installation, persistent PowerCLI configuration, or vSphere state change occurs.

## Validation

The workflow fails closed when:

- the manager certificate or environment does not match
- the PowerCLI distribution, child modules, or PowerShell runtime fall outside the project's tested constraint
- an ambient or returned connection makes endpoint selection ambiguous
- the host match is missing or ambiguous
- cluster or manager health is degraded
- a conflicting task is active
- evacuation capacity is insufficient
- backup or recovery evidence is missing
- a pinned device or workload cannot move
- authorization is absent

## Dry-run report

The report lists:

- selected stable objects
- workloads that could move
- workloads blocked from moving
- capacity before and projected during maintenance
- expected tasks
- expected task deadlines and unknown-outcome handling
- network and storage dependencies
- stop conditions
- recovery path
- checks not run

## Result

Pester evidence for the fictitious wrapper shows that its PowerCLI mutation boundary is not called during discovery, validation failure, `-WhatIf`, or confirmation refusal. No live vCenter integration test is claimed.

The example stops after reviewable dry-run output and closes only its owned connection. It does not place the host into maintenance mode, migrate a workload, change power state, alter storage or networking, change persistent PowerCLI configuration, or claim production readiness.

## Adaptation warning

Replace fictitious values only inside an adopting repository with reviewed configuration and authorization. Re-run official compatibility and lifecycle verification for the exact installed product.
