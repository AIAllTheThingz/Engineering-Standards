---
id: OS-WINSRV-AGENT-001
title: Windows Server Agent Standard
version: 0.1.0
status: baseline
---

# Windows Server Agent Standard

## Purpose

Define mandatory behavior for agents designing, scripting, administering, reviewing, troubleshooting, recovering, upgrading, or decommissioning Windows Server 2016, 2019, 2022, and 2025 systems.

## Authority and scope

The authoritative boundary is the exact server plus the system that owns its configuration: Active Directory and Group Policy, Azure Arc or Update Manager, Windows Server Update Services, Configuration Manager, Desired State Configuration, Windows Admin Center, cluster management, cloud management, or another explicitly approved control plane.

Identify standalone, domain-joined, cluster, Server Core, Desktop Experience, physical, virtual, cloud, and role-specific boundaries. Management-tool access does not authorize live execution.

## Mandatory behavior

- Record server identity, domain or workgroup, environment, owner, edition, release, build, installation option, architecture, roles, cluster state, lifecycle phase, update source, and acting identity.
- Treat Windows Server 2016 as legacy extended-support operation with migration ownership; verify the published end date before every change.
- Treat Windows Server 2019 as extended-support operation and verify current phase for 2022 and 2025.
- Prefer Windows Server 2025 for new deployments only when role, application, hardware, driver, backup, security, and management compatibility are proven.
- Discover pending reboot, servicing stack, component store, update history, role health, event logs, backup, storage, BitLocker, firewall, Defender, policy, certificates, time, and remote access before change.
- Require explicit authorization for role changes, updates, reboot, service, registry, Group Policy, identity, firewall, WinRM/RDP, storage, encryption, driver, cluster, boot, or destructive actions.
- Preserve console or alternate administrative access before changing domain trust, network, firewall, certificate, WinRM, RDP, PowerShell remoting, or logon policy.
- Use Microsoft-supported tooling and role-specific procedures. Do not edit Active Directory, cluster, servicing, or manager-owned databases directly.
- Use Cluster-Aware Updating or a reviewed equivalent for clustered roles; do not patch nodes independently without quorum, drain, capacity, and failover evidence.
- Verify actual role and workload health after servicing. An installed KB or successful restart is not completion.

## Product-specific rules

### OS-WINSRV-TARGET-001

**Requirement:** Resolve the exact server, domain, environment, management authority, role, cluster membership, and acting identity before mutation.

**Expected evidence:** Stable device identity, management source, OS facts, role inventory, cluster scope, and identity class.

### OS-WINSRV-LIFE-002

**Requirement:** Classify 2016, 2019, 2022, or 2025 against the current Microsoft lifecycle and prohibit unsupported operation without a time-bounded approved exception.

**Expected evidence:** Release/build, edition, lifecycle source and review date, support phase, entitlement if applicable, and migration owner.

### OS-WINSRV-PATCH-003

**Requirement:** Validate update source, applicability, free space, component health, role prerequisites, restart behavior, rollback, canary, and post-update acceptance before fleet servicing.

**Expected evidence:** Update plan, prechecks, staged results, per-node state, restart evidence, and postchecks.

### OS-WINSRV-ROLE-004

**Requirement:** Apply role-specific backup, recovery, sequencing, and health checks for directory, certificate, DNS, DHCP, file, web, database, cluster, and other stateful roles.

**Expected evidence:** Role inventory, authoritative recovery procedure, dependency checks, and owner acceptance.

### OS-WINSRV-ACCESS-005

**Requirement:** Preserve and test alternate access before changes to identity, logon, certificate, firewall, network, WinRM, RDP, PowerShell remoting, or Group Policy.

**Expected evidence:** Redacted access-path test, break-glass owner, rollback trigger, and post-change access validation.

### OS-WINSRV-SEC-006

**Requirement:** Preserve Secure Boot, BitLocker, Defender, firewall, audit, least privilege, credential protections, and applicable security baselines unless a reviewed exception exists.

**Expected evidence:** Before/after control state and approved exception record where applicable.

### OS-WINSRV-CLUSTER-007

**Requirement:** Validate quorum, drain, failover, capacity, storage, networking, role health, and restart order before clustered maintenance.

**Expected evidence:** Cluster validation, node order, health gates, stop conditions, and failback result.

## Automation

Prefer supported PowerShell modules, CIM/WMI interfaces, DSC, Windows Admin Center, Windows Update APIs, Azure management, and role-specific tools. Use the PowerShell language package and document when Windows PowerShell 5.1 is required by an in-box module.

Automation must support discovery and preview, use stable identities, bound batches and restarts, preserve transcripts or structured logs without secrets, handle pending restarts and partial fleets, and verify actual state.

## Completion

Completion requires current OS and update state, completed required restart, role and workload health, cluster and replication status where applicable, access, security controls, backup, monitoring, owner acceptance, checks not run, and residual risk.

## Authoritative starting points

- [Windows Server documentation](https://learn.microsoft.com/en-us/windows-server/)
- [Windows Server 2016 lifecycle](https://learn.microsoft.com/en-us/lifecycle/products/windows-server-2016)
- [Windows Server 2019 lifecycle](https://learn.microsoft.com/en-us/lifecycle/products/windows-server-2019)
- [Windows Server 2022 lifecycle](https://learn.microsoft.com/en-us/lifecycle/products/windows-server-2022)
- [Windows Server 2025 lifecycle](https://learn.microsoft.com/en-us/lifecycle/products/windows-server-2025)
