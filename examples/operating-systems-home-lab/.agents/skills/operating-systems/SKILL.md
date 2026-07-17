---
name: operating-systems
description: Review and analyze synthetic operating-system scenarios using the copied Windows, Linux, macOS, and FreeBSD standards. Use for portfolio-grade home-lab planning, package selection, hardening review, troubleshooting, patching, recovery, and migration exercises. Do not use for production access, credential retrieval, live host changes, or external writes.
---

# Advanced Operating-System Engineering

Treat an operating system as a privileged execution and security boundary. A routine-looking package, policy, service, firewall, identity, boot, storage, or update action can remove access, interrupt workloads, corrupt data, or affect an entire fleet.

## Demo Boundary

This copy is a portfolio-grade home-lab demonstration, not a production-certified Active skill. Use only synthetic hosts, inventories, configurations, identifiers, and scenarios committed beneath this example workspace. Treat every execution phase in the copied standards as design and review guidance only: do not connect to endpoints, retrieve credentials, change external state, or claim live verification. Refuse requests to bypass governance, reveal secrets, or perform production operations.

Read the workspace `AGENTS.md` and its inherited central authorities: `agents/AGENTS_Base.md`, `governance/RISK_CLASSIFICATION.md`, `governance/COMPLETION_EVIDENCE.md`, `governance/EXCEPTION_PROCESS.md`, and `governance/AI_GENERATED_CODE_POLICY.md`. If an inherited authority is unavailable in a standalone copy, mark the affected control `Blocked`; do not fabricate policy or production evidence.

## Establish authority and inventory

1. Read the adopting repository's root and nearest scoped `AGENTS.md` files.
2. Read [`OS_SELECTION_GUIDE.md`](OS_SELECTION_GUIDE.md), [`SHARED_RESPONSIBILITY_MODEL.md`](SHARED_RESPONSIBILITY_MODEL.md), [`OS_CHANGE_LIFECYCLE.md`](OS_CHANGE_LIFECYCLE.md), and [`UPGRADE_MIGRATION_DECISION_MATRIX.md`](UPGRADE_MIGRATION_DECISION_MATRIX.md) as applicable.
3. Resolve the exact device, host, image, management authority, environment, owner, edition, release, build or kernel, architecture, role, and acting identity.
4. Inventory update sources, policy, services, identity, network, storage, encryption, endpoint controls, backup, monitoring, dependencies, and lifecycle.
5. Classify privilege, access, reboot, availability, data, security, compatibility, licensing, and recovery impact.
6. Require explicit authorization for consequential execution.

Do not infer authorization from repository access, credentials, remote-management reachability, an installed agent, or this skill.

## Select operating-system packages

Select every materially affected OS boundary.

| Evidence | Package |
|---|---|
| Windows Server 2016, 2019, 2022, or 2025; Server Core; Windows Update; WSUS; Active Directory roles; Failover Clustering; PowerShell; DSC; or Windows Admin Center | [`windows-server/`](windows-server/README.md) |
| Windows 10 or Windows 11 endpoints; Intune; Configuration Manager; Group Policy; BitLocker; Defender; Windows Autopilot; or Windows client servicing | [`windows-client/`](windows-client/README.md) |
| Red Hat Enterprise Linux, Rocky Linux, AlmaLinux, or CentOS Stream; RPM; DNF; SELinux; systemd; firewalld; subscription management; or Enterprise Linux automation | [`rhel-family/`](rhel-family/README.md) |
| Ubuntu Server or Desktop; APT; Snap; cloud-init; Netplan; AppArmor; Landscape; Ubuntu Pro; or unattended upgrades | [`ubuntu/`](ubuntu/README.md) |
| Debian stable; APT; dpkg; systemd; Debian Security Advisories; unattended upgrades; or Debian release upgrades | [`debian/`](debian/README.md) |
| SUSE Linux Enterprise Server or Desktop; Zypper; SCC; SUSE Manager; YaST; AppArmor; Snapper; or service-pack migration | [`suse-linux-enterprise/`](suse-linux-enterprise/README.md) |
| Oracle Linux; UEK or RHCK; ULN; Ksplice; DNF; SELinux; Oracle Linux Automation Manager; or OS Management Hub | [`oracle-linux/`](oracle-linux/README.md) |
| Managed Mac computers; macOS; Apple Business Manager; MDM or declarative device management; FileVault; bootstrap tokens; PPPC; or system extensions | [`macos/`](macos/README.md) |
| FreeBSD RELEASE or supported branches; `freebsd-update`; `pkg`; Ports; jails; ZFS; boot environments; `rc.conf`; PF; or IPFW | [`freebsd/`](freebsd/README.md) |

For each selected package:

1. Read its `README.md`, `AGENTS.md`, `MANIFEST.md`, and operational standard.
2. Apply the actual automation-language package, commonly PowerShell, Bash, Python, or Terraform/OpenTofu.
3. Apply security, testing, observability, SRE, architecture, CI/CD, supply-chain, documentation, and release disciplines as needed.
4. Use the package templates when adoption, review, or evidence records must be retained.
5. Treat examples as fictitious composition guidance only.

Verify the exact vendor, edition, release, servicing channel, architecture, hardware, repository, subscription, management-tool compatibility, and support state against current authoritative sources before execution.

## Work through safe phases

1. **Discover:** inventory exact targets, current configuration, health, policy sources, active work, dependencies, backup, and pending restart without mutation.
2. **Validate:** verify identity, authorization, privilege, support, compatibility, recovery, capacity, package provenance, access preservation, and prerequisites.
3. **Plan or preview:** render exact targets, before-to-after state, dependency order, reboots, user or workload impact, stop conditions, rollback, and evidence.
4. **Stage:** test artifacts and changes on representative non-production systems and canary rings.
5. **Authorize:** obtain accountable approval for the reviewed scope and maintenance window.
6. **Execute:** use supported interfaces, bounded concurrency, health gates, and explicit stop conditions.
7. **Verify actual state:** query OS, services, identity, network, storage, security, backup, monitoring, and workload health.
8. **Observe and close:** monitor the defined period, retain evidence, assign follow-up, and disclose residual risk.

## Engineer reliable automation

- Prefer supported management APIs, configuration systems, package tools, modules, and CLIs.
- Use stable device IDs and verified management scope; reject ambiguous hostnames or stale inventory.
- Separate discovery, validation, preview, staging, execution, verification, and reporting.
- Make mutation opt-in and require confirmation for reimage, wipe, reboot, identity, firewall, storage, encryption, boot, security-control, or broad fleet actions.
- Preserve out-of-band, break-glass, or alternate access before changing the primary management path.
- Validate signed repositories, packages, scripts, profiles, policies, and update metadata.
- Bound batches, concurrency, retries, timeouts, reboot orchestration, and health polling.
- Stop a rollout when canary, access, security, workload, or recovery gates fail.
- Record before and after state, tool versions, policy origin, per-target results, reboots, and correlation IDs.
- Redact credentials, recovery keys, tokens, certificates, user data, device identifiers, and sensitive inventory.
- Test missing, duplicate, unreachable, denied, stale, partially updated, restart-pending, rollback, and recovery paths.
- Never disable SELinux, AppArmor, Secure Boot, firewalling, endpoint protection, encryption, code-signing, or platform security merely to make a change succeed.

## Validate and report

Report the selected package, OS vendor and release boundary, management authority, target scope, lifecycle status, authorization state, before/intended/actual state, reboot and availability impact, security and recovery impact, validation results, checks not run, residual risk, owners, and required reviewers.

Distinguish planned, staged, implemented, executed, verified, observed, and production-approved states.
