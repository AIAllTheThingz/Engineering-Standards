---
id: OS-MAN-001
title: Operating-System Standards Manifest
version: 0.1.0
status: baseline
---

# Operating-System Standards Manifest

## Collection entry points

- `AGENTS.md`
- `SKILL.md`
- `README.md`
- `MANIFEST.md`
- `OS_SELECTION_GUIDE.md`
- `SHARED_RESPONSIBILITY_MODEL.md`
- `OS_CHANGE_LIFECYCLE.md`
- `UPGRADE_MIGRATION_DECISION_MATRIX.md`

## Complete operating-system packages

- `windows-server`
- `windows-client`
- `rhel-family`
- `ubuntu`
- `debian`
- `suse-linux-enterprise`
- `oracle-linux`
- `macos`
- `freebsd`

## Complete package requirements

Every package must include:

- `AGENTS.md`
- useful `README.md`
- `MANIFEST.md`
- `standards/OPERATIONS_AND_AUTOMATION_STANDARD.md`
- `templates/ADOPTION_CHECKLIST.md`
- `templates/REVIEW_CHECKLIST.md`
- `templates/EVIDENCE_RECORD_TEMPLATE.md`
- `examples/ADOPTION_EXAMPLE.md`
- stable identifiers and expected evidence
- current authoritative-source guidance
- explicit lifecycle, security, access-preservation, validation, recovery, failure-mode, and completion boundaries

## Collection acceptance checks

- Every declared package exists and is routed exactly once from `SKILL.md`.
- Package READMEs explain applicability, authority, adoption, lifecycle, validation, failure modes, recovery, composition, and limitations.
- Normative requirements are testable and identify expected evidence.
- Links resolve and Markdown IDs are unique.
- Examples use fictitious non-production values and contain no credentials or real device data.
- Product-specific behavior requires current official-documentation verification.
- Legacy, extended-support, and end-of-life boundaries are explicit.
- No package disables a security control merely to achieve configuration success.
- No package claims automatic security, compliance, recoverability, zero downtime, or production readiness.
- Repository validation passes.

## Validation

```bash
python tools/validate-standards/validate_repository.py
python tools/check-links/check_links.py
python tools/validate-skills/validate_skills.py
python tools/validate-all/run_all.py --include-tests
```
