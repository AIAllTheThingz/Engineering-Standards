# Exception Process

| Field | Value |
| --- | --- |
| Status | Active |
| Version | 1.0.0 |
| Owner role | Governance Review Board |
| Last reviewed | 2026-06-19 |
| Changelog | See [CHANGELOG.md](../CHANGELOG.md). |

## Purpose

An exception is a temporary, explicit, reviewed decision to operate outside a mandatory governance control. Exceptions exist so real constraints can be handled transparently without pretending that a missing control passed.

Exceptions MUST be narrow, time-bounded, risk-classified, approved by an accountable owner, and supported by compensating controls. They MUST NOT be used to avoid review, skip evidence, hide tooling gaps, or permanently rewrite the standard.

## Scope

This process applies whenever a repository cannot satisfy a mandatory requirement in:

- [ORGANIZATION_CONTRACT.md](ORGANIZATION_CONTRACT.md)
- [COMPLETION_EVIDENCE.md](COMPLETION_EVIDENCE.md)
- [RISK_CLASSIFICATION.md](RISK_CLASSIFICATION.md)
- [AI_GENERATED_CODE_POLICY.md](AI_GENERATED_CODE_POLICY.md)
- Agent standards, schemas, reusable workflows, action requirements, or required repository templates.

An exception does not waive legal, regulatory, contractual, or approved organizational security requirements unless the authority that owns those requirements approves the waiver.

## Normative Terminology

`MUST` and `MUST NOT` are mandatory. `SHOULD` and `SHOULD NOT` are expected unless a rationale is recorded. `MAY` is optional.

`Exception owner` means the person accountable for remediation. `Approver` means the person or group authorized to accept the temporary risk. `Compensating control` means an alternate control that reduces risk while the mandatory control is not met.

## Exception Identifier

Every exception MUST have a stable identifier in the form `GOV-YYYY-NNN` or another repository-approved `GOV-*` identifier. The identifier MUST appear in:

- Exception request.
- Pull request or issue.
- Completion evidence.
- Governance configuration when a validation check is disabled or advisory.
- Renewal, revocation, and closure records.

## Required Fields

An exception request MUST include:

- Identifier.
- Requester.
- Exception owner.
- Affected repository and paths.
- Exact control being excepted.
- Reason the control cannot currently be met.
- Risk classification.
- Impact of granting the exception.
- Impact of rejecting the exception.
- Compensating controls.
- Validation that will still run.
- Validation that will not run.
- Expiration date.
- Remediation plan and owner.
- Approval authority required.
- Evidence location.

Requests missing these fields are incomplete and MUST NOT be approved.

## Request Workflow

1. Requester identifies the exact mandatory control that cannot be met.
2. Requester classifies the risk using [RISK_CLASSIFICATION.md](RISK_CLASSIFICATION.md).
3. Requester documents compensating controls and remediation plan.
4. Requester opens a governance exception issue or pull request section using the approved template.
5. CI validates that the exception reference is syntactically valid.
6. Required reviewers evaluate the request.
7. Approver approves, rejects, requests changes, or asks for emergency handling.
8. If approved, the exception is recorded in evidence and any related config.
9. Owner remediates before expiration or requests renewal.

The request MUST be reviewed before the noncompliant change merges unless it is an emergency exception.

## Approval Workflow

Approval authority depends on risk:

| Risk | Minimum approval |
| --- | --- |
| Low | Repository owner or code owner. |
| Moderate | Repository owner plus affected control owner. |
| High | Repository owner plus security, platform, data, or governance reviewer as applicable. |
| Critical | Accountable executive or delegated governance authority plus required domain reviewers. |

Approvers MUST verify that:

- The request identifies a real blocker.
- The scope is narrow.
- The expiration is reasonable.
- Compensating controls reduce risk.
- Remaining validation is adequate.
- Evidence will not claim `Passed` for controls that did not run.
- The remediation plan has an owner and due date.

Approval MUST be explicit. Silence, lack of objection, or merge permission is not approval.

## Rejection Conditions

An exception MUST be rejected when:

- The request is for convenience, speed, preference, or avoiding review.
- The request hides a failing test without mitigation.
- The request would violate law, regulation, contract, or approved security policy.
- The request has no expiration date.
- The request has no compensating control.
- The scope is broader than necessary.
- The owner is missing or lacks authority.
- The risk classification is clearly understated.
- The same exception has repeatedly expired without remediation.
- The change would create unacceptable safety, security, legal, or data risk.

Rejected requests SHOULD remain visible with the reason for rejection so future reviewers understand the decision.

