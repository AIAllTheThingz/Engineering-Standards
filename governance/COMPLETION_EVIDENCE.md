# Completion Evidence

| Field | Value |
| --- | --- |
| Status | Active |
| Version | 1.0.0 |
| Owner role | Governance Evidence Maintainers |
| Last reviewed | 2026-06-19 |
| Changelog | See [CHANGELOG.md](../CHANGELOG.md). |

## Purpose

Completion evidence is the auditable record that proves what was changed, how it was validated, what did not run, what artifacts were produced, who approved the work, and what risks remain. Work MUST NOT be described as complete, production-ready, released, or safe to merge unless the evidence supports that statement.

Evidence is not a formality. It is the mechanism that prevents false test claims, unreviewed risk acceptance, missing rollback, hidden skipped tests, and unverifiable generated artifacts.

## Applicability

This policy applies to pull requests, direct commits, releases, emergency changes, generated code, generated documentation, workflow changes, examples, templates, and manual operational work performed under this standards repository.

Evidence MAY be stored in the repository, attached to a release, uploaded as CI artifacts, linked from a pull request, or retained in an approved audit system. Wherever it is stored, it MUST be reviewable by maintainers with responsibility for the change.

## Required Evidence Object

Completion evidence MUST include the fields defined by [../schemas/completion-result.schema.json](../schemas/completion-result.schema.json):

- Repository and branch.
- Commit SHA or `unknown` when the work has not yet been committed.
- Pull request reference when applicable.
- Governance version.
- Risk classification.
- Overall status.
- Start and completion timestamps in UTC.
- Summary of work.
- Changed files.
- Commands executed.
- Commands not executed.
- Test evidence records.
- Artifact records.
- Warnings, known limitations, remaining risks, exceptions, and approvals.

Evidence MUST be specific. "Tests passed" is insufficient. "Ran `Invoke-Pester -Path tests -Output Detailed`, exit code 0, 8 passed, 0 failed" is evidence.

## Test Evidence Records

Each test, build, lint, scan, review, or manual validation record MUST include:

- Name and category.
- Status.
- Exact command or manual procedure.
- Working directory or system inspected.
- Start and completion timestamps.
- Runtime and tool version when known.
- Exit code when a command ran.
- Summary.
- Warnings.
- Failure reason when status is `Failed`, `Blocked`, or `NotRun`.

Manual validation MUST name what was inspected and by whom in the approval or summary. Screenshots, rendered documents, logs, or reports SHOULD be attached as artifacts when manual review is used to support a decision.

## Overall Status Calculation

The overall evidence status MUST be calculated from the individual records and required validation set:

| Condition | Overall status |
| --- | --- |
| Any mandatory validation is `Failed` | `Failed` |
| Any mandatory validation is `Blocked` and no approved exception covers it | `Blocked` |
| Any mandatory validation is `NotRun` and no approved exception covers it | `NotRun` |
| All mandatory validations are `Passed`, optional checks are `Passed` or justified `NotApplicable`, and no contradictions exist | `Passed` |
| The change is outside the scope of a validation category and the reason is recorded | Category may be `NotApplicable` |

An overall `Passed` status is prohibited when any mandatory test is `Failed`, `Blocked`, or `NotRun`. A repository MAY treat an optional check as `NotApplicable`, but the evidence MUST explain why it does not apply.

## Mandatory Validation Set

The mandatory validation set depends on the change. At minimum:

| Change type | Mandatory validation |
| --- | --- |
| Governance documentation | Documentation completeness, Markdown links, reviewer assessment. |
| Schemas and JSON fixtures | JSON parse, schema structural validation, valid/invalid fixtures. |
| Scripts and PowerShell modules | Parser validation, relevant Pester tests, lint when available. |
| GitHub Actions and workflows | YAML syntax validation, permission review, trigger review, action pinning review. |
| Application code | Build, unit tests, relevant integration tests, dependency review. |
| Security-sensitive code | Security review, negative tests or threat analysis, secret scan where available. |
| Database migration | Migration validation, rollback validation, data classification review. |
| Infrastructure | Plan validation, target scope review, rollback or recovery plan. |
| Release | Aggregate validation, release notes, artifact integrity, approval evidence. |
| AI-generated change | Human review, false-claim check, prompt-data review, relevant technical validation. |

