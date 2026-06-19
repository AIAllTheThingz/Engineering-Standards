# Risk Classification

| Field | Value |
| --- | --- |
| Status | Active |
| Version | 1.0.0 |
| Owner role | Risk Review Maintainers |
| Last reviewed | 2026-06-19 |
| Changelog | See [CHANGELOG.md](../CHANGELOG.md). |

## Purpose

Risk classification determines the amount of review, validation, approval, rollback planning, and completion evidence required for an engineering change. It prevents teams from treating a cosmetic README edit, a dependency update, an authorization change, and a destructive production migration as equivalent work.

Every nontrivial change MUST have a risk classification. The classification MUST be recorded in the pull request, issue, release record, or completion evidence.

## Normative Terminology

`MUST` and `MUST NOT` are mandatory. `SHOULD` and `SHOULD NOT` are expected unless a rationale is recorded. `MAY` is optional.

`Likelihood` estimates how probable it is that the change can fail, be misused, or produce unintended behavior. `Impact` estimates the damage if it does. The final risk classification MUST consider both, plus automatic escalation factors.

## Classification Levels

| Level | Meaning |
| --- | --- |
| Low | Failure is isolated, reversible, and has no production, security, sensitive-data, or customer impact. |
| Moderate | Failure can affect contributor workflow, noncritical functionality, or limited internal behavior, but rollback is straightforward. |
| High | Failure can affect production behavior, security controls, confidential data, deployment, identity, billing, reliability, or broad users. |
| Critical | Failure can cause broad outage, irreversible data loss, credential compromise, regulated data exposure, legal obligation, safety impact, or destructive production change. |

If the classification is uncertain, select the higher level until a reviewer with domain authority approves a lower classification.

## Likelihood Scoring

Score likelihood from 0 to 3:

| Score | Level | Indicators |
| --- | --- | --- |
| 0 | Rare | Simple change, well-understood code path, strong existing tests, no external dependency. |
| 1 | Unlikely | Limited behavior change, small blast radius, tests cover primary path. |
| 2 | Possible | Multiple components, new dependency, partial test coverage, unfamiliar code, generated code, or manual operation. |
| 3 | Likely | Complex migration, brittle workflow, broad automation, insufficient tests, incident response, or known unstable dependency. |

Likelihood MUST be increased when the change is generated, rushed, manually executed, poorly tested, or dependent on unavailable external systems.

## Impact Scoring

Score impact from 0 to 3:

| Score | Level | Indicators |
| --- | --- | --- |
| 0 | Negligible | No user, production, security, or data impact. |
| 1 | Limited | Internal inconvenience, local failure, or easily reversible behavior. |
| 2 | Significant | Production path, confidential data, customer-visible behavior, deployment reliability, or security defense-in-depth. |
| 3 | Severe | Regulated data, identity, cryptography, destructive production action, broad outage, financial loss, legal obligation, or safety impact. |

Impact MUST reflect the worst credible consequence, not the expected happy path.

## Dimension Scoring

Classify across these dimensions. Assign 0-3 points per dimension and record the rationale for Moderate, High, and Critical changes.

| Dimension | 0 | 1 | 2 | 3 |
| --- | --- | --- | --- | --- |
| Production impact | None | Internal or nonproduction only | Limited production path | Broad production or release path |
| Security impact | None | Defense-in-depth | Auth, secrets, privileged path, dependency execution | Identity, cryptography, credential exposure, regulated security control |
| Data sensitivity | Public or synthetic | Internal | Confidential | Regulated, customer-sensitive, financial, safety, or legal |
| Destructive capability | None | Local or generated artifact cleanup | Scoped data/state modification | Broad, wildcard, production, or irreversible deletion |
| Recovery complexity | Revert only | Documented rollback | Coordinated rollback or migration | Tested disaster recovery or no true rollback |
| Change complexity | Trivial | Single component | Multiple components or generated code | Distributed, cross-system, emergency, or manual production operation |

## Score To Classification

Use the highest of the dimension score, likelihood/impact combination, and automatic escalation result.

