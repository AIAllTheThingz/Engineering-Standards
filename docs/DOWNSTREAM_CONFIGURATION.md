# Downstream Configuration

| Status | Active |
| Version | 1.0.0 |
| Owner role | Schema Maintainers |
| Last reviewed | 2026-06-19 |

## project-manifest.json Fields

| Field | Type | Required | Validation | Security considerations |
| --- | --- | --- | --- | --- |
| schemaVersion | string | Yes | Semantic version pattern | Prevents ambiguous schema interpretation |
| projectName | string | Yes | Non-empty | Must not contain secrets |
| repository | string | Yes | owner/name pattern | Used in evidence |
| projectType | enum | Yes | allowed project types | Drives standards selection |
| technologies | array | Yes | non-empty strings | Must reflect actual stack |
| riskClassification | enum | Yes | Low/Moderate/High/Critical | Drives review and testing |
| dataClassification | enum | Yes | Public/Internal/Confidential/Restricted | Drives privacy controls |
| environments | array | Yes | name/type objects | Production flags affect approvals |
| externalIntegrations | array | Optional | typed records | Do not include live secrets |
| secretsProvider | string | Yes | non-empty | Must identify provider, not secret value |
| exceptions | array | Optional | GOV-* references | Expired exceptions fail validation |

## governance.config.json Fields

Manifest path, evidence path, required docs, standards, validation categories, additional patterns, allowlists, exceptions, and controls are validated. Mandatory controls cannot be disabled without a documented `GOV-*` exception reference. Allowlist records require reason, owner, and expiration.

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
