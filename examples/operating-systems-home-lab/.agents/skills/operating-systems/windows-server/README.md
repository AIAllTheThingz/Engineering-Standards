---
id: OS-WINSRV-README-001
title: Windows Server Package
version: 0.1.0
status: baseline
---

# Windows Server Package

## Scope

Standards for Windows Server 2016, 2019, 2022, and 2025 across physical, virtual, cloud, standalone, domain, Server Core, Desktop Experience, and clustered deployments.

## Use this package for

- installation, images, roles, features and configuration
- Windows Update, WSUS, Azure Update Manager and servicing
- PowerShell, DSC, CIM/WMI and Windows Admin Center automation
- identity, Group Policy, certificates, remote access and privilege
- Defender, firewall, auditing, BitLocker and baselines
- services, tasks, network, storage, backup and monitoring
- in-place upgrade, parallel replacement, recovery and retirement

Compose Hyper-V work with the virtualization package and application-specific roles with their relevant standards.

## Lifecycle posture

The named versions do not have equal lifecycle status. Windows Server 2016 is an extended-support legacy platform approaching its published 2027 end date. Windows Server 2019 is in extended support. Verify the current phase of 2022 and 2025 at execution time. Prefer 2025 for new systems only after compatibility evidence.

## Management authority

Record whether configuration is owned by Group Policy, DSC, Configuration Manager, Azure, WSUS, Windows Admin Center, cluster tooling, image pipeline, or local administration. Resolve policy conflicts before execution.

## Safe adoption

1. Inventory exact servers, versions, roles, clusters, policy, update sources, backup and ownership.
2. Complete the adoption checklist and lifecycle classification.
3. Apply the operational standard and PowerShell guidance.
4. Define canary and failure-domain-aware rollout rings.
5. Test role-specific restart, rollback, restore and alternate access.
6. Retain evidence with the supplied template.

## Validation and failure modes

Validate target, lifecycle, update trust, component health, free space, role/application compatibility, pending restart, cluster capacity, backup, alternate access and monitoring. Test partial fleets, failed restarts, role degradation, cluster failover, access loss, update-source outage and recovery.

## Security and recovery

Do not weaken Defender, firewall, Secure Boot, BitLocker, credential protections, audit, code signing or baselines merely to make a role or update succeed. Treat role-aware backup, system state, bare-metal recovery, key custody and tested restore as separate requirements.

## Package contents

- [Agent instructions](AGENTS.md)
- [Operations and automation standard](standards/OPERATIONS_AND_AUTOMATION_STANDARD.md)
- [Adoption checklist](templates/ADOPTION_CHECKLIST.md)
- [Review checklist](templates/REVIEW_CHECKLIST.md)
- [Evidence template](templates/EVIDENCE_RECORD_TEMPLATE.md)
- [Fictitious example](examples/ADOPTION_EXAMPLE.md)
- [Manifest](MANIFEST.md)

## Limitations

This package does not replace Microsoft role documentation, validate a specific update, prove application compatibility, provide organization-specific Group Policy or security baselines, authorize execution, or guarantee recovery.
