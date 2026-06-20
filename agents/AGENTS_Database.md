# AGENTS Database Standard

| Field | Value |
| --- | --- |
| Status | Active |
| Version | 1.1.0 |
| Owner role | Engineering Standards Maintainers |
| Last reviewed | 2026-06-20 |
| Changelog | See [../CHANGELOG.md](../CHANGELOG.md). |

## Purpose

This document defines enforceable enterprise requirements for AI agents creating, reviewing, or modifying database schemas, SQL, migrations, data repair scripts, seed data, ETL/ELT processes, permissions, database deployment automation, backup and recovery procedures, and database completion evidence.

It inherits [AGENTS_Base.md](AGENTS_Base.md), the repository-root [../AGENTS.md](../AGENTS.md), and the governance documents. It does not replace application, worker, integration, infrastructure, or PowerShell standards; it adds database-specific controls for data safety, availability, security, integrity, performance, and recoverability.

When this standard says a control is required, agents MUST implement it, prove it already exists, record a valid `NotApplicable`, `NotRun`, or `Blocked` status with reason, or reference an approved active exception.

## Applicability And Inheritance

This standard applies to:

- SQL Server, Azure SQL Database, Azure SQL Managed Instance, PostgreSQL, MySQL, MariaDB, Oracle Database, SQLite, other relational databases, and NoSQL databases where the rule applies.
- Schemas, tables, columns, keys, constraints, indexes, views, functions, triggers, stored procedures, sequences, partitions, security policies, and permissions.
- EF Core migrations, DACPAC and SQL database projects, Flyway, Liquibase, DbUp, native SQL migration scripts, and other migration frameworks.
- Data repair scripts, backfills, transformations, seed data, reference data, reporting queries, ETL/ELT pipelines, and batch processors.
- Database CI/CD, deployment automation, rollback scripts, backup verification, restore validation, replication, clustering, failover-sensitive changes, and database evidence.

Cross-standard handoffs are mandatory:

- Application data access, EF Core code, DbContext lifetime, API behavior, and .NET migration tooling MUST also apply [AGENTS_DotNet.md](AGENTS_DotNet.md).
- PowerShell migration, deployment, data repair, reporting, or administrative automation MUST also apply [AGENTS_PowerShell.md](AGENTS_PowerShell.md).
- Scheduled jobs, queue consumers, ETL workers, backfills, and unattended processors MUST also apply [AGENTS_WorkerService.md](AGENTS_WorkerService.md).
- External feeds, file transfers, webhooks, vendor APIs, partner data, and cross-system synchronization MUST also apply [AGENTS_Integration.md](AGENTS_Integration.md).
- Database hosts, managed database services, networking, storage, TLS, backup infrastructure, clustering, and failover configuration MUST also apply [AGENTS_Infrastructure.md](AGENTS_Infrastructure.md).

Local instructions MAY strengthen this standard. They MUST NOT weaken root, base, security, review, evidence, validation, or exception controls.

## Normative Terminology

`MUST` and `MUST NOT` are mandatory. `SHOULD` and `SHOULD NOT` are expected controls that require recorded rationale when omitted. `MAY` is optional.

`Destructive` means a change that can delete, truncate, overwrite, anonymize, narrow, disable, reseed, revoke, broaden, corrupt, or irreversibly transform data, metadata, identity, permissions, availability, or recoverability.

`DryRun` means a validation or preview path that inspects target scope, planned mutations, affected-row estimates, permissions, and stop conditions without mutation.

`NotRun` means validation did not execute. `Blocked` means validation could not complete because a required tool, engine, credential, backup system, replica, approval, or environment was unavailable. Agents MUST NOT convert unavailable database tooling, credentials, ephemeral databases, backups, replicas, production access, or approvals into `Passed`.

## Required Discovery

Before editing database-related files, agents MUST inspect and record the relevant subset of:

