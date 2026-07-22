# AGENTS Bash Standard

| Field | Value |
| --- | --- |
| Status | Active |
| Version | 1.1.0 |
| Owner role | Engineering Standards Maintainers |
| Last reviewed | 2026-07-21 |
| Changelog | See [../CHANGELOG.md](../CHANGELOG.md). |

## Purpose

This standard defines enforceable requirements for AI agents creating, reviewing, or modifying Bash scripts, libraries, automation, build and deployment entry points, scheduled jobs, and operational tooling. It also defines the supported functional Bash baseline, trusted toolchain, reusable workflow boundary, and required evidence.

## Applicability And Inheritance

This standard inherits [AGENTS_Base.md](AGENTS_Base.md). The base standard, repository-root [../AGENTS.md](../AGENTS.md), and governance documents remain authoritative. Local instructions MAY strengthen these controls and MUST NOT weaken them.

## Normative Terminology

`MUST` and `MUST NOT` are mandatory. `SHOULD` and `SHOULD NOT` require a recorded rationale when omitted. `MAY` is optional. Canonical outcomes are `Passed`, `Failed`, `Blocked`, `NotRun`, and `NotApplicable`.

## Required Discovery

Before editing, agents MUST identify shell identity and version matrix; operating systems, filesystems, locale, and GNU or BSD utility assumptions; shebangs and invocation paths; sourced files and functions; inputs, secrets, targets, remote operations, destructive commands, package or download behavior, background jobs, tests, analysis tools, deployment behavior, and existing user changes from `git status --short`.

## Risk Classification

Agents MUST apply [../governance/RISK_CLASSIFICATION.md](../governance/RISK_CLASSIFICATION.md). Privileged commands, production mutation, package installation, remote execution, secret handling, destructive filesystem behavior, service control, or security-control changes are High or Critical as defined there.

## Shell Identity And Compatibility

Every script MUST explicitly declare whether it requires Bash or portable POSIX `sh`. Bash scripts MUST use an environment-appropriate Bash shebang such as `#!/usr/bin/env bash` or an approved absolute interpreter path. Bash-specific features MUST NOT be used under a POSIX shell declaration.

Repositories MUST declare the supported Bash version matrix and tested operating systems. Utility, filesystem, encoding, locale, and GNU versus BSD command assumptions MUST be explicit. Portability claims MUST NOT be made without execution evidence for the claimed shells and platforms.

## Architecture And Script Structure

Entry points, sourced libraries, functions, configuration, generated files, tests, and operational assets MUST have clear boundaries. Sourced files MUST NOT execute unexpected mutations on import. Functions SHOULD have narrow responsibilities and explicit input and output behavior. Scripts MUST avoid dependence on an unspecified current directory.

## Strict And Failure Behavior

`set -euo pipefail` MAY be useful but MUST NOT be treated as a substitute for explicit failure handling. Scripts MUST preserve command and pipeline failure exit codes, understand conditional-command, negation, subshell, function, command-substitution, and sourced-script behavior, and check cleanup failures where they affect integrity. Expected nonzero statuses MUST be handled explicitly. Failures MUST NOT be swallowed or ignored, and an entry point MUST produce an explicit final exit status.

## Quoting And Expansion

Variable expansions MUST be quoted unless intentional word splitting or globbing is justified, reviewed, and bounded. Arrays MUST be used when preserving multiple arguments. Positional parameters MUST be validated, and forwarding MUST use `"$@"` rather than flattening arguments.

Globs MUST be scoped and their zero-match behavior understood. Word splitting, command substitution, arithmetic expansion, and here-documents MUST be reviewed for injection, truncation, newline, locale, and expansion behavior. User-controlled values MUST NOT become options; use `--` where the command supports it and otherwise validate or prefix operands safely.

## Configuration And Secret Handling

Configuration sources and precedence MUST be explicit. Plaintext secrets MUST NOT be committed or printed. Secrets MUST NOT be exposed through `set -x`, logs, command-line arguments, process listings, temporary files, environment dumps, or error messages. Tracing MUST be disabled or tightly bounded around sensitive operations.

Approved secret delivery MAY use a scoped environment variable, protected file descriptor, stdin, restrictive temporary file, or vault client according to the target command. Environment inheritance MUST be minimized and credentials MUST be cleaned up when lifecycle permits.

## Input Validation And Trust Boundaries

Command-line, environment, file, network, remote, and generated inputs MUST be treated as untrusted until validated. Validation MUST constrain format, size, count, identity, allowed root, host, command, and destination. Empty or malformed inputs MUST fail closed and MUST NOT select broader defaults.

## Error Handling And Logging

Diagnostics MUST identify the failed operation and safe target context without secrets. Traps MUST preserve the original failure unless cleanup failure requires a more severe outcome. Logs MUST be bounded and redacted. A successful final exit MUST NOT follow an unhandled mandatory failure.

