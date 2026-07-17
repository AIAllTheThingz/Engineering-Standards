---
id: VIRT-VSPH-MANIFEST-001
title: VMware vSphere and ESXi Package Manifest
version: 0.2.0
status: baseline
---

# VMware vSphere and ESXi Package Manifest

## Required files

- `AGENTS.md`
- `README.md`
- `MANIFEST.md`
- `standards/OPERATIONS_AND_AUTOMATION_STANDARD.md`
- `standards/POWERCLI_AUTOMATION_STANDARD.md`
- `templates/ADOPTION_CHECKLIST.md`
- `templates/REVIEW_CHECKLIST.md`
- `templates/EVIDENCE_RECORD_TEMPLATE.md`
- `examples/ADOPTION_EXAMPLE.md`

## Acceptance checks

- `AGENTS.md` contains product-specific stable rules and evidence.
- README explains authority, applicability, interfaces, adoption, lifecycle, security, recovery, validation, failure modes, composition, and limitations.
- The operational standard covers discovery through closure.
- The PowerCLI standard covers distribution and module versions, explicit connections, certificates, stable targeting, configuration scope, confirmation, bounded tasks, cleanup, structured evidence, and isolated tests.
- Templates support adoption, review, and evidence.
- The example is fictitious and non-production.
- Official product documentation is linked and current behavior requires revalidation.
- Snapshots or checkpoints are not represented as backups.
- Links resolve and IDs are unique.
- No credential, production identifier, unsupported compatibility claim, or automatic production-readiness claim is present.
- Repository validation passes.
