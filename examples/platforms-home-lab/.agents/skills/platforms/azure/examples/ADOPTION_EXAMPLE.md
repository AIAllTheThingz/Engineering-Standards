---
id: AZ-EX-001
title: Microsoft Azure Platform Adoption Example
version: 0.2.0
status: baseline
---
# Microsoft Azure Platform Adoption Example

## Fictitious project

This example models a non-production project using the [Microsoft Azure Platform package](../README.md).

No production accounts, subscriptions, projects, clusters, registries, backends, credentials, endpoints, regions, networks, data, or approvals are included.

## Selected standards

- [Governance](https://github.com/AIAllTheThingz/Public-Access-Agents/blob/af649326961de32adcd2c5644c4305fa893d4ade/governance/README.md)
- [Microsoft Azure Platform](../README.md)
- [Terraform and OpenTofu](../../terraform/)
- [Kubernetes](../../kubernetes/)
- [Application Security](https://github.com/AIAllTheThingz/Public-Access-Agents/tree/af649326961de32adcd2c5644c4305fa893d4ade/disciplines/application-security)
- [Site Reliability Engineering](https://github.com/AIAllTheThingz/Public-Access-Agents/tree/af649326961de32adcd2c5644c4305fa893d4ade/disciplines/sre)
- [Privacy and Data Governance](https://github.com/AIAllTheThingz/Public-Access-Agents/tree/af649326961de32adcd2c5644c4305fa893d4ade/disciplines/privacy)

## Project-specific tailoring

The adopting project would declare:

- target structure and ownership
- human and workload identity
- privileged access
- network paths and public exposure
- data, secrets, keys, certificates, and state
- policy and guardrail behavior
- logging, monitoring, alerts, and retention
- deployment, rollout, and recovery
- budgets, quotas, capacity, and scaling
- validation commands
- evidence retention
- reviewers, approvers, and operators

## Example root instruction excerpt

> Use the Microsoft Azure Platform package as a platform overlay. Preserve governance, profile, language, discipline, framework, platform, virtualization, operating-system, and networking requirements. Confirm the target and actor before modification. Review destructive, public, privileged, data, recovery, and cost impact. Verify actual state and record exact evidence.

## Example change workflow

1. Discover target and current state.
2. Classify risk.
3. Render a reviewable plan or configuration.
4. Identify replacements and destructive actions.
5. Define recovery and stop criteria.
6. Obtain authorization.
7. Apply the smallest approved change.
8. Verify actual state, denied behavior, logs, and recovery assumptions.
9. Record limitations and follow-up.

## Non-production warning

This example demonstrates composition only. It does not configure, test, approve, certify, or deploy Microsoft Azure resources.
