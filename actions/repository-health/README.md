# Repository Health

| Field | Value |
| --- | --- |
| Status | Active |
| Version | 1.0.0 |
| Owner role | GitHub Actions Maintainers |
| Last reviewed | 2026-07-12 |
| Changelog | See [../../CHANGELOG.md](../../CHANGELOG.md). |

## Purpose

This action validates that a repository has the minimum governance structure needed to adopt the Engineering Standards model. It checks required files, JSON parseability, manifest/config semantics, documentation completeness, schema fixtures, Pester test presence, CODEOWNERS signals, action metadata, and action documentation.

## Inputs

- `path`: repository root. Defaults to `.`.
- `output-json`: optional repository-relative JSON report path.
- `advisory`: when `true`, records findings but returns success.
- `repository-owner-type`: optional trusted owner type with exact accepted values `Unknown`, `User`, or `Organization`. It defaults to `Unknown`, so offline validation never infers live GitHub ownership from a repository name. Supply `User` or `Organization` only from trusted repository metadata or verified GitHub API evidence. This compatibility input does not prove that an owner identity exists or has repository review access.

## Outputs

- `report-path`: JSON report path when configured.
- `failed-count`: intended count of blocking findings. The JSON report is authoritative.

## Checks

The action checks:

- Required root files such as `README.md`, `SECURITY.md`, `CONTRIBUTING.md`, `AGENTS.md`, `project-manifest.json`, and `governance.config.json`, plus a `CODEOWNERS` file in a GitHub-supported location.
- Required governance docs such as `docs/BRANCH_PROTECTION.md` and `docs/ACTION_SECURITY.md`.
- JSON parsing for repository JSON files.
- `project-manifest.json` and `governance.config.json` semantic validation.
- Documentation completeness.
- Schema and fixture validation.
- Presence of Pester tests.
- Deterministic CODEOWNERS validation for user, organization/team, and conservative email-owner syntax; full-line and inline comments; placeholders; active default coverage; and repository-specific high-risk path coverage. The action selects the same single CODEOWNERS location GitHub uses: `.github/CODEOWNERS` first, then root `CODEOWNERS`, then `docs/CODEOWNERS`; lower-priority files are ignored when a higher-priority file exists, and result paths identify the selected file. Candidate path segments must match exact ordinal casing, and the selected file must be a regular file rather than a symbolic link, junction, or reparse point. An invalid higher-priority candidate fails validation instead of falling through to a lower-priority file. Configure high-risk paths with `ownership.requiredCodeownerPaths` in `governance.config.json`. Each configured value must be a rooted literal CODEOWNERS path and must exist with exact casing. Values ending in `/` must be directories; other values must be files. Repository health evaluates every concrete file below an explicitly configured directory, without discovering outside that directory; an empty directory uses its configured base path. When the property is absent, repository health requires default `*` coverage but does not invent Engineering Standards paths for downstream repositories. Required-path ownership uses the last matching rule. The supported matching subset is `*`, rooted or unrooted literal file and directory rules, and simple `*` or `**` globs; a later decision-relevant unsupported pattern fails closed. With owner type `Unknown`, structurally valid user, team, and email forms are accepted without a live-eligibility claim. User-versus-organization compatibility is enforced only from explicit trusted input; identity existence and repository review access require separate GitHub API evidence.
- Presence of action metadata and README files for local actions.

## Exit Codes

- `0`: no blocking health failures, or advisory mode was used.
- `1`: one or more required health checks failed.

## Validation And Evidence

Evidence SHOULD include the command, exit code, JSON report, failed checks, warnings, and remediation plan. Repository health passing does not mean production readiness; it means the repository has the required governance structure.

## Security Boundaries

The action reads repository files and runs repository-local validators from this standards package. It does not require secrets and does not perform network operations.

## Examples

Downstream repository using the safe generic fallback (valid default `*` CODEOWNERS coverage, with no central-repository path assumptions):

```yaml
- uses: AIAllTheThingz/Engineering-Standards/actions/repository-health@0123456789abcdef0123456789abcdef01234567
  with:
    path: .
    output-json: evidence/repository-health.json
```

This central user-owned governance repository, whose `governance.config.json` declares its mandatory high-risk paths, with verified owner metadata:

```yaml
- uses: AIAllTheThingz/Engineering-Standards/actions/repository-health@0123456789abcdef0123456789abcdef01234567
  with:
    path: .
    repository-owner-type: User
```

Organization-owned repository with verified owner metadata:

```yaml
- uses: AIAllTheThingz/Engineering-Standards/actions/repository-health@0123456789abcdef0123456789abcdef01234567
  with:
    path: .
    repository-owner-type: Organization
```

## Related Documents

- [../../docs/ACTION_SECURITY.md](../../docs/ACTION_SECURITY.md)
- [../../governance/ORGANIZATION_CONTRACT.md](../../governance/ORGANIZATION_CONTRACT.md)
- [../../governance/COMPLETION_EVIDENCE.md](../../governance/COMPLETION_EVIDENCE.md)
