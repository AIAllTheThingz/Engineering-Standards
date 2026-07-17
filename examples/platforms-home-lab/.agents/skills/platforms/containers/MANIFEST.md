---
id: CONT-MAN-001
title: Container Platform Package Manifest
version: 0.2.0
status: baseline
---
# Container Platform Package Manifest

## Required files

- `AGENTS.md`
- `README.md`
- `MANIFEST.md`
- `standards/IMAGE_BASE_STANDARD.md`
- `standards/BUILD_REPRODUCIBILITY_STANDARD.md`
- `standards/RUNTIME_SECURITY_STANDARD.md`
- `standards/SECRETS_CONFIGURATION_STANDARD.md`
- `standards/NETWORK_FILESYSTEM_STANDARD.md`
- `standards/HEALTH_LIFECYCLE_STANDARD.md`
- `standards/SUPPLY_CHAIN_SCANNING_STANDARD.md`
- `standards/RESOURCE_OBSERVABILITY_STANDARD.md`
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