- Database engine and exact version.
- Compatibility level, dialect, managed-service restrictions, required extensions, and supported feature set.
- Deployment target, topology, managed service versus self-hosted status, and environment separation.
- Development model: EF Core migrations, DACPAC/database project, Flyway, Liquibase, DbUp, native scripts, ORM-generated, state-based, hybrid, or another framework.
- Migration history, naming, ordering, checksum behavior, ownership, and already-applied immutable migrations.
- Schema ownership, namespace conventions, object naming, and authoritative source of schema truth.
- Data classification, tenant boundaries, retention requirements, and privacy obligations.
- Estimated row counts, table sizes, hot paths, production traffic, and maintenance windows.
- Backup, restore, point-in-time recovery, log/WAL/archive chain, and restore-test status.
- Replication, Availability Groups, clustering, read replicas, sharding, partitioning, CDC, temporal tables, and failover behavior.
- Application versions that will coexist during rollout and whether rolling deployments are expected.
- Connection pooling, command timeout, lock timeout, transaction timeout, retry, and cancellation behavior.
- Current indexes, constraints, triggers, views, procedures, functions, permissions, roles, and security policies.
- Query plans, statistics, cardinality, blocking, lock escalation, deadlock history, parameter sensitivity, and query-store or equivalent telemetry where relevant.
- Drift detection, schema comparison tooling, test database availability, synthetic fixtures, credentials, execution identity, deployment procedure, rollback procedure, and existing user changes from `git status`.

Agents MUST inspect prior migrations and adjacent schema objects before adding or modifying database changes. Guessing from filenames is insufficient.

## Risk Classification

Database work MUST be classified using [../governance/RISK_CLASSIFICATION.md](../governance/RISK_CLASSIFICATION.md). Risk MUST be reclassified when scope, row count, lock behavior, runtime, data sensitivity, permissions, production target, replication impact, or rollback feasibility changes.

Critical by default:

- `DROP`, `TRUNCATE`, broad `DELETE`, destructive `ALTER`, primary-key change, irreversible transformation, unbounded export, cross-tenant data movement, broad production data repair, regulated-data deletion, authentication or authorization table change, payment/clinical/financial/session data change, encryption key or certificate change, permission broadening, disabling constraints, triggers, auditing, replication, or security policies, backup retention reduction, and production data repair across broad scope.

High by default:

- Non-null column additions to populated tables, column type changes, large index builds, foreign-key or unique constraint changes, backfills, production-path query changes, trigger changes, stored procedure changes used by production applications, partition changes, replication-sensitive changes, long-running migrations, and changes with lock or availability risk.

Moderate examples:

- Additive nullable columns, new isolated tables, read-only reporting objects, nonproduction fixture changes, and documentation for existing database objects when no behavior changes.

Agents MUST NOT lower risk classification merely to reduce required validation or approval.

## Supported Database Engines And Versions

Every database project MUST declare:

- Supported engines and supported versions.
- Compatibility levels, dialects, required extensions, and managed-service restrictions.
- Collation, case-sensitivity, character encoding, time-zone behavior, and date/time precision assumptions.
- Identifier-length limits, reserved-word constraints, quoting rules, and naming portability limits.
- Transactional DDL support, online operation support, resumable operation support, generated-column behavior, computed-column behavior, and engine-specific rollback limitations.

Agents MUST NOT silently introduce syntax unsupported by declared engines. Engine-specific SQL MUST be isolated and documented. Cross-engine compatibility claims MUST be tested against each declared engine or recorded as `NotRun`. End-of-support engine versions MUST NOT be introduced. Existing unsupported engines MUST be identified as risk.

## Database Development Model

Each repository MUST declare one authoritative schema model:

- Migration-first.
- State-based database project.
- Hybrid.
- ORM-generated.
- Native SQL.

The selected model MUST define migration ordering, ownership, review process, history table or checksum protection where supported, drift detection, generated SQL review, and reconciliation between schema model, migrations, deployment scripts, rollback scripts, and documentation.

Agents MUST NOT edit already-applied immutable migrations unless repository policy explicitly permits it and deployment state is known. Agents MUST NOT create manual production-only schema drift without recorded reconciliation. Tool-generated migrations and tool-generated SQL MUST be reviewed as code for destructive operations, data loss, locks, unsupported syntax, transaction behavior, and rollback limitations.

