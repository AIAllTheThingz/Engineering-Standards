---
id: VIRT-SELECT-001
title: Virtualization Selection Guide
version: 0.2.0
status: baseline
---

# Virtualization Selection Guide

## Purpose

Select the smallest complete set of virtualization packages for the actual control planes in scope.

## Selection rules

1. Select by authoritative manager and ownership boundary, not only by hypervisor ancestry.
2. Select both source and destination packages for cross-platform migrations.
3. Select generic KVM/libvirt only when direct Linux KVM management is in scope.
4. Select a product package when its manager owns hosts, networking, storage, policy, or inventory.
5. Add language and discipline packages for the actual automation and operational risks.
6. Verify product name, version, edition, lifecycle, and support against current official documentation.

## Evidence-to-package map

| Evidence | Select |
|---|---|
| vCenter, ESXi, vSphere HA/DRS, vMotion, VCF PowerCLI or VMware PowerCLI | `vsphere-esxi` plus `languages/powershell` for PowerCLI code |
| XenServer, Citrix Hypervisor, XenCenter, XAPI, `xe` | `xenserver-citrix-hypervisor` |
| Proxmox VE, PVE cluster, Corosync, Ceph, `pvesh` | `proxmox-ve` |
| XCP-ng, Xen Orchestra, XAPI pool | `xcp-ng` |
| Direct QEMU/KVM/libvirt, `virsh`, `virt-install` | `kvm-libvirt` |
| Nutanix AHV/AOS, Prism Central or Element, `acli` | `nutanix-ahv` |
| Hyper-V, Failover Clustering, CSV, SCVMM, Hyper-V PowerShell | `microsoft-hyper-v` |
| RHV Manager, RHV 4.4, storage domains, self-hosted engine | `red-hat-virtualization` |
| Oracle Linux KVM or Oracle Linux Virtualization Manager | `oracle-linux-kvm` |

## Common compositions

### vSphere VCF PowerCLI automation

- virtualization/vsphere-esxi
- virtualization/vsphere-esxi/standards/POWERCLI_AUTOMATION_STANDARD.md
- languages/powershell
- disciplines/testing
- disciplines/application-security
- disciplines/observability
- profiles/internal-automation

### Hyper-V cluster automation

- virtualization/microsoft-hyper-v
- languages/powershell
- disciplines/sre
- disciplines/testing
- disciplines/documentation
- profiles/internal-automation

### Proxmox infrastructure automation

- virtualization/proxmox-ve
- languages/bash or languages/python
- languages/terraform-opentofu when Terraform/OpenTofu is used
- disciplines/ci-cd
- disciplines/supply-chain
- disciplines/sre

### Direct KVM/libvirt host management

- virtualization/kvm-libvirt
- languages/bash or languages/python
- disciplines/application-security
- disciplines/testing
- disciplines/observability

### Cross-platform migration

- source virtualization package
- destination virtualization package
- disciplines/architecture
- disciplines/integration
- disciplines/testing
- disciplines/sre
- disciplines/documentation
- migration, rollback, and completion-evidence templates

## Do not select by misleading evidence

- A QEMU process does not automatically mean the generic KVM package is the authoritative manager.
- Xen ancestry does not make XenServer and XCP-ng operationally interchangeable.
- A PowerShell module's presence does not prove the connected vCenter or Hyper-V target is correct.
- A VM export format does not prove destination compatibility.
- A vendor feature list does not prove licensing, configuration, or support in the target environment.

## Selection record

Record:

- selected packages
- manager and hypervisor product names
- versions and editions
- authoritative endpoints and environments
- automation language and interface
- source and destination for migrations
- lifecycle and support state
- excluded packages and rationale
- validation date and official sources checked
