# Contributing

| Field | Value |
| --- | --- |
| Status | Active |
| Version | 1.0.0 |
| Owner role | Governance Maintainers |
| Last reviewed | 2026-06-19 |
| Changelog | See [CHANGELOG.md](CHANGELOG.md) unless this file is at repository root. |

## Normative Terminology

`MUST` and `MUST NOT` define mandatory requirements. `SHOULD` and `SHOULD NOT` define expected practices that require a documented reason when not followed. `MAY` defines optional behavior. Every mandatory statement is intended to be testable by automation, review, or recorded evidence.

## Purpose

Contributions improve central standards, schemas, actions, workflows, templates, and examples.

## Local Setup

Clone the repository, use PowerShell 7, and run the local validation commands listed in `README.md`. Do not install global tools just to hide a `NotRun` result; document missing tools honestly.

## Branching And Pull Requests

Use a short branch name that describes the change. Pull requests MUST include risk classification, evidence, rollback notes, tests performed, tests not performed, and any exception references.

## Documentation Requirements

Policy changes MUST update related docs, templates, examples, schemas, and tests. New controls MUST define requirement, rationale, validation, evidence, failure behavior, and exception handling.

## Security Requirements

Do not add secrets, production endpoints, customer data, private keys, or live credentials. Scanner rules MUST avoid real secret examples.

## Review Boundaries

Governance contracts, schemas, actions, workflows, and scanner configuration require specialized review by CODEOWNERS.

## Related Documents

- `CODEOWNERS`
- `governance/RISK_CLASSIFICATION.md`
- `governance/COMPLETION_EVIDENCE.md`


## Operating Controls

Contributors MUST treat this file as an enforceable governance document rather than advisory prose. Validation includes documentation completeness checks, schema checks, Markdown link checks, repository health checks, and relevant example project tests. Evidence MUST identify the command, environment, result, and reason for any skipped or blocked validation. Exceptions MUST reference `governance/EXCEPTION_PROCESS.md`, include a `GOV-*` identifier, name a compensating control, and define an expiry date. Related documents include `governance/ORGANIZATION_CONTRACT.md`, `governance/COMPLETION_EVIDENCE.md`, and `docs/MAINTAINER_GUIDE.md`.