## Schema Ownership And Naming

Schema and object ownership MUST be intentional. Objects MUST NOT default unintentionally to privileged users such as `dbo`, `root`, `postgres`, `sys`, or owner-equivalent identities when a narrower owner is appropriate.

Database changes MUST use consistent conventions for schemas, tables, columns, indexes, keys, constraints, views, procedures, functions, triggers, partitions, and security policies. Durable relational entities MUST define explicit primary keys unless justified. Foreign keys, nullability, defaults, data types, lengths, precision, scale, collation, and cascade behavior MUST be explicit where behavior matters.

Agents MUST avoid reserved words, ambiguous names, brittle abbreviations, engine-default lengths where data shape matters, and generic columns such as `Value`, `Data`, `Type`, or `Status` without a defined domain contract. Naming changes MUST account for dependent applications, reports, jobs, views, procedures, integrations, permissions, documentation, and rollback.

## Migration Strategy

Migrations MUST be ordered, deterministic, reviewable, scoped, versioned, auditable, tested against the declared engine, and compatible with deployment sequencing. They MUST be repeatable where the framework expects repeatability and idempotent where the framework expects idempotency.

Each migration MUST document:

- Purpose, forward behavior, preconditions, expected row count, expected runtime, lock and blocking risk, transaction behavior, data impact, application compatibility, replication impact, backup or recovery dependency, rollback or mitigation, irreversible steps, validation query, and post-deployment verification.

Agents MUST NOT place unrelated schema changes into one migration. Migration names SHOULD be stable, ordered, and descriptive. Migration checksum or history tampering is prohibited unless explicitly approved for a known safe reconciliation.

## Expand-And-Contract And Rolling Deployment Compatibility

Changes that cannot be safely deployed atomically MUST use expand-and-contract:

1. Add new nullable or additive structure.
2. Deploy compatible application code.
3. Backfill in bounded batches.
4. Verify data and behavior.
5. Switch reads or writes.
6. Remove old structure only in a later approved deployment after evidence confirms old usage ended.

Old and new application versions MUST remain compatible during rolling deployments unless coordinated downtime is approved. Agents MUST NOT rename and drop in one step when overlapping applications may exist. Agents MUST NOT immediately convert populated nullable columns to `NOT NULL` without validation and rollout planning.

Feature flags, dual-read, and dual-write MAY be used only when consistency, observability, repair, and rollback behavior are defined. Automatic production migration-on-startup is prohibited unless explicitly approved and governed. Controlled deployment migrations or migration bundles are preferred.

## Destructive Operations

Destructive operations include `DROP`, `TRUNCATE`, `DELETE`, `UPDATE` that overwrites existing values, unsafe `MERGE` or upsert, narrowing `ALTER COLUMN`, primary or foreign-key changes, constraint removal, trigger disablement, permission revocation or broad grant, partition switch or drop, data purge, anonymization, encryption-key changes, sequence reseeding, and identity reseeding.

Destructive operations MUST include:

- Explicit execution mode, exact database/schema/table/partition/tenant/row scope, preflight validation, affected-row estimate, preview or `DryRun` where feasible, transaction strategy, backup or recovery verification, before-state evidence, intended-change evidence, after-state evidence, row-count thresholds, stop conditions, approval, rollback or mitigation, refusal of wildcard or broad targets, and revalidation immediately before mutation.

Agents MUST NOT make destructive action the first implemented or first tested path. `DELETE` or `UPDATE` without a validated predicate is prohibited unless explicitly approved as a full-table operation. `TRUNCATE` MUST NOT be used as a convenience shortcut. `DROP IF EXISTS` MUST NOT hide unexpected state. Constraints, triggers, auditing, replication, or security policies MUST NOT be disabled merely to make a migration pass. Database errors that determine success MUST NOT be suppressed.

## Data Repair, Backfill, And Transformation Safety

