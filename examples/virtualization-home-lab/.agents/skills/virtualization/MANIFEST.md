---
id: VIRT-MAN-001
title: Virtualization Standards Manifest
version: 0.2.0
status: baseline
---

# Virtualization Standards Manifest

## Collection entry points

- `AGENTS.md`
- `SKILL.md`
- `README.md`
- `MANIFEST.md`
- `VIRTUALIZATION_SELECTION_GUIDE.md`
- `SHARED_RESPONSIBILITY_MODEL.md`
- `VIRTUALIZATION_CHANGE_LIFECYCLE.md`
- `MIGRATION_DECISION_MATRIX.md`

## Complete virtualization packages

- `vsphere-esxi`
- `xenserver-citrix-hypervisor`
- `proxmox-ve`
- `xcp-ng`
- `kvm-libvirt`
- `nutanix-ahv`
- `microsoft-hyper-v`
- `red-hat-virtualization`
- `oracle-linux-kvm`

## Complete package requirements

Every package must include:

- `AGENTS.md`
- useful `README.md`
- `MANIFEST.md`
- `standards/OPERATIONS_AND_AUTOMATION_STANDARD.md`
- additional interface-specific standards declared by the package manifest when present
- `templates/ADOPTION_CHECKLIST.md`
- `templates/REVIEW_CHECKLIST.md`
- `templates/EVIDENCE_RECORD_TEMPLATE.md`
- `examples/ADOPTION_EXAMPLE.md`
- stable identifiers
- current authoritative-source guidance
- explicit validation, recovery, failure-mode, and completion boundaries

## Collection acceptance checks

- Every declared package exists and is routed exactly once from `SKILL.md`.
- Package READMEs explain applicability, composition, adoption, validation, failure modes, lifecycle, and limitations.
- Normative requirements are testable and identify expected evidence.
- Links resolve and Markdown IDs are unique.
- Examples use fictitious non-production values and contain no credentials.
- Product-specific behavior requires current official-documentation verification.
- Legacy or end-of-life boundaries are explicit.
- No package treats snapshots or checkpoints as backups.
- No package claims automatic security, recoverability, zero downtime, or production readiness.
- Repository validation passes.

## Validation

```bash
python tools/validate-standards/validate_repository.py
python tools/check-links/check_links.py
python tools/validate-skills/validate_skills.py
python tools/validate-all/run_all.py --include-tests
```
