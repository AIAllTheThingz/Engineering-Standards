# Validate Evidence

| Field | Value |
| --- | --- |
| Status | Active |
| Version | 1.0.0 |
| Owner role | GitHub Actions Maintainers |
| Last reviewed | 2026-06-19 |
| Changelog | See [CHANGELOG.md](../../CHANGELOG.md) unless this file is at repository root. |

## Normative Terminology

`MUST` and `MUST NOT` define mandatory requirements. `SHOULD` and `SHOULD NOT` define expected practices that require a documented reason when not followed. `MAY` defines optional behavior. Every mandatory statement is intended to be testable by automation, review, or recorded evidence.

## Purpose

Validates completion evidence, status consistency, timestamp order, and artifact hashes.

## Inputs

- `path`: required behavior and validation are documented in `action.yml`; paths are resolved beneath the workspace.
- `evidence-path`: required behavior and validation are documented in `action.yml`; paths are resolved beneath the workspace.
- `expected-commit-sha`: required behavior and validation are documented in `action.yml`; paths are resolved beneath the workspace.
- `output-json`: required behavior and validation are documented in `action.yml`; paths are resolved beneath the workspace.

## Outputs

- `report-path`: emitted through `$GITHUB_OUTPUT` when running inside GitHub Actions and included in the JSON report.
- `failed-count`: emitted through `$GITHUB_OUTPUT` when running inside GitHub Actions and included in the JSON report.

## Exit Codes

- `0`: no mandatory failures were found.
- `1`: one or more mandatory failures were found.
- Advisory mode records findings but returns `0` so teams can adopt the check before making it blocking.

## Security Boundaries

The action treats repository files, paths, configuration, and evidence as untrusted input. It validates paths, avoids executing repository-provided code, redacts suspected secrets, and does not require repository secrets.

## Usage Examples

```yaml
- uses: AIAllTheThingz/Engineering-Standards/actions/validate-evidence@<commit-sha>
  with:
    path: .
    output-json: evidence/validate-evidence.json
```

## Troubleshooting

Check the JSON report first. Path failures usually mean a configured path escaped the workspace or a required file is missing. Schema failures usually identify the field name. Scanner findings require either remediation or a reviewed allowlist entry with a reason and expiration.

## Known Limitations

This action validates governance contracts and evidence; it does not replace code review, threat modeling, dependency scanning, or production approval.

