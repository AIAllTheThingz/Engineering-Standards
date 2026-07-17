---
id: PLAT-INDEX-001
title: Platform Standards
version: 0.2.0
status: baseline
---
# Platform Standards

Use [`SKILL.md`](SKILL.md) when an agent must select and apply these platform packages during infrastructure or deployment design, implementation, review, validation, troubleshooting, or migration work.

## Purpose

Platform packages define controls for the environments that build, deploy, execute, connect, store, observe, recover, and bill software and infrastructure.

They answer questions that language and framework standards cannot answer alone:

- Which account, subscription, project, cluster, registry, workspace, or backend is the target?
- Which identity is allowed to act?
- What may be public?
- Where do secrets, keys, certificates, state, and data live?
- Which policies and guardrails apply?
- How are changes planned, authorized, applied, verified, and recovered?
- Which logs, metrics, alerts, budgets, quotas, and operators exist?
- What proves that a provider feature is actually configured?
- Who owns the boundary after deployment?

A platform package is an overlay. It supplements governance, project profiles, languages, disciplines, frameworks, and project-specific instructions.

## Platform catalog

| Platform | Purpose |
|---|---|
| [Containers](containers/) | Define secure, reproducible, minimal, observable, and supportable container image and runtime behavior. |
| [Kubernetes](kubernetes/) | Define secure, isolated, observable, resilient, and reviewable Kubernetes workload and cluster-facing configuration. |
| [Terraform and OpenTofu](terraform/) | Define safe, reviewable, reproducible, and recoverable infrastructure-as-code planning and execution. |
| [Microsoft Azure](azure/) | Define secure, governed, observable, resilient, and cost-aware Azure resource design and change behavior. |
| [Amazon Web Services](aws/) | Define secure, governed, observable, resilient, and cost-aware AWS account and resource behavior. |
| [Google Cloud Platform](gcp/) | Define secure, governed, observable, resilient, and cost-aware Google Cloud organization and resource behavior. |

## What a complete platform package contains

