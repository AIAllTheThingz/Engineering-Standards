# AGENTS PowerShell Standard

| Field | Value |
| --- | --- |
| Status | Active |
| Version | 1.1.1 |
| Owner role | Engineering Standards Maintainers |
| Last reviewed | 2026-06-20 |
| Changelog | See [../CHANGELOG.md](../CHANGELOG.md). |

## Purpose

This standard defines enforceable enterprise requirements for AI agents creating, reviewing, or modifying PowerShell automation. It covers scripts, modules, module manifests, PSD1 configuration, scheduled tasks, unattended jobs, CI/CD scripts, administrative runbooks, remote-management workflows, REST and vendor API integrations, reporting tools, infrastructure orchestration, and destructive or production-changing automation.

The goal is safe, reviewable, testable, and evidence-backed PowerShell. Agents MUST design PowerShell changes so administrators can understand the intended targets, credentials, configuration, modes, validation, output, rollback, and failure behavior before any mutation occurs.

## Applicability And Inheritance

This standard inherits [AGENTS_Base.md](AGENTS_Base.md). The base standard remains authoritative for instruction hierarchy, mandatory work phases, evidence, exceptions, prohibited agent behavior, and completion status.

Agents MUST resolve instructions in the order defined by [AGENTS_Base.md](AGENTS_Base.md) and the repository-root [../AGENTS.md](../AGENTS.md). Repository-root and directory-local `AGENTS.md` files MAY add stricter local validation, commands, target restrictions, or operational controls. They MUST NOT weaken this standard, the base standard, or governance documents.

This standard applies to:

- `.ps1`, `.psm1`, `.psd1`, `.ps1xml`, and PowerShell-driven CI files.
- Script modules, binary-module wrappers, module manifests, DSC resources, scheduled jobs, Task Scheduler automation, and administration scripts.
- PowerShell that calls REST APIs, cloud APIs, directory services, virtualization platforms, databases, backup systems, IPAM/DNS platforms, privileged-access systems, package feeds, or remote hosts.
- PowerShell examples, templates, tests, fixtures, generated evidence, and local validation tooling.
- Agent-authored commands executed from a PowerShell shell.

When PowerShell orchestrates another technology, this standard applies to the PowerShell portion and the relevant technology standard applies to the underlying platform.

## Normative Terminology

`MUST`, `MUST NOT`, and `REQUIRED` are mandatory. `SHOULD` and `SHOULD NOT` are expected controls that require a recorded rationale when omitted. `MAY` is optional.

`Windows PowerShell` means the Windows-only PowerShell edition, commonly version 5.1. `PowerShell 7` or `PowerShell Core` means the cross-platform `pwsh` edition. Compatibility claims MUST distinguish these editions.

`State-changing` means creating, updating, deleting, disabling, enabling, moving, restarting, publishing, assigning permission, changing configuration, sending notification as part of completion, or mutating an external system. `Destructive` means state-changing behavior that can remove data, revoke access, stop service, break production, or require recovery. `DryRun` means an end-to-end simulation that validates intent without mutation. `WhatIf` means PowerShell `ShouldProcess` preview behavior for individual state-changing operations.

## Required Discovery Before Editing Or Running PowerShell

Before modifying files or running nontrivial PowerShell, agents MUST inspect the repository and identify:

- Applicable root, base, technology, and directory-local instructions.
- Supported PowerShell runtime matrix, including whether Windows PowerShell 5.1, PowerShell 7.x, or PowerShell 5.0 is required.
- Existing module structure, manifests, exported functions, private functions, entry-point scripts, configuration files, tests, examples, and generated output locations.
- Pester tests, PSScriptAnalyzer settings, parser-validation commands, manifest validation commands, CI workflow behavior, and evidence generation.
- Whether files are signed, packaged, published, scheduled, or used by production operations.
- Configuration sources, PSD1 files, CSV inputs, manual target parameters, environment variables, and precedence rules.
- Credential, token, certificate, managed identity, CyberArk CCP, vault, secret-management, or current-user authentication flows.
- Remoting, WinRM, SSH, CIM, WMI, scheduled task, service-control, registry, filesystem, Active Directory, PKI, PowerCLI/vSphere, Rubrik, Infoblox, CyberArk, REST API, cloud API, or database operations.
- Destructive operations and whether `SupportsShouldProcess`, `-WhatIf`, `-Confirm`, `-DryRun`, execution modes, plan/apply separation, target allowlists, rollback, and recovery guidance exist.
- Existing user changes from `git status --short`.

Agents MUST complete discovery before modifying files except for an explicitly requested trivial isolated edit. Agents MUST NOT infer behavior only from filenames.

## Risk Classification

Agents MUST classify PowerShell work using [../governance/RISK_CLASSIFICATION.md](../governance/RISK_CLASSIFICATION.md).

PowerShell work is at least Moderate risk when it changes reusable automation, CI scripts, module manifests, configuration loading, target input, credential flow, remote calls, reporting, scheduled execution, or administrative behavior.

PowerShell work is High or Critical when it touches:

- Production hosts, services, identities, certificates, secrets, firewall rules, registry, scheduled tasks, storage, backups, monitoring, or data.
- WinRM, SSH remoting, CIM, WMI, PowerCLI, Azure, Microsoft Graph, AWS, GCP, Kubernetes, database, backup, IPAM/DNS, privileged-access, or directory-service automation.
- Destructive commands such as `Remove-*`, `Clear-*`, `Disable-*`, `Stop-*`, `Restart-*`, production `Set-*`, cross-boundary `Move-*`, registry mutation, VM power operations, DNS deletion, backup policy changes, account changes, or mutation APIs.
- Credential rotation, role assignment, permission changes, token scopes, certificate issuance, certificate revocation, privileged sessions, package publishing, module signing, install scripts, bootstrap scripts, or security control changes.

