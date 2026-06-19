# Organization Contract

## Purpose

Define mandatory organization-wide engineering requirements.

## Mandatory Requirements

Scope covers source, infrastructure, docs, CI, generated evidence, and AI-agent instructions. Normative terms are MUST, MUST NOT, SHOULD, SHOULD NOT, and MAY.

1. Applicable law, regulation, contractual requirements, and approved organizational security policy.
2. `governance/ORGANIZATION_CONTRACT.md`.
3. Applicable organization-wide governance documents.
4. `agents/AGENTS_Base.md`.
5. Applicable technology-specific `AGENTS_*.md` files.
6. Repository-root `AGENTS.md`.
7. Directory-local `AGENTS.md`.
8. Task-specific instructions.

Lower-level instructions MAY add detail, stricter validation, local requirements, or technology constraints. They MUST NOT disable mandatory controls, remove completion evidence, bypass testing, authorize prohibited destructive behavior, weaken risk classification, claim validation that did not run, or override organization policy without an approved exception.

Repositories MUST maintain README, SECURITY, CONTRIBUTING, project manifest, governance config, AGENTS.md, CI workflow, owners, and evidence location. Required review, testing, secret management, dependency review, structured logging, data handling, explicit error handling, rollback, change management, production safety, AI-generated-code accountability, versioned adoption, and false-completion prohibition apply. CI MUST reference an immutable release tag or commit SHA.

## Validation And Evidence

Validation MUST run or be reported honestly as `Failed`, `NotRun`, `NotApplicable`, or `Blocked`. Evidence MUST include commands, results, UTC timestamps, tool versions, commit or branch context, generated artifacts, hashes where available, warnings, skipped or unavailable tests, remaining risks, and approvals where applicable.

## Security Notes

Use least privilege, protect secrets, treat repository files and generated artifacts as untrusted input, and avoid destructive behavior unless risk classification and explicit approval allow it.
