---
id: PLAT-AGENT-001
title: Platform Standards Agent Instructions
version: 0.2.0
status: baseline
---
# Platform Standards Agent Instructions

## Purpose

These instructions govern agents that create, modify, review, organize, or document platform standards, templates, manifests, and examples under this directory.

Platform changes can alter identity, network exposure, data handling, infrastructure state, availability, recovery, cost, operational ownership, and production blast radius. Treat them as operational and security changes, not as decorative deployment configuration.

## Scope

These instructions apply to:

- container image and runtime standards
- Kubernetes workload and cluster-facing standards
- Terraform and OpenTofu execution standards
- Microsoft Azure, Amazon Web Services, and Google Cloud standards
- platform adoption, review, and evidence templates
- platform examples and manifests
- references from governance, disciplines, frameworks, profiles, and examples

## Instruction precedence

Authority and obligations are controlled by root governance. Within that boundary:

1. Explicit authorized user requirements
2. The nearest applicable `AGENTS.md`
3. This platform `AGENTS.md`
4. The selected platform package `AGENTS.md`
5. Referenced governance, profile, language, discipline, framework, virtualization, operating-system, and networking standards
6. Repository conventions
7. General agent preferences

More-specific instructions may specialize or strengthen applicable requirements. They must not silently weaken parent governance, authorization, security, evidence, or production-readiness controls.

## Required reading

Before modifying platform standards:

- [README.md](README.md)
- [MANIFEST.md](MANIFEST.md)
- [PLATFORM_SELECTION_GUIDE.md](PLATFORM_SELECTION_GUIDE.md)
- [SHARED_RESPONSIBILITY_MODEL.md](SHARED_RESPONSIBILITY_MODEL.md)
- [PLATFORM_CHANGE_LIFECYCLE.md](PLATFORM_CHANGE_LIFECYCLE.md)
- [PLATFORM_DECISION_MATRIX.md](PLATFORM_DECISION_MATRIX.md)
- the affected package `AGENTS.md`, README, manifest, standards, templates, and example

Read relevant governance and discipline packages before changing security, identity, data, networking, observability, resilience, cost, or release requirements.

## Non-negotiable editing rules

- Preserve stable document and rule identifiers unless an approved breaking change includes migration.
- Do not invent cloud accounts, subscriptions, projects, tenants, clusters, registries, endpoints, identities, credentials, regions, networks, data classifications, quotas, or service limits.
- Keep service-specific claims generic unless they are verified against current official provider documentation.
- Do not imply that a platform feature is configured merely because the provider offers it.
- Do not weaken identity, network, secret, logging, recovery, or approval controls to simplify an example.
- Do not make a tool-generated plan, manifest, or policy result equivalent to production approval.
- Do not allow an agent or automation to authorize its own privileged, destructive, public, or production-affecting work.
- Keep examples fictitious and explicitly non-production.
- Do not expose credentials, tokens, private keys, connection strings, personal data, internal identifiers, or exploitable infrastructure details.
- Update cross-references, manifests, templates, examples, and migration guidance with package changes.
- Record checks not run, unsupported environments, and residual risk.

## Required working method

1. Identify the platform boundary and affected environments.
2. Confirm authority, target identity, and current state before modification.
3. Inspect architecture, deployment definitions, state, policies, identities, networks, data, observability, recovery, and tests.
4. Classify risk and identify destructive, privileged, public, or hard-to-reverse actions.
5. Define acceptance criteria, validation, rollback or recovery, and evidence.
6. Make the smallest coherent standards change.
7. Preserve existing rule IDs and semantics unless change is explicit.
8. Update templates and examples so they remain consistent.
9. Validate links, IDs, JSON, manifests, and package structure.
10. Review the final diff for hidden weakening, unsupported provider claims, unresolved placeholders, and production values.
11. Record compatibility, migration, evidence, and limitations.

## Platform-standard quality

A platform standard should define:

- applicability and supported boundary
- owner and accountable roles
- identity and authorization expectations
- network and exposure expectations
- data, secret, key, and certificate handling
- configuration and policy enforcement
- observability and audit evidence
- availability, recovery, and failure behavior
- cost, capacity, and quota considerations
- change, rollout, rollback, and drift handling
- required validation and completion evidence
- exception and review boundaries

Avoid vague instructions such as “secure the resource,” “follow cloud best practices,” or “enable monitoring” without stating ownership, evidence, and expected behavior.

## Current documentation

Cloud and platform services change. When a rule depends on provider-specific behavior:

- verify the behavior against current official documentation
- identify the service and feature boundary
- avoid unsupported assumptions about defaults
- record version, region, edition, feature, or compatibility constraints where relevant
- state when an adopting project must revalidate the rule

## Validation

Run from the repository root:

```bash
python tools/validate-standards/validate_repository.py
python tools/check-links/check_links.py
```

Also perform a human-readable review for:

- conflicting platform and governance authority
- incorrect relative links
- stale provider terminology
- unsupported default or compatibility claims
- missing ownership
- hidden public exposure
- unbounded privilege
- false production-readiness claims
- unresolved placeholders
- grammar and ambiguity

## Completion gate

Platform standards work is incomplete until:

- affected IDs and links are valid
- README, manifest, standards, templates, and examples agree
- original rules are preserved or migration is documented
- no credentials or production-specific values are present
- provider-specific claims are supportable
- validation evidence is recorded
- unresolved authority, target, recovery, cost, or compatibility questions are disclosed