Broad wildcard production destructive operations are Critical by default. A lower classification requires documented rationale and accountable review.

## Supported PowerShell Versions And Compatibility

Every PowerShell project MUST declare its supported runtime matrix in documentation, manifest metadata where applicable, and CI or validation evidence.

At minimum:

- Windows PowerShell 5.1 compatibility MUST be explicitly declared as supported or unsupported.
- PowerShell 7.x compatibility MUST be explicitly declared as supported or unsupported.
- If a downstream repository requires PowerShell 5.0, that requirement MUST be honored and validated separately.
- Cross-version projects MUST avoid syntax, APIs, modules, remoting behavior, parallel features, or encoding assumptions unsupported by a claimed runtime.
- Agents MUST NOT assume PowerShell 7-only syntax, modules, or APIs when Windows PowerShell compatibility is required.
- The selected compatibility target MUST be reflected in module manifests, documentation, CI, and tests.
- Compatibility claims that were not tested MUST be reported as `NotRun`, not `Passed`.

Compatibility validation SHOULD run the relevant host explicitly:

```powershell
powershell.exe -NoProfile -File .\tools\Test-Project.ps1
pwsh -NoProfile -File ./tools/Test-Project.ps1
```

Agents MUST report which commands actually ran and which hosts were unavailable.

## Required Solution Architecture

Existing repository structure MUST be respected unless restructuring is explicitly in scope and justified. For new or substantially rebuilt enterprise PowerShell solutions, agents SHOULD use a maintainable architecture similar to:

```text
ProjectName/
  Invoke-ProjectName.ps1
  ProjectName.psd1
  README.md
  CHANGELOG.md
  config/
    ProjectName.example.psd1
    ProjectName.psd1
  modules/
    ReportingTools/
      ReportingTools.psm1
      ReportingTools.psd1
    CredentialTools/
      CredentialTools.psm1
      CredentialTools.psd1
    EmailTools/
      EmailTools.psm1
      EmailTools.psd1
  input/
    Servers.example.csv
  output/
  logs/
  tests/
    Unit/
    Integration/
  docs/
```

This is a reference architecture, not a mandatory filename template. Agents MUST:

- Separate entry-point orchestration from reusable functions.
- Separate public functions, private helpers, configuration, tests, reporting, email, credential handling, and generated artifacts.
- Avoid monolithic scripts when logic is reusable, high-risk, or complex.
- Export module functions intentionally.
- Keep generated artifacts out of source directories.
- Use synthetic values in example configuration and input files.
- Keep CI, README, manifests, tests, and examples synchronized with the chosen structure.

## Safe Phased-Development Model

Agents MUST develop PowerShell automation in safe phases:

1. Discovery only.
2. Validation only.
3. `DryRun` or execution-plan simulation.
4. Report generation.
5. Execution mode only when explicitly enabled.

The default behavior MUST be non-destructive. Discovery and validation MUST be usable before mutation is enabled. State-changing behavior MUST be gated by an explicit parameter, mode, command, or approved runbook step.

Execution mode MUST consume explicit validated targets, not broad unreviewed discovery results. High-risk scripts SHOULD support plan/apply separation. A saved execution plan SHOULD include enough identity data, timestamps, and expected state to detect stale or changed targets before apply. Read-only operation MUST remain available after execution mode exists. Destructive operations MUST NOT be the first implemented or first tested path.

## Configuration Requirements

Values that vary by environment, operation, tenant, target set, credential mode, reporting destination, retry behavior, timeout, concurrency, email routing, or scheduling MUST be externalized.

Enterprise PowerShell configuration MUST use PSD1 files unless a repository has an approved alternative. Agents MUST NOT hard-code domain names, usernames, server FQDNs, API endpoints, SMTP servers, paths, timeouts, retry counts, report locations, environment names, certificate thumbprints, vault identifiers, tenant identifiers, subscription names, or similar operational values.

Configuration handling MUST:

- Provide a sanitized example PSD1 file.
- Validate required keys, types, ranges, mutually exclusive settings, and allowed values at startup.
- Reject unknown or misspelled critical configuration keys when practical.
- Resolve relative paths against a documented stable base, preferably the configuration file directory or script root.
- Document configuration precedence.
- Keep configuration, credentials, and runtime input separate.
- Exclude environment-specific configuration files from source control where appropriate.
- Never store secrets in PSD1 files.

Safe PSD1 loading and validation example:

```powershell
function Import-ExampleConfiguration {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string]$ConfigurationPath
    )

    Set-StrictMode -Version Latest
    $resolvedPath = (Resolve-Path -LiteralPath $ConfigurationPath).Path
    $config = Import-PowerShellDataFile -LiteralPath $resolvedPath
    $allowedKeys = @('ProfileName', 'OutputRoot', 'RetryCount', 'OperationTimeoutSeconds')
    $unknownKeys = @($config.Keys | Where-Object { $_ -notin $allowedKeys })
    if ($unknownKeys.Count -gt 0) {
        throw "Unknown configuration keys: $($unknownKeys -join ', ')"
    }
    if (-not $config.ProfileName) { throw 'ProfileName is required.' }
    if ($config.RetryCount -lt 0 -or $config.RetryCount -gt 10) {
        throw 'RetryCount must be between 0 and 10.'
    }
    [pscustomobject]$config
}
```

## Parameter And Input Requirements

User-facing scripts and public functions MUST use `CmdletBinding`. State-changing commands MUST use `SupportsShouldProcess` and risk-appropriate `ConfirmImpact`.

Parameters MUST:

- Use strong types and validation attributes.
- Avoid positional-only interfaces for operationally significant parameters.
- Provide explicit modes such as `Discovery`, `Validate`, `DryRun`, `Report`, and `Execute` where applicable.
- Clearly document parameter sets.
- Reject ambiguous combinations.
- Return structured objects for machine consumption.
- Use nonzero exit codes for failed automation or CI execution.
- Avoid `Write-Host` for data output.
- Use `Write-Progress` only for interactive progress and never as the sole evidence of activity.

For scripts operating on one or more targets:

- CSV-driven bulk input MUST be supported when multiple targets are expected.
- Direct/manual target entry MUST be supported when a CSV is not supplied, unless the workflow is intentionally bulk-only.
- CSV schemas MUST be documented and include sanitized examples.
- Headers, duplicate targets, empty rows, malformed values, unsupported values, and conflicting options MUST be validated.
- Target identifiers MUST be normalized safely.
- Reports MUST preserve the original requested target and record the resolved canonical target when applicable.
- Localhost or local execution SHOULD be supported when safe and meaningful.
- Empty input MUST fail safely and MUST NOT mean all targets.
- Large CSV input SHOULD support batching, bounded concurrency, and resumable reporting where justified.

## Credential And Secret Handling

PowerShell code MUST NOT hard-code secrets, print secrets, write secrets to logs or artifacts, commit credential-shaped examples, store secrets in PSD1 or CSV files, or pass secrets through process command lines when safer alternatives exist.

When credential handling is needed, solutions SHOULD use a reusable `CredentialTools` module or an established repository equivalent. Supported credential modes MUST be documented as applicable:

1. `CurrentUser`.
2. Prompt using `Get-Credential`.
3. CyberArk CCP.
4. Managed identity, certificate authentication, secret-management module, platform vault, or another approved noninteractive method.

Credential-mode precedence MUST be documented and tested with synthetic values. Recommended default precedence is:

1. Explicit approved noninteractive credential source configured for the task.
2. CyberArk CCP, managed identity, or certificate mode.
3. Explicit supplied `PSCredential`.
4. Prompt mode for interactive use.
5. `CurrentUser` only when intentionally selected or documented as the default.

Agents MUST:

- Never silently fall back from a secure enterprise source to plaintext, embedded, or weaker credentials.
- Make `CurrentUser` behavior explicit.
- Avoid prompt mode for scheduled tasks.
- Read CyberArk CCP settings from configuration, excluding secrets.
- Validate CyberArk CCP TLS certificates.
- Never disable certificate validation.
- Avoid logging passwords, bearer tokens, API keys, client secrets, private keys, credential objects, authorization headers, or raw vault responses.
- Limit plaintext conversion to the final API boundary and clear references promptly.
- Distinguish authentication failure from authorization failure and connectivity failure.
- Document double-hop behavior for remoting workflows.

If a secret may have been exposed, agents MUST stop normal completion claims and report remediation requirements.

## Remoting And Remote Administration

This standard applies to WinRM, PowerShell remoting, CIM/WMI, SSH remoting, scheduled tasks, service control, registry operations, filesystem operations, Active Directory, PKI, PowerCLI/vSphere, Rubrik, Infoblox, CyberArk, REST APIs, cloud APIs, databases, and other vendor systems.

Agents MUST NOT enable WinRM, firewall rules, CredSSP, SSH, delegation, or trusted-host settings automatically unless explicitly in scope and approved.

Remote administration scripts MUST:

- Define target allowlisting.
- Define authentication and authorization expectations.
- Validate remoting with `Test-WSMan` and a safe `Invoke-Command` test where applicable.
- Document that code signing does not enable WinRM.
- Use bounded concurrency.
- Define timeout, retry, and backoff.
- Prevent accidental fan-out to an entire domain, tenant, cluster, subscription, or inventory.
- Refuse wildcard production targets without explicit validated scope.
- Handle offline and unreachable hosts per target.
- Make continue-or-stop behavior configurable and documented.
- Avoid CredSSP unless specifically approved.
- Never bypass TLS certificate validation or SSH host-key validation.
- Remove remote temporary files safely.
- Close sessions in `finally` blocks.
- Avoid leaving systems in maintenance mode, stopped state, or partially changed state after a later step fails.

Multi-system orchestration MUST record step-level state and support compensating actions or operator recovery instructions.

Safe WinRM validation example:

```powershell
$target = 'server01.example.invalid'
Test-WSMan -ComputerName $target -ErrorAction Stop | Out-Null
Invoke-Command -ComputerName $target -ScriptBlock { $PSVersionTable.PSVersion.ToString() } -ErrorAction Stop
```

This validates connectivity. It does not enable WinRM, grant authorization, or make later mutations safe.

## State-Changing And Destructive Operations

State-changing and destructive operations include `Remove-*`, `Clear-*`, `Disable-*`, `Stop-*`, `Restart-*`, production `Set-*`, cross-boundary `Move-*`, registry changes, service changes, firewall changes, scheduled-task changes, permission changes, certificate revocation or removal, VM power operations, DNS deletion, backup policy changes, file deletion, account changes, and API mutations.

Such operations MUST:

- Default to no mutation.
- Require explicit execution mode.
- Validate exact target identity immediately before mutation.
- Use `SupportsShouldProcess`.
- Use `ConfirmImpact = 'High'` for high-risk mutations.
- Record before state where safe.
- Record intended change.
- Record after state where safe.
- Record rollback or recovery guidance.
- Refuse root paths, drive roots, system directories, repository parents, broad OUs, broad wildcard scopes, and ambiguous targets.
- Check prerequisite success between destructive steps.
- Stop or compensate safely when a critical step fails.
- Never reinterpret `not found` as permission to create, delete, or broaden scope.
- Avoid suppressing confirmation globally.
- Avoid `-ErrorAction SilentlyContinue` for failures that determine destructive-operation success.

