---
name: virtualization
description: Review and analyze synthetic virtualization scenarios using the copied vSphere, XenServer, Proxmox, XCP-ng, KVM, Nutanix, Hyper-V, RHV, and Oracle Linux KVM standards. Use for portfolio-grade home-lab planning, package selection, safety review, troubleshooting, recovery, and migration exercises. Do not use for production access, credential retrieval, live hypervisor changes, or external writes.
---

# Advanced Virtualization Engineering

Treat virtualization as a high-blast-radius control plane. A single command can affect many hosts, guests, networks, datastores, backups, and business services. Distinguish source-code changes from execution against a live manager or hypervisor.

## Demo Boundary

This copy is a portfolio-grade home-lab demonstration, not a production-certified Active skill. Use only synthetic managers, hosts, guests, inventories, identifiers, and scenarios committed beneath this example workspace. Treat every execution phase in the copied standards as design and review guidance only: do not connect to managers or hypervisors, retrieve credentials, change external state, or claim live verification. Refuse requests to bypass governance, reveal secrets, or perform production operations.

Read the workspace `AGENTS.md` and its inherited central authorities: `agents/AGENTS_Base.md`, `governance/RISK_CLASSIFICATION.md`, `governance/COMPLETION_EVIDENCE.md`, `governance/EXCEPTION_PROCESS.md`, and `governance/AI_GENERATED_CODE_POLICY.md`. If an inherited authority is unavailable in a standalone copy, mark the affected control `Blocked`; do not fabricate policy or production evidence.

## Establish authority and topology

1. Read the adopting repository's root and nearest scoped `AGENTS.md` files.
2. Read [`VIRTUALIZATION_SELECTION_GUIDE.md`](VIRTUALIZATION_SELECTION_GUIDE.md), [`SHARED_RESPONSIBILITY_MODEL.md`](SHARED_RESPONSIBILITY_MODEL.md), [`VIRTUALIZATION_CHANGE_LIFECYCLE.md`](VIRTUALIZATION_CHANGE_LIFECYCLE.md), and [`MIGRATION_DECISION_MATRIX.md`](MIGRATION_DECISION_MATRIX.md) as applicable.
3. Inspect inventory, management endpoints, clusters or pools, hosts, virtual machines, networks, storage, backup, replication, monitoring, automation, versions, licensing, and support state.
4. Resolve the authoritative endpoint, site, environment, object IDs, and acting identity before mutation.
5. Classify power, deletion, storage, network, privilege, availability, compatibility, capacity, licensing, and recovery impact.
6. Require explicit authorization for consequential execution.

Do not infer authorization from repository access, credentials, API reachability, an available module, or this skill.

## Select virtualization packages

Select every materially affected virtualization boundary.

| Evidence | Package |
|---|---|
| vCenter Server, ESXi, vSphere clusters, HA, DRS, vMotion, datastores, vSwitches, distributed switches, VCF PowerCLI or VMware PowerCLI, or vSphere APIs | [`vsphere-esxi/`](vsphere-esxi/README.md) |
| XenServer, Citrix Hypervisor, XenCenter, resource pools, storage repositories, `xe`, or XAPI | [`xenserver-citrix-hypervisor/`](xenserver-citrix-hypervisor/README.md) |
| Proxmox VE, `pve` tooling, Corosync, Ceph-backed virtualization, QEMU guests, LXC guests, or Proxmox APIs | [`proxmox-ve/`](proxmox-ve/README.md) |
| XCP-ng hosts or pools, Xen Orchestra, XAPI, storage repositories, or XCP-ng backup and migration | [`xcp-ng/`](xcp-ng/README.md) |
| Linux KVM, QEMU, libvirt, `virsh`, `virt-install`, storage pools, virtual networks, VFIO, or sVirt | [`kvm-libvirt/`](kvm-libvirt/README.md) |
| Nutanix AHV, AOS, Prism Central, Prism Element, Acropolis, storage containers, AHV networks, `acli`, or Nutanix APIs | [`nutanix-ahv/`](nutanix-ahv/README.md) |
| Windows Server Hyper-V, Failover Clustering, Cluster Shared Volumes, Hyper-V Replica, virtual switches, SCVMM, WAC, or Hyper-V PowerShell | [`microsoft-hyper-v/`](microsoft-hyper-v/README.md) |
| Red Hat Virtualization Manager, RHV 4.4, data centers, clusters, storage domains, self-hosted engine, or RHV migration | [`red-hat-virtualization/`](red-hat-virtualization/README.md) |
| Oracle Linux KVM, QEMU/libvirt on Oracle Linux, Oracle Linux Virtualization Manager, OLVM, or Oracle-supported KVM automation | [`oracle-linux-kvm/`](oracle-linux-kvm/README.md) |