## Renewal

Renewal is not automatic. A renewal request MUST be submitted before expiration and MUST include:

- Original exception identifier.
- Current status.
- Work completed since approval.
- Reason remediation is incomplete.
- Updated risk classification.
- Updated compensating controls.
- New expiration date.
- Approval from the same level of authority or higher.

Repeated renewals SHOULD trigger governance review of the underlying control, project plan, or ownership model. A renewal MUST NOT be used to convert a temporary exception into permanent policy.

## Revocation

An approved exception MUST be revoked when:

- The compensating control is not implemented.
- The exception scope is exceeded.
- New information increases risk beyond approved acceptance.
- The owner is no longer accountable.
- Evidence shows contradiction or false claims.
- A security incident, data exposure, or production failure is linked to the exception.
- The mandatory control has been remediated.

Revocation MUST be recorded with timestamp, decision maker, reason, and required remediation.

## Emergency Exceptions

Emergency exceptions MAY be approved after action only when delaying action would worsen an active incident, security exposure, outage, data integrity problem, or legal obligation.

Emergency exception evidence MUST include:

- Incident or emergency reference.
- Decision maker.
- Time of decision in UTC.
- Action taken.
- Control bypassed.
- Reason delay was unacceptable.
- Validation performed before action.
- Post-action validation required.
- Expiration or closure criteria.

Emergency exceptions are High or Critical by default. They MUST receive post-action review as soon as practical. Failure to complete post-action evidence revokes the exception and triggers remediation.

## CI Validation

CI SHOULD validate:

- Exception identifiers match the approved pattern.
- Expiration dates are present and not expired.
- Required fields exist where exceptions are stored in structured files.
- Disabled or advisory controls reference a `GOV-*` exception.
- Completion evidence lists active exceptions.
- Overall evidence status does not claim `Passed` when mandatory validation is missing without an approved exception.

CI validation does not approve exceptions. It only verifies that records are structurally present and consistent.

## Expiration Handling

An exception is invalid after its expiration date. When an exception expires:

- CI MUST fail if the expired exception is required for a disabled control.
- New merges depending on the exception MUST stop.
- Completion evidence MUST report the related validation as `Failed`, `Blocked`, or `NotRun`, not `Passed`.
- The owner MUST either remediate the control or submit a renewal.

Expired exceptions SHOULD remain in history for audit, but active configuration MUST NOT depend on them.

## Approved Example

Identifier: `GOV-2026-001`

Control: YAML syntax validation for workflow files.

Reason: Local development environment lacks a YAML parser, but CI has one configured.

Risk: Moderate.

Scope: Local completion evidence for one pull request.

Compensating controls: Markdown links, documentation completeness, workflow review, and CI YAML validation on push.

Expiration: 2026-07-01.

Approval: Repository owner and CI reviewer.

Decision: Approved because the exception is narrow, time-bounded, and CI still validates the control before release.

## Rejected Example

Identifier: `GOV-2026-002`

Request: Skip all Pester tests because they are slow.

Risk claimed: Low.

Decision: Rejected.

Reason: Slow tests are not a valid exception by themselves. The request has no compensating controls, no narrowed scope, and no remediation plan. The actual risk is at least Moderate because test coverage would be removed.

## Expired Example

Identifier: `GOV-2026-003`

Control: Dependency vulnerability remediation.

Expiration: 2026-06-01.

Current date: 2026-06-19.

Decision: Expired and invalid.

Required action: CI must fail if the repository still depends on this exception. The owner must remediate the dependency or request renewal with updated risk, evidence, and approval.

## Failure Behavior

If a change relies on an exception that is missing, malformed, rejected, revoked, or expired, the change is noncompliant. Maintainers MUST NOT merge by removing the control, disabling CI, editing evidence, or marking the control as `NotApplicable`.

If exception evidence contradicts completion evidence, the higher-risk interpretation wins until the contradiction is resolved.

## Related Documents

- [ORGANIZATION_CONTRACT.md](ORGANIZATION_CONTRACT.md)
- [COMPLETION_EVIDENCE.md](COMPLETION_EVIDENCE.md)
- [RISK_CLASSIFICATION.md](RISK_CLASSIFICATION.md)
- [AI_GENERATED_CODE_POLICY.md](AI_GENERATED_CODE_POLICY.md)
- [../templates/issues/governance_exception.yml](../templates/issues/governance_exception.yml)

## Revision History

- 1.0.0: First substantive implementation phase defining request, approval, rejection, renewal, revocation, emergency, CI, expiration, and examples.
