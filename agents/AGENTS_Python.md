# AGENTS Python Standard

| Field | Value |
| --- | --- |
| Status | Active |
| Version | 1.0.0 |
| Owner role | Engineering Standards Maintainers |
| Last reviewed | 2026-07-19 |
| Changelog | See [../CHANGELOG.md](../CHANGELOG.md). |

## Purpose

This standard defines enforceable requirements for AI agents creating, reviewing, or modifying Python applications, libraries, CLI tools, workers, web services, automation, data-processing code, tests, and packaging. It establishes governance foundations; it does not prescribe or provide a repository-wide Python runtime toolchain or workflow.

## Applicability And Inheritance

This standard inherits [AGENTS_Base.md](AGENTS_Base.md). The base standard, repository-root [../AGENTS.md](../AGENTS.md), and governance documents remain authoritative. Local instructions MAY strengthen these controls and MUST NOT weaken them.

The standard applies to Python source, packaging metadata, generated code, tests, scripts, notebooks promoted to maintained code, CI commands, and Python-driven integrations or infrastructure. Work crossing another boundary MUST also apply the relevant standard listed under Cross-Standard Handoffs.

## Normative Terminology

`MUST` and `MUST NOT` are mandatory. `SHOULD` and `SHOULD NOT` require a recorded rationale when omitted. `MAY` is optional. Canonical outcomes are `Passed`, `Failed`, `Blocked`, `NotRun`, and `NotApplicable`.

## Required Discovery

Before editing, agents MUST identify the supported interpreter and operating-system matrix; project and source layout; entry points and public APIs; `pyproject.toml` and build backend; approved package manager, resolver, indexes, lock or pinning strategy; configured formatter, linter, type checker, test runner, dependency audit, and package-build process; external processes, networks, data formats, secrets, destructive operations, deployment targets, and existing user changes from `git status --short`.

## Risk Classification

Agents MUST use [../governance/RISK_CLASSIFICATION.md](../governance/RISK_CLASSIFICATION.md). Changes involving authentication, authorization, secrets, unsafe data formats, build backends, install-time execution, production data, privileged automation, destructive behavior, or security controls are High or Critical as defined by that policy.

## Supported Runtime And Compatibility

Each repository MUST declare a supported CPython version matrix, including the minimum and maximum tested versions. Unsupported or untested versions MUST be identified explicitly and MUST NOT be represented as supported. Alternative implementations such as PyPy MUST be declared and tested when compatibility is claimed.

Operating-system support, architecture, filesystem case behavior, path conventions, default encoding, UTF-8 expectations, locale, time zone, and native-library assumptions MUST be documented where behavior depends on them. Portability or unsupported-version claims MUST NOT be made without execution evidence for the claimed matrix.

## Architecture And Project Structure

`pyproject.toml` SHOULD be the preferred modern project contract. Applications, libraries, CLI tools, workers, web services, automation, data-processing code, tests, and packaging MUST have explicit entry points and ownership boundaries. Repositories MUST define source layout, import boundaries, package names, public APIs, and rules for internal modules; accidental imports from tests, working-directory-dependent imports, and undeclared namespace behavior MUST NOT become production contracts.

Libraries MUST document compatibility and public API changes. Projects producing distributions MUST define wheel and source-distribution behavior and verify their contents. Build backends execute code: arbitrary or unreviewed package-build execution MUST NOT occur inside a trusted validation boundary.

## Dependency And Supply-Chain Controls

Each repository MUST declare one approved package manager and resolver. Dependency resolution MUST be reproducible through an approved lockfile or fully pinned dependency set; hashes MUST be validated when required by repository risk and supply-chain policy. Direct and transitive sources, private indexes, trusted publishers, licenses, vulnerabilities, provenance, and SBOM requirements MUST be reviewed where applicable.

Implicit untrusted package indexes MUST NOT be used. Private index configuration MUST prevent dependency confusion and unintended public fallback. Install-time scripts, build hooks, editable installs, VCS dependencies, and local path dependencies MUST NOT execute unreviewed code in a trusted boundary. Dependencies MUST be necessary and scoped. This foundation does not mandate Ruff, mypy, pyright, pytest, pip-audit, or another future tool; the repository MUST declare its approved formatter, linter, type checker, test runner, dependency audit mechanism, and package-build process where applicable.