| Result | Classification |
| --- | --- |
| Total dimension score 0-3 and no dimension above 1 | Low |
| Total dimension score 4-7 or any dimension at 2 with limited blast radius | Moderate |
| Total dimension score 8-11, any dimension at 3, or likelihood 2 with impact 2 | High |
| Total dimension score 12+, likelihood 2 or 3 with impact 3, or any automatic Critical escalation | Critical |

The scoring model supports judgment; it does not replace it. Reviewers MAY raise the classification when context shows hidden risk. Reviewers MUST NOT lower a classification solely to reduce required validation.

## Automatic Escalation Factors

The change is Critical unless an accountable security or platform reviewer explicitly documents why a lower classification is safe:

- Production destructive operation.
- Authentication, authorization, privileged identity, token issuance, or session validation change.
- Cryptography implementation, key generation, key storage, signing, encryption, or certificate validation change.
- Regulated data migration, deletion, export, retention, or access change.
- Broad infrastructure targeting, wildcard deletion, public network exposure, firewall changes, or identity boundary changes.
- Release automation that can publish artifacts, deploy to production, or sign packages.
- Secret rotation failure, suspected credential exposure, or incident containment action.
- Human safety, legal obligation, material financial risk, or customer trust event.

The change is at least High when it modifies:

- CI permissions, workflow triggers, or third-party action execution.
- Dependency install or build scripts.
- Logging of confidential or user-provided data.
- Database schema in production-bound services.
- Job deduplication, billing, notifications, or irreversible side effects.
- AI-generated code in security-sensitive areas.

## Decision Process

1. Identify affected systems, users, data, environments, and trust boundaries.
2. Score likelihood and impact.
3. Score the six dimensions.
4. Check automatic escalation factors.
5. Select the final classification.
6. Define required reviewers, tests, evidence, and rollback.
7. Record the classification and rationale.
8. Reclassify if the scope expands, validation fails, or new information appears.

If the change spans multiple areas, classify by the highest-risk area. Splitting a change into multiple pull requests MUST NOT be used to hide aggregate risk.

## Required Evidence By Level

| Risk | Required evidence |
| --- | --- |
| Low | Summary, changed files, relevant command output or reviewer rationale. |
| Moderate | Test commands and exit codes, relevant artifacts, reviewer approval, rollback note when behavior changes. |
| High | Full completion evidence, security/platform/data review as applicable, negative or integration tests, rollback plan, remaining risks. |
| Critical | Full completion evidence, written accountable approval, tested rollback or recovery evidence, release or incident record, artifact hashes, post-change verification. |

Evidence requirements are additive. A High change also needs all applicable Low and Moderate evidence.

## Review And Approval By Level

| Risk | Review | Approval | Merge or release gate |
| --- | --- | --- | --- |
| Low | Qualified reviewer | Standard repository approval | Required checks pass. |
| Moderate | Code owner | Code owner approval | Required checks and evidence pass. |
| High | Code owner plus domain reviewer | Security, platform, data, or release owner as applicable | Full evidence review and rollback plan. |
| Critical | Segregated reviewers and accountable owner | Written accountable approval | Release/incident approval, recovery evidence, post-change verification. |

## Emergency Changes

Emergency changes are used only when delay would worsen an active incident, security exposure, outage, or material operational harm. Emergency changes are High or Critical by default.

Emergency action MAY occur before all normal evidence is complete, but the owner MUST record:

- Incident or emergency reference.
- Decision maker and timestamp.
- Action taken.
- Risk accepted.
- Validation performed before action.
- Follow-up validation required after action.
- Expiration or closure criteria for any temporary exception.

Post-emergency evidence MUST be completed as soon as practical and reviewed by the accountable owner.

## Reclassification

Risk MUST be reclassified when:

- Scope changes.
- New files, systems, data classes, or permissions are added.
- A required validation fails.
- A reviewer identifies a missed impact.
- An exception is requested.
- The change moves from nonproduction to production.
- Generated code touches a higher-risk domain than initially understood.

Reclassification MUST be documented. Lowering risk after review requires rationale and approval from the reviewer responsible for the higher-risk domain.

## Technology-Specific Examples

### PowerShell

- Low: Add `-Verbose` output to a local reporting script.
- Moderate: Add `SupportsShouldProcess` to a nonproduction cleanup command.
- High: Add remote service restart automation.
- Critical: Add wildcard production deletion or tenant-wide permission changes.