If tooling is unavailable, the status is `NotRun` or `Blocked`. The evidence MUST name the missing tool and identify the remediation needed to run it.

## Skipped, Blocked, And Not Applicable Tests

Skipped tests affect completion based on why they were skipped:

- `NotRun` means the test did not execute. It prevents overall `Passed` when the test is mandatory.
- `Blocked` means the test could not complete because of an external condition. It prevents overall `Passed` unless an approved exception covers it.
- `NotApplicable` means the test is irrelevant to the change. It is allowed only when the evidence explains the scope reason.

Examples:

- YAML validation is `NotRun` when no YAML parser is installed.
- Integration tests are `Blocked` when a required sandbox is down.
- Database migration validation is `NotApplicable` for a README-only typo fix.

## Artifact Hash Verification

Artifacts SHOULD include records conforming to [../schemas/artifact-record.schema.json](../schemas/artifact-record.schema.json). Hashes are REQUIRED for artifacts used to support release, security, compliance, or manual validation decisions.

Artifact records SHOULD include:

- Name.
- Type.
- Relative path or artifact URL.
- Media type.
- Size.
- SHA-256 hash.
- Creation timestamp.
- Producer.
- Retention requirement.
- Sensitivity classification.
- Related test or validation record.

Evidence validation MUST recompute hashes for local artifacts when possible. A hash mismatch is a failed validation because the reviewed artifact is no longer the artifact described by the evidence.

## Evidence Retention

Retention MUST match risk:

| Risk | Minimum retention |
| --- | --- |
| Low | Pull request or commit history sufficient for routine review. |
| Moderate | Evidence retained with CI artifacts or repository evidence for at least the active support period. |
| High | Evidence retained with release, incident, or audit records for the period required by the owning team. |
| Critical | Evidence retained in durable audit storage with approvals, rollback proof, and artifact hashes. |

Evidence containing confidential or regulated information MUST be stored only in systems approved for that data classification. Sensitive evidence SHOULD be summarized in the repository with a pointer to the protected record.

## Approval Evidence

Approval evidence MUST identify the approver, role, decision, timestamp, and scope of approval. Approvals are required when:

- Risk is High or Critical.
- A mandatory control is excepted.
- A destructive operation is performed.
- Production behavior changes.
- A release is approved.
- Emergency action occurred before full validation.

Approval comments MUST be tied to the evidence or pull request. A chat message or verbal approval is insufficient unless it is transcribed into the evidence record with approver confirmation.

## Manual Validation

Manual validation is allowed when automation cannot reasonably prove the behavior. It MUST record:

- Reviewer or operator.
- Item inspected.
- Acceptance criteria.
- Result.
- Timestamp.
- Artifacts reviewed.
- Limitations.

Manual validation MUST NOT replace automation merely because automation is inconvenient. If automation is missing but should exist, the evidence MUST record the gap and a follow-up owner.

## Contradictory Results

Evidence is contradictory when:

- Overall status is `Passed` while a mandatory test is `Failed`, `Blocked`, or `NotRun`.
- A summary claims a command passed but the recorded exit code is nonzero.
- A test is marked `Passed` without a command, procedure, or manual validation record.
- A change claims no security impact while modifying authentication, authorization, secrets, cryptography, dependency execution, or workflow permissions.
- A release claims artifacts were reviewed but artifact hashes are missing or mismatched.
- A skipped test is described as success.

Contradictory evidence MUST be corrected before merge or release. If contradiction reflects a real unresolved risk, the overall status MUST be downgraded.

## Evidence Review

Reviewers MUST inspect evidence before approving Moderate, High, or Critical changes. Evidence review MUST confirm:

- Required validations are present.
- Status values are consistent.
- Commands are plausible for the changed files.
- Warnings and limitations are not hiding failures.
- Exceptions are valid and unexpired.
- Artifact hashes exist where required.
- Rollback evidence is sufficient for the risk level.

Evidence generated by an AI tool MUST be reviewed with the same skepticism as any other generated claim. The reviewer SHOULD compare evidence against CI logs, local command output, or artifact metadata when risk is High or Critical.

## Valid Example

