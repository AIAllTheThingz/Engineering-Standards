# Adoption Guide

| Status | Active |
| Version | 1.0.0 |
| Owner role | Governance Adoption Maintainers |
| Last reviewed | 2026-06-19 |

## Prerequisites

Teams need repository owner approval, a maintainer who can edit CI, PowerShell 7 for local validation, and permission to configure branch protection.

## Staged Adoption

1. Inventory existing standards, CI checks, local AGENTS files, templates, and exceptions.
2. Classify the project type and risk using `governance/RISK_CLASSIFICATION.md`.
3. Create `project-manifest.json` and declare owners, technologies, data classification, environments, integrations, secrets provider, workflows, and evidence paths.
4. Create `governance.config.json` and list required documentation, standards, validation categories, allowlists, and exceptions.
5. Select agent standards and add local `AGENTS.md`.
6. Add reusable CI pinned to a commit SHA.
7. Run in advisory mode and remediate findings.
8. Enable enforcement mode and branch protection.
9. Establish governance update ownership and drift detection.

## Complete Example

```yaml
jobs:
  governance:
    uses: AIAllTheThingz/Engineering-Standards/.github/workflows/governance-ci.yml@<commit-sha>
    with:
      project-path: .
      governance-version: v1.0.0
```

## Migration From Copied Standards

Copied files SHOULD be replaced by central references. If a local copy is operationally required, record source URL, version, update owner, drift check command, and statement that the central version is authoritative.

## Rollback And Troubleshooting

If validation blocks a critical fix, use advisory mode only with an approved exception and compensating controls. Common failures are documented in `docs/TROUBLESHOOTING.md`.

## Governance Operating Requirements

Teams MUST apply this document together with the organization contract, completion evidence policy, exception process, and risk classification model. Validation MUST include the automated checks that apply to the repository type plus a reviewer assessment of any material risk that automation cannot prove. Evidence MUST be stored in the repository or attached to the pull request, and it must distinguish Passed, Failed, Blocked, Skipped, and NotRun results without contradiction.

## Exception Handling

Exceptions MUST follow `governance/EXCEPTION_PROCESS.md`. An exception request needs a `GOV-*` reference, owner, expiry date, compensating control, rollback plan when applicable, and approval from the accountable maintainer. Expired exceptions are treated as failures until renewed or remediated.

## Related Documents

- `governance/ORGANIZATION_CONTRACT.md`
- `governance/COMPLETION_EVIDENCE.md`
- `governance/RISK_CLASSIFICATION.md`
- `governance/EXCEPTION_PROCESS.md`
- `docs/ADOPTION_GUIDE.md`
