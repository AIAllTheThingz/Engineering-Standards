---
id: AZ-PKG-001
title: Microsoft Azure Platform Package
version: 0.2.0
status: baseline
---
# Microsoft Azure Platform Package

## Purpose

Define secure, governed, observable, resilient, and cost-aware Azure resource design and change behavior.

This package is a project-agnostic platform overlay. It specializes governance and relevant language, framework, discipline, virtualization, operating-system, networking, and profile standards for work on this platform.

Status: **baseline**

A baseline package is usable for adoption and review but must be tailored to real environments, provider behavior, organization policy, operational ownership, and risk.

## When to adopt this package

Adopt this package when one or more of the following are true:

- Azure tenants, management groups, subscriptions, resource groups, resources, identities, policies, and deployments
- network, data, key, secret, logging, monitoring, resilience, quota, and cost controls
- Azure CLI, PowerShell, SDK, ARM, Bicep, Terraform/OpenTofu, portal, and deployment automation
- production and non-production Azure environments and cross-subscription dependencies

Do not omit it merely because another team “owns the platform.” Shared responsibility requires both sides of a boundary to be explicit.

## What this package does not replace

This package does not replace:

- service-specific current Azure documentation
- language, infrastructure-as-code, container, or Kubernetes packages
- security, architecture, privacy, data, SRE, CI/CD, and release disciplines
- tenant-specific policy, landing-zone, identity, network, and operations decisions

It does not grant access, select production services, configure real infrastructure, or approve a deployment.

## Package structure

```text
platforms/azure/
├── AGENTS.md
├── README.md
├── MANIFEST.md
├── standards/
├── templates/
│   ├── ADOPTION_CHECKLIST.md
│   ├── REVIEW_CHECKLIST.md
│   └── EVIDENCE_RECORD_TEMPLATE.md
└── examples/
    └── ADOPTION_EXAMPLE.md
```

## Normative entry point

Start with [`AGENTS.md`](AGENTS.md). It preserves the platform's mandatory rule identifiers, defines working behavior, and points to supporting standards.

[`MANIFEST.md`](MANIFEST.md) defines required files and package acceptance checks.

## Supporting standards

| Standard | Purpose |
|---|---|
| [`Tenant, Subscription, and Resource Organization Standard`](standards/RESOURCE_ORGANIZATION_STANDARD.md) | Define tenant, management group, subscription, resource-group, naming, tagging, ownership, environment, and policy boundaries. |
| [`Identity and Access Standard`](standards/IDENTITY_ACCESS_STANDARD.md) | Use managed identities and federation, least-privilege RBAC, privileged access, conditional controls, and reviewable role scope. |
| [`Network Boundary Standard`](standards/NETWORK_BOUNDARY_STANDARD.md) | Define public and private access, virtual networks, routing, DNS, firewalls, endpoints, ingress, egress, and trust-boundary tests. |
| [`Data, Key, and Secret Standard`](standards/DATA_KEY_SECRET_STANDARD.md) | Classify data, define encryption, keys, secrets, certificates, rotation, backup, recovery, and access. |
| [`Policy and Governance Standard`](standards/POLICY_GOVERNANCE_STANDARD.md) | Use management hierarchy, Azure Policy, deployment controls, exemptions, remediation, resource locks, and change traceability. |
| [`Logging and Monitoring Standard`](standards/LOGGING_MONITORING_STANDARD.md) | Define activity, resource, security, application, and diagnostic logging, retention, alerts, access, and operational ownership. |
| [`Resilience and Recovery Standard`](standards/RESILIENCE_RECOVERY_STANDARD.md) | Define regions, zones, redundancy, backup, restore, failover, dependency failure, quotas, and tested recovery objectives. |
| [`Cost, Capacity, and Quota Standard`](standards/COST_QUOTA_STANDARD.md) | Define budgets, tags, ownership, reservations or commitments where applicable, quotas, scaling, anomaly detection, and shutdown policy. |
| [`Azure Completion Evidence`](standards/COMPLETION_EVIDENCE.md) | Record scope, identities, RBAC, network, data, policy, logs, resilience, cost, deployment, validation, and limitations. |