## Configuration And Secret Handling

Configuration sources and precedence MUST be explicit and validated. Secrets MUST NOT be committed, embedded in artifacts, placed in URLs, exposed in logs or exceptions, or inherited unnecessarily by child processes. Secret values MUST come from an approved provider, use least privilege, and be redacted from diagnostic output.

## Type And Data Safety

Stable public contracts and risk-sensitive logic MUST use meaningful type hints. Dynamically typed boundaries MUST validate types, shapes, ranges, encodings, sizes, and nullability. Agents MUST NOT claim type checking occurred unless the configured type checker actually ran.

External JSON, YAML, XML, archives, and custom formats MUST be parsed with safe modes, explicit schemas or bounded validation, and resource limits. Untrusted data MUST NOT be loaded with unsafe pickle, marshal, YAML object construction, XML external entities, or equivalent object-deserialization behavior. Archive extraction MUST validate resolved destinations, reject traversal and unsafe links, and bound entry count, expanded size, compression ratio, and cleanup.

## Input Validation And Trust Boundaries

All command-line, file, environment, network, database, queue, plugin, and user inputs MUST be treated as untrusted until validated. Validation MUST occur at the trust boundary and MUST constrain length, count, format, range, identity, and destination. Validation failures MUST be explicit and MUST NOT silently substitute broader targets or permissive defaults.

## Error And Exception Handling

Exceptions MUST preserve actionable context without secrets. Broad catches MUST NOT silently continue, convert failure to success, or discard cancellation. Expected domain failures SHOULD use specific exceptions or result contracts. Top-level entry points MUST return honest exit codes, and partial failure MUST be surfaced with the affected scope.

## Logging And Sensitive-Data Redaction

Logging MUST be structured where supported and MUST include correlation and operation context without tokens, credentials, personal data, request bodies, or child-process secrets. Redaction MUST occur before serialization. Debug logging MUST NOT weaken production secrecy.

## Filesystem And Path Safety

Paths MUST be resolved against an explicit allowed root. Traversal, symlink, junction, reparse-point, archive-entry, and time-of-check/time-of-use risks MUST be considered. Temporary files and directories MUST use secure platform facilities, restrictive permissions where supported, unique names, and reliable cleanup. Writes affecting integrity SHOULD be atomic.

Destructive automation MUST reject empty, root, home, wildcard, traversal, or unbounded targets and MUST provide a dry-run or plan mode where feasible. Recursive actions MUST validate scope and links before mutation.

## External Process And Command Execution

External commands MUST prefer argument arrays that preserve argument boundaries. Unsafe shell interpolation and executable command strings built from untrusted input are prohibited. `shell=True` MUST NOT be used with untrusted or concatenated input. `os.system` and equivalent shell execution MUST NOT be used when a direct process API can express the operation.

`subprocess` calls MUST define the executable identity, argument boundaries, working directory, required environment, timeout, cancellation behavior, output bounds, and accepted exit codes. Environment inheritance MUST be minimized. External command failures MUST propagate honestly, child processes MUST be cleaned up, and captured output MUST NOT expose secrets.

## Dynamic Execution

Untrusted data MUST NOT become executable code through `eval`, `exec`, dynamic imports, import hooks, reflection, generated code, templates, or runtime compilation. Plugin loading and extension discovery MUST define allowlists, source and integrity requirements, version contracts, isolation, and trust boundaries. Runtime monkey patching SHOULD NOT be used in production code and MUST be narrowly justified and tested when unavoidable.

## Network And Integration Behavior

Network clients MUST validate TLS certificates and hostnames, use explicit connection and operation timeouts, bound response sizes and pagination, constrain redirects, and define proxy and environment behavior. Retries MUST be bounded, use backoff and jitter where appropriate, honor cancellation, classify retryable failures, and account for idempotency. Authentication MUST use approved secret handling and logs MUST redact credentials and sensitive payloads. External integration work MUST also apply [AGENTS_Integration.md](AGENTS_Integration.md).

## Async And Concurrency

AsyncIO code MUST define event-loop lifecycle, task ownership, cancellation, timeouts, exception observation, and shutdown. Background tasks MUST NOT be orphaned or fail silently. Threading and multiprocessing MUST define shared-state synchronization, process start assumptions, serialization boundaries, resource limits, child cleanup, and partial-failure behavior. Mutable shared state SHOULD be minimized.