## Command Execution

Unsafe `eval` is prohibited. Executable shell text MUST NOT be constructed from untrusted input. `bash -c`, `sh -c`, SSH remote command strings, and similar interpreters MUST be avoided when safe argument boundaries are available; when unavoidable, commands MUST use fixed reviewed text and pass data as positional arguments or another structured channel.

`sudo` use MUST be explicit, least privilege, noninteractive where automation requires it, and limited to reviewed commands. Working directories, executable paths, environment inheritance, timeouts, output bounds, cancellation, and accepted exit codes MUST be defined. Secrets SHOULD NOT be passed in arguments. Remote execution MUST preserve safe argument boundaries and verify host identity. Child command failures MUST propagate honestly.

## Filesystem And Destructive Operations

Destructive targets MUST be resolved and validated against an explicit allowlist and scope boundary. Scripts MUST reject empty, root, home, wildcard, traversal, or unbounded destructive targets. `rm`, `find -delete`, `chmod`, `chown`, package managers, filesystem mutation, service control, and remote mutation MUST validate exact targets and options before execution.

Destructive automation MUST provide dry-run or plan behavior where feasible. Irreversible operations require explicit confirmation or approval, rollback or recovery instructions, bounded scope, and evidence. Wildcard expansion MUST NOT determine an unreviewed destructive scope.

## Temporary Resources And Cleanup

Temporary files and directories MUST use `mktemp` or an equivalently secure facility, unpredictable names, restrictive permissions, and validated ownership. Predictable or race-prone temporary paths are prohibited. Trap-based cleanup MUST cover normal exit and relevant signals, be idempotent, quote paths, reject unsafe cleanup targets, and avoid masking the primary failure. Background children and partial temporary output MUST be cleaned up.

## Downloads And Supply Chain

Downloads MUST use TLS verification, an exact version or immutable artifact identity, and approved checksum or signature verification before execution. Piping unverified `curl` or `wget` output directly into `bash`, `sh`, or another interpreter is prohibited. Mutable branches and latest-release URLs MUST NOT be executed without a reviewed integrity mechanism.

Package managers, repositories, keys, install scripts, and executable artifacts MUST be approved and pinned or constrained according to risk. Installation MUST NOT silently broaden repositories, disable signature checks, or execute unreviewed content.

## Network And Integration Behavior

Network commands MUST verify TLS and remote identity, define timeouts, bound retries and output, respect idempotency, and handle redirects deliberately. Authentication data MUST be protected and redacted. API, SSH, file-transfer, and other cross-system work MUST also apply [AGENTS_Integration.md](AGENTS_Integration.md).

## Concurrency And Lifecycle

Scripts MUST use locking when concurrent execution is unsafe. PID files alone MUST NOT be treated as proof of process identity or lock ownership. Signal behavior, background jobs, child-process groups, cleanup, and `wait` results MUST be explicit. Every started background job MUST be owned, observed, and reaped. Partial failure MUST be surfaced; retries MUST be bounded and idempotency-aware; orphaned processes are prohibited.

## Testing Requirements

Tests MUST cover syntax, positive, negative, boundary, destructive-target, quoting, signal, cleanup, pipeline, command-failure, and failure-path behavior. Tests MUST use synthetic targets and MUST NOT execute against production systems. Destructive samples MUST NOT be executed by standards validation.

Missing tools or environments MUST be reported as `NotRun` or `Blocked` with an exact reason and MUST NOT be converted to `Passed`. A missing offline artifact or unavailable approved source is `Blocked`; a malformed lock, hash mismatch, unsafe archive, unexpected tool version, or incomplete required evidence is `Failed`.

The supported functional baseline is GNU Bash 5.2 on Ubuntu 24.04 x86-64 with ShellCheck 0.11.0, shfmt 3.13.1, and Bats 1.13.0. Exact sources and SHA-256 values are declared in `examples/bash-project/bash-toolchain.lock.json`. Other shells, Bash versions, operating systems, architectures, and BSD utility semantics require their own execution evidence and are not implied by this baseline.

Functional validation MUST run only declared test entry points after syntax, ShellCheck, formatting, toolchain, path, archive, and filesystem trust-boundary gates pass. It MUST use an isolated read-only project copy, a fixed allowlisted environment, bounded files and output, explicit timeouts, Linux Landlock filesystem rules, `no_new_privs`, subreaper cleanup, and child process-group termination. Hosted execution MUST require Landlock ABI 4 or newer and deny TCP connect and bind operations. It MUST reject symbolic links, hard links, traversal, special files, root overlap, caller tool configuration, startup hooks, and executable shadows before caller Bash code executes.

## Static-Analysis Requirements

