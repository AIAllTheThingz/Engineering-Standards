# Troubleshooting

| Status | Active |
| Version | 1.0.0 |
| Owner role | Support Maintainers |
| Last reviewed | 2026-06-19 |

## Purpose

This guide helps maintainers diagnose validation, evidence, workflow, and adoption failures. Troubleshooting must preserve evidence integrity: do not hide failures, rewrite results as Passed, or bypass required controls without an approved exception.

When a failure reveals a real governance gap, fix the gap. When a failure is caused by a validator defect, preserve the failing evidence and open a central repository fix.

## Triage Order

Start by identifying the failing category, command, working directory, exit code, and affected file. Then determine whether the failure is policy, schema, workflow, environment, tooling, or evidence related.

Do not change multiple controls at once during diagnosis. Small fixes make evidence easier to trust.

## Contract Validation Failures

Contract validation usually fails because `project-manifest.json` or `governance.config.json` is missing, malformed, points to nonexistent paths, references standards that do not exist, or contains expired exceptions.

Fix the manifest and config first. If the repository type is unusual, update the central schema rather than adding unsupported local fields.

## Schema Validation Failures

Schema failures mean the JSON does not match the declared contract. Common causes include missing required fields, invalid enum values, additional properties, incorrect path structure, or evidence statuses that contradict the schema.

Run:

```powershell
pwsh -NoProfile -File scripts/Test-JsonSchemas.ps1 -Path .
```

If a fixture fails after a schema change, update both valid and invalid fixtures intentionally.

## Documentation Completeness Failures

Documentation completeness fails when required documents are too shallow, missing required concepts, contain empty headings, include unresolved placeholders outside templates, or use fake validation commands.

Author the missing content. Do not pad documents with repeated boilerplate. The document should explain requirements, validation, evidence, exception handling, failure behavior, and related references.

## Markdown Link Failures

Markdown link failures usually come from renamed files, deleted documents, or relative paths that no longer resolve. Fix the link target or remove the stale reference.

Run:

```powershell
pwsh -NoProfile -File scripts/Test-MarkdownLinks.ps1 -Path .
```

External links may be reviewed manually if the repository does not enable external-link validation.

## Evidence Validation Failures

Evidence validation fails when completion evidence is missing required fields, reports overall Passed while tests are Failed, Blocked, Skipped, or NotRun, omits required command metadata, references missing artifacts, or contains contradictory approval information.

Regenerate completion evidence after validation runs. Never edit evidence to claim a run occurred when it did not.

## Forbidden Pattern Findings

Forbidden-pattern findings may indicate exposed secrets, unsafe shell behavior, risky workflow triggers, or documented examples of dangerous constructs. Treat blocking findings as security issues until proven otherwise.

If the finding is documentation or a known false positive, use a narrow reviewed allowlist with owner, reason, path, rule id, and expiration. Prefer rewriting examples to avoid dangerous-looking patterns.

## Repository Health Failures

Repository health failures identify missing required files, invalid manifest or config, absent tests, missing action metadata, incomplete docs, or CODEOWNERS concerns. Fix missing files before tuning validators.

CODEOWNERS warnings often mean placeholders or organization-specific teams need confirmation. Resolve them before branch protection enforcement.

## Workflow Failures

Workflow failures often come from wrong reusable workflow paths, branch filters that do not include the active branch, missing permissions, unpinned actions, or artifact upload paths that are not created on failure.

Confirm that downstream repositories call:

```yaml
uses: AIAllTheThingz/Engineering-Standards/.github/workflows/governance-ci-reusable.yml@<pinned-commit-sha>
```

Entry workflows should call reusable workflows. Reusable workflows should not call entry workflows.

## Pester Failures

Pester failures indicate validator behavior changed or a regression was introduced. Read the failing test name before changing implementation. If a test is obsolete because governance policy changed, update the policy, validator, and test together.

Run:

```powershell
pwsh -NoProfile -Command "Invoke-Pester -Path tests -Output Detailed"
```

## YAML Parsing Gaps

If local YAML tooling is unavailable, record YAML validation as `NotRun` rather than Passed. GitHub Actions will still parse workflows remotely, but local evidence must accurately state what was and was not checked.

Install a supported YAML parser or add a validator before making YAML syntax claims in completion evidence.

## Branch Protection Issues

If required checks do not appear in branch protection settings, first run the workflow on the target branch so GitHub creates the check name. Then configure the exact check name.

If a repository changed from `master` to `main`, update workflow branch filters, branch protection rules, documentation, and adoption evidence together.

## Template Issues

Templates may contain placeholders inside `templates/`, but generated repository files must replace them. If documentation completeness fails after copying a template, fill in repository-specific details instead of suppressing the validator.

Issue and pull request templates should request sanitized evidence. Do not ask users to paste secrets, production tokens, private keys, or customer data.

## Exception Issues

Expired exceptions fail validation or review. Renewing an exception requires updated risk assessment, owner approval, new expiration, and evidence of compensating controls.

An exception cannot approve false evidence or known secret exposure.

## Recovery Steps

After fixing a failure, rerun the smallest relevant validator, then run aggregate validation. Regenerate completion evidence only after the final validation run.

If a central bug blocks many downstream repositories, open an emergency fix in this repository, document affected versions, and publish guidance.

## Evidence

Troubleshooting evidence should include failing command, exit code, logs with secrets redacted, changed files, rerun command, final result, and any manual reviewer notes.

When a tool was unavailable, include runtime context and mark the status honestly as `NotRun` or `Blocked`.

## Related

- `docs/ADOPTION_GUIDE.md`
- `docs/DOWNSTREAM_CONFIGURATION.md`
- `docs/BRANCH_PROTECTION.md`
- `docs/ACTION_SECURITY.md`
- `governance/COMPLETION_EVIDENCE.md`
- `governance/EXCEPTION_PROCESS.md`
