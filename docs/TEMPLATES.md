# Templates

| Status | Active |
| Version | 1.0.0 |
| Owner role | Template Maintainers |
| Last reviewed | 2026-06-19 |

## Purpose

This document defines how repository, issue, pull request, test plan, evidence, and threat-model templates are maintained and used. Templates help downstream repositories start from a complete governance posture, but they are not evidence by themselves.

Copied templates MUST be completed with repository-specific details before enforcement. Leaving template placeholders in authoritative repository documents is a validation failure.

## Template Inventory

Repository templates live under `templates/repository`. Issue templates live under `templates/issues` and are mirrored into `.github/ISSUE_TEMPLATE` when used by this repository. Pull request, test-plan, evidence, and threat-model templates live under their own template directories.

Maintainers MUST keep central templates aligned with schemas, governance documents, branch protection guidance, and reusable workflows.

## Repository Templates

Repository manifest and governance-configuration templates use contract
`1.2.0`. Replace the repository identity and owner records, but keep
`governanceVersion`, immutable `governanceCommitSha`, and
`workflowInterfaceVersion` distinct. Select `central-reference`, `vendored`, or
`local` standards consumption deliberately, and keep local evidence paths
separate from hosted workflow evidence declarations.

Repository templates provide starting points for `README.md`, `CONTRIBUTING.md`, `SECURITY.md`, `AGENTS.md`, `project-manifest.json`, and `governance.config.json`. They must prompt for purpose, owners, risk, evidence, validation commands, rollback, security reporting, and exceptions.

Generated repository files MUST replace placeholders, remove template notes, and include real commands.

## Issue Templates

Issue templates must collect enough information for triage without requesting secrets. Bug reports should ask for affected version, expected behavior, observed behavior, sanitized logs, impact, and reproduction steps. Feature requests should ask for use case, affected control, downstream impact, and compatibility concerns.

Governance exception issue templates must ask for scope, risk, compensating controls, expiration, owner, approval request, and remediation plan.

## Pull Request Template

The pull request template must require summary, reason, risk classification, security impact, data impact, testing, skipped validation, evidence, rollback, exceptions, and checklist confirmation.

Pull requests that change governance controls must identify whether the change is breaking, backward compatible, or a patch clarification.

## Test Plan Template

The test plan template must prompt for scope, requirements, environment, test data, positive cases, negative cases, security cases, failure recovery, rollback validation, evidence collection, and exit criteria.

Test plans for High and Critical changes must include destructive-operation controls and production rollback validation when applicable.

## Evidence Template

Evidence templates must match the active schema. They may show example values, but they must not be used as completed evidence without replacing command, runtime, timestamps, status, summary, warnings, and artifact references.

Evidence must be generated from actual validation whenever possible. Manual evidence requires reviewer context and limitations.

## Release Verification Template

`templates/releases/POST_RELEASE_VERIFICATION.template.json` starts a truthful
post-publication observation record with external work set to `NotRun`. Replace
its identities, timestamps, hashes, and reasons only after re-fetching the tag,
GitHub Release, and downstream canary Evidence. The template complements the
full release-lifecycle schema; it does not authorize tag creation, release
publication, or protection changes and is not Passed evidence by itself.

## Threat Model Template

Threat-model templates must prompt for system overview, trust boundaries, assets, actors, entry points, data flows, dependencies, threats, mitigations, residual risk, assumptions, abuse cases, and review history.

Threat models are required for systems that process restricted data, manage identity or authorization, expose public APIs, run privileged automation, or perform destructive operations.

## Placeholder Rules

Placeholders are allowed only inside template files. They should be clear and safe, such as `<project-name>` or `<pinned-commit-sha>`. Do not use placeholders that look like real secrets, production endpoints, or valid credentials.

Generated files outside `templates/` MUST NOT retain placeholder values.

## Validation

Template changes require documentation completeness validation and, when JSON templates change, schema validation against equivalent fixtures or manual review showing how the template maps to required schema fields.

Run:

```powershell
pwsh -NoProfile -File scripts/Test-DocumentationCompleteness.ps1 -Path .
pwsh -NoProfile -File scripts/Test-JsonSchemas.ps1 -Path .
```

## Evidence

Evidence for template changes must identify which templates changed, which downstream documents or workflows are affected, and whether examples were updated. If a template change creates new required downstream work, release notes must say so.

Maintainers SHOULD include before-and-after review notes for major template changes.

## Exceptions

Exceptions to template requirements require template maintainer approval. A downstream repository may temporarily keep an incomplete generated file only with a `GOV-*` exception, an owner, an expiration, and a remediation plan.

Template exceptions cannot approve missing security reporting instructions, missing evidence paths, or fake validation commands.

## Related

- `templates/repository/README.template.md`
- `templates/repository/project-manifest.template.json`
- `templates/repository/governance.config.template.json`
- `templates/pull-request/pull_request_template.md`
- `templates/test-plans/TEST_PLAN.template.md`
- `templates/threat-models/THREAT_MODEL.template.md`
- `templates/releases/POST_RELEASE_VERIFICATION.template.json`
- `docs/ADOPTION_GUIDE.md`
- `docs/DOWNSTREAM_CONFIGURATION.md`