Syntax validation and the configured static-analysis and formatting checks MUST run for changed scripts when available. Required findings MUST fail validation unless governed by an approved exception. Tool configuration and suppressions MUST be version controlled and narrowly justified.

## Packaging And Distribution

Distributed scripts MUST define supported shells, versions, utilities, installation paths, permissions, integrity verification, upgrade, uninstall, and compatibility behavior. Archives or installers MUST NOT introduce unsafe ownership, permissions, traversal, or implicit execution.

## Deployment And Operational Requirements

Scheduled, daemonized, privileged, or deployment scripts MUST define identity, environment, working directory, logging, timeouts, locking, signal handling, health or completion signals, rollback, and recovery. Process start or zero exit alone MUST NOT be treated as service readiness.

## Validation Commands

Each Bash repository MUST document exact interpreter, syntax, analysis, formatting, and test commands. The central standards and governed example use:

```powershell
pwsh -NoProfile -File scripts/Test-AgentStandards.ps1 -Path .
pwsh -NoProfile -File examples/bash-project/tools/Test-Example.ps1
```

The reusable hosted entry point is `.github/workflows/bash-ci-reusable.yml`, called at a full immutable 40-character standards commit SHA with a repository-relative `project-path`. It uses exact `/usr/bin/bash`, invokes ShellCheck with a trusted `/dev/null` rc file and warning severity, invokes shfmt with fixed formatting flags, and invokes Bats only for the project-declared test file. The existing `scripts/Test-BashStaticAnalysis.ps1` remains a separate non-executing static control and MUST NOT be made functional.

## Evidence Requirements

Evidence MUST comply with [../governance/COMPLETION_EVIDENCE.md](../governance/COMPLETION_EVIDENCE.md), record exact commands, working directory, shell and utility versions, exit codes, limitations, and artifacts, and distinguish local from hosted execution. Agents MUST NOT fabricate shell compatibility, analysis, tests, workflow runs, approvals, or production behavior.

Functional artifacts MUST contain normalized syntax, ShellCheck, shfmt, Bats, toolchain-bootstrap, toolchain, CycloneDX SBOM, aggregate test, completion, evidence-validation, and step-outcome records. Records MUST contain only sanitized repository-relative identities and MUST NOT contain workstation paths, credentials, startup variables, or token-like values. Local runs MUST record hosted execution as `NotRun`; only a downloaded, identity-verified GitHub artifact may support a hosted `Passed` claim.

## Rollback Requirements

Changes MUST document how to restore scripts, configuration, files, packages, permissions, services, and remote state. Irreversible behavior requires explicit approval and verified recovery or compensation.

## Exceptions

Exceptions MUST follow [../governance/EXCEPTION_PROCESS.md](../governance/EXCEPTION_PROCESS.md). Convenience, missing tools, or time pressure are not implicit exceptions.

## Cross-Standard Handoffs

- Bash infrastructure and deployment automation MUST apply [AGENTS_Infrastructure.md](AGENTS_Infrastructure.md).
- Bash APIs, SSH, webhooks, and file transfers MUST apply [AGENTS_Integration.md](AGENTS_Integration.md).
- Scheduled, daemonized, and background Bash jobs MUST apply [AGENTS_WorkerService.md](AGENTS_WorkerService.md).
- Bash database administration and migration scripts MUST apply [AGENTS_Database.md](AGENTS_Database.md).
- Bash and PowerShell cross-orchestration MUST apply [AGENTS_PowerShell.md](AGENTS_PowerShell.md).
- Bash-driven frontend builds or deployments MUST apply [AGENTS_WebFrontend.md](AGENTS_WebFrontend.md).
- Bash driving .NET tooling MUST apply [AGENTS_DotNet.md](AGENTS_DotNet.md).
- Bash driving Python tooling MUST apply [AGENTS_Python.md](AGENTS_Python.md).

## Related Documents

- [AGENTS_Base.md](AGENTS_Base.md)
- [../governance/RISK_CLASSIFICATION.md](../governance/RISK_CLASSIFICATION.md)
- [../governance/COMPLETION_EVIDENCE.md](../governance/COMPLETION_EVIDENCE.md)
- [../governance/EXCEPTION_PROCESS.md](../governance/EXCEPTION_PROCESS.md)
- [../governance/AI_GENERATED_CODE_POLICY.md](../governance/AI_GENERATED_CODE_POLICY.md)

## Revision History

| Version | Date | Summary |
| --- | --- | --- |
| 1.1.0 | 2026-07-21 | Added the supported functional Bash runtime, hash-locked ShellCheck, shfmt, and Bats toolchain, isolated reusable workflow boundary, example project, and fail-closed evidence contract. |
| 1.0.0 | 2026-07-19 | Established the Bash standards, hierarchy, schema, validation, and evidence foundation. |
