# Action Security

| Field | Value |
| --- | --- |
| Status | Active |
| Version | 1.0.0 |
| Owner role | Action Security Maintainers |
| Last reviewed | 2026-06-19 |

## Purpose

This guide defines security requirements for GitHub Actions, composite actions, reusable workflows, and repository-local validation scripts in this governance repository. Actions are part of the trust boundary: a weak workflow can bypass review, expose secrets, publish untrusted artifacts, or convert untrusted pull request content into executable commands.

## Applicability

This guide applies to:

- `.github/workflows/*.yml`
- `workflows/*.yml`
- `actions/*/action.yml`
- Action PowerShell scripts.
- Reusable workflow examples.
- Evidence upload and validation steps.
- Any workflow that checks out, validates, packages, publishes, or deploys repository content.

## Least Privilege

Validation workflows SHOULD use:

```yaml
permissions:
  contents: read
```

Actions MUST NOT require write permissions for ordinary pull-request validation. Write permissions require documented purpose, risk classification, reviewer approval, and evidence. Broad permissions such as `write-all` are prohibited without an approved exception.

Secrets SHOULD NOT be available to validation jobs for untrusted pull requests. If secrets are required, split validation so untrusted code is not checked out or executed in the secret-bearing job.

## Untrusted Pull Requests And Forks

Pull request content, filenames, workflow inputs, issue text, comments, generated evidence, and artifacts are untrusted. Workflows MUST NOT execute untrusted pull request code with privileged tokens.

Avoid `pull_request_target` unless there is a documented security requirement and the workflow does not check out or execute untrusted code. If `pull_request_target` is used, reviewers MUST confirm:

- The checkout ref is trusted.
- No untrusted scripts run.
- Secrets are not exposed to fork content.
- Labels, comments, or changed files do not become executable commands.

## Command Injection Defenses

Workflow and action authors MUST treat inputs as untrusted. Use typed script parameters and argument arrays. Do not concatenate workflow inputs, filenames, branch names, PR titles, issue bodies, or JSON fields into shell commands.

PowerShell actions SHOULD call scripts with parameter arrays and `-LiteralPath` where possible. Avoid dynamic execution patterns such as `Invoke-Expression` except when documenting a prohibited example. If dynamic execution appears in production action code, it requires security review and an approved exception.

## Path Safety

Actions MUST resolve repository-provided paths under the workspace and reject traversal. Output report paths MUST also remain under the workspace. Recursive operations MUST verify absolute targets before deletion, move, or overwrite.

Examples of unsafe path behavior:

- Accepting `../outside.json` as an output path.
- Passing user-controlled paths to another shell for deletion.
- Treating filenames from a pull request as trusted command arguments without literal-path handling.

## Action Pinning

Third-party actions in reusable workflows MUST be pinned by immutable commit SHA unless an approved exception exists. Major-version tags are not sufficient for governance-critical validation.

Pinned actions currently used by this repository:

- `actions/checkout`: `34e114876b0b11c390a56381ad16ebd13914f8d5`
- `actions/setup-node`: `49933ea5288caeca8642d1e84afbd3f7d6820020`
- `actions/setup-dotnet`: `67a3573c9a986a3f9c594539f4ab511d57bb3ce9`
- `actions/upload-artifact`: `ea165f8d65b6e75b540449e92b4886f43607fa02`

Changing these pins requires review of release notes, permissions, and supply-chain risk.

## Artifact And Evidence Safety

Artifacts are untrusted until validated. Evidence files MUST be schema-validated and reviewed before they support completion claims. Artifact hashes SHOULD be recomputed for local artifacts and compared to recorded evidence.

Actions MUST NOT upload secrets, raw tokens, private keys, unredacted logs, regulated data, or production payloads as artifacts. Artifact names and paths MUST be treated as untrusted.

## Composite Action Requirements

Composite actions SHOULD:

- Use `pwsh` with explicit scripts rather than inline complex logic.
- Pass inputs as parameters.
- Validate paths in the script.
- Emit JSON reports.
- Avoid repository secrets.
- Return nonzero when mandatory validation fails.
- Document advisory mode separately from blocking mode.

Composite actions MUST keep `action.yml`, README, implementation script, and tests synchronized.

## Scanner And Health Actions

Security scanner actions MUST redact findings, support narrow allowlists, and report limitations. Repository health actions MUST validate structure without treating existence as complete proof of readiness.

Allowlist entries require owner, reason, and expiration. Expired entries are ignored. Warnings require review; they are not automatic approval.

## Review Checklist

Reviewers MUST check:

- Permissions are least privilege.
- Third-party actions are pinned by SHA.
- Untrusted code is not executed with secrets.
- Inputs and paths are validated.
- Dynamic command execution is absent or explicitly justified.
- Outputs and artifacts do not expose secrets.
- Action docs match implementation.
- Tests cover failure paths, not just success paths.
- Evidence records failed, blocked, and not-run checks honestly.

## Validation

Action changes SHOULD run:

```powershell
pwsh -NoProfile -File scripts/Test-MarkdownLinks.ps1 -Path .
pwsh -NoProfile -File scripts/Test-DocumentationCompleteness.ps1 -Path .
pwsh -NoProfile -File actions/forbidden-pattern-scan/Invoke-ForbiddenPatternScan.ps1 -Path .
pwsh -NoProfile -File actions/repository-health/Invoke-RepositoryHealth.ps1 -Path .
Invoke-Pester -Path tests/actions -Output Detailed
```

Workflow syntax validation MUST run through `scripts/Test-YamlSyntax.ps1` with PyYAML pinned to a reviewed version in CI. Workflow semantic validation MUST run through `scripts/Test-GitHubWorkflowArchitecture.ps1` to detect recursion, invalid reusable paths, unsupported inputs, broad permissions, and unpinned third-party actions.

## Exception Handling

Exceptions MUST follow [../governance/EXCEPTION_PROCESS.md](../governance/EXCEPTION_PROCESS.md). Exceptions are required for broad write permissions, unpinned third-party actions, privileged `pull_request_target`, dynamic command execution in action code, or secret-bearing validation of untrusted pull requests.

## Related Documents

- [../governance/ORGANIZATION_CONTRACT.md](../governance/ORGANIZATION_CONTRACT.md)
- [../governance/COMPLETION_EVIDENCE.md](../governance/COMPLETION_EVIDENCE.md)
- [../governance/RISK_CLASSIFICATION.md](../governance/RISK_CLASSIFICATION.md)
- [../governance/EXCEPTION_PROCESS.md](../governance/EXCEPTION_PROCESS.md)
- [../actions/forbidden-pattern-scan/README.md](../actions/forbidden-pattern-scan/README.md)
- [../actions/repository-health/README.md](../actions/repository-health/README.md)
