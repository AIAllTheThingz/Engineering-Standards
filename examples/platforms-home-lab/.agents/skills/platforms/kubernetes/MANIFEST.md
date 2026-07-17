---
id: K8S-MAN-001
title: Kubernetes Platform Package Manifest
version: 0.2.0
status: baseline
---
# Kubernetes Platform Package Manifest

## Required files

- `AGENTS.md`
- `README.md`
- `MANIFEST.md`
- `standards/CLUSTER_NAMESPACE_STANDARD.md`
- `standards/WORKLOAD_SECURITY_STANDARD.md`
- `standards/IDENTITY_RBAC_STANDARD.md`
- `standards/NETWORK_INGRESS_STANDARD.md`
- `standards/CONFIG_SECRETS_STANDARD.md`
- `standards/RESOURCES_AVAILABILITY_STANDARD.md`
- `standards/DEPLOYMENT_ROLLOUT_STANDARD.md`
- `standards/OBSERVABILITY_OPERATIONS_STANDARD.md`
- `standards/COMPLETION_EVIDENCE.md`
- `templates/ADOPTION_CHECKLIST.md`
- `templates/REVIEW_CHECKLIST.md`
- `templates/EVIDENCE_RECORD_TEMPLATE.md`
- `examples/ADOPTION_EXAMPLE.md`

## Package acceptance checks

- `AGENTS.md` preserves the original platform document and rule identifiers.
- README explains applicability, composition, adoption, tailoring, validation, failure modes, and limitations.
- Every supporting standard has a unique front-matter identifier.
- Templates remain fictitious and contain no credentials or production values.
- Example links resolve.
- Platform-specific claims are supportable and defer to current official documentation where appropriate.
- Repository validation and relative-link checking pass.
- Package status remains `baseline` until maturity review approves promotion.

## Validation

```bash
python tools/validate-standards/validate_repository.py
python tools/check-links/check_links.py
```

The adopting repository must add executable platform-specific validation.