Data repair, backfill, and transformation work MUST support discovery mode, validation mode, preview or `DryRun`, report generation, and explicit execute mode. Execution MUST target an exact population and use bounded batch size, stable ordering or keyset pagination, checkpoints, resumability, idempotency or duplicate protection, throttling, lock monitoring, timeout behavior, failure threshold, per-batch row counts, total row counts, sanitized before/after samples, reconciliation totals, restart behavior, audit trail, and operator stop or cancel behavior.

Data repair scripts MUST fail safely on empty scope. Empty input MUST NOT mean all rows. Scripts MUST support a maximum affected-row threshold and refuse execution when estimated scope exceeds approval. Agents SHOULD avoid `OFFSET` pagination for unstable high-volume mutation where keyset batching is safer. Large backfills MUST NOT run as one giant transaction unless explicitly justified. Partial success MUST be recorded honestly.

## SQL Query Construction And Injection Prevention

SQL values MUST use parameterized queries, bound parameters, safe ORM APIs, or equivalent engine-native parameter binding. Agents MUST NOT concatenate or interpolate untrusted values into SQL. Stored procedures do not automatically make unsafe SQL safe.

Dynamic `WHERE`, `ORDER BY`, table, schema, column, database, function, procedure, or predicate fragments MUST use allowlisted identifiers and safe quoting. `LIKE` patterns MUST be treated as data and escaped when literal matching is intended. Parameter type and length SHOULD match target columns where practical. Application and database layers MUST both enforce authorization boundaries. Security-sensitive query changes require negative tests for injection attempts.

## Dynamic SQL And Identifier Safety

Dynamic SQL is allowed only when static SQL cannot reasonably satisfy the requirement. It MUST include explicit justification, parameterization for values, identifier allowlists, safe engine-specific identifier quoting, restricted execution identity, safe audit logging without sensitive SQL values, and tests for injection attempts.

Agents MUST NOT pass user-provided table names, schema names, column names, function names, procedure names, `ORDER BY` fragments, arbitrary predicates, or raw SQL snippets directly into dynamic SQL.

For SQL Server, agents SHOULD use `sp_executesql` for parameterized values where dynamic SQL is required. `QUOTENAME` may be used for validated identifiers, but it is not a substitute for allowlisting. `EXEC` of concatenated untrusted strings is prohibited. Equivalent safe patterns MUST be documented for other engines.

## Query Design And Performance

Production queries, persisted views, integrations, and stable contracts MUST use explicit column lists. `SELECT *` MUST NOT be introduced into stable production contracts unless an exceptional use is documented and reviewed. Queries MUST use schema-qualified objects where appropriate, deterministic ordering where order matters, bounded result sets, pagination for large collections, correct null semantics, explicit time-zone and collation behavior, reviewed join predicates, aggregation correctness, duplicate handling, query timeout policy, and cancellation support from callers where applicable.

High-impact queries MUST include estimated or actual execution-plan review as appropriate, row estimate versus actual review where available, cardinality considerations, statistics considerations, index use, scan/seek behavior, join strategy, sort/hash spill risk, memory grant risk, temp storage impact, parameter sensitivity or sniffing considerations, plan cache behavior, compilation or recompilation behavior, parallelism impact, blocking and lock duration, and baseline plus post-change measurement.

Performance claims require measurements. Plan forcing, hints, `OPTION(RECOMPILE)`, `NOLOCK`, read-uncommitted behavior, optimizer hints, and engine-specific tuning directives require documented rationale. `NOLOCK` MUST NOT be used as a generic performance fix. Query Store or equivalent SHOULD be used where available for regression analysis. High-impact query changes require rollback or feature-disable strategy.

## Index Design

Every new index requires a query or use-case justification. Index review MUST consider key order, selectivity, included columns, filtered or partial indexes, covering behavior, write amplification, storage cost, duplicate or overlapping indexes, fragmentation and maintenance implications, online or resumable creation availability, sort/temp space requirements, locking and blocking, replication impact, unique enforcement, and partition alignment.

