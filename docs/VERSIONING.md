# Versioning

| Status | Active |
| Version | 1.0.0 |
| Owner role | Release Maintainers |
| Last reviewed | 2026-06-19 |

## Purpose

This document defines how the engineering standards repository versions governance policy, schemas, validators, workflows, templates, and examples. Versioning exists so downstream repositories can make deliberate adoption decisions and prove which control set governed a change.

Downstream repositories SHOULD pin to immutable commit SHAs for workflow execution. Human-facing references may use release versions when the release tag is protected.

## Version Format

The repository uses semantic versioning: `MAJOR.MINOR.PATCH`. The `VERSION` file records the current repository version. Release tags SHOULD use `vMAJOR.MINOR.PATCH`.

Pre-release identifiers MAY be used for release candidates, such as `v1.2.0-rc.1`, but downstream production repositories SHOULD NOT pin to release candidates unless an approved exception exists.

## Major Versions

Increment the major version for breaking governance changes. Breaking changes include new mandatory fields without defaults, removed schema values, stricter validation that fails previously valid repositories, changed reusable workflow inputs, removal of supported standards, or changes that require new branch protection checks.

Major releases MUST include migration guidance, downstream impact, validation changes, and deprecation notes.

## Minor Versions

Increment the minor version for backward-compatible governance additions. Examples include new optional validation categories, new templates, clearer documentation, additional examples, new non-breaking schema fields, and new advisory checks.

Minor releases MAY introduce controls that are advisory at first and become mandatory in a later major version. The release notes must state the enforcement timeline.

## Patch Versions

Increment the patch version for defect fixes, typo corrections, documentation clarification, validator bug fixes that preserve intended behavior, fixture corrections, and workflow reliability improvements that do not change downstream obligations.

A patch release MUST NOT add new mandatory work for downstream repositories unless the change fixes a security issue and the release notes state the urgency.

## Compatibility Matrix

Maintainers SHOULD support the current major version and one previous major version. Support means security fixes, critical validator fixes, and migration guidance. It does not guarantee that every new feature is backported.

If a security incident requires ending support early, the release process must document the reason, affected versions, and required downstream action.

## Schema Compatibility

Adding optional fields is usually compatible. Adding required fields, narrowing enums, changing field meaning, or changing evidence status semantics is breaking unless a compatibility bridge is implemented.

Schema changes MUST include fixture updates and validation evidence.

Current evidence-schema migration approach:

- Existing historical documents may remain at `1.0.0`.
- New additive fields are introduced under `1.1.0`.
- Validators may accept both `1.0.0` and `1.1.0` during the compatibility window.
- Generators should move forward to `1.1.0` once the compatibility path is in place.

## Workflow Compatibility

Reusable workflow changes are breaking when they remove inputs, rename required jobs, require new permissions, change artifact names relied on by downstream automation, or stop supporting a branch pattern used by downstream repositories.

Changing an action pin to a secure equivalent is normally a patch change if behavior is unchanged. Changing job structure or evidence generation semantics may require a minor or major version depending on downstream impact.

## Documentation Compatibility

Policy text can be breaking. A sentence that changes a SHOULD into a MUST, adds an approval requirement, or forbids an existing practice changes obligations even when no code changed.

Reviewers MUST classify documentation changes by effect, not by file extension.

## Pinning Guidance

Production repositories SHOULD pin reusable workflows to commit SHAs. Release tags are acceptable when the organization protects tags and documents who may move them. Floating branch references such as `@master` are useful for examples and early adoption but are weaker supply-chain controls.

Do not pin third-party actions by major version in production reusable workflows. Use full commit SHAs.

## Deprecation

Deprecations require a documented replacement, timeline, affected files, validation impact, and removal version. A deprecated control remains valid until the removal version unless a security advisory states otherwise.

Downstream repositories with approved exceptions must still plan migration before removal.

## Release Notes

Every release MUST identify breaking changes, new controls, fixed defects, migration actions, changed pins, schema changes, workflow changes, and known issues. Release notes should include example downstream actions when adoption is expected.

If no downstream action is required, state that explicitly.

## Changelog Requirements

`CHANGELOG.md` is the human-readable release ledger. Each release entry MUST include release status, added controls, changed controls, validation performed, known limitations, and migration notes. Security-sensitive fixes SHOULD reference advisories or private report identifiers without disclosing exploit details prematurely.

The changelog MUST agree with `VERSION`, release evidence, and the release tag. If a release is prepared but not tagged, the changelog should state that it is prepared for review rather than published.

## Version File

The root `VERSION` file contains the exact current version without a leading `v`. Release tags SHOULD add the `v` prefix. For example, `VERSION` contains `1.0.0` and the release tag is `v1.0.0`.

Changing `VERSION` requires a changelog update, release evidence refresh, and release maintainer review.

## Validation

Before changing `VERSION`, validate the intended release:

```powershell
pwsh -NoProfile -File scripts/Invoke-GovernanceValidation.ps1 -Path . -Category JsonSchemas,MarkdownLinks,DocumentationCompleteness,Contract,ForbiddenPatterns,RepositoryHealth,Evidence,Examples
```

Schema and validator changes also require Pester evidence.

## Evidence

Version changes require evidence that the release candidate was validated from the repository state being tagged. Evidence must record actual commands, outcomes, warnings, and limitations.

If a release contains generated artifacts, include artifact hashes or the artifact manifest referenced by completion evidence.

## Exceptions

Exceptions to versioning rules require release maintainer approval. Examples include emergency security patch releases, skipped support windows, or temporary tag movement during incident response.

All such exceptions must include a `GOV-*` reference and a post-incident cleanup plan.

## Related

- `docs/RELEASE_PROCESS.md`
- `docs/MAINTAINER_GUIDE.md`
- `governance/COMPLETION_EVIDENCE.md`
- `governance/EXCEPTION_PROCESS.md`
- `docs/ADOPTION_GUIDE.md`
