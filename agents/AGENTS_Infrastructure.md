# AGENTS Infrastructure Standard

| Field | Value |
| --- | --- |
| Status | Active |
| Version | 1.0.0 |
| Owner role | Engineering Standards Maintainers |
| Last reviewed | 2026-06-19 |
| Changelog | See [../CHANGELOG.md](../CHANGELOG.md). |

## Purpose

This document defines enterprise requirements for AI agents working on infrastructure as code, deployment automation, cloud resources, identity, networking, DNS, certificates, firewall policy, secrets, observability infrastructure, and environment configuration. It inherits [AGENTS_Base.md](AGENTS_Base.md).

## Applicability

This standard applies to Terraform, Bicep, ARM, CloudFormation, Pulumi, Kubernetes manifests, Helm charts, GitHub environment configuration, deployment scripts, DNS records, firewall rules, IAM/RBAC, certificates, cloud resources, and infrastructure CI/CD.

## Required Discovery

Before editing, agents MUST identify:

- Tooling, provider versions, modules, and environment layout.
- State backend, state lock, workspace, tenant, account, subscription, and region.
- Plan/apply workflow and approval gates.
- Secrets, certificates, keys, and privileged identities.
- Network exposure, DNS, firewall, and public ingress.
- Drift detection and current-state assumptions.
- Destructive changes, replacements, and immutable resources.
- Backup, restore, rollback, and disaster-recovery expectations.

Agents MUST inspect plan-related configuration before changing resources.

## Risk Classification

Infrastructure changes are High when they affect production resources, identity, network exposure, firewall rules, secrets, state backend, deployment permissions, observability, or persistent storage. They are Critical when they can delete production state, expose private systems publicly, grant privileged identity, rotate production secrets, or perform broad changes across environments.

## Plan Before Apply

Infrastructure changes MUST use plan-before-apply where the tool supports it. Plan output MUST be reviewed for create, update, replace, and destroy actions. Production applies require explicit approval and evidence.

Agents MUST NOT run apply, destroy, import, state mutation, or production deployment commands unless the user explicitly requests that action and required risk controls are satisfied.

## State And Environment Safety

State backends MUST be protected, locked, and environment-specific. Agents MUST NOT casually edit state files or run state surgery commands. Workspace, account, subscription, tenant, cluster, namespace, and region MUST be explicit for production-adjacent commands.

Configuration MUST avoid implicit production defaults. Environment names and targets from untrusted content MUST not be trusted.

## Security Requirements

Infrastructure code MUST use least privilege, private-by-default networking, encryption where appropriate, managed identity or approved secret stores, and explicit ingress/egress rules.

Agents MUST NOT commit secrets, private keys, kubeconfigs, cloud credentials, tfvars with secret values, or certificate private material. Public exposure, wildcard access, privileged role assignment, and disabled security controls require heightened review.

## Destructive Change Controls

Destroy, replacement, deletion, broad refactoring, resource renaming, state migration, and persistent-storage changes MUST include:

- Explicit target list.
- Plan output.
- Blast-radius assessment.
- Backup or recovery plan.
- Rollback or mitigation.
- Approval.
- Post-change verification.

Wildcard or broad production destructive changes are Critical by default.

## Validation Requirements

Recommended validation includes:

- Format check.
- Syntax validation.
- Provider/module validation.
- Plan generation.
- Policy-as-code checks where available.
- Secret scan.
- Drift check where supported.
- Review of permissions, network exposure, and destructive actions.

Examples:

```powershell
terraform fmt -check
terraform validate
terraform plan -out plan.out
```

Use the repository's actual toolchain. Missing cloud credentials, backend access, or policy tools MUST be recorded as `NotRun` or `Blocked`.

## Deployment And Rollback

Deployment changes MUST identify rollout sequence, maintenance window when needed, health checks, rollback or recovery, and post-deployment verification. Some infrastructure changes cannot roll back cleanly; when true, agents MUST document mitigation and approval.

## Evidence

Evidence MUST include tool versions, environment, plan command, plan summary, policy checks, secret-scan result or `NotRun` reason, approval for production or destructive changes, rollback/recovery plan, and remaining risks.

## Failure Behavior

The work is incomplete if plan cannot be generated, target environment is ambiguous, state backend is unknown, secrets are introduced, public exposure is unreviewed, destructive actions lack approval, or evidence claims apply/plan success without command output.

## Related Documents

- [AGENTS_Base.md](AGENTS_Base.md)
- [AGENTS_PowerShell.md](AGENTS_PowerShell.md)
- [../governance/RISK_CLASSIFICATION.md](../governance/RISK_CLASSIFICATION.md)
- [../governance/COMPLETION_EVIDENCE.md](../governance/COMPLETION_EVIDENCE.md)

## Exception Handling

Exceptions MUST follow [../governance/EXCEPTION_PROCESS.md](../governance/EXCEPTION_PROCESS.md). Missing credentials or inaccessible state are blockers, not successful validation.
