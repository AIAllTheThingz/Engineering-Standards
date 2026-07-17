---
id: PLAT-MAN-001
title: Platform Standards Manifest
version: 0.2.0
status: baseline
---
# Platform Standards Manifest

## Collection entry points

- `AGENTS.md`
- `SKILL.md`
- `README.md`
- `MANIFEST.md`
- `PLATFORM_SELECTION_GUIDE.md`
- `SHARED_RESPONSIBILITY_MODEL.md`
- `PLATFORM_CHANGE_LIFECYCLE.md`
- `PLATFORM_DECISION_MATRIX.md`

## Complete platform packages

- `containers`
- `kubernetes`
- `terraform`
- `azure`
- `aws`
- `gcp`

## Complete package requirements

Every package must include:

- `AGENTS.md`
- useful `README.md`
- `MANIFEST.md`
- platform-specific supporting standards
- adoption checklist
- review checklist
- evidence-record template
- adoption example
- stable identifiers
- validation evidence

## Collection acceptance checks

- Every original platform document and rule ID remains present.
- Platform READMEs explain applicability, composition, adoption, validation, evidence, failure modes, and limitations.
- Links resolve.
- Markdown IDs are unique.
- Examples contain no production values or credentials.
- Provider-specific behavior is framed for current official-documentation verification.
- No package claims production readiness or automatic security.
- Repository validation passes.

## Validation

```bash
python tools/validate-standards/validate_repository.py
python tools/check-links/check_links.py
```