Indexes MUST NOT be added merely because a tool suggested them. Redundant indexes MUST be identified. Large index creation requires runtime, storage, log-growth, blocking, and rollback analysis. Dropping an index requires dependency and usage review. Production index maintenance MUST NOT be embedded casually in application migrations.

## Constraints And Referential Integrity

Durable relational entities MUST have primary keys unless explicitly justified. Foreign keys MUST be used where referential integrity is required. Unique constraints MUST enforce true business uniqueness. Check constraints SHOULD enforce durable domain rules. Defaults MUST NOT hide missing required application input.

Cascade behavior MUST be explicit. Broad cascade delete requires impact analysis. Constraint validation after bulk operations is required. Permanently untrusted or disabled constraints are prohibited. Business invariants SHOULD be enforced at the strongest appropriate layer, including database constraints when they protect shared data from multiple writers.

## Transactions And Consistency

Database changes MUST define transaction boundaries, commit points, rollback behavior, savepoint behavior where applicable, retry safety, timeout policy, and partial-failure handling. Long-running migrations MUST justify transaction scope and log growth. Agents MUST avoid mixing non-idempotent external side effects inside database transactions unless a safe pattern such as an outbox is used.

Transactions MUST NOT hide partial failure. Error handling MUST preserve the original failure and stop unsafe continuation. Retried transactions MUST be idempotent or protected against duplicate effects.

## Isolation, Locking, Blocking, And Deadlocks

Agents MUST consider isolation level, lock duration, lock escalation, blocking chains, deadlock risk, statement timeout, lock timeout, online operation support, and concurrent application traffic. High-risk changes MUST document maintenance window or online strategy, monitoring, abort criteria, and operator response.

`NOLOCK` and read-uncommitted behavior MUST NOT be used to ignore correctness problems. Deadlock retry behavior MUST have bounds and preserve idempotency. Queries that require consistent reads MUST document the chosen isolation behavior.

## Concurrency And Idempotency

Concurrent writers, retries, replays, duplicate requests, worker overlap, migration reruns, and deployment retries MUST be safe by design. Agents MUST use unique constraints, optimistic concurrency, leases, locks, idempotency keys, checkpoints, or equivalent controls where required.

Migration and backfill scripts MUST define whether rerun is safe. If rerun is unsafe, the script MUST detect prior execution and fail clearly. Empty input, duplicate input, stale execution plans, and changed target state MUST be handled explicitly.

## Stored Procedures, Functions, Views, And Triggers

Stored procedures, functions, and views MUST define ownership, parameters, result contract, permissions, error behavior, transaction behavior, performance expectations, dependency impact, and versioning/compatibility rules. Changes to production-used routines are at least High unless proven isolated.

Triggers require explicit justification. They MUST handle multi-row operations, avoid one-row assumptions, avoid hidden recursive or cascading behavior, define ordering and failure behavior, include performance and observability controls, and be included in migration and rollback evidence. Triggers MUST NOT silently call remote systems.

## Seed, Reference, And Test Data

Agents MUST distinguish seed data from reference/configuration data. Seed and reference data MUST use deterministic identifiers where appropriate, idempotent application, explicit ownership, versioning, referential integrity, safe update/delete behavior, and synthetic examples.

Production secrets, customer data, patient data, employee data, regulated data, and realistic sensitive values MUST NOT appear in seed files, tests, fixtures, examples, logs, evidence, or screenshots. Test data cleanup MUST be scoped to test environments. Production identity or sequence values MUST NOT be destructively reseeded for convenience.

## Security, Identities, Roles, And Permissions

Database access MUST use least privilege. Application, migration, reporting, monitoring, backup, and administrative identities SHOULD be separate where practical. Application accounts MUST NOT use `sysadmin`, `dbo`-equivalent, `superuser`, owner, or unrestricted administrator credentials.

Agents MUST avoid shared personal administrator accounts, plaintext credentials, secret-bearing connection strings, broad `GRANT ALL`, hidden permission broadening, and default/public role expansion. Managed identity, integrated authentication, certificate authentication, or approved secret stores SHOULD be used where supported. Explicit `GRANT`, `DENY`, `REVOKE`, role membership, ownership chaining, definer/invoker rights, cross-database access, and break-glass access MUST be reviewed when changed.