ShouldProcess example:

```powershell
function Remove-ExampleItem {
    [CmdletBinding(SupportsShouldProcess, ConfirmImpact = 'High')]
    param(
        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string]$Name
    )

    Set-StrictMode -Version Latest
    $ErrorActionPreference = 'Stop'
    if ($PSCmdlet.ShouldProcess($Name, 'Remove example item')) {
        Remove-Item -LiteralPath $Name -Force
    }
}
```

## WhatIf, Confirm, And DryRun Semantics

Agents MUST clearly distinguish:

- `-WhatIf`: PowerShell `ShouldProcess` preview for each state-changing operation.
- `-Confirm`: interactive approval controlled through `ShouldProcess`.
- `-DryRun`: richer end-to-end simulation that may validate configuration, credentials, target resolution, connectivity, permissions, dependencies, reports, and planned actions without mutation.

Every state-changing command MUST call `$PSCmdlet.ShouldProcess()` around the actual mutation. Declaring `SupportsShouldProcess` without wrapping mutation is noncompliant.

`-DryRun` MUST NOT call mutating APIs. If a vendor API lacks native simulation, `DryRun` MUST stop before the mutation call and report the intended request safely. Scheduled and unattended workflows MUST NOT depend on interactive `-Confirm` prompts. Execution mode MUST be explicit. `Force` MUST NOT bypass validation, scope controls, authorization, target safety, or `ShouldProcess`; it MAY reduce prompts only when documented.

DryRun gating example:

```powershell
if ($Mode -eq 'DryRun') {
    [pscustomobject]@{
        Target = $ResolvedTarget
        Action = 'Set example property'
        ChangedState = $false
        Status = 'NotRun'
    }
    return
}

if ($Mode -ne 'Execute') {
    throw 'Mutation requires -Mode Execute.'
}

if ($PSCmdlet.ShouldProcess($ResolvedTarget, 'Set example property')) {
    Set-ExampleProperty -Target $ResolvedTarget -Value $Value
}
```

Tests MUST verify that `WhatIf` and `DryRun` perform no mutation.

## Idempotency, Retries, Rollback, And Partial Failure

PowerShell automation that changes state MUST detect current state before changing it and safely skip already-compliant targets.

Agents MUST:

- Define whether repeated execution is safe.
- Avoid duplicate side effects.
- Retry only transient failures.
- Avoid automatic retry of non-idempotent operations unless duplicate protection exists.
- Use bounded retries with backoff and optional jitter.
- Respect API rate limits and `Retry-After`.
- Record each retry.
- Distinguish transient, permanent, validation, authentication, authorization, connectivity, and dependency failures.
- Return per-target and overall status.
- Make partial success visible.
- Consider resume or restart capability for long multi-target workflows.
- Never rerun completed destructive steps blindly after partial failure.

Rollback guidance MUST identify what can be reverted, what is irreversible, and what operator recovery steps exist.

## Logging, Progress, And Operator Feedback

Enterprise PowerShell automation MUST log enough information to troubleshoot without exposing secrets.

Logging MUST use structured records with:

- Timestamp.
- Severity.
- Run ID.
- Component.
- Target.
- Operation.
- Sanitized message.

Log levels SHOULD include Debug, Verbose, Information, Warning, Error, and Critical where appropriate. Logs MUST be written to a configurable path. Console verbosity and file logging SHOULD be independently configurable.

Transcript use MUST be evaluated carefully because transcripts can capture sensitive values. If `Start-Transcript` is used, documentation MUST explain redaction limitations, and structured logs MUST still exist.

Progress output MUST NOT corrupt pipeline output. Long-running scripts SHOULD display progress or periodic status. Noninteractive jobs SHOULD emit heartbeat or status entries where appropriate. Log rotation and retention SHOULD be configurable for scheduled tasks. Logging failure MUST be handled deliberately.

## Reporting And Artifact Requirements

Enterprise scripts SHOULD use a reusable `ReportingTools` module or established equivalent. Reporting formats MUST be configurable and SHOULD include CSV, JSON, HTML, and TXT where operationally useful.

A single normalized result object SHOULD drive all output formats. Reports MUST include:

- Run ID.
- Script or tool name and version.
- Start and end timestamps.
- Duration.
- Operator or execution identity when safe.
- Host running the script.
- Mode: Discovery, Validation, DryRun, Report, or Execute.
- Configuration profile name, not secrets.
- Requested target.
- Resolved target.
- Per-target status.
- Action planned.
- Action performed.
- Changed state indicator.
- Error category.
- Sanitized error message.
- Retry count.
- Evidence or correlation identifiers where applicable.

Status values SHOULD include `Passed`, `Failed`, `Skipped`, `Blocked`, `NotRun`, `NotApplicable`, and `PartiallySucceeded` when target-level partial completion is meaningful. Skipped or unavailable validation MUST NOT be marked `Passed`.

HTML output MUST encode untrusted values. CSV output MUST avoid formula injection. JSON output SHOULD use a documented schema or stable contract. Reports MUST NOT contain secrets. Report filenames SHOULD be deterministic, collision-resistant, and include a timestamp or run ID. Report write failure MUST be surfaced and MUST NOT be hidden behind otherwise successful operation. Modifying scripts SHOULD capture before and after state where safe and practical.

Structured result example:

```powershell
[pscustomobject]@{
    RunId = $RunId
    ToolName = 'Invoke-Example'
    Mode = $Mode
    RequestedTarget = $RequestedTarget
    ResolvedTarget = $ResolvedTarget
    Status = 'Passed'
    ActionPlanned = 'Validate target'
    ActionPerformed = 'Validated target'
    ChangedState = $false
    ErrorCategory = $null
    SanitizedErrorMessage = $null
    RetryCount = 0
}
```

