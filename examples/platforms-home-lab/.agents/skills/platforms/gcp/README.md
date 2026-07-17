---
id: GCP-PKG-001
title: Google Cloud Platform Package
version: 0.2.0
status: baseline
---
# Google Cloud Platform Package

## Purpose

Define secure, governed, observable, resilient, and cost-aware Google Cloud organization and resource behavior.

This package is a project-agnostic platform overlay. It specializes governance and relevant language, framework, discipline, virtualization, operating-system, networking, and profile standards for work on this platform.

Status: **baseline**

A baseline package is usable for adoption and review but must be tailored to real environments, provider behavior, organization policy, operational ownership, and risk.

## When to adopt this package

Adopt this package when one or more of the following are true:

- Google Cloud organizations, folders, projects, identities, policies, networks, data, resources, and deployments
- service accounts, workload identity, IAM, organization policies, keys, secrets, logs, backups, quotas, and budgets
- gcloud, SDKs, Infrastructure Manager, Terraform/OpenTofu, console, and deployment automation
- production and non-production projects and cross-project dependencies

Do not omit it merely because another team “owns the platform.” Shared responsibility requires both sides of a boundary to be explicit.

## What this package does not replace

This package does not replace:

- service-specific current Google Cloud documentation
- language, infrastructure-as-code, container, or Kubernetes packages
- security, architecture, privacy, data, SRE, CI/CD, and release disciplines
- organization-specific resource hierarchy, identity, network, security, and operations strategy

It does not grant access, select production services, configure real infrastructure, or approve a deployment.

## Package structure

```text
platforms/gcp/
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
| [`Organization, Folder, and Project Standard`](standards/ORG_PROJECT_STRUCTURE_STANDARD.md) | Define resource hierarchy, project boundaries, environments, billing, ownership, labels, shared services, and policy inheritance. |
| [`Identity and Access Standard`](standards/IDENTITY_ACCESS_STANDARD.md) | Use federation and workload identity, bounded service accounts, least-privilege IAM, conditions, impersonation, and privileged-access review. |
| [`Network and Service Perimeter Standard`](standards/NETWORK_PERIMETER_STANDARD.md) | Define VPCs, shared networks, firewall policies, routes, DNS, private access, service perimeters, ingress, egress, and tests. |
| [`Data, Key, and Secret Standard`](standards/DATA_KEY_SECRET_STANDARD.md) | Classify data, define encryption, keys, secrets, certificates, rotation, backup, recovery, residency, and access. |
| [`Policy and Guardrail Standard`](standards/POLICY_GUARDRAIL_STANDARD.md) | Use organization policies, hierarchy, deployment controls, security services, exceptions, and remediation. |
| [`Logging and Monitoring Standard`](standards/LOGGING_MONITORING_STANDARD.md) | Define audit, service, security, application, and diagnostic logging, routing, retention, alerts, access, and ownership. |
| [`Resilience and Recovery Standard`](standards/RESILIENCE_RECOVERY_STANDARD.md) | Define regions, zones, redundancy, backup, restore, failover, dependency failure, quotas, and tested recovery objectives. |
| [`Cost, Capacity, and Quota Standard`](standards/COST_QUOTA_STANDARD.md) | Define billing ownership, budgets, labels, commitments where appropriate, quotas, scaling, anomaly detection, and lifecycle controls. |
| [`Google Cloud Completion Evidence`](standards/COMPLETION_EVIDENCE.md) | Record hierarchy scope, identities, IAM, network, data, policies, logs, resilience, cost, deployment, validation, and limitations. |

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
- review federation, service accounts, IAM bindings, conditions, and privileged access
- test required and denied network and perimeter paths
- verify audit, service, security logs, alerts, routing, and retention
- exercise backup, restore, failover, and recovery where applicable
- review budgets, quotas, scaling, organization policies, and exceptions

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

- creating long-lived service-account keys for workloads
- granting primitive or broad roles at organization or project scope without justification
- exposing services publicly while assuming authentication alone is a network boundary
- omitting required audit logs or routing them without retention and ownership
- using keys and secrets without rotation, backup, and access review
- creating projects without hierarchy, billing, policy, and operational ownership

Other recurring failures include copying examples into production, relying on undocumented defaults, changing the wrong environment, and claiming readiness without operational evidence.

## Companion packages

This platform commonly composes with:

- [Terraform and OpenTofu](../terraform/)
- [Kubernetes](../kubernetes/)
- [Application Security](https://github.com/AIAllTheThingz/Public-Access-Agents/tree/af649326961de32adcd2c5644c4305fa893d4ade/disciplines/application-security)
- [Site Reliability Engineering](https://github.com/AIAllTheThingz/Public-Access-Agents/tree/af649326961de32adcd2c5644c4305fa893d4ade/disciplines/sre)
- [Data Engineering](https://github.com/AIAllTheThingz/Public-Access-Agents/tree/af649326961de32adcd2c5644c4305fa893d4ade/disciplines/data-engineering)

Companion packages supplement this platform overlay. They do not replace its applicable rules.

## Templates and example

- [`ADOPTION_CHECKLIST.md`](templates/ADOPTION_CHECKLIST.md)
- [`REVIEW_CHECKLIST.md`](templates/REVIEW_CHECKLIST.md)
- [`EVIDENCE_RECORD_TEMPLATE.md`](templates/EVIDENCE_RECORD_TEMPLATE.md)
- [`ADOPTION_EXAMPLE.md`](examples/ADOPTION_EXAMPLE.md)

Templates are starting points. Replace blank fields with reviewed project facts and never insert production secrets into public examples.

## Current official references

Service-specific behavior changes. Verify adopting-project decisions against current official documentation:

- https://cloud.google.com/architecture/framework
- https://cloud.google.com/infrastructure-manager/docs/deploy-resources
- https://cloud.google.com/deployment-manager/docs/deprecations

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