Security changes require negative tests and approval.

## Data Classification And Privacy

Database changes MUST classify data as Public, Internal, Confidential, Regulated, or Secret/Restricted according to repository policy. Classification MUST drive access, logging, evidence, retention, testing, export, masking, backup, and risk classification.

Agents MUST enforce data minimization, purpose limitation, retention, deletion or purge policy, auditability, export controls, tenant isolation, and subject access/deletion implications where applicable. Production data MUST NOT be copied into tests. Troubleshooting extracts MUST be sanitized. Data copy, restore, refresh, and reporting workflows MUST include masking or sanitization where required. Cross-border or residency requirements MUST be documented where applicable.

## Encryption, Masking, And Row-Level Controls

Database connections MUST use TLS where supported and required. Certificate validation MUST NOT be bypassed as normal configuration, and `TrustServerCertificate`-style bypasses require explicit approval and evidence. Encryption-at-rest capability, key ownership, key rotation, backup, restore, and recovery behavior MUST be documented when affected.

Column-level encryption requires review of query, index, rotation, and operational impact. Dynamic masking MUST be treated as display control, not authorization. Row-level security policies MUST be tested for allow and deny behavior. Tenant predicates MUST fail closed. Bypass paths and security policy disablement require review and approval. Encryption does not replace access control.

## Backup, Restore, And Recovery

"A backup exists" is not sufficient evidence. Backup and recovery review MUST identify backup type, schedule, retention, encryption, storage location, access controls, restore test status, recovery point objective, recovery time objective, point-in-time capability, log/WAL/archive chain requirements, backup age, affected database coverage, recovery owner, and restore validation evidence where policy requires.

Before destructive production work, agents MUST verify backup status through an authoritative mechanism, verify affected database coverage, verify recovery procedure, and record `NotRun` or `Blocked` when backup verification cannot occur. Agents MUST never fabricate backup confirmation.

## Replication, High Availability, And Disaster Recovery

Database changes MUST review Availability Groups, clustering, replication, log shipping, read replicas, sharding, multi-region systems, failover, replica lag, write routing, read consistency, schema propagation, online operation support, sequence or identity behavior, CDC, temporal features, backup ownership, and disaster-recovery compatibility where applicable.

Changes MUST document primary/replica execution target, propagation behavior, failover risk, replica lag effect, read-only workload effect, rollback behavior, monitoring, and coordination with infrastructure teams when required.

## ETL, ELT, Workers, And Batch Processing

ETL, ELT, backfill, and batch-processing changes MUST apply [AGENTS_WorkerService.md](AGENTS_WorkerService.md) and [AGENTS_Integration.md](AGENTS_Integration.md) when workers or external systems are involved.

Agents MUST define source and target contracts, watermarks, checkpoints, idempotency, duplicate detection, late-arriving data behavior, schema drift handling, retry and dead-letter behavior, batch size, throttling, restart behavior, partial failure, reconciliation counts, data lineage, retention, sensitive-data handling, and memory bounds. Full reloads MUST be intentional and approved. Silent row rejection is prohibited.

## Observability, Auditing, And Operational Readiness

Database work MUST produce supportable operational evidence for migration start/end/status, migration version, duration, rows affected, batch counts, retry counts, blocking duration, deadlock events, query timeout events, backup/restore status, replication lag, storage and log growth, connection saturation, long-running queries, failed login events, permission changes, security audit events, and correlation/change/ticket identifier where applicable.

Logs and evidence MUST NOT contain passwords, tokens, secret-bearing connection strings, encryption keys, raw regulated data, full sensitive SQL parameter values, or production data samples without sanitization. Operational runbooks MUST define alert ownership and response for high-risk failures.

## Validation Commands

Repository-root [../AGENTS.md](../AGENTS.md) is the source of truth for repository validation. Database commands are conditional on engine, migration framework, and available tooling. Evidence MUST record exact commands, working directory, tool version, exit code, target engine, target classification, and status.

