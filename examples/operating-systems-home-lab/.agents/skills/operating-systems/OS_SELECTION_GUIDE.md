---
id: OS-SELECT-001
title: Operating-System Selection Guide
version: 0.1.0
status: baseline
---

# Operating-System Selection Guide

## Purpose

Select the smallest complete set of OS packages for the actual systems, images, management planes, and lifecycle boundaries in scope.

## Selection rules

1. Select by installed OS and authoritative management boundary, not by a similar command or package format.
2. Select both source and destination packages for upgrades that cross OS families or management models.
3. Treat image construction and live fleet mutation as separate scopes with separate evidence.
4. Verify edition, release, servicing channel, architecture, repository, subscription, hardware, and management compatibility from current authoritative sources.
5. Select language, framework, platform, virtualization, networking, profile, and discipline packages for the actual automation and operational risks.

## Evidence-to-package map

| Evidence | Select |
|---|---|
| Windows Server 2016, 2019, 2022, or 2025 | `windows-server` |
| Windows 10 or Windows 11 endpoint | `windows-client` |
| RHEL, Rocky Linux, AlmaLinux, or CentOS Stream | `rhel-family` |
| Ubuntu Server or Ubuntu Desktop | `ubuntu` |
| Debian stable or supported oldstable/LTS | `debian` |
| SLES, SLED, SUSE modules/extensions, or SUSE Manager | `suse-linux-enterprise` |
| Oracle Linux with UEK or RHCK | `oracle-linux` |
| macOS on Apple hardware | `macos` |
| FreeBSD RELEASE or supported branch | `freebsd` |

## Lifecycle selection

### Windows Server

| Release | Initial posture for new adoption |
|---|---|
| 2016 | Legacy/extended-support operation only; require migration ownership before the published 2027 end date |
| 2019 | Extended-support operation; prefer a newer certified release for new deployments |
| 2022 | Supported operation; verify the current lifecycle phase, edition, hardware, roles, and application certification |
| 2025 | Preferred starting point for new deployment when workload, role, hardware, driver, backup, and management compatibility are proven |

### Windows client

- Use a currently serviced Windows 11 feature release and edition for normal new deployments.
- Do not treat general Windows 10 as current. Require documented LTSC eligibility, active ESU coverage, or a time-bounded exception and migration plan.
- Verify feature-release end dates separately for Home/Pro and Enterprise/Education.

### Linux and FreeBSD

- Prefer the vendor-recommended production, stable, or LTS channel.
- Treat interim, testing, unstable, rolling, preview, beta, vault, archived, ELS, ESM, LTSS, ELTS, or legacy channels as explicit risk and support decisions.
- For Enterprise Linux derivatives, identify the actual distribution and use its repositories, signatures, release policy, errata, and upgrade guidance. Do not assume RHEL entitlement or support transfers to a derivative.
- For FreeBSD, prefer the current Production Release. A Legacy Release must still appear on the supported-release list and have an owned upgrade date.

### macOS

- Verify the exact hardware model can run the intended release.
- Verify the release is receiving applicable Apple security updates.
- Validate MDM, security tooling, applications, extensions, identity, backup, and recovery behavior before rollout.

## Common compositions

### Windows fleet automation

- `operating-systems/windows-server` or `operating-systems/windows-client`
- `languages/powershell`
- `disciplines/testing`
- `disciplines/application-security`
- `disciplines/observability`
- `profiles/internal-automation`

### Linux fleet configuration

- selected Linux OS package
- `languages/bash` and/or `languages/python`
- `disciplines/ci-cd`
- `disciplines/supply-chain`
- `disciplines/sre`
- `profiles/internal-automation`

### Managed macOS endpoints

- `operating-systems/macos`
- `profiles/desktop-application` where software is deployed
- `disciplines/privacy`
- `disciplines/application-security`
- `disciplines/observability`

### Cross-family migration

- source OS package
- destination OS package
- applicable virtualization or cloud package
- architecture, integration, testing, SRE, documentation, and recovery guidance

## Selection record

Record selected and excluded packages, exact installed OS facts, management authority, environment, target set, lifecycle and support state, update sources, automation language and tool, source/destination for migrations, official sources checked, source-review date, and unresolved compatibility assumptions.