```text
platform/
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

- `AGENTS.md` is the normative entry point.
- `README.md` explains scope, selection, adoption, tailoring, validation, failure modes, and limitations.
- `MANIFEST.md` defines required files and acceptance checks.
- `standards/` contains platform-specific controls.
- `templates/` supports adoption, review, and evidence.
- `examples/` demonstrates composition using fictitious values.

## Selection model

Use [PLATFORM_SELECTION_GUIDE.md](PLATFORM_SELECTION_GUIDE.md).

Select a platform package when the platform controls material:

- execution
- deployment
- identity
- network
- data
- secret or key storage
- infrastructure state
- policy enforcement
- observability
- availability or recovery
- capacity, quota, or cost

Multiple packages commonly apply. A Kubernetes workload in Azure may require Containers, Kubernetes, Azure, and Terraform/OpenTofu. Removing one layer from the standards list does not remove the layer from reality, which remains stubbornly uncooperative.

## Composition model

A typical platform composition includes:

```text
governance
+ project profile
+ language package
+ framework package
+ discipline packages
+ container or orchestration platform
+ infrastructure-as-code platform
+ cloud platform
+ project-specific root and nested instructions
```

Each layer has a different responsibility:

- governance controls authority, risk, evidence, exceptions, and production readiness
- profiles describe project shape
- languages and frameworks govern implementation
- disciplines govern cross-cutting engineering work
- platforms govern execution and deployment boundaries
- project instructions declare actual targets, constraints, owners, and validation

## Shared responsibility

Use [SHARED_RESPONSIBILITY_MODEL.md](SHARED_RESPONSIBILITY_MODEL.md).

Every material control needs an owner. “The provider handles it” is incomplete unless the provider-managed boundary and customer-controlled configuration are both understood.

## Platform change lifecycle

Use [PLATFORM_CHANGE_LIFECYCLE.md](PLATFORM_CHANGE_LIFECYCLE.md).

Platform changes must distinguish:

- discovery
- desired state
- plan or rendered configuration
- authorization
- execution
- actual-state verification
- operational observation
- closure and follow-up

A successful CLI exit code proves that a process exited successfully. It does not prove that the correct account was changed, the network remained private, the logs arrived, the backup restores, or the bill will remain civilized.

## Identity and authorization

Platform adoption must define:

- human federation
- workload identity
- service accounts, roles, or managed identities
- privileged and emergency access
- credential lifetime
- role and policy scope
- approval for consequential execution
- access review and removal
- audit evidence

Prefer short-lived, workload-bound credentials. Long-lived credentials have an unfortunate habit of becoming institutional fossils.

## Network and exposure

Declare:

- public endpoints
- private endpoints
- ingress and egress
- routing
- DNS
- firewalls, security groups, or policies
- service-to-service paths
- administrative access
- denied paths
- inspection and logging
- ownership

Test required and denied paths. A diagram with arrows is not a network test.

## Data, secrets, keys, and certificates

Declare:

- classification
- location and residency
- access
- encryption
- key ownership
- secret source
- certificate lifecycle
- backup and restore
- retention and deletion
- logging boundaries
- rotation and recovery

Do not place secrets in source, images, manifests, plans, state, logs, examples, or command history.

## Observability and operations

Platform evidence should cover:

- audit logs
- configuration history
- service logs
- metrics and traces
- health and readiness
- alerts and dashboards
- retention and access
- cost and quota signals
- runbooks
- escalation
- operational owner

Telemetry that nobody owns is merely expensive historical fiction.

## Resilience and recovery

Define:

- failure domains
- redundancy
- backup
- restore
- failover
- rollback or roll-forward
- recreation
- recovery objectives
- dependency failure
- migration recovery
- test schedule
- owner

Provider availability claims do not prove that the project configured, tested, or can operate the relevant features.

## Cost, capacity, and quotas

Review:

- ownership and tagging or labeling
- budgets and alerts
- quota and service limits
- capacity assumptions
- scaling
- lifecycle and unused resources
- data transfer
- commitments where applicable
- anomaly handling
- non-production shutdown

Cost is an operational property. Ignoring it does not make it nonfunctional; it merely gives finance a surprise later.

## Adoption procedure

1. Read root governance and this collection `AGENTS.md`.
2. Select the project profile.
3. Identify every authoritative platform boundary.
4. Select complete platform packages.
5. Select relevant language, framework, discipline, virtualization, operating-system, and networking packages.
6. Assign platform, application, security, data, operations, and cost owners.
7. Declare exact supported tools, providers, environments, and constraints.
8. Complete package adoption checklists.
9. Define project-specific validation and evidence.
10. Review public exposure, privilege, data, recovery, and destructive impact.
11. Validate repository structure and links.
12. Obtain accountable review.

## Tailoring rules

Tailoring may:

- declare exact accounts, environments, regions, tools, and versions in the adopting private repository
- identify approved services and patterns
- add stricter security and recovery controls
- define commands and evidence
- mark inapplicable rules with justification
- add nested platform instructions

Tailoring must not:

- add credentials or sensitive values to public standards
- weaken governance or authorization silently
- assume provider defaults are secure or enabled
- remove recovery, logging, cost, or ownership because a service is managed
- claim compatibility, resilience, or production readiness without evidence
- turn an example into production configuration by changing only the name

## Evidence model

Platform evidence should identify:

- target identity
- actor identity
- artifact, configuration, plan, or manifest
- current and desired state
- created, changed, replaced, and destroyed resources
- identity and policy impact
- network and data impact
- secret and key impact
- validation commands and results
- actual-state verification
- recovery evidence
- observability evidence
- cost and quota review
- checks not run
- limitations and residual risk
- reviewers and approvers

## Validation

From the repository root:

```bash
python tools/validate-standards/validate_repository.py
python tools/check-links/check_links.py
```

An adopting project must also run current platform and provider validation appropriate to its actual targets.

## Maturity

All platform packages are currently `baseline`.

A baseline package is usable for adoption and review but should continue to mature through real implementation feedback, provider documentation review, incident learning, and compatibility testing.

## Maintaining platform packages

A platform-package change must:

- preserve stable IDs unless migration is approved
- update README, manifest, standards, templates, and examples together
- verify current provider or project documentation where behavior is service-specific
- disclose compatibility and migration impact
- validate links and identifiers
- state checks not run
- avoid unsupported claims about defaults or production readiness

## Non-production boundary

These packages do not configure accounts, subscriptions, projects, clusters, state backends, registries, networks, identities, secrets, data stores, budgets, or production approvals. They define reusable standards. The adopting organization must supply real facts, authority, evidence, and judgment.