## Testing Requirements

Tests MUST include positive, negative, boundary, failure-path, and security cases. Async, concurrency, integration, and package-build tests MUST be included where applicable. Tests MUST use synthetic data and safe targets and MUST NOT call production systems. Deserialization, path traversal, command arguments, timeout, cancellation, redaction, retry, and partial-failure behavior MUST have negative-path coverage when present.

Missing tools or environments MUST be reported as `NotRun` or `Blocked` with an exact reason; they MUST NOT be converted to `Passed`. A test command that did not run provides no success evidence.

## Static-Analysis Requirements

Repositories MUST declare approved formatting, linting, type-checking, security-analysis, and dependency-audit commands appropriate to their risk. Configurations MUST be version controlled. Required findings MUST fail validation unless governed by an approved exception.

## Packaging And Distribution

Package names, versions, included files, licenses, metadata, entry points, and supported Python requirements MUST be explicit. Published artifacts MUST be built reproducibly where feasible, tested after installation in an isolated environment, scanned as required, and bound to source provenance. Publishing MUST require approved credentials and target verification. This PR does not provide Python package-build infrastructure.

## Deployment And Operational Requirements

Applications and workers MUST define configuration injection, least-privilege identity, health and readiness signals, resource bounds, graceful shutdown, rollback, observability, and supported upgrade behavior. Deployment success MUST NOT be inferred from process start alone.

## Validation Commands

Each Python repository MUST document exact commands for interpreter discovery, dependency verification, formatting, linting, type checking, tests, audit, and package build where applicable. For this central standards foundation, deterministic validation is:

```powershell
pwsh -NoProfile -File scripts/Test-AgentStandards.ps1 -Path .
```

## Evidence Requirements

Evidence MUST comply with [../governance/COMPLETION_EVIDENCE.md](../governance/COMPLETION_EVIDENCE.md), record exact commands, working directory, tool versions, exit codes, limitations, and artifact identity, and distinguish local from hosted execution. Agents MUST NOT fabricate interpreter coverage, tests, builds, scans, workflow runs, or approvals.

## Rollback Requirements

Changes MUST define rollback for code, configuration, dependencies, schemas, stored data, packages, and deployments where applicable. Irreversible migrations or external effects require explicit approval, backup or compensation, and verified recovery steps.

## Exceptions

Exceptions MUST follow [../governance/EXCEPTION_PROCESS.md](../governance/EXCEPTION_PROCESS.md). Missing tools, time, or convenience are not implicit exceptions.

## Cross-Standard Handoffs

- Python web backends that affect browser behavior MUST apply [AGENTS_WebFrontend.md](AGENTS_WebFrontend.md).
- Python database access, migrations, and data repair MUST apply [AGENTS_Database.md](AGENTS_Database.md).
- Python workers, schedulers, and long-running jobs MUST apply [AGENTS_WorkerService.md](AGENTS_WorkerService.md).
- Python API clients, webhooks, queues, and file transfers MUST apply [AGENTS_Integration.md](AGENTS_Integration.md).
- Python infrastructure automation and deployment tooling MUST apply [AGENTS_Infrastructure.md](AGENTS_Infrastructure.md).
- Python orchestrated by PowerShell or invoking PowerShell MUST apply [AGENTS_PowerShell.md](AGENTS_PowerShell.md).
- Python interoperating with .NET services or tooling MUST apply [AGENTS_DotNet.md](AGENTS_DotNet.md).

## Related Documents

- [AGENTS_Base.md](AGENTS_Base.md)
- [../governance/RISK_CLASSIFICATION.md](../governance/RISK_CLASSIFICATION.md)
- [../governance/COMPLETION_EVIDENCE.md](../governance/COMPLETION_EVIDENCE.md)
- [../governance/EXCEPTION_PROCESS.md](../governance/EXCEPTION_PROCESS.md)
- [../governance/AI_GENERATED_CODE_POLICY.md](../governance/AI_GENERATED_CODE_POLICY.md)

## Revision History

| Version | Date | Summary |
| --- | --- | --- |
| 1.0.0 | 2026-07-19 | Established the Python standards, hierarchy, schema, validation, and evidence foundation. |
