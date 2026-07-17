---
id: IAC-MAN-001
title: Terraform and OpenTofu Platform Package Manifest
version: 0.2.0
status: baseline
---
# Terraform and OpenTofu Platform Package Manifest

## Required files

- `AGENTS.md`
- `README.md`
- `MANIFEST.md`
- `standards/STATE_BACKEND_STANDARD.md`
- `standards/PLAN_APPLY_STANDARD.md`
- `standards/PROVIDER_MODULE_STANDARD.md`
- `standards/VARIABLES_SECRETS_STANDARD.md`
- `standards/MODULE_DESIGN_STANDARD.md`
- `standards/DRIFT_IMPORT_STANDARD.md`
- `standards/DESTRUCTIVE_CHANGE_STANDARD.md`
- `standards/TESTING_POLICY_STANDARD.md`
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