## Adoption workflow

1. Read root governance and the [platform collection guide](../README.md).
2. Select the project profile.
3. Confirm this platform controls a material boundary.
4. Select applicable language, framework, discipline, companion platform, virtualization, operating-system, and networking packages.
5. Copy or compose the complete package.
6. Preserve stable identifiers.
7. Declare exact target types, tools, versions, environments, identities, and ownership.
8. Complete the adoption checklist.
9. Define executable project validation.
10. Review destructive, privileged, public, data, recovery, cost, and quota impact.
11. Obtain accountable review.
12. Record limitations and exceptions.

## Project tailoring checklist

Before adoption, define:

- platform boundary and authoritative target
- account, subscription, project, cluster, registry, backend, workspace, or environment structure
- human and workload identity
- privileged and emergency access
- public and private network paths
- data classification, location, encryption, retention, and recovery
- secret, key, and certificate ownership
- policy, admission, guardrail, drift, and exception handling
- logging, monitoring, alerts, dashboards, and retention
- deployment, rollout, migration, and rollback
- backup, restore, failover, recreation, and recovery objectives
- budgets, cost ownership, quotas, limits, and scaling
- test environments and validation commands
- artifact, configuration, state, plan, and evidence retention
- reviewers, approvers, operators, and escalation
- supported versions and migration commitments

## Identity and authorization expectations

- Prefer short-lived, federated, workload-bound credentials.
- Use least privilege at the narrowest practical scope.
- Separate planning, review, and privileged execution where practical.
- Review inherited, resource-based, custom, emergency, and escalation permissions.
- Record the actor, target, scope, and authorization for consequential work.
- Remove access that is obsolete or broader than required.
- Do not let an agent approve its own privileged or production-affecting action.

## Network and exposure expectations

- Declare every required public and private path.
- Minimize public exposure.
- Control ingress and egress.
- Define DNS, routing, firewalls, policies, endpoints, and administrative paths.
- Test required paths and denied paths.
- Record ownership and operational visibility.
- Do not treat authentication as a substitute for a network boundary.

## Data, secret, key, and state expectations

- Classify sensitive data and platform state.
- Define location, access, encryption, backup, restore, retention, deletion, and residency where applicable.
- Keep secrets out of committed configuration, images, plans, state exports, logs, and examples.
- Define key, certificate, and secret rotation.
- Protect plans, manifests, state, and diagnostic artifacts when they contain sensitive values.
- Test recovery rather than assuming the provider or tool performs it automatically.

## Change and recovery expectations

The project must define:

- current-state discovery
- desired state
- plan or rendered configuration
- authorization
- execution identity
- rollout and stop criteria
- replacement and destructive action handling
- migration ordering
- rollback, roll-forward, restore, failover, or recreation
- actual-state verification
- monitoring period
- incident and escalation path

Use [PLATFORM_CHANGE_LIFECYCLE.md](../PLATFORM_CHANGE_LIFECYCLE.md).

## Observability and operations

Define:

- audit and configuration history
- application and service logs
- metrics and traces
- health and readiness
- alerts and dashboards
- retention and access
- runbooks and escalation
- operational owner
- cost and quota signals
- evidence that telemetry reaches the intended destination

## Cost, capacity, and quota expectations

- Assign cost ownership.
- Use tags or labels consistently where supported.
- Define budgets and anomaly response.
- Review quota and service limits before production dependence.
- Define scaling and saturation behavior.
- Remove or suspend unused resources safely.
- Review data transfer and retained storage.
- Record expected material cost changes.

## Testing expectations

Platform testing should cover:

