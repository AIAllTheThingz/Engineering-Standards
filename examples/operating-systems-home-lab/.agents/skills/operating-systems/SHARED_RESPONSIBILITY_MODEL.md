---
id: OS-RESP-001
title: Operating-System Shared Responsibility Model
version: 0.1.0
status: baseline
---

# Operating-System Shared Responsibility Model

## Purpose

Make ownership explicit across hardware or hosting, images, operating systems, workloads, identity, security, network, storage, backup, management tooling, and automation.

## Responsibility map

| Boundary | Minimum accountable responsibility |
|---|---|
| Vendor or distribution | Publishes releases, advisories, updates, lifecycle, documentation, and supported interfaces; does not operate the adopter's systems |
| Hardware, cloud, or virtualization owner | Owns firmware or platform compatibility, console or recovery access, physical/virtual resources, and platform failure domains |
| Image or provisioning owner | Owns installation source, image provenance, baseline, bootstrap, enrollment, secrets handling, reproducibility, and image retirement |
| OS owner | Owns version, repositories, configuration, patching, kernel, services, host security, lifecycle, inventory, and operational evidence |
| Workload owner | Owns application compatibility, dependencies, downtime, service validation, data consistency, and acceptance |
| Identity owner | Owns directory integration, local-account policy, privileged access, service identities, certificates, break-glass access, and deprovisioning |
| Network owner | Owns addressing, DNS, time, proxies, firewall policy, required and denied paths, management access, and validation |
| Storage and data owner | Owns volumes, filesystems, mounts, encryption, keys, quotas, integrity, retention, and data migration |
| Security owner | Owns baseline, vulnerability response, logging, auditing, endpoint controls, exceptions, and residual-risk acceptance |
| Backup and recovery owner | Owns independent backup, restore tests, bare-metal or rebuild procedures, recovery objectives, and evidence |
| Management-platform owner | Owns MDM, configuration management, update infrastructure, inventory, policy authority, service health, and audit retention |
| Automation owner | Owns code, dependencies, target selection, preview, batching, retries, logs, tests, rollback behavior, and safe rerun |
| Change approver | Authorizes exact scope, timing, risk, rollback, and stop conditions; must not be replaced by an agent |

## Boundary rules

- A cloud, hypervisor, or MDM success status does not prove OS or workload health.
- OS ownership does not automatically authorize application downtime, directory changes, network policy, key rotation, or data deletion.
- A filesystem snapshot, restore point, rollback transaction, or APFS snapshot is not an independent backup by default.
- A vendor-supported release is not automatically compatible with installed applications, drivers, agents, hardware, images, or organization policy.
- Configuration-management reachability is not proof that alternate recovery access works.
- Security exceptions require accountable approval, compensating controls, expiry, and remediation ownership.

## Managed and unmanaged systems

Classify every target as managed, partially managed, unmanaged, quarantined, recovery-only, or retired. Do not silently enroll, take ownership of, or mutate an unmanaged system. Resolve conflicting policy authorities before execution.

## Evidence handoffs

Before execution, responsible owners provide current inventory, lifecycle, dependency, authorization, backup, recovery, access, and acceptance evidence. After execution, the automation or OS owner provides per-target outcomes, actual state, reboots, failures, deviations, security status, workload checks, monitoring status, checks not run, and residual risk.

## Failure ownership

Define who responds if the management system, repository, identity service, network, host, boot path, storage, encryption, endpoint control, backup system, or automation runner fails mid-change. “The script stopped” is a state description, not an ownership model.
