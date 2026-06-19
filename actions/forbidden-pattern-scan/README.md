# Forbidden Pattern Scan

| Field | Value |
| --- | --- |
| Status | Active |
| Version | 1.0.0 |
| Owner role | GitHub Actions Maintainers |
| Last reviewed | 2026-06-19 |
| Changelog | See [../../CHANGELOG.md](../../CHANGELOG.md). |

## Purpose

This action scans repository text files for defensive forbidden patterns such as embedded credential assignments, private key markers, disabled TLS validation, dangerous PowerShell execution, broad destructive commands, unsafe workflow permissions, and download-and-execute patterns.

It is a governance guardrail, not a complete secret scanner or SAST product. Repositories SHOULD still use dedicated secret scanning, dependency scanning, and code review.

## Inputs

- `path`: repository or workspace path to scan. Defaults to `.`.
- `pattern-file`: optional repository-relative custom pattern file. Defaults to this action's `forbidden-patterns.json`.
- `allowlist-file`: optional repository-relative allowlist file.
- `output-json`: optional repository-relative JSON report path.
- `advisory`: when `true`, records findings but returns success.

All repository-provided paths are resolved under the scan root. Traversal outside the workspace is rejected.

## Outputs

- `report-path`: JSON report path when configured.
- `failed-count`: intended count of blocking findings. The PowerShell report is authoritative when consuming this value outside the composite action.

## Report Contents

The report includes scanner version, root path, pattern file, allowlist file, advisory mode, scanned file count, skipped files, findings, failed count, and warning count. Findings include pattern id, severity, path, line number, description, and redacted match snippet.

## Allowlist Requirements

Allowlist entries must include:

- `patternId`
- `path`
- `owner`
- `reason`
- `expiresOn`

Expired entries are ignored. Entries with short or missing reasons are ignored. Allowlists should be narrow and temporary.

## Exit Codes

- `0`: no blocking findings, or advisory mode was used.
- `1`: one or more `error` severity findings occurred.

## Validation And Evidence

Evidence SHOULD include the exact scanner command, exit code, JSON report, any allowlist entries used, and reviewer rationale for remaining warnings. A warning is not proof of safety; it is a prompt for review.

## Security Boundaries

The action does not execute repository files. It reads text files, skips binary and large files, redacts matches, and treats pattern and allowlist files as untrusted configuration. The scanner does not need repository secrets.

## Example

```yaml
- uses: AIAllTheThingz/Engineering-Standards/actions/forbidden-pattern-scan@<commit-sha>
  with:
    path: .
    output-json: evidence/forbidden-pattern-scan.json
```

## Related Documents

- [../../docs/ACTION_SECURITY.md](../../docs/ACTION_SECURITY.md)
- [../../governance/COMPLETION_EVIDENCE.md](../../governance/COMPLETION_EVIDENCE.md)
- [../../governance/EXCEPTION_PROCESS.md](../../governance/EXCEPTION_PROCESS.md)
