---
id: VIRT-INDEX-001
title: Virtualization Standards
version: 0.2.0
status: baseline
---

# Virtualization Standards

Use [`SKILL.md`](SKILL.md) when an agent must select and apply virtualization packages during design, scripting, administration, review, troubleshooting, lifecycle, recovery, or migration work.

## Purpose

This collection provides project-agnostic engineering standards for hypervisor and virtualization control planes. It governs how agents discover, validate, plan, automate, execute, verify, and document work without assuming that access equals authorization or that a successful task proves a safe outcome.

Virtualization spans several coupled boundaries:

- management plane and API
- hypervisor hosts
- clusters, pools, scheduling, and availability
- virtual machines, templates, tools, and virtual hardware
- virtual switches, VLANs, overlays, and administrative networks
- datastores, storage repositories, storage domains, volumes, and replication
- snapshots, checkpoints, backup, restore, export, and disaster recovery
- firmware, drivers, hardware compatibility, and device passthrough
- licensing, subscriptions, support, lifecycle, and migration
- automation identities, modules, SDKs, CLIs, state, logs, and evidence

A package is an overlay. It supplements root governance, languages, disciplines, platforms, frameworks, profiles, and the adopting repository's actual environment instructions.

## Virtualization catalog

| Package | Primary boundary |
|---|---|
| [VMware vSphere and ESXi](vsphere-esxi/) | vCenter-managed or standalone ESXi inventory, clusters, hosts, VMs, vMotion, HA/DRS, networking, storage, Lifecycle Manager, VCF PowerCLI, and APIs |
| [XenServer and Citrix Hypervisor](xenserver-citrix-hypervisor/) | XenServer/Citrix Hypervisor hosts, pools, XenCenter, XAPI, `xe`, storage repositories, networks, HA, and lifecycle |
| [Proxmox VE](proxmox-ve/) | Proxmox nodes and clusters, Corosync quorum, QEMU/LXC workloads, storage, Ceph, networking, firewall, backup, and API automation |
| [XCP-ng](xcp-ng/) | XCP-ng hosts and pools, Xen Orchestra, XAPI, storage repositories, networks, backup, upgrades, and migration |
| [KVM and libvirt](kvm-libvirt/) | Linux KVM/QEMU/libvirt hosts, domains, storage pools, virtual networks, migration, device assignment, and automation |
| [Nutanix AHV](nutanix-ahv/) | AHV/AOS clusters, Prism, hosts, VMs, storage containers, networks, policies, lifecycle, protection, and APIs |
| [Microsoft Hyper-V](microsoft-hyper-v/) | Windows Server Hyper-V hosts and clusters, CSV, virtual switches, live migration, Replica, SCVMM/WAC, and PowerShell |
| [Red Hat Virtualization](red-hat-virtualization/) | RHV 4.4 legacy operations, Manager, hosts, clusters, storage domains, networks, self-hosted engine, and migration |
| [Oracle Linux KVM](oracle-linux-kvm/) | Standalone Oracle Linux KVM/libvirt and Oracle Linux Virtualization Manager environments |

## Selection

Use [`VIRTUALIZATION_SELECTION_GUIDE.md`](VIRTUALIZATION_SELECTION_GUIDE.md).

Select every package that materially controls the target. A migration between products normally requires both source and destination packages plus the shared migration guidance.

KVM is an underlying hypervisor technology used by several products, but product-managed KVM environments are not interchangeable. Select the product package when its manager owns configuration. Select generic KVM/libvirt only for directly managed Linux KVM environments or when the underlying boundary is itself in scope.

## Shared responsibility

Use [`SHARED_RESPONSIBILITY_MODEL.md`](SHARED_RESPONSIBILITY_MODEL.md).

Every material responsibility needs an owner, including:

- management plane
- host hardware, firmware, and hypervisor
- identity and privileged access
- guest operating systems and applications
- networking and security boundaries
- storage, replication, backup, and restore
- monitoring, alerting, capacity, and performance
- licensing, support, lifecycle, and migration
- automation source, credentials, execution, and evidence

“The hypervisor handles it” is not an ownership model.

## Change lifecycle

Use [`VIRTUALIZATION_CHANGE_LIFECYCLE.md`](VIRTUALIZATION_CHANGE_LIFECYCLE.md).

Virtualization changes must separate:

1. discovery
2. validation
3. plan or dry-run
4. risk and recovery review
5. authorization
6. bounded execution
7. actual-state verification
8. observation
9. closure and evidence

Powering on a VM successfully proves that a VM powered on. It does not prove application health, data integrity, network correctness, backup coverage, or business readiness.

## Migration

Use [`MIGRATION_DECISION_MATRIX.md`](MIGRATION_DECISION_MATRIX.md).

Migration work must define:

- source and destination authority
- supported conversion path
- workload dependency map
- backup and rollback
- guest tools and drivers
- boot mode, disk, controller, CPU, and device compatibility
- network identity and cutover
- licensing and support
- downtime and synchronization
- validation and acceptance
- decommission hold period

A copied virtual disk is not a completed migration.

## Automation model

Custom scripts and orchestration should use safe phases:

1. **Discovery:** inventory and report only.
2. **Validation:** verify target, identity, compatibility, health, capacity, backup, and prerequisites.
3. **DryRun or plan:** show exact intended objects and actions.
4. **Report:** create durable structured evidence.
5. **Execution:** require explicit enablement and confirmation.
6. **Verification:** query actual state and workload health.
7. **Recovery:** provide rollback, restore, failback, or operator-intervention guidance.

Apply the appropriate language package. Hyper-V and vSphere automation commonly use PowerShell; Linux-centered virtualization commonly uses Bash, Python, Ansible, Terraform/OpenTofu, or supported APIs. The product and repository determine the actual toolchain.

For vSphere PowerCLI work, apply the vSphere package's [VCF PowerCLI automation standard](vsphere-esxi/standards/POWERCLI_AUTOMATION_STANDARD.md) together with the [PowerShell package](https://github.com/AIAllTheThingz/Public-Access-Agents/tree/af649326961de32adcd2c5644c4305fa893d4ade/languages/powershell).

## High-risk operations

Treat these as high risk unless environment evidence supports a lower classification:

- manager, cluster, pool, or host upgrade
- firmware or driver change
- host evacuation or maintenance
- datastore, storage repository, storage domain, or virtual disk mutation
- virtual network, distributed switch, bridge, VLAN, overlay, or firewall mutation
- snapshot or checkpoint deletion and consolidation
- bulk power operations
- cluster membership or quorum changes
- backup, replication, failover, or disaster-recovery changes
- guest conversion or cross-platform migration
- passthrough, SR-IOV, GPU, TPM, Secure Boot, or confidential-computing changes
- certificate, identity, RBAC, or privileged-access changes
- unsupported or end-of-life platform operation

## Compatibility

Before a material change, verify applicable compatibility across:

- management plane and hypervisor
- mixed cluster or pool versions
- server hardware and firmware
- CPU generation and migration compatibility
- storage array, protocol, multipathing, and plugin
- physical and virtual networking
- guest operating system and guest tools
- virtual hardware, firmware, controllers, and drivers
- backup, replication, monitoring, and security products
- API, SDK, CLI, module, provider, and automation versions
- licensing, entitlement, subscription, and vendor support

Do not turn a remembered compatibility claim into a production decision.

## Validation

Repository validation:

```bash
python tools/validate-all/run_all.py --include-tests
```

Adopting projects should also run product-supported health, compatibility, configuration, backup, restore, cluster, storage, network, and workload validation appropriate to the exact environment.

Record exact commands, timestamps, target scope, results, and checks not run. Redact sensitive inventory and credentials.

## Maturity and review

All packages begin at `baseline`. They are usable minimum standards but require representative adoption, current source review, and independent virtualization-specialist review before promotion to `stable`.

Review provider-specific packages when product lifecycle, licensing, management architecture, security guidance, API behavior, or support policy changes.

## Limitations

These standards:

- do not replace vendor documentation, compatibility matrices, support contracts, or release notes
- do not know an adopting environment's topology, workload dependencies, maintenance window, or recovery capability
- do not grant authorization
- do not guarantee zero downtime or successful migration
- do not certify security, compliance, supportability, or production readiness
- cannot prove that a snapshot, replica, or backup is restorable without a recovery test
- cannot make unsupported products supported

## Authoritative sources

The repository source catalog is [`../SOURCES.md`](https://github.com/AIAllTheThingz/Public-Access-Agents/blob/af649326961de32adcd2c5644c4305fa893d4ade/SOURCES.md). Verify current vendor documentation before relying on product-specific behavior.