## Reusable Module Requirements

Reusable PowerShell logic SHOULD live in modules rather than duplicated scripts. Modules MUST separate public and private functions where practical, expose stable public contracts, and keep exported functions synchronized with manifests.

Credential, reporting, email, API client, retry, path-safety, and logging logic SHOULD be factored into reusable modules or established local equivalents when used by multiple tools.

Public functions MUST have comment-based help. Private functions SHOULD include comment-based help or a concise purpose contract when nontrivial. Modules MUST avoid hidden global state, implicit production targets, and side effects during import.

## Code Documentation Requirements

All generated or materially modified PowerShell code MUST be maintainable by administrators who did not author it.

Scripts and modules MUST include a top-level header describing purpose, safety model, dependencies, configuration, inputs, outputs, and examples. Every public function and user-facing script MUST include comment-based help with:

- `.SYNOPSIS`.
- `.DESCRIPTION`.
- `.PARAMETER` for every public parameter.
- `.EXAMPLE` with safe realistic examples.
- `.INPUTS`.
- `.OUTPUTS`.
- `.NOTES`.
- `.LINK` when useful.

Private functions SHOULD include comment-based help or a concise purpose contract when nontrivial. Inline comments SHOULD explain non-obvious safety gates, credential flow, retries, API behavior, data normalization, reporting, rollback, and cleanup. Agents MUST NOT comment obvious syntax line by line.

README documentation MUST explain prerequisites, supported PowerShell versions, required modules, installation, configuration, credential modes and precedence, input CSV schema, manual target usage, discovery mode, validation mode, `DryRun` versus `WhatIf`, execution mode, reporting, email, scheduling, code signing, exit codes, troubleshooting, security considerations, rollback, and recovery.

README documentation MUST include every public entry-point parameter and switch. For each public parameter or switch, the README MUST document the parameter set, default value, accepted value or `ValidateSet` choice, required or optional status, mutually exclusive combinations, interaction constraints, safety implications, and at least one safe example. Public parameters MUST NOT exist only in comment-based help without corresponding operator-facing README documentation. README examples MUST cover every operational mode. State-changing examples MUST remain safe by default and MUST use `-WhatIf` or `-DryRun` before `-Mode Execute` or equivalent execution mode. Deprecated parameters and aliases MUST be clearly marked.

Hidden, undocumented, or behavior-changing public switches are prohibited. If a parameter is intentionally internal, it MUST NOT be exposed as a public entry-point parameter. README parameter documentation and comment-based help MUST remain synchronized. Tests or documentation-completeness validation SHOULD detect undocumented public parameters where practical.

Examples MUST be safe by default and MUST NOT target real production systems.

## Error Handling And Exit Behavior

Entry points MUST use `Set-StrictMode -Version Latest` unless a documented compatibility issue exists. `$ErrorActionPreference = 'Stop'` MUST be set at entry points unless justified.

Agents MUST:

- Use `try`/`catch`/`finally` around external resources and recoverable operations.
- Preserve original exception context.
- Sanitize errors before logging or reporting.
- Use terminating errors for unrecoverable failures.
- Use meaningful exit codes.
- Close sessions, dispose clients, and remove temporary resources in `finally` blocks.
- Avoid swallowing errors to keep CI green.
- Avoid converting `Failed`, `Blocked`, or `NotRun` to `Passed`.
- Aggregate per-target errors without losing detail.

An operation that succeeded but failed to report its result MUST NOT be represented as fully `Passed` without qualification.

## Path And Filesystem Safety

PowerShell code that handles paths MUST:

- Prefer `-LiteralPath` for user-controlled paths.
- Resolve and normalize paths.
- Verify targets remain beneath the approved root.
- Reject traversal.
- Reject drive roots and ambiguous paths.
- Avoid string-built deletion commands.
- Validate UNC paths.
- Distinguish local and remote path semantics.
- Prevent output directories from overlapping destructive input directories.
- Use safe temporary directories.
- Clean temporary content in `finally` blocks when appropriate.
- Never delete recursively based only on a user-provided relative string.

Safe path-boundary validation example:

```powershell
function Resolve-ChildPath {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string]$Root,

        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string]$ChildPath,

        [switch]$AllowRoot
    )

    Set-StrictMode -Version Latest
    $ErrorActionPreference = 'Stop'

    $separatorChars = @(
        [System.IO.Path]::DirectorySeparatorChar,
        [System.IO.Path]::AltDirectorySeparatorChar
    )

    $resolvedRoot = (Resolve-Path -LiteralPath $Root).Path.TrimEnd($separatorChars)
    $candidate = [System.IO.Path]::GetFullPath(
        (Join-Path -Path $resolvedRoot -ChildPath $ChildPath)
    )

    $rootBoundary = $resolvedRoot + [System.IO.Path]::DirectorySeparatorChar
    $isRoot = $candidate.Equals($resolvedRoot, [System.StringComparison]::OrdinalIgnoreCase)
    $isChild = $candidate.StartsWith($rootBoundary, [System.StringComparison]::OrdinalIgnoreCase)

    if (($isRoot -and -not $AllowRoot) -or (-not $isRoot -and -not $isChild)) {
        throw 'Target path resolves outside the approved root or root access is not permitted.'
    }

    $candidate
}
```

Prefix matching without a directory boundary is unsafe because sibling paths can share the same leading text as an approved root. Root access MUST be explicitly allowed for the specific operation. Destructive operations MUST revalidate the target immediately before mutation. Cross-platform tools MUST account for platform-specific case sensitivity instead of assuming Windows comparison behavior everywhere. Lexical path validation alone is not sufficient for reparse points, symlinks, junctions, UNC paths, or time-of-check/time-of-use changes; those cases may require additional filesystem and security validation. Path authorization and filesystem authorization are separate concerns.