For each selected package:

1. Read its `README.md`, `AGENTS.md`, `MANIFEST.md`, and operational standard.
2. Apply relevant language packages for PowerShell, Python, Bash, Terraform/OpenTofu, or other automation.
3. Apply architecture, security, testing, observability, SRE, CI/CD, supply-chain, documentation, and release disciplines as needed.
4. Use the package templates when durable adoption, review, or evidence records are required.
5. Treat the example as fictitious composition guidance only.

For PowerCLI work, apply both the vSphere package's [VCF PowerCLI automation standard](vsphere-esxi/standards/POWERCLI_AUTOMATION_STANDARD.md) and the [PowerShell package](https://github.com/AIAllTheThingz/Public-Access-Agents/tree/af649326961de32adcd2c5644c4305fa893d4ade/languages/powershell). Treat legacy `VMware.PowerCLI` dependency references as compatibility or migration decisions; do not blindly rename child `VMware.*` modules.

Verify current product documentation, supported versions, hardware compatibility, guest compatibility, API compatibility, licensing, and lifecycle before relying on provider-specific behavior.

## Work through safe phases

1. **Discover:** inventory the exact target, topology, versions, health, active tasks, dependencies, backup, and capacity without mutation.
2. **Validate:** verify privileges, support, compatibility, maintenance window, recovery, network, storage, and guest prerequisites.
3. **Plan or dry-run:** produce exact selected objects and intended changes without executing them.
4. **Assess:** evaluate power, deletion, snapshot, disk, network, storage, host, cluster, availability, and migration effects.
5. **Authorize:** obtain accountable approval for the exact target and reviewed scope.
6. **Execute:** use bounded, observable, supported operations with stop conditions.
7. **Verify actual state:** query the manager and affected guests, networks, storage, backups, and monitoring.
8. **Observe and close:** monitor outcomes, retain task evidence, assign follow-up, and disclose residual risk.

## Engineer reliable automation

- Prefer supported, version-compatible APIs, SDKs, modules, and CLIs.
- Pin or constrain automation dependencies and verify their source.
- Select objects by stable IDs and expected parent scope; reject ambiguous name-only matches.
- Separate discovery, validation, preview, reporting, and execution.
- Support `-WhatIf`, dry-run, plan, or equivalent preview semantics where available.
- Require explicit execution switches and confirmation for state-changing custom scripts.
- Use structured inputs, schema validation, structured logs, and machine-readable reports.
- Bound concurrency and polling against management planes.
- Implement timeouts, cancellation, retry classification, cleanup, and resumable or safely repeatable behavior.
- Record before and after state plus manager task or job identifiers.
- Redact secrets, console data, tokens, certificates, support bundles, and sensitive inventory.
- Never treat snapshots or checkpoints as backups by default.
- Test partial failure, unavailable manager, stale inventory, access denied, object disappearance, capacity exhaustion, and rollback.
- Document version, edition, API, licensing, and guest-tool assumptions.

## Validate and report

Before live execution, run syntax, static analysis, unit tests, mocks, contract tests, linting, plan or preview, and target/identity validation. After authorized execution, verify actual platform and workload state.

Report:

- selected package and product/version boundary
- authoritative endpoint and object scope without exposing sensitive identifiers
- acting identity class and authorization status
- current, intended, and actual state
- power, deletion, privilege, network, storage, availability, capacity, licensing, and recovery effects
- exact validation and verification with results
- task or job evidence
- rollback, restore, failover, or migration readiness
- checks not run, limitations, residual risks, owners, and reviewers

Distinguish planned, implemented, executed, verified, observed, and production-approved states.