Unavailable validation MUST be recorded as `NotRun` or `Blocked` with the exact reason. A syntax check does not prove apply, rollback, performance, permissions, replication, backup, restore, or production safety. Examples MUST use placeholders. Secrets MUST NOT be passed visibly on command lines. Apply commands MUST target ephemeral or nonproduction databases unless production execution is explicitly approved.

SQL Server syntax or nonproduction apply example:

```powershell
sqlcmd -S "<server>" -d "<database>" -E -b -i ".\path\migration.sql"
```

DACPAC script-generation example:

```powershell
sqlpackage /Action:Script /SourceFile:".\database.dacpac" /TargetConnectionString:"<approved-secret-source>"
```

EF Core examples:

```powershell
dotnet ef migrations list
dotnet ef migrations script --idempotent
dotnet ef database update
```

Flyway examples:

```powershell
flyway validate
flyway info
flyway migrate
```

Liquibase examples:

```powershell
liquibase validate
liquibase status
liquibase update-sql
```

PostgreSQL example:

```powershell
psql --set ON_ERROR_STOP=on --file ".\path\migration.sql"
```

Repository-approved static or build tools MAY include SQLFluff, sql-lint, TSQLLint, SSDT build, database project build, and engine-native parser or compile checks. Query plan validation requires engine-specific commands. Backup/restore validation requires authoritative tooling. CI MUST NOT use fake commands that only print success.

## Testing Requirements

Database changes MUST include applicable tests or justified statuses. Tests SHOULD use ephemeral or isolated databases and synthetic data where feasible. Destructive tests MUST never target production.

Applicable tests include migration ordering, migration checksum/history, clean database apply, upgrade from prior supported version, idempotency where expected, rollback where supported, roll-forward mitigation where rollback is unsafe, destructive-change detection, empty scope, maximum row threshold, `DryRun`/preview, batch/restart behavior, partial failure, constraints, foreign keys, unique constraints, nullability, defaults, permission allow/deny, row-level security allow/deny, tenant isolation, SQL injection attempts, dynamic identifier allowlists, query result correctness, query plan/performance baseline, deadlock/retry behavior, concurrency conflicts, replication compatibility where testable, seed/reference idempotency, and synthetic data verification.

Skipped or unavailable tests require exact `NotRun`, `Blocked`, or `NotApplicable` status and reason.

## Deployment And Rollback

Database deployment MUST define deployment order, application compatibility, migration tool and version, execution identity, target database identity, maintenance window, lock timeout, statement timeout, batch size, monitoring, abort criteria, backup verification, validation queries, rollback or forward-fix, feature flag strategy where applicable, communication, approval, and post-deployment observation period.

Build success is not deployment success. Script generation is not apply success. Apply success is not application compatibility success. Rollback success must be tested or honestly marked `NotRun`. Irreversible changes require explicit approval. Production migrations MUST NOT run automatically from application startup unless governed and approved. A failed migration MUST NOT be hidden by later successful steps.

## Documentation Requirements

README files and runbooks MUST document supported engines and versions, development model, tooling prerequisites, local test database setup, configuration and secret sources, migration creation, migration review, apply procedure, rollback/mitigation, backup verification, validation commands, query plan review, data repair workflow, `DryRun`/preview, row thresholds, permissions, data classification, HA/replication impact, troubleshooting, known limitations, emergency stop, recovery owner, and every public script parameter, migration option, environment variable, and operational mode.

Examples MUST use synthetic names and placeholders only.

## Completion Evidence

Completion evidence MUST align with [../governance/COMPLETION_EVIDENCE.md](../governance/COMPLETION_EVIDENCE.md) and root [../AGENTS.md](../AGENTS.md). Evidence for database work MUST include:

- Exact files changed, exact commands, working directories, exit codes, tool versions, engine and version, compatibility level or dialect, migration framework and version, target database classification, migration ordering result, static validation, clean apply result, upgrade result, rollback result or mitigation, `DryRun`/preview result, estimated and actual affected rows, runtime, lock/blocking observations, query plan/performance review, permissions review, backup verification, replication/HA review, security review, test counts, GitHub Actions status, artifact verification, remaining risks, approvals, and exceptions.