Recursive delete and move operations MUST verify the resolved absolute path before execution and MUST support preview, confirmation, or explicit execution mode.

## External Executables And Command Invocation

Agents MUST avoid `Invoke-Expression` and avoid string-built shell commands. Native executable calls MUST use argument arrays or safe process APIs where practical.

External command handling MUST:

- Check executable existence.
- Capture stdout, stderr, and exit code.
- Define accepted exit codes.
- Redact sensitive arguments.
- Apply timeouts.
- Record tool version when used for validation or evidence.
- Avoid piping downloaded content directly to execution.
- Avoid `cmd /c` or `powershell -Command` as an avoidable quoting workaround.

Executable-not-found, timeout, rejected exit code, and stderr warning conditions MUST be handled distinctly when they affect completion.

## Security And Prohibited Patterns

PowerShell changes MUST NOT introduce:

- Plaintext passwords, tokens, API keys, or private keys.
- Secrets in PSD1, CSV, source code, examples, logs, reports, command lines, or Git history.
- `Invoke-Expression` for avoidable or untrusted input.
- Download-and-execute pipelines.
- TLS certificate-validation bypass.
- SSH host-key bypass.
- `Set-ExecutionPolicy Bypass` as a routine requirement.
- Automatic execution policy changes.
- Broad recursive deletion without boundary validation.
- Implicit production targets.
- Wildcard destructive operations.
- Automatic module installation from untrusted repositories.
- Trust in PSGallery or another repository without policy review.
- Suppression of errors that determine success.
- Self-modifying signed scripts.
- Runtime modification of signed files.
- Tests that call production systems.
- Tests that merely print success.
- Fabricated evidence.
- Logging entire credential or API-response objects without redaction.
- Global `ConfirmPreference` changes to evade prompts.
- Unbounded parallelism.
- Deprecated WMI commands when a supported CIM alternative is required by compatibility policy, except documented legacy compatibility.
- `Send-MailMessage` as the preferred modern email implementation without documenting compatibility and security limitations.
- Disabling antivirus, EDR, AMSI, script-block logging, or security controls.
- Adding security-product exclusions unless explicitly authorized and governed as a high-risk exception.

Negative examples in documentation MUST clearly identify the prohibited behavior.

## Module And Manifest Requirements

Reusable modules MUST include `.psd1` manifests unless the repository has an approved exception.

Manifest requirements include:

- `RootModule`.
- `ModuleVersion`.
- `GUID`.
- `Author` or owner.
- `CompanyName` where appropriate.
- `Copyright`.
- `Description`.
- `PowerShellVersion`.
- `CompatiblePSEditions` where appropriate.
- `RequiredModules`.
- `FunctionsToExport`.
- `CmdletsToExport`.
- `AliasesToExport`.
- `PrivateData` and `PSData` metadata where appropriate.
- `ProjectUri` and `LicenseUri` when available.

Agents MUST export functions explicitly and avoid `FunctionsToExport = '*'`. Manifests and module exports MUST remain synchronized. Modules MUST use semantic versioning. `Test-ModuleManifest` MUST validate changed manifests.

Publishing MUST require an explicit destination and MUST NOT occur from a dirty working tree without explicit approval. Package and signing behavior MUST be documented.

Manifest validation example:

```powershell
Test-ModuleManifest -Path .\modules\ExampleTools\ExampleTools.psd1
```

## Testing Requirements

PowerShell behavior changes MUST include Pester tests unless the test is not applicable or cannot run; omitted or unavailable tests MUST be recorded as `NotApplicable`, `NotRun`, or `Blocked` with a reason.

Applicable tests SHOULD cover:

- Parser validity.
- Configuration validation.
- Missing configuration.
- Unknown configuration keys.
- CSV schema validation.
- Empty CSV.
- Duplicate targets.
- Manual target input.
- Localhost behavior where supported.
- Parameter sets.
- Discovery mode.
- Validation mode.
- `DryRun`.
- `WhatIf`.
- Execute gating.
- `ShouldProcess` invocation.
- No mutation under `DryRun` or `WhatIf`.
- Credential precedence.
- CyberArk CCP request behavior using mocks.
- Secret redaction.
- Logging.
- Report generation for CSV, JSON, HTML, and TXT where supported.
- HTML encoding.
- CSV formula-injection handling.
- Email success and failure using mocks.
- Retry behavior.
- Timeout behavior.
- Partial failure.
- Idempotency.
- Unsafe path refusal.
- Wildcard target refusal.
- Error and exit-code behavior.
- Cleanup in `finally` blocks.
- Module exports and manifests.
- Windows PowerShell 5.1 compatibility where claimed.
- PowerShell 7 compatibility where claimed.

Tests MUST use mocks, synthetic data, temporary paths, and test doubles. They MUST NOT use real credentials, call production endpoints, mutate real infrastructure, or assert only console wording. Integration tests MUST be clearly separated and opt-in. Skipped or unavailable tests MUST include reasons.

Pester example:

```powershell
Invoke-Pester -Path .\tests -Output Detailed
```

## Validation Commands

Agents MUST use repository-local commands from [../AGENTS.md](../AGENTS.md) as the source of truth. For PowerShell changes, applicable validation includes:

```powershell
git status --short
git diff --check
git diff
```