### .NET

- Low: Refactor internal method without behavior change and with tests.
- Moderate: Add health endpoint or structured logging.
- High: Change authorization policy, token validation, or dependency injection for privileged services.
- Critical: Implement cryptography, signing, identity issuance, or regulated-data export.

### Web Frontend

- Low: CSS-only layout fix.
- Moderate: Change client-side validation with server validation unchanged.
- High: Change token storage, redirect handling, content security policy, or API authorization assumptions.
- Critical: Introduce script injection risk, payment flow changes, or authentication bypass potential.

### Database

- Low: Add documentation for an existing table.
- Moderate: Add nullable column with no backfill.
- High: Backfill confidential data, change indexes on high-traffic tables, or alter constraints.
- Critical: Drop, truncate, irreversible migration, regulated-data deletion, or production data repair.

### Infrastructure

- Low: Rename a tag.
- Moderate: Add plan-only validation.
- High: Modify firewall, identity, storage policy, deployment environment, or scaling behavior.
- Critical: Public exposure, privileged role assignment, production state deletion, or region-wide failover.

### Worker Service

- Low: Tune log wording.
- Moderate: Adjust retry delay.
- High: Change idempotency, duplicate prevention, billing jobs, notification jobs, or queue visibility.
- Critical: Delete queued work, replay production events broadly, or disable safeguards during incident recovery.

### Integration

- Low: Update vendor documentation link.
- Moderate: Adjust timeout for noncritical endpoint.
- High: Change credential flow, webhook verification, payment integration, or customer data mapping.
- Critical: Disable signature verification, process untrusted callbacks as privileged, or bulk export regulated data.

## Sample Assessments

### Sample 1: Documentation Completeness Script

Change: Add a script that validates required governance documentation.

Likelihood: 1 because the script is local and testable. Impact: 1 because a false failure can block contributors but does not affect production. Dimension score: 4. Classification: Moderate. Required evidence: script parser validation, example run, Pester test, documentation update.

### Sample 2: Workflow Permission Update

Change: Modify GitHub Actions permissions from read-only to write for pull requests.

Likelihood: 2 because workflow behavior depends on event context. Impact: 2 because token permissions affect repository integrity. Automatic escalation: at least High due CI permission change. Classification: High. Required evidence: permission review, trigger review, action pinning review, branch protection review.

### Sample 3: Production Data Repair

Change: Run a script that deletes duplicate customer records from production.

Likelihood: 2 because the operation is manual and data-dependent. Impact: 3 because regulated or customer data may be irreversibly changed. Automatic escalation: Critical due production destructive data change. Required evidence: owner approval, dry run, backup or recovery plan, exact target scope, post-change verification.

### Sample 4: AI-Generated Authorization Helper

Change: AI-generated helper centralizes role checks in a web service.

Likelihood: 2 because generated code may miss edge cases. Impact: 3 because authorization failure can grant access. Automatic escalation: Critical unless security reviewer documents a lower classification. Required evidence: human review, security review, negative tests, authorization matrix, completion evidence.

## Common Mistakes

- Classifying by number of lines changed instead of blast radius.
- Treating "internal only" as Low when internal systems contain confidential data.
- Ignoring rollback complexity.
- Treating workflow changes as documentation.
- Treating AI-generated changes as lower risk because they were generated quickly.
- Splitting destructive work into small pull requests to avoid Critical classification.
- Calling a test `NotApplicable` because the tool is unavailable.

## Related Documents

- [ORGANIZATION_CONTRACT.md](ORGANIZATION_CONTRACT.md)
- [COMPLETION_EVIDENCE.md](COMPLETION_EVIDENCE.md)
- [EXCEPTION_PROCESS.md](EXCEPTION_PROCESS.md)
- [AI_GENERATED_CODE_POLICY.md](AI_GENERATED_CODE_POLICY.md)
- [../docs/BRANCH_PROTECTION.md](../docs/BRANCH_PROTECTION.md)

## Revision History

- 1.0.0: First substantive implementation phase with scoring, escalation factors, evidence by level, emergency treatment, reclassification, examples, and sample assessments.
