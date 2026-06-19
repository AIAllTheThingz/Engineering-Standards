# Release Process

| Status | Active |
| Version | 1.0.0 |
| Owner role | Release Maintainers |
| Last reviewed | 2026-06-19 |

## Preparation

Confirm milestone scope, update documentation, verify schema compatibility, and ensure examples still validate. Security-sensitive changes require action-security review.

## Validation

Run JSON schema validation, Markdown link validation, documentation completeness, contract validation, scanner, repository health, Pester, parser validation, YAML validation when tooling exists, and evidence validation.

## Tagging

Create an annotated release tag after validation. Publish migration notes for breaking changes and list pinned action updates.

## Rollback

If a release is defective, publish a corrective patch. Do not rewrite released tags unless responding to a documented security incident with explicit maintainer approval.

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

## Reviewer Guidance

Reviewers MUST verify that the described control is implemented in executable automation, reviewer workflow, or maintained documentation. A passing result is only credible when the evidence identifies the command that ran, the relevant version or configuration, the exit code, and any environment limitation. When a tool is unavailable, the result is `NotRun` or `Blocked`; it is not converted into success. Teams SHOULD prefer small, reviewable changes that improve one control at a time, then update this repository after the evidence proves the behavior. Related implementation details live in the reusable workflows, action README files, schemas, and examples. Exceptions remain temporary and must be removed from active evidence when the underlying issue is remediated.