```powershell
pwsh -NoProfile -File scripts/Test-AgentStandards.ps1 -Path .
pwsh -NoProfile -File scripts/Test-MarkdownLinks.ps1 -Path .
pwsh -NoProfile -File scripts/Test-DocumentationCompleteness.ps1 -Path .
pwsh -NoProfile -File actions/forbidden-pattern-scan/Invoke-ForbiddenPatternScan.ps1 -Path . -OutputJson evidence/forbidden-patterns.json
Invoke-Pester -Path tests -Output Detailed
Invoke-ScriptAnalyzer -Path . -Recurse -Severity Error
```

Parser validation example:

```powershell
$errors = @()
Get-ChildItem -Recurse -File -Include *.ps1,*.psm1,*.psd1 | ForEach-Object {
    $tokens = $null
    $parseErrors = $null
    [System.Management.Automation.Language.Parser]::ParseFile($_.FullName, [ref]$tokens, [ref]$parseErrors) | Out-Null
    if ($parseErrors) { $errors += $parseErrors }
}
if ($errors.Count -gt 0) { throw 'PowerShell parser validation failed.' }
```

PSScriptAnalyzer example:

```powershell
Invoke-ScriptAnalyzer -Path . -Recurse -Severity Error
```

Compatibility-aware examples:

```powershell
powershell.exe -NoProfile -File .\tools\Test-Project.ps1
pwsh -NoProfile -File ./tools/Test-Project.ps1
```

Agents MUST NOT claim Windows PowerShell 5.1, PowerShell 7, Pester, PSScriptAnalyzer, parser validation, or manifest validation passed unless the exact check ran.

## Code-Signing Requirements

Scripts and modules MUST remain compatible with Authenticode signing. Agents MUST NOT generate code that modifies itself after signing, modify signed files at runtime, or place generated content after an Authenticode signature block.

When downstream policy requires signing, entry-point scripts and reusable modules MUST be signed. README documentation MUST include signing and validation instructions using placeholders only.

Safe signing examples:

```powershell
$now = Get-Date
$approvedSubject = 'CN=Example Code Signing'
$timestampServer = 'https://timestamp.example.invalid'

$certificates = @(
    Get-ChildItem -Path Cert:\CurrentUser\My -CodeSigningCert |
        Where-Object {
            $_.HasPrivateKey -and
            $_.NotBefore -le $now -and
            $_.NotAfter -gt $now -and
            $_.Subject -eq $approvedSubject
        }
)

if ($certificates.Count -eq 0) {
    throw 'No valid matching code-signing certificate was found.'
}

if ($certificates.Count -gt 1) {
    throw 'Multiple matching code-signing certificates were found. Use an explicit approved selector.'
}

$certificate = $certificates[0]

Set-AuthenticodeSignature `
    -FilePath .\Invoke-Example.ps1 `
    -Certificate $certificate `
    -TimestampServer $timestampServer
