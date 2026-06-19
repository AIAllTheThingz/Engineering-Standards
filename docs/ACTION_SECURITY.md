# Action Security

| Status | Active |
| Version | 1.0.0 |
| Owner role | Action Security Maintainers |
| Last reviewed | 2026-06-19 |

## Least Privilege

Validation workflows SHOULD use `contents: read` and no secrets. Actions MUST NOT require write permissions for pull-request validation.

## Untrusted Pull Requests And Forks

Pull-request content, filenames, workflow inputs, issue text, and generated evidence are untrusted. Avoid `pull_request_target` unless a documented security requirement exists and checkout of untrusted code is prevented.

## Injection Defenses

Use PowerShell parameters, quote paths, reject traversal, avoid `Invoke-Expression`, and never concatenate untrusted context into executable commands.

## Safe Example

```powershell
pwsh -File ./scripts/Test-MarkdownLinks.ps1 -Path $env:GITHUB_WORKSPACE
```

## Unsafe Example

```powershell
Invoke-Expression $env:USER_SUPPLIED_COMMAND
```

## Action Pinning

Pinned SHAs: checkout `{CHECKOUT_SHA}`, setup-node `{SETUP_NODE_SHA}`, setup-dotnet `{SETUP_DOTNET_SHA}`, upload-artifact `{UPLOAD_SHA}`.

## Review Checklist

- Permissions are read-only unless justified.
- Third-party actions are pinned.
- Outputs do not contain secrets.
- Artifacts are validated before trust.
- Paths remain under workspace.

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