- configuration and schema validation
- identity and authorization
- allowed and denied network paths
- secret and key access
- policy and guardrail behavior
- deployment and rollout
- replacement and destructive changes
- failure and recovery
- logs, alerts, and operational signals
- drift and reconciliation
- quota, capacity, and scaling assumptions
- cost-impact review

Do not substitute a successful deployment command for actual-state, recovery, security, and operational validation.

## Suggested validation

Use repository-defined commands and current provider or platform tooling. Typical validation includes:

- validate deployment definitions and effective resource configuration
- review identities, RBAC, privileged access, and inherited permissions
- test required and denied network paths
- verify logging, alerts, dashboards, and retention
- exercise backup, restore, failover, and recovery where applicable
- review budgets, quotas, scaling, policy compliance, and exceptions

Record commands exactly and distinguish passed, failed, partially validated, and not-run checks.

## Completion evidence

Use [`templates/EVIDENCE_RECORD_TEMPLATE.md`](templates/EVIDENCE_RECORD_TEMPLATE.md) and [`standards/COMPLETION_EVIDENCE.md`](standards/COMPLETION_EVIDENCE.md).

Evidence should include:

- target and actor identity
- selected tools, versions, and service boundaries
- configuration, plan, state, manifest, image, or artifact identity
- changed, replaced, and destroyed resources
- identity, network, data, secret, policy, recovery, cost, and quota impact
- validation commands and results
- actual-state verification
- operational evidence
- checks not run
- limitations and residual risk
- reviewer and approver

## Common failure modes

- using long-lived client secrets where managed identity or federation is available
- assigning broad roles at subscription scope without justification
- exposing services publicly because private connectivity was inconvenient
- creating resources without diagnostic settings or an operational owner
- using policy exemptions without owner, reason, expiry, and remediation
- claiming resilience because a service has an availability option that was never configured or tested

Other recurring failures include copying examples into production, relying on undocumented defaults, changing the wrong environment, and claiming readiness without operational evidence.

## Companion packages

This platform commonly composes with:

- [Terraform and OpenTofu](../terraform/)
- [Kubernetes](../kubernetes/)
- [Application Security](https://github.com/AIAllTheThingz/Public-Access-Agents/tree/af649326961de32adcd2c5644c4305fa893d4ade/disciplines/application-security)
- [Site Reliability Engineering](https://github.com/AIAllTheThingz/Public-Access-Agents/tree/af649326961de32adcd2c5644c4305fa893d4ade/disciplines/sre)
- [Privacy and Data Governance](https://github.com/AIAllTheThingz/Public-Access-Agents/tree/af649326961de32adcd2c5644c4305fa893d4ade/disciplines/privacy)

Companion packages supplement this platform overlay. They do not replace its applicable rules.

## Templates and example

- [`ADOPTION_CHECKLIST.md`](templates/ADOPTION_CHECKLIST.md)
- [`REVIEW_CHECKLIST.md`](templates/REVIEW_CHECKLIST.md)
- [`EVIDENCE_RECORD_TEMPLATE.md`](templates/EVIDENCE_RECORD_TEMPLATE.md)
- [`ADOPTION_EXAMPLE.md`](examples/ADOPTION_EXAMPLE.md)

Templates are starting points. Replace blank fields with reviewed project facts and never insert production secrets into public examples.

## Current official references

Service-specific behavior changes. Verify adopting-project decisions against current official documentation:

- https://learn.microsoft.com/azure/well-architected/

## Maintaining the package

Changes must:

- preserve stable identifiers unless migration is approved
- update README, manifest, standards, templates, and example together
- verify service-specific claims against current official documentation
- disclose compatibility and migration impact
- keep requirements specific and testable
- validate links and identifiers
- state checks not run
- avoid unsupported claims about defaults, security, resilience, or production readiness

## Completion boundary

Adopting this package does not prove that the resulting infrastructure or workloads are secure, private, resilient, observable, cost-controlled, recoverable, compatible, or production-ready. Completion requires implementation, validation, evidence, and accountable review.