```

```powershell
$signature = Get-AuthenticodeSignature -FilePath .\Invoke-Example.ps1
if ($signature.Status -ne 'Valid') {
    throw "Signature validation failed: $($signature.Status)"
}
```

Code-signing requirements:

- The certificate MUST include the Code Signing EKU.
- Certificate selection MUST validate `HasPrivateKey`, current validity period, intended certificate store, trust chain, timestamp-server policy, and a unique certificate match.
- Certificate selection MUST use an explicit approved selector such as subject, thumbprint, or another governed identifier. Real thumbprints MUST NOT appear in examples.
- Certificate discovery MUST fail when zero certificates match or multiple certificates match.
- Certificate discovery MUST NOT silently use `Select-Object -First 1` as the only selection safeguard.
- Revocation status MUST be checked where enterprise PKI and network access can validate it.
- Private keys MUST remain on an approved signing workstation, HSM, key vault, or protected signing service.
- Timestamping SHOULD be used when policy allows so signatures remain valid after certificate expiration.
- Timestamp servers MUST be validated according to enterprise policy.
- Certificate discovery does not replace enterprise approval. The selected certificate MUST be approved for the repository and release process.
- Signature status MUST be validated after signing with `Get-AuthenticodeSignature`.
- `AllSigned` and `RemoteSigned` documentation MUST be accurate.
- `Bypass` MUST NOT be prescribed as the normal solution.
- Trust-chain requirements MUST be documented.
- Common failures MUST be documented, including unknown publisher, untrusted root CA, expired certificate, revoked certificate, missing timestamp, modified script after signing, inaccessible private key, and incorrect EKU.
- Signing MUST be described as publisher and integrity evidence, not proof that code is safe.
- Documentation MUST explain that code signing does not enable WinRM or authorize remote access.
- Tests and build processes MUST NOT strip or corrupt valid signature blocks unintentionally.
- Source changes after signing require re-signing.

## Scheduling And Unattended Execution

Scheduled and unattended PowerShell MUST be noninteractive and least-privilege by design.

Agents MUST document and implement:

- No interactive prompts.
- No prompt credential mode.
- Explicit service account, gMSA, managed identity, certificate, or vault-based credentials.
- Stable working directory.
- Absolute or safely resolved paths.
- Configurable log and report retention.
- Locking or concurrency control to prevent overlapping runs.
- Documented exit codes.
- Reliable noninteractive report generation.
- Optional notification behavior.
- Module availability in the scheduled account context.
- Safe execution identity recording.
- Missed-run and retry behavior.

Task Scheduler creation SHOULD support `WhatIf` when automated. Agents MUST NOT store passwords in task definitions or scripts. Documentation MUST explain `Run whether user is logged on or not` implications. Scheduled execution MUST NOT default to destructive mode merely because it is unattended.

## Performance, Timeout, Retry, And Concurrency Controls

Enterprise PowerShell automation MUST explicitly configure or document:

- Connection timeout.
- Operation timeout.
- Retry count.
- Backoff.
- Rate limiting.
- Concurrency.
- Batch size.
- Per-target failure behavior.
- Overall failure threshold.
- Cancellation handling where practical.

Agents MUST use bounded parallelism. They MUST NOT use unbounded `Start-Job`, `ThreadJob`, runspace, or `ForEach-Object -Parallel` fan-out. Windows PowerShell compatibility MUST be considered before selecting parallelization features. Reports SHOULD preserve deterministic order where practical. Large files SHOULD be streamed rather than fully loaded when possible. Vendor API limits MUST be respected.

## Email Notification Requirements

When email notification is required, solutions SHOULD use a reusable `EmailTools` module or established equivalent.

Email controls MUST include:

- PSD1-driven SMTP and message settings.
- No hard-coded recipients, SMTP hosts, ports, TLS choices, sender addresses, or distribution lists.
- Authentication secrets from approved credential handling.
- TLS and certificate validation.
- No certificate-check bypass.
- Attachment size controls.
- Sanitized report attachments only.
- Separate reporting of email failure from task execution failure.
- Clear scheduled-execution behavior.

Optional notification failure SHOULD NOT make the core operation appear failed unless notification is a stated completion requirement. Templates SHOULD support success, partial-success, failure, and dry-run subjects. Subject lines MUST NOT include sensitive details.

If legacy `Send-MailMessage` is used, documentation MUST explain its compatibility and security limitations and why it is acceptable for that repository.

## Completion Evidence

PowerShell completion evidence MUST align with [../governance/COMPLETION_EVIDENCE.md](../governance/COMPLETION_EVIDENCE.md) and [../AGENTS.md](../AGENTS.md).

Evidence MUST report:

- Files changed.
- Commands run.
- Exit codes.
- PowerShell versions and editions tested.
- Parser result.
- PSScriptAnalyzer result or `NotRun` reason.
- Pester result or `NotRun` reason.
- `Test-ModuleManifest` result where applicable.
- Configuration validation result.
- `WhatIf` result.
- `DryRun` result.
- Execute-mode test result, if safely run.
- Credential mode tests using synthetic values.
- Report-format tests.
- Signing validation result or `NotRun` reason.
- Remoting validation result or `NotRun` reason.
- Scheduled-execution validation or `NotRun` reason.
- Git diff review.
- Evidence files updated.
- Whether GitHub Actions actually ran.
- Whether artifacts were independently verified.
- Remaining risks and gaps.

Permitted completion statuses are `Passed`, `Failed`, `Blocked`, `NotRun`, and `NotApplicable`. Unavailable tools, inaccessible environments, absent credentials, and unexecuted checks MUST NOT be labeled `Passed`.

## Failure Behavior

PowerShell work is incomplete when:

- Parser validation fails.
- A CI script exits zero after detecting failure.
- A state-changing command lacks `ShouldProcess`.
- `SupportsShouldProcess` is declared but mutation is not wrapped in `$PSCmdlet.ShouldProcess()`.
- A destructive operation lacks exact target validation.
- Secrets are introduced or exposed.
- Required applicable tests are missing without evidence status and reason.
- A manifest is inconsistent with exports.
- A remote operation lacks target, timeout, failure, or rollback behavior.
- Reports hide partial success, skipped validation, or failed notification.
- Signing, scheduling, remoting, or compatibility claims are made without validation or `NotRun` evidence.

Agents SHOULD fix failures within scope. If a fix requires broader redesign, credentials, production access, or human approval, the agent MUST report the blocker.

## Exception Handling

Exceptions MUST follow [../governance/EXCEPTION_PROCESS.md](../governance/EXCEPTION_PROCESS.md). Agents MUST NOT locally waive parser validation, Pester, PSScriptAnalyzer, manifest validation, signing requirements, credential controls, remoting controls, destructive-operation safeguards, or evidence requirements without an approved active exception.

Expired, missing, malformed, rejected, or unapproved exceptions MUST NOT be treated as valid. If a PowerShell-specific validation cannot run, record `NotRun` or `Blocked` with the reason. Do not relabel it as `NotApplicable` unless the changed files truly do not involve that validation category.

## Related Documents

- [AGENTS_Base.md](AGENTS_Base.md)
- [../AGENTS.md](../AGENTS.md)
- [../governance/ORGANIZATION_CONTRACT.md](../governance/ORGANIZATION_CONTRACT.md)
- [../governance/COMPLETION_EVIDENCE.md](../governance/COMPLETION_EVIDENCE.md)
- [../governance/RISK_CLASSIFICATION.md](../governance/RISK_CLASSIFICATION.md)
- [../governance/EXCEPTION_PROCESS.md](../governance/EXCEPTION_PROCESS.md)
- [../governance/AI_GENERATED_CODE_POLICY.md](../governance/AI_GENERATED_CODE_POLICY.md)
- [../docs/ACTION_SECURITY.md](../docs/ACTION_SECURITY.md)
- [../docs/TROUBLESHOOTING.md](../docs/TROUBLESHOOTING.md)

## Revision History

- 1.1.1: Corrected path-boundary validation guidance to prevent prefix-collision sibling paths, strengthened README public-parameter documentation requirements, and hardened Authenticode certificate-selection guidance against silent first-match selection.
- 1.1.0: Rebuilt as a comprehensive enterprise PowerShell standard with explicit runtime compatibility, PSD1-first configuration, CSV/manual target input, phased safe development, `DryRun` and `WhatIf` semantics, credential/reporting/email module patterns, remoting controls, destructive-operation safeguards, Authenticode signing, scheduled execution, testing, validation, and completion evidence.
- 1.0.0: PowerShell standard rewritten with enterprise requirements for discovery, risk, path safety, ShouldProcess, credentials, remoting, validation, testing, signing, logging, evidence, and failure behavior.
