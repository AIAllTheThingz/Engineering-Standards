# Repository Health

| Field | Value |
| --- | --- |
| Status | Active |
| Version | 1.0.0 |
| Owner role | GitHub Actions Maintainers |
| Last reviewed | 2026-06-19 |
| Changelog | See [../../CHANGELOG.md](../../CHANGELOG.md). |

## Purpose

This action validates that a repository has the minimum governance structure needed to adopt the Engineering Standards model. It checks required files, JSON parseability, manifest/config semantics, documentation completeness, schema fixtures, Pester test presence, CODEOWNERS signals, action metadata, and action documentation.

## Inputs

- `path`: repository root. Defaults to `.`.
- `output-json`: optional repository-relative JSON report path.
- `advisory`: when `true`, records findings but returns success.

## Outputs

- `report-path`: JSON report path when configured.
- `failed-count`: intended count of blocking findings. The JSON report is authoritative.

## Checks

The action checks:

- Required root files such as `README.md`, `SECURITY.md`, `CONTRIBUTING.md`, `CODEOWNERS`, `AGENTS.md`, `project-manifest.json`, and `governance.config.json`.
- Required governance docs such as `docs/BRANCH_PROTECTION.md` and `docs/ACTION_SECURITY.md`.
- JSON parsing for repository JSON files.
- `project-manifest.json` and `governance.config.json` semantic validation.
- Documentation completeness.
- Schema and fixture validation.
- Presence of Pester tests.
- Presence of action metadata and README files for local actions.

## Exit Codes

- `0`: no blocking health failures, or advisory mode was used.
- `1`: one or more required health checks failed.

## Validation And Evidence

Evidence SHOULD include the command, exit code, JSON report, failed checks, warnings, and remediation plan. Repository health passing does not mean production readiness; it means the repository has the required governance structure.

## Security Boundaries

The action reads repository files and runs repository-local validators from this standards package. It does not require secrets and does not perform network operations.

## Example

```yaml
- uses: AIAllTheThingz/Engineering-Standards/actions/repository-health@<commit-sha>
  with:
    path: .
    output-json: evidence/repository-health.json
```

## Related Documents

- [../../docs/ACTION_SECURITY.md](../../docs/ACTION_SECURITY.md)
- [../../governance/ORGANIZATION_CONTRACT.md](../../governance/ORGANIZATION_CONTRACT.md)
- [../../governance/COMPLETION_EVIDENCE.md](../../governance/COMPLETION_EVIDENCE.md)
