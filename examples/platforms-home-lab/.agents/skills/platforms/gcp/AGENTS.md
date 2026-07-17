---
id: PLAT-GCP
title: Google Cloud Platform Agent Standard
version: 0.2.0
status: baseline
applies_to:
  - gcp
depends_on:
  - GOV-SECDEV
  - GOV-RISK
---
# Google Cloud Platform Agent Standard

## Purpose

This file defines mandatory rules for agents creating, modifying, reviewing, validating, deploying, or documenting Google Cloud Platform platform work.

The package supplements root governance, project profiles, languages, disciplines, frameworks, and project-specific instructions.

> Make the smallest authorized, reviewable, recoverable, observable, and well-documented platform change that satisfies the requirement.

## Scope

This standard applies to:

- Google Cloud organizations, folders, projects, identities, policies, networks, data, resources, and deployments
- service accounts, workload identity, IAM, organization policies, keys, secrets, logs, backups, quotas, and budgets
- gcloud, SDKs, Deployment Manager or successor tooling, Terraform/OpenTofu, console, and deployment automation
- production and non-production projects and cross-project dependencies

## Instruction precedence

1. Applicable governance, legal, contractual, safety, and security obligations
2. Explicit authorized user requirements
3. The nearest more-specific `AGENTS.md`
4. This platform package `AGENTS.md`
5. Referenced project profile, language, discipline, framework, platform, virtualization, operating-system, and networking standards
6. Repository conventions
7. General agent preferences

More-specific instructions may specialize or strengthen applicable controls. They must not silently weaken authorization, identity, network, data, recovery, evidence, or production-readiness requirements.

## Required supporting standards

Read every applicable supporting standard before implementation:

- `standards/ORG_PROJECT_STRUCTURE_STANDARD.md`
- `standards/IDENTITY_ACCESS_STANDARD.md`
- `standards/NETWORK_PERIMETER_STANDARD.md`
- `standards/DATA_KEY_SECRET_STANDARD.md`
- `standards/POLICY_GUARDRAIL_STANDARD.md`
- `standards/LOGGING_MONITORING_STANDARD.md`
- `standards/RESILIENCE_RECOVERY_STANDARD.md`
- `standards/COST_QUOTA_STANDARD.md`
- `standards/COMPLETION_EVIDENCE.md`

## Non-negotiable behavior

- Confirm the target account, subscription, project, cluster, registry, backend, workspace, environment, or equivalent boundary before modification.
- Confirm the actor identity, authorization, and approved scope.
- Inspect current state, drift, dependencies, policies, identities, networks, data, secrets, logs, recovery, quotas, and ownership.
- Do not invent provider behavior, service limits, environment values, credentials, endpoints, regions, accounts, or production facts.
- Treat plans, state, manifests, images, policies, and generated configuration as potentially sensitive.
- Prefer least privilege, short-lived identity, private access, secure defaults, and explicit deny behavior.
- Do not expose secrets through source, images, layers, manifests, plans, state, logs, examples, or command history.
- Identify replacements, deletions, privilege expansion, public exposure, data movement, and irreversible operations before execution.
- Require explicit authorization for destructive, privileged, public, or production-affecting actions.
- Define rollback, roll-forward, restore, failover, recreation, or accepted recovery limitations.
- Verify actual state after change rather than relying only on tool exit status.
- Preserve logging, monitoring, alerting, support ownership, and cost visibility.
- Add or update tests and documentation with behavior changes.
- Record checks not run and remaining risks.
- Never claim production readiness from configuration presence alone.

## Required working method

1. Discover target identity, current state, ownership, and applicable instructions.
2. Classify risk and identify trust, privilege, data, network, state, and recovery boundaries.
3. Define desired state, acceptance criteria, validation, and evidence.
4. Render or generate a reviewable plan, diff, or configuration where supported.
5. Review destructive, replacement, public, privileged, and cost-impacting actions.
6. Obtain authorization proportionate to risk.
7. Execute the narrowest approved change.
8. Verify actual state and denied behavior.
9. Observe health, logs, alerts, recovery, quota, and cost signals.
10. Review the final diff and evidence for unrelated changes, secrets, unsupported assumptions, and limitations.
11. Report exact outcomes, checks not run, and residual risk.

## Preserved mandatory rules

### GCP-ID-001

**Requirement:** Prefer workload identity and short-lived credentials.

**Expected evidence:** Federation, workload identity, service-account, and credential inventory evidence.

### GCP-IAM-002

**Requirement:** Use least-privilege IAM at the narrowest practical scope.

**Expected evidence:** IAM role, binding, condition, inheritance, service-account, and escalation review.

### GCP-NET-003

**Requirement:** Restrict public exposure and define service perimeters or network boundaries where applicable.

**Expected evidence:** Network, firewall, routing, DNS, perimeter, ingress, egress, and denied-path tests.

### GCP-LOG-004

**Requirement:** Enable appropriate audit and service logging.

**Expected evidence:** Audit, service, security, retention, routing, access, and alert evidence.

### GCP-KEY-005

**Requirement:** Use approved secret and key-management services.

**Expected evidence:** Secret, key, certificate, identity, access, rotation, backup, and recovery review.

### GCP-POL-006

**Requirement:** Use organization policies and deployment controls where available.

**Expected evidence:** Organization policy, hierarchy, constraint, exception, remediation, and deployment-gate evidence.

## Decision gates

Stop when:

- target identity is ambiguous
- authorization is absent
- the plan or rendered configuration cannot be reviewed
- destructive or replacement actions are unexplained
- recovery is required but undefined
- credentials or sensitive data would be exposed
- public or privileged access expands without review
- required operational ownership is absent
- actual state cannot be verified

## Completion evidence

Record:

- selected platform and relevant versions or service boundaries
- target and actor identity
- changed files and affected resources
- current and desired state
- plan, rendered configuration, or deployment artifact
- identity, policy, network, data, secret, recovery, and cost impact
- exact validation commands and results
- actual-state verification
- checks not run
- limitations and residual risk
- accountable review and approval

Do not report platform work complete until applicable evidence is recorded and remaining limitations are explicit.
