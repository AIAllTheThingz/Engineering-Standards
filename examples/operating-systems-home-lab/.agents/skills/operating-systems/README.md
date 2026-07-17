---
id: OS-README-001
title: Operating-System Engineering Standards
version: 0.1.0
status: baseline
---

# Operating-System Engineering Standards

## Purpose

Provide composable standards for safe, secure, supportable, testable, recoverable, and evidence-based operating-system engineering and automation.

## Package catalog

| Package | Scope |
|---|---|
| [Windows Server](windows-server/) | Windows Server 2016, 2019, 2022, and 2025 hosts, roles, servicing, security, PowerShell, and fleet operations |
| [Windows client](windows-client/) | Windows 10 exceptions and supported Windows 11 endpoint provisioning, management, security, servicing, and retirement |
| [RHEL family](rhel-family/) | RHEL, Rocky Linux, AlmaLinux, and CentOS Stream with vendor-specific lifecycle and repository boundaries |
| [Ubuntu](ubuntu/) | Current supported Ubuntu Server and Desktop releases, preferably LTS for production |
| [Debian](debian/) | Current Debian stable and explicitly approved supported oldstable/LTS use |
| [SUSE Linux Enterprise](suse-linux-enterprise/) | Current supported SLES/SLED releases, modules, extensions, service packs, and lifecycle |
| [Oracle Linux](oracle-linux/) | Current supported Oracle Linux releases, UEK/RHCK, ULN, Ksplice, and management tooling |
| [macOS](macos/) | Current security-updated macOS on compatible Apple hardware with managed deployment and platform security |
| [FreeBSD](freebsd/) | Current supported FreeBSD production and explicitly approved legacy release branches |

## What “current” means

The collection intentionally avoids a permanent hard-coded claim that one point release is always current. Before adoption or execution, record:

- vendor and product
- edition and servicing channel
- major, minor, build, kernel, and architecture as applicable
- standard, extended, subscription-backed, community, or legacy support phase
- security-update coverage and repository scope
- hardware and management-tool support
- source-review date and authoritative lifecycle links

The initial source review was performed on 2026-07-14. Every live use must revalidate current facts.

## Important lifecycle boundaries

- Windows Server 2016 remains in extended support only through its published end date and should have an approved migration plan.
- Windows Server 2019 is in extended support. Windows Server 2022 and 2025 have later published support boundaries, but exact phase and edition must still be checked.
- General Windows 10 Home, Pro, Enterprise, and Education servicing ended on 2025-10-14. Windows 10 use requires an eligible LTSC lifecycle, ESU coverage, or a documented isolated exception with migration ownership.
- Windows 11 servicing is edition- and feature-release-specific.
- Linux and FreeBSD “supported major version” does not always mean every minor release or package source remains supported.
- Apple publishes security releases and hardware compatibility rather than a general-purpose enterprise lifecycle table. Verify actual security-update availability for the model and installed release.

## Common control model

All packages require:

- authoritative target and management-source verification
- supported release, repository, artifact, and tool verification
- non-mutating discovery before change
- explicit plan or preview and accountable authorization
- staged and canary rollout for broad changes
- preserved administrative and recovery access
- secure configuration without control-bypass shortcuts
- bounded automation, reboots, retries, polling, and concurrency
- actual-state, service, security, backup, monitoring, and workload verification
- redacted evidence and honest disclosure of checks not run

## Selection and composition

Start with [OS_SELECTION_GUIDE.md](OS_SELECTION_GUIDE.md). Add:

- the relevant language package for automation
- applicable cloud, container, or virtualization packages
- application-security, testing, observability, SRE, CI/CD, supply-chain, documentation, and release disciplines
- an internal-automation, desktop-application, CLI, worker, or other project profile when appropriate

Select both source and destination OS packages for cross-family migrations. Apply platform or virtualization packages separately when their managers own images, boot, network, storage, policy, snapshots, or recovery.

## Adoption

1. Identify exact OS boundaries and management authorities.
2. Select the smallest complete package set.
3. Record installed release, lifecycle, architecture, repositories, roles, security controls, backup, and ownership.
4. Tailor package requirements without weakening authorization, lifecycle, security, access preservation, recovery, testing, or evidence.
5. Complete the adoption and review checklists.
6. Test automation and recovery on representative non-production systems.
7. Define canary rings, stop conditions, maintenance windows, and acceptance.
8. Preserve evidence using the package template.

## Validation

Validate syntax, static analysis, input schemas, configuration checks, package signatures, dry-run or diff, unit tests, mocks, isolated integration tests, canary results, negative cases, partial failure, reboot behavior, rollback, and recovery as applicable.

Never use production as the first test environment.

## Known failure modes

- targeting the wrong host, tenant, enrollment, policy group, or environment
- trusting stale inventory, DNS, hostname, or display-name-only matching
- applying a package or policy from the wrong vendor, release, architecture, or repository
- losing remote access through identity, firewall, network, certificate, or service changes
- leaving a fleet partially patched or indefinitely restart-pending
- assuming an update succeeded because the deployment tool returned success
- disabling security controls to resolve application incompatibility
- treating a filesystem snapshot, restore point, or package rollback as a complete backup
- upgrading without application, driver, agent, hardware, or management compatibility
- deleting the source before migration acceptance and recovery validation
- exposing recovery keys, user data, logs, inventory, or credentials in automation output

## Limitations

These packages do not certify an environment, replace vendor support, supply organization-specific baselines, authorize live execution, guarantee recovery, or prove compliance. Adopters must define their own inventory, ownership, risk tolerance, regulatory controls, maintenance windows, approved versions, repositories, identity architecture, backup, and incident response.
