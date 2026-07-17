---
id: K8S-TPL-ADOPT-001
title: Kubernetes Platform Adoption Checklist
version: 0.2.0
status: baseline
---
# Kubernetes Platform Adoption Checklist

## Selection

- [ ] This platform controls a material project boundary.
- [ ] The project profile is selected.
- [ ] Applicable language, framework, discipline, companion platform, virtualization, operating-system, and networking packages are selected or explicitly omitted.
- [ ] Shared responsibility is documented.

## Target and authority

- [ ] Target account, subscription, project, cluster, registry, backend, workspace, or environment is identified.
- [ ] Human and workload identities are defined.
- [ ] Privileged and emergency access are defined.
- [ ] Consequential execution requires explicit authorization.

## Security and data

- [ ] Least-privilege access is reviewed.
- [ ] Public and private network paths are documented.
- [ ] Data classification and location are documented.
- [ ] Secrets, keys, certificates, and state are protected.
- [ ] Logging avoids sensitive data.

## Reliability and operations

- [ ] Deployment and rollout behavior are defined.
- [ ] Rollback, restore, failover, or recreation is defined.
- [ ] Logs, metrics, alerts, dashboards, and runbooks have owners.
- [ ] Capacity, quotas, limits, budgets, and scaling are reviewed.
- [ ] Support and escalation ownership are assigned.

## Validation and evidence

- [ ] Project-specific commands are documented.
- [ ] Allowed and denied behavior is tested.
- [ ] Actual state is verified.
- [ ] Checks not run are disclosed.
- [ ] Limitations and residual risk are recorded.
- [ ] Accountable review is complete.

## Related guidance

- [Package README](../README.md)
- [Shared Responsibility Model](../../SHARED_RESPONSIBILITY_MODEL.md)
- [Platform Change Lifecycle](../../PLATFORM_CHANGE_LIFECYCLE.md)
