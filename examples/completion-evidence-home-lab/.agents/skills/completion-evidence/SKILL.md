---
name: completion-evidence
description: Assemble and verify completion evidence from synthetic validation outcomes using canonical statuses and commit semantics. Use for reconciling commands, exit codes, test counts, approvals, artifact metadata, limitations, and validated content into an honest completion record. Do not use to fabricate runs, convert missing checks to Passed, expose secrets, bypass approvals, or claim local output proves GitHub execution.
---

# Completion Evidence

Build an attributable record of what was actually implemented, validated,
reviewed, approved, and operationally verified.

## Demo boundary

This is a portfolio-grade home-lab demonstration, not a production-certified
Active skill. Use only synthetic results committed beneath this example. Do not
dispatch workflows, download artifacts, inspect secrets, update live pull
requests, or represent illustrative records as authoritative evidence.

Read `AGENTS.md` and the read-only authorities
`../../agents/AGENTS_Base.md`, `../../agents/AGENTS_Integration.md`,
`../../governance/RISK_CLASSIFICATION.md`,
`../../governance/COMPLETION_EVIDENCE.md`,
`../../governance/EXCEPTION_PROCESS.md`, and
`../../governance/AI_GENERATED_CODE_POLICY.md`. If those pinned central
authorities are unavailable in a standalone copy, report the affected control
as `Blocked`; do not invent policy.

## Workflow

1. Identify the exact validated content SHA. Set `commitSha` equal to
   `validatedCommitSha`; use `evidenceCommitSha` only for the later commit that
   intentionally contains checked-in evidence.
2. Ingest exact commands, exit codes, counts, timestamps, environment, and
   sanitized failure details. Reject unstructured success claims.
3. Use only `Passed`, `Failed`, `Blocked`, `NotRun`, or `NotApplicable`. Required
   missing checks are `NotRun`; unmet prerequisites with a concrete reason are
   `Blocked`.
4. Preserve the distinction between `executionContext: Local` and real hosted
   execution. Local evidence cannot populate GitHub run ID, attempt, artifact,
   or hosted-success fields.
5. Require attributable approvals when policy requires them. An absent approval
   cannot be inferred from an author, actor, or green test.
6. Verify artifact names, hashes, run metadata, and source commit against the
   independently downloaded artifact before claiming verification.
7. Reject contradictions: zero exit with failed required tests, `Passed` with
   required `NotRun`, mismatched SHAs, approval-required without approval, or
   hosted success without run metadata.
8. Report evidence files changed, exact checks, remaining gaps, GitHub execution,
   and artifact-verification state.

Never improve a status for presentation. Preserve the least favorable required
result until real evidence changes it.
