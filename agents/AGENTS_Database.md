# AGENTS Database Standard

| Field | Value |
| --- | --- |
| Status | Active |
| Version | 1.0.0 |
| Owner role | Engineering Standards Maintainers |
| Last reviewed | 2026-06-19 |
| Changelog | See [../CHANGELOG.md](../CHANGELOG.md). |

## Purpose

This document defines enterprise requirements for AI agents working on database schema, migrations, queries, stored procedures, data access scripts, seed data, rollback scripts, and database automation. It inherits [AGENTS_Base.md](AGENTS_Base.md).

## Applicability

This standard applies to SQL and NoSQL schema changes, migration frameworks, stored procedures, functions, triggers, views, indexes, constraints, permissions, seed data, data repair scripts, ETL/ELT jobs, rollback scripts, and CI validation for database changes.

## Required Discovery

Before editing, agents MUST identify:

- Database engine, version, and migration framework.
- Migration ordering and naming conventions.
- Rollback mechanism or mitigation strategy.
- Data classification and production-data restrictions.
- Required permissions and execution identity.
- Backup, restore, and point-in-time recovery assumptions.
- Long-running operations, locks, blocking, replication, and availability impact.
- Existing tests, fixtures, seed data, and validation scripts.

Agents MUST inspect prior migrations before adding a new one.

## Risk Classification

Database changes are Critical by default when they delete, truncate, overwrite, anonymize, backfill regulated data, change primary keys, alter authentication/authorization tables, or perform broad production data repair.

Additive nullable changes are often Moderate. Indexes on high-traffic tables, constraint changes, data backfills, and query changes on production paths are High unless proven lower.

## Migration Requirements

Migrations MUST be ordered, reviewable, and deterministic. They SHOULD be idempotent where the migration framework expects idempotency. Each migration SHOULD identify forward behavior, rollback behavior, data impact, lock risk, and expected runtime.

Destructive changes MUST include explicit approval, backup or recovery plan, target scope, and rollback or mitigation evidence. "Rollback impossible" is allowed only when documented and approved.

## Query And Data Access Requirements

Queries MUST use parameterization or safe framework APIs. Agents MUST avoid string-built SQL from untrusted input. Query changes SHOULD consider indexes, execution plans, cardinality, timeouts, transaction scope, isolation level, and lock behavior.

Data repair scripts MUST target explicit records, support dry-run or preview when feasible, record affected-row counts, and refuse broad execution without approval.

## Security And Privacy

Database work MUST enforce least privilege. Agents MUST NOT commit credentials, connection strings with secrets, production dumps, regulated data, or realistic customer records. Test data MUST be synthetic or approved.

Changes that alter access to confidential or regulated data require security and data review.

## Validation Requirements

Recommended validation includes:

- Static syntax validation for SQL or migration files.
- Migration ordering check.
- Destructive-change scan.
- Apply test against an ephemeral database where feasible.
- Rollback validation where supported.
- Query plan or performance review for high-impact queries.
- Permission review for grants, roles, policies, and ownership changes.

If an ephemeral database is unavailable, record `NotRun` or `Blocked` and identify what environment is required.

## Evidence

Evidence MUST include migration files changed, validation commands, target engine, apply result or `NotRun` reason, rollback result or mitigation, affected data classification, destructive-change assessment, approvals, and remaining risk.

## Failure Behavior

The work is incomplete if migrations are unordered, rollback is missing for reversible changes, destructive operations lack approval, production data appears in fixtures, query validation did not run without explanation, or evidence claims a database validation passed when no database was available.

## Related Documents

- [AGENTS_Base.md](AGENTS_Base.md)
- [AGENTS_DotNet.md](AGENTS_DotNet.md)
- [../governance/RISK_CLASSIFICATION.md](../governance/RISK_CLASSIFICATION.md)
- [../governance/COMPLETION_EVIDENCE.md](../governance/COMPLETION_EVIDENCE.md)

## Exception Handling

Exceptions MUST follow [../governance/EXCEPTION_PROCESS.md](../governance/EXCEPTION_PROCESS.md). Database safety controls MUST NOT be waived for convenience, speed, or lack of a local database.