Permitted statuses are `Passed`, `Failed`, `Blocked`, `NotRun`, and `NotApplicable`. Evidence MUST NOT label unexecuted engine validation, apply, rollback, backup verification, restore validation, replica validation, performance validation, production validation, or GitHub Actions validation as `Passed`.

## Failure Behavior

Database work is incomplete when migrations are unordered, schema source of truth is ambiguous, syntax validation fails, clean apply fails, upgrade fails, destructive operations lack approval, row scope is ambiguous, empty scope can mean all rows, backup verification is claimed without evidence, rollback or mitigation is absent, production data appears in tests or evidence, SQL injection risk exists, dynamic identifiers are not allowlisted, `DELETE` or `UPDATE` lacks validated scope, `SELECT *` is introduced into stable production contracts without justification, query performance claims lack evidence, blocking or deadlock risk is ignored, permission broadening lacks review, tenant isolation lacks deny tests, migration-on-startup is enabled without approval, replication or HA impact is ignored, tests are skipped without status and reason, or GitHub/production execution is claimed without evidence.

Agents MUST downgrade completion status to `Failed`, `Blocked`, or `NotRun` when evidence requires it.

## Exception Handling

Exceptions MUST follow [../governance/EXCEPTION_PROCESS.md](../governance/EXCEPTION_PROCESS.md). Exceptions MUST be active, scoped, time-bounded, reviewed, and included in completion evidence.

Exceptions MUST NOT permit plaintext secrets, fabricated evidence, unparameterized untrusted SQL, unbounded destructive operations, hidden production scope, unverified backup claims, production data in fixtures, silent permission broadening, disabled security policies without compensating controls, migration history tampering, or relabeling `NotRun` as `Passed`.

## Related Documents

- [AGENTS_Base.md](AGENTS_Base.md)
- [AGENTS_DotNet.md](AGENTS_DotNet.md)
- [AGENTS_PowerShell.md](AGENTS_PowerShell.md)
- [AGENTS_WorkerService.md](AGENTS_WorkerService.md)
- [AGENTS_Integration.md](AGENTS_Integration.md)
- [AGENTS_Infrastructure.md](AGENTS_Infrastructure.md)
- [../AGENTS.md](../AGENTS.md)
- [../governance/ORGANIZATION_CONTRACT.md](../governance/ORGANIZATION_CONTRACT.md)
- [../governance/COMPLETION_EVIDENCE.md](../governance/COMPLETION_EVIDENCE.md)
- [../governance/RISK_CLASSIFICATION.md](../governance/RISK_CLASSIFICATION.md)
- [../governance/EXCEPTION_PROCESS.md](../governance/EXCEPTION_PROCESS.md)
- [../governance/AI_GENERATED_CODE_POLICY.md](../governance/AI_GENERATED_CODE_POLICY.md)
- [../docs/ADOPTION_GUIDE.md](../docs/ADOPTION_GUIDE.md)
- [../docs/DOWNSTREAM_CONFIGURATION.md](../docs/DOWNSTREAM_CONFIGURATION.md)
- [../docs/ACTION_SECURITY.md](../docs/ACTION_SECURITY.md)
- [../docs/TROUBLESHOOTING.md](../docs/TROUBLESHOOTING.md)

## Revision History

- 1.1.0: Rebuilt as a comprehensive enterprise database and SQL standard covering engines, development models, schemas, migrations, expand-and-contract, destructive operations, backfills, SQL injection prevention, dynamic SQL, query design, plans, indexes, constraints, transactions, locking, concurrency, routines, seed data, security, privacy, encryption, backup, recovery, HA, replication, ETL, observability, validation, testing, deployment, rollback, documentation, evidence, failures, exceptions, and cross-standard handoffs.
- 1.0.0: Initial database standard with baseline requirements for discovery, risk, migrations, query safety, data repair, security, validation, evidence, and exceptions.
