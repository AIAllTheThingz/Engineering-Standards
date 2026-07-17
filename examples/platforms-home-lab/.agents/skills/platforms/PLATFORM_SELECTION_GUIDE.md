---
id: PLAT-SELECT-001
title: Platform Selection Guide
version: 0.2.0
status: baseline
---
# Platform Selection Guide

## Purpose

This guide helps an adopting repository select platform packages based on actual deployment and execution boundaries rather than team preference or fashionable diagrams.

## Selection questions

Ask:

1. Are artifacts built and run as containers?
2. Are workloads scheduled or reconciled by Kubernetes?
3. Is infrastructure declared or changed with Terraform or OpenTofu?
4. Which cloud providers own identity, network, data, logging, recovery, quota, or billing behavior?
5. Which platform is authoritative for each boundary?
6. Which parts are managed by the provider, platform team, application team, or another service?
7. What is the production blast radius?
8. What state, secrets, credentials, keys, certificates, or personal data are involved?
9. What rollback, restore, failover, or recreation path exists?
10. What evidence proves the selected platform controls are implemented?

## Common compositions

### Containerized application

Usually selects:

- Containers
- the application language and framework
- Application Security
- Testing
- Software Supply Chain
- Observability
- Release Engineering
- the hosting platform package

### Kubernetes workload

Usually selects:

- Containers
- Kubernetes
- application language and framework packages
- Application Security
- Architecture
- Testing
- Observability
- SRE
- CI/CD
- Supply Chain
- Release Engineering
- cloud package when the cluster or dependencies use a cloud provider

### Cloud infrastructure as code

Usually selects:

- Terraform and OpenTofu language package
- Terraform and OpenTofu platform package
- selected cloud platform package
- Architecture
- Application Security
- CI/CD
- Testing
- Observability
- SRE
- Release Engineering

### Multi-cloud system

Select each provider package that controls a material boundary. Do not create a vague “cloud-neutral” layer that erases provider-specific identity, network, data, logging, quota, and recovery behavior.

## Selection rule

A platform package applies when that platform controls material execution, deployment, identity, data, network, policy, observability, recovery, or billing behavior.

A platform package does not apply merely because a transitive service, tool, or development environment mentions the platform.

## Omission records

When a plausible platform package is omitted, record:

- why it is not authoritative for the project
- which other package controls the boundary
- who reviewed the decision
- what would trigger re-selection

## Re-selection triggers

Revisit platform selection when:

- deployment target changes
- a container or orchestration layer is introduced
- infrastructure becomes code-managed
- cloud provider or account structure changes
- identity or secret source changes
- public exposure changes
- data location or classification changes
- resilience, recovery, or availability expectations change
- a managed service replaces self-hosted infrastructure
- billing, quota, or operational ownership changes
