# Security Policy

| Field | Value |
| --- | --- |
| Status | Active |
| Version | 1.0.0 |
| Owner role | Security Maintainers |
| Last reviewed | 2026-06-19 |
| Changelog | See [CHANGELOG.md](CHANGELOG.md). |

## Purpose

This policy defines how security issues are reported, triaged, fixed, and evidenced for the Engineering Standards repository. It covers governance policy, AI-agent standards, schemas, validation scripts, composite actions, reusable workflows, examples, templates, and release artifacts.

The repository is security-sensitive because downstream repositories may rely on it to decide whether code is safe to merge, whether evidence is credible, and whether AI-assisted changes meet organization controls.

## Supported Versions

The current major version receives security fixes. One previous major version SHOULD receive critical fixes and migration guidance when practical. Unsupported versions SHOULD be upgraded unless an approved `GOV-*` exception exists.

Release tags and commit SHAs used by downstream repositories must be treated as part of the security boundary. If a release is found to contain a validation bypass or unsafe workflow behavior, maintainers must publish affected versions and recommended pins.

## Reporting Process

Report vulnerabilities through the organization's private security intake for `AIAllTheThingz/Engineering-Standards`. Do not open public issues for exploitable validation bypasses, secret exposure, workflow injection, compromised dependencies, artifact poisoning, cache poisoning, prompt-injection issues in repository instructions, or false negatives that allow unsafe code to pass validation.

A useful report includes affected version or commit, affected file or workflow, reproduction steps using sanitized data, expected behavior, observed behavior, impact, and any known workaround. Reports MUST NOT include live credentials, customer records, private keys, production endpoints, or exploit payloads beyond what is needed for safe reproduction.

## Security Scope

Security issues include but are not limited to:

- Governance validators accepting invalid manifests, configs, evidence, or exceptions.
- Completion evidence allowing contradictory or false Passed results.
- GitHub Actions using excessive permissions or unsafe event triggers.
- Composite actions executing untrusted input unsafely.
- Scanner rules leaking secrets, missing high-confidence secrets, or encouraging unsafe allowlists.
- Agent standards authorizing destructive operations, secret exposure, or false test evidence.
- Templates asking users to paste sensitive data.
- Release artifacts or tags that cannot be traced to validation evidence.

General documentation wording issues are handled as normal bugs unless they create a realistic bypass or unsafe behavior.

## Triage

Security maintainers MUST classify reports by likelihood, impact, affected versions, downstream exposure, exploitability, and whether the issue weakens a mandatory control. High and Critical issues require prompt maintainer escalation and a release or mitigation plan.

If the report involves a suspected exposed secret, rotate or invalidate the credential before normal debugging continues. If the issue involves a published unsafe workflow or action pin, publish downstream guidance even before the final fix if waiting increases risk.

## Remediation

Security fixes MUST include validation evidence and, when applicable, tests that prevent recurrence. Workflow fixes require permission review and action pin review. Validator fixes require positive and negative test cases. Documentation fixes that change security obligations require release notes.

Emergency fixes may use the emergency release process, but skipped validation must be recorded as `NotRun` or `Blocked` with compensating controls and follow-up work.

## Disclosure

Maintainers SHOULD publish an advisory or release note when a vulnerability affects downstream repositories, required controls, released tags, or reusable workflows. Disclosure should include affected versions, severity, mitigation, fixed version or commit, and downstream action required.

Do not publish sensitive report details that enable exploitation before downstream maintainers have a reasonable migration path.

## Dependency And Workflow Security

Third-party GitHub Actions in production workflows MUST be pinned by full commit SHA. Workflow permissions MUST be least privilege. `pull_request_target` requires explicit security review and is not allowed for workflows that execute untrusted code.

Dependency concerns, compromised packages, suspicious action behavior, or toolchain integrity concerns should be reported through the private security process.

## Evidence

Security fixes require completion evidence that identifies commands run, tests not run, known limitations, warnings, artifact hashes when applicable, and approvals. A fix is not complete when evidence contradicts the actual validation state.

Evidence must be sanitized. Logs, screenshots, and artifacts must not contain secrets, tokens, private keys, customer data, or production-only endpoints.

## Exceptions

Exceptions to this policy require a `GOV-*` record, security maintainer approval, owner, expiration, compensating control, and remediation plan. Exceptions cannot approve known secret exposure, false evidence, or permanent disabling of mandatory security controls.

## Related

- [Action Security](docs/ACTION_SECURITY.md)
- [Release Process](docs/RELEASE_PROCESS.md)
- [Exception Process](governance/EXCEPTION_PROCESS.md)
- [Completion Evidence](governance/COMPLETION_EVIDENCE.md)
- [AI Generated Code Policy](governance/AI_GENERATED_CODE_POLICY.md)