```json
{
  "schemaVersion": "1.0.0",
  "repository": "ExampleOrg/example-service",
  "commitSha": "0123456789abcdef0123456789abcdef01234567",
  "branch": "feature/add-health-check",
  "pullRequest": "https://github.com/ExampleOrg/example-service/pull/42",
  "governanceVersion": "1.0.0",
  "riskClassification": "Moderate",
  "status": "Passed",
  "summary": "Added service health check and tests.",
  "commandsExecuted": [
    "dotnet test"
  ],
  "commandsNotExecuted": [],
  "tests": [
    {
      "name": "dotnet test",
      "status": "Passed",
      "command": "dotnet test",
      "exitCode": 0,
      "summary": "All tests passed."
    }
  ],
  "warnings": [],
  "knownLimitations": [],
  "remainingRisks": [],
  "exceptions": [],
  "approvals": []
}
```

This example is valid because the overall status agrees with the test status and the evidence identifies the command.

## Invalid Examples

Invalid because a mandatory test did not run but the overall status claims success:

```json
{
  "status": "Passed",
  "tests": [
    {
      "name": "YAML validation",
      "status": "NotRun",
      "failureReason": "No YAML parser installed."
    }
  ]
}
```

Invalid because the evidence claims a test passed without an executable command, manual procedure, or reviewer:

```json
{
  "status": "Passed",
  "tests": [
    {
      "name": "Security review",
      "status": "Passed",
      "summary": "Looks safe."
    }
  ]
}
```

Invalid because an artifact is used for release evidence without a hash:

```json
{
  "artifacts": [
    {
      "name": "release.zip",
      "path": "dist/release.zip"
    }
  ]
}
```

## Failure Behavior

Evidence validation MUST fail when required fields are missing, timestamps are invalid, artifact hashes mismatch, exception references are malformed, or `Passed` conflicts with failed or unexecuted mandatory validation.

When evidence validation fails, maintainers MUST correct the evidence or downgrade the completion claim. They MUST NOT edit validation scripts, delete records, or reclassify tests merely to obtain a successful result.

## Commit Semantics

Completion evidence distinguishes the commit that was validated from the commit that contains the evidence record.

- `validatedCommitSha` is the repository commit whose contents were validated.
- `commitSha` is retained for compatibility and MUST match `validatedCommitSha`.
- `evidenceCommitSha` is the commit containing a checked-in evidence file when that relationship is intentionally recorded. It MAY be null to avoid infinite evidence-regeneration commits.
- When `evidenceCommitSha` is supplied, `validatedCommitSha` MUST be an ancestor of or equal to it.
- GitHub Actions artifact evidence MUST use `executionContext: GitHubActions`, MUST set `validatedCommitSha` to `GITHUB_SHA`, and MUST leave `evidenceCommitSha` null.

Checked-in local evidence is not authoritative proof of GitHub execution. It may remain overall `NotRun` because GitHub-hosted execution, controlled-failure execution, and artifact verification occur outside the local context.

## Verified Run Metadata

`evidence/latest-verified-run.json` stores metadata for the most recently downloaded and independently verified GitHub evidence artifact. It records run IDs, artifact IDs, artifact ZIP hash, branch, trigger, conclusion, controlled-failure run, verifier, and verification timestamp. It MUST NOT store temporary artifact URLs, credentials, or copied artifact payloads.

## Pester And Scanner Evidence

Detailed Pester evidence MUST be sanitized before upload. `evidence/pester-details.json` preserves individual test results while replacing repository, runner, user-profile, and temporary absolute paths. Raw XML is temporary unless it passes the same sanitization checks.

Forbidden-pattern scanning excludes generated evidence and build output by default so scanner reports do not recursively scan their own prior findings. Maintainers may use `-IncludeGeneratedEvidence` only for targeted diagnostics.

## Related Documents

- [ORGANIZATION_CONTRACT.md](ORGANIZATION_CONTRACT.md)
- [RISK_CLASSIFICATION.md](RISK_CLASSIFICATION.md)
- [EXCEPTION_PROCESS.md](EXCEPTION_PROCESS.md)
- [AI_GENERATED_CODE_POLICY.md](AI_GENERATED_CODE_POLICY.md)
- [../schemas/completion-result.schema.json](../schemas/completion-result.schema.json)
- [../actions/validate-evidence/README.md](../actions/validate-evidence/README.md)

## Revision History

- 1.0.0: First substantive implementation phase defining status calculation, mandatory validation, retention, approvals, review, and examples.
