# Evidence Directory

This directory contains a mixture of current authority pointers, durable release records, and historical/local validation snapshots. File location alone does **not** imply that an evidence record validates the current `master` head.

## Current Authority

`latest-verified-run.json` is the repository's durable pointer to the most recently **independently verified hosted Governance CI artifact**. Update it only after the named GitHub run completes, the artifact is downloaded independently, the ZIP SHA-256 matches GitHub metadata, and the structured evidence inside the archive is inspected.

A newer workflow run that has not completed or whose artifact has not been independently verified MUST NOT replace this pointer. Missing verification remains `NotRun` or `Blocked`; it is never inferred from workflow status alone.

Release authority is recorded separately in the release lifecycle/status records. For published governance releases, use `docs/RELEASE_STATUS.md`, `governance/downstream-compatibility.json`, the immutable protected release tag, and the corresponding lifecycle evidence rather than treating `latest-verified-run.json` as release evidence.

## Historical And Local Snapshots

Many other JSON files directly under `evidence/` were generated for specific historical branches, issues, or local validation sessions. Examples include local aggregate, contract, environment, completion, and validator outputs. Those files remain truthful for the exact commit, branch, execution context, timestamps, and limitations embedded in each record.

Do not interpret an old root-level filename such as `environment.json`, `governance-validation.json`, `aggregate-governance.json`, or `local-completion-result.json` as proof for the current `master` head unless the record itself binds to that head and its validation context.

Historical records should be preserved rather than silently rewritten to look current. When a future maintenance change deliberately archives or replaces one of these snapshots, preserve provenance and update all repository references in the same reviewed change.

## Release Evidence

`evidence/releases/` contains release-specific durable records. Historical published-release evidence is immutable context and must not be rewritten merely because later releases corrected or superseded behavior.

Release tags and GitHub Releases are external state. Evidence cleanup must never move, recreate, delete, or rewrite a published release tag or alter a historical release merely to make old evidence appear current.

## History

`evidence/history/` is the preferred location for intentionally archived evidence sets when a reviewed cleanup proves that moving a historical snapshot will not break a schema, validator, test, documentation link, or durable audit reference.

Do not perform bulk evidence moves or deletions. First inventory consumers of the exact path, preserve the original commit identity, and validate the resulting repository state.

## Maintenance Rules

- Record actual execution context and exact commit SHA.
- Use hosted GitHub metadata only for hosted execution claims.
- Independently hash artifacts used as authoritative hosted evidence.
- Preserve `Failed`, `Blocked`, and `NotRun` honestly.
- Do not regenerate historical evidence solely to make it match a later branch or commit.
- Do not delete evidence unless it is replaced or archived with equivalent provenance and the change is reviewed.
- Treat `latest-verified-run.json` as a pointer, not as a substitute for the artifact it references.
