---
id: OS-WINSRV-OPS-001
title: Windows Server Operations and Automation Standard
version: 0.1.0
status: baseline
---

# Windows Server Operations and Automation Standard

## Applicability

This standard applies to Windows Server 2016, 2019, 2022, and 2025 installation, configuration, roles, servicing, security, automation, recovery, upgrade, and retirement.

## Discovery

Collect exact device and management identity; domain, environment, edition, release, build, architecture, installation option, activation and lifecycle; roles, features, cluster membership and dependencies; update policy, source, history, pending reboot and component health; services, tasks, local/domain identities, privileges and certificates; network, DNS, time, proxy, firewall and remote access; volumes, storage, BitLocker, VSS and backup; Defender, audit, baseline, vulnerabilities, logs, monitoring, capacity, owners and maintenance window.

Discovery must not trigger update scans or repairs when those actions can change state unless authorized.

## Validation

Validate target, acting identity, support phase, update and artifact trust, role/application/driver/agent compatibility, component-store health, free space, power and restart behavior, cluster and failover prerequisites, backup and role-aware recovery, alternate access, monitoring, rollback, owners and acceptance tests.

Stop on ambiguous target, unsupported release, unhealthy role, unresolved pending operation, absent recovery, access risk, low capacity, or conflicting maintenance.

## Plan, stage, and authorize

The plan must list exact servers and roles, KBs or configuration changes, source policy, sequence, batches, drain/failover, restarts, canaries, success gates, stop conditions, rollback or recovery, observation and evidence. Stage representative roles and hardware. Obtain authorization for the exact reviewed scope.

## Execution

- Reconfirm server, domain, environment, role, cluster, and management source.
- Use Microsoft-supported modules, APIs, servicing tools, and role procedures.
- Bound parallel targets and failure domains.
- Preserve console or alternate access.
- Drain and validate clustered roles before node restart.
- Stop on trust, servicing, role, access, cluster, security, backup, or monitoring failure.
- Record per-target update, configuration, restart, task, and manual-intervention state.
- Do not force success by disabling security or deleting servicing state.

## Verification

Verify installed release/build and expected updates; restart state; boot and component health; roles, services, scheduled tasks, replication and cluster state; identity, certificates and access; required/denied network paths; storage, BitLocker and data; Defender, firewall, audit and baseline; backup, monitoring, vulnerabilities and workload acceptance.

## Version handling

| Version | Required handling |
|---|---|
| 2016 | Extended-support legacy operation; record migration plan and published 2027 boundary |
| 2019 | Extended-support operation; avoid new deployment unless compatibility justifies it |
| 2022 | Verify current lifecycle phase and application/role certification |
| 2025 | Preferred new-deployment candidate when full compatibility is proven |

Do not infer support from media availability or successful activation.

## Role cautions

- Directory services: require system-state/recovery planning, replication health, FSMO and site awareness, and role-specific change authority.
- AD CS: protect keys and CA database, preserve offline/root boundaries, and use certificate-specific backup and recovery.
- DNS/DHCP: preserve authoritative data, leases, failover, forwarders, security policy and dependent-service validation.
- Failover Clustering: validate quorum, storage, networks, capacity, drain, failover and Cluster-Aware Updating behavior.
- File services: validate shares, ACLs, DFS, quotas, VSS, encryption, data integrity and client access.
- Hyper-V: compose the Microsoft Hyper-V virtualization package.

## Automation and testing

Use structured configuration and output; separate discover, validate, preview, execute and verify; use `SupportsShouldProcess` or equivalent for custom PowerShell; handle Windows PowerShell 5.1 dependencies explicitly; sign or verify scripts where required; bound remoting, retries, timeouts and restarts; redact secrets; and retain correlation.

Test wrong target/domain, access denied, unreachable host, unsupported build, update-source failure, signature/applicability failure, low space, component corruption, pending reboot, role-health failure, cluster drain/failover failure, restart timeout, partial batch, log redaction, rollback and safe rerun.

## Recovery and completion

Define update uninstall only when supported, configuration rollback, role-aware restore, system-state or bare-metal recovery, alternate access and manual handoff. Do not remove recovery material until acceptance and retention gates pass.

Completion requires actual-state and workload evidence, not merely tool exit status.
