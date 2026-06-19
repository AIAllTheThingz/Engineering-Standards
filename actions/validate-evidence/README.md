# Validate Evidence

| Field | Value |
| --- | --- |
| Status | Active |
| Version | 1.0.0 |
| Owner role | GitHub Actions Maintainers |
| Last reviewed | 2026-06-19 |
| Changelog | See [../../CHANGELOG.md](../../CHANGELOG.md). |

## Purpose

This action validates completion evidence. It checks schema-required fields, semantic status consistency, timestamp order, optional commit consistency, artifact hashes, safe paths, test-evidence rules, duplicate test names, and artifact-to-test references.

## Inputs

- `path`: repository root. Defaults to `.`.
- `evidence-path`: completion evidence JSON path. Defaults to `evidence/completion-result.json`.
- `expected-commit-sha`: optional commit SHA that the evidence must match.
- `output-json`: optional repository-relative JSON report path.

## Outputs

- `report-path`: JSON report path when configured.
- `failed-count`: intended count of blocking findings. The JSON report is authoritative.

## Exit Codes

- `0`: evidence validation passed.
- `1`: evidence is missing, malformed, contradictory, unsafe, or inconsistent with artifacts.

## Evidence Rules

The action rejects:

- Overall `Passed` with `Failed`, `Blocked`, or `NotRun` mandatory tests.
- `NotRun` tests with process exit codes.
- `Passed` tests with failure reasons.
- Completion timestamps before start timestamps.
- Duplicate test evidence names.
- Artifact hash mismatches.
- Artifacts referencing unknown tests.
- Paths that escape the repository.

## Security Boundaries

Evidence is untrusted input. The action resolves paths under the repository root and recomputes local artifact hashes where artifacts are present. Missing artifacts produce warnings unless the evidence semantics require them for release or audit review.

## Example

```yaml
- uses: AIAllTheThingz/Engineering-Standards/actions/validate-evidence@<commit-sha>
  with:
    path: .
    evidence-path: evidence/completion-result.json
```

## Related Documents

- [../../governance/COMPLETION_EVIDENCE.md](../../governance/COMPLETION_EVIDENCE.md)
- [../../schemas/completion-result.schema.json](../../schemas/completion-result.schema.json)
- [../../schemas/test-evidence.schema.json](../../schemas/test-evidence.schema.json)
- [../../schemas/artifact-record.schema.json](../../schemas/artifact-record.schema.json)
