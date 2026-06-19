# Governance Architecture

This repository separates authority, instruction, machine-readable contracts, and execution.

1. Applicable law, regulation, contractual requirements, and approved organizational security policy.
2. `governance/ORGANIZATION_CONTRACT.md`.
3. Applicable organization-wide governance documents.
4. `agents/AGENTS_Base.md`.
5. Applicable technology-specific `AGENTS_*.md` files.
6. Repository-root `AGENTS.md`.
7. Directory-local `AGENTS.md`.
8. Task-specific instructions.

Lower-level instructions MAY add detail, stricter validation, local requirements, or technology constraints. They MUST NOT disable mandatory controls, remove completion evidence, bypass testing, authorize prohibited destructive behavior, weaken risk classification, claim validation that did not run, or override organization policy without an approved exception.

Reusable workflows invoke composite actions and produce evidence artifacts for PR enforcement.
