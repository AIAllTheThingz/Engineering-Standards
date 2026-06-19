# Validate Contract

| Field | Value |
| --- | --- |
| Status | Active |
| Version | 1.0.0 |
| Owner role | GitHub Actions Maintainers |
| Last reviewed | 2026-06-19 |
| Changelog | See [../../CHANGELOG.md](../../CHANGELOG.md). |

## Purpose

This action validates governance contract adoption. It checks the project manifest, governance configuration, required documentation paths, applicable agent standards, evidence path syntax, and exception references.

For the standards repository itself, it also runs documentation completeness. For downstream example or consuming repositories, it validates configured required documentation and resolves applicable agent standards from the downstream repository first, then from the central standards repository.

## Inputs

- `path`: repository root. Defaults to `.`.
- `manifest-path`: manifest path relative to repository root. Defaults to `project-manifest.json`.
- `config-path`: governance config path relative to repository root. Defaults to `governance.config.json`.
- `output-json`: optional repository-relative JSON report path.
- `advisory`: when `true`, records findings but returns success.

## Outputs

- `report-path`: JSON report path when configured.
- `failed-count`: intended count of blocking findings. The JSON report is authoritative.

## Exit Codes

- `0`: contract validation passed, or advisory mode was used.
- `1`: manifest, config, documentation, standard, evidence path, or exception validation failed.

## Security Boundaries

Inputs are treated as untrusted. Paths must resolve under the repository root. The action validates JSON and file presence; it does not execute downstream repository code.

## Evidence

Evidence SHOULD include the command, exit code, report JSON, manifest/config versions, and any blocked or missing contract requirements.

## Example

```yaml
- uses: AIAllTheThingz/Engineering-Standards/actions/validate-contract@<commit-sha>
  with:
    path: .
    output-json: evidence/validate-contract.json
```

## Related Documents

- [../../governance/ORGANIZATION_CONTRACT.md](../../governance/ORGANIZATION_CONTRACT.md)
- [../../governance/EXCEPTION_PROCESS.md](../../governance/EXCEPTION_PROCESS.md)
- [../../schemas/project-manifest.schema.json](../../schemas/project-manifest.schema.json)
- [../../schemas/governance-config.schema.json](../../schemas/governance-config.schema.json)
