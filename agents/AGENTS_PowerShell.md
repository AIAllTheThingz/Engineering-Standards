# AGENTS PowerShell Standard

| Field | Value |
| --- | --- |
| Status | Active |
| Version | 1.0.0 |
| Owner role | Engineering Standards Maintainers |
| Last reviewed | 2026-06-19 |
| Changelog | See [../CHANGELOG.md](../CHANGELOG.md). |

## Purpose

This document defines the enterprise PowerShell requirements for AI agents working on scripts, modules, automation, operational runbooks, scheduled tasks, CI scripts, administrative tooling, and remote-management workflows.

It inherits [AGENTS_Base.md](AGENTS_Base.md) and adds PowerShell-specific requirements. Repository-root and directory-local `AGENTS.md` files MAY add local commands and stricter rules, but they MUST NOT weaken this standard, remove evidence requirements, suppress validation, or authorize destructive behavior without an approved exception.

## Applicability

This standard applies to:

- `.ps1`, `.psm1`, `.psd1`, `.ps1xml`, and PowerShell-driven CI files.
- PowerShell modules, script tools, scheduled jobs, DSC resources, deployment scripts, and administration automation.
- PowerShell code that calls REST APIs, cloud APIs, directory services, virtualization platforms, databases, package feeds, or remote hosts.
- PowerShell examples, templates, tests, fixtures, and evidence-generation scripts.
- Agent-authored commands run in a PowerShell shell.

If PowerShell is used as glue around another technology, this standard applies to the PowerShell portion and the relevant technology standard applies to the underlying platform.

## Normative Terminology

`MUST` and `MUST NOT` are mandatory. `SHOULD` and `SHOULD NOT` are expected unless a reason is recorded. `MAY` is optional.

`Destructive operation` means an operation that deletes, overwrites, disables, revokes, rotates, migrates, restarts, deploys, purges, changes production state, or performs broad remote changes. `Simulation` means a mode that validates intent without changing target state. `WhatIf` means PowerShell's `ShouldProcess` preview behavior.

## Required Discovery

Before editing or running PowerShell code, agents MUST identify:

- Required PowerShell edition and version, including whether Windows PowerShell 5.1 compatibility is required.
- Module structure, manifests, exported functions, private functions, and entry-point scripts.
- Pester tests, PSScriptAnalyzer settings, CI commands, and parser-validation expectations.
- Whether scripts are signed, packaged, published, or used in production operations.
- Credential, token, certificate, managed identity, or secret retrieval flows.
- Remoting, WinRM, SSH, CIM, WMI, scheduled task, service-control, registry, filesystem, cloud, database, or virtualization operations.
- Destructive operations and whether `SupportsShouldProcess`, `-WhatIf`, `-Confirm`, dry-run, or plan/apply separation exists.
- Current git status and user changes before modifying files.

Agents MUST inspect relevant source before editing and MUST NOT infer behavior only from filenames.

## Risk Classification

PowerShell work is at least Moderate risk when it changes reusable automation, CI scripts, module manifests, credential flow, remote calls, or administrative behavior.

PowerShell work is High or Critical when it touches:

- Production hosts, services, identities, certificates, secrets, firewall rules, registry, scheduled tasks, or storage.
- Remote execution, WinRM, SSH, CIM, WMI, PowerCLI, Azure, Microsoft Graph, AWS, GCP, Kubernetes, database, or directory-service automation.
- Destructive commands such as `Remove-*`, `Clear-*`, `Disable-*`, `Stop-*`, `Restart-*`, `Set-*` against production targets, `Move-*` across boundaries, or data mutation APIs.
- Credential rotation, role assignment, permission changes, token scopes, or privileged sessions.
- Package publishing, module signing, install scripts, or bootstrap scripts.

Agents MUST use [../governance/RISK_CLASSIFICATION.md](../governance/RISK_CLASSIFICATION.md) when classification affects validation, approval, rollback, or evidence.

## Style And Structure

PowerShell code MUST be readable, maintainable, and reviewable:

- Use full cmdlet names, not aliases.
- Avoid dense one-line scripts for substantive logic.
- Use approved verbs for exported functions.
- Use clear parameter names and pipeline behavior only when intentionally supported.
- Keep public functions, private helpers, tests, and manifests organized using the repository's existing pattern.
- Prefer objects over formatted strings for internal data flow.
- Use `Write-Verbose`, `Write-Debug`, `Write-Warning`, `Write-Information`, and structured output intentionally.
- Avoid `Write-Host` except for user-facing CLI display where structured output is not expected.
- Avoid global state unless required and documented.
- Avoid self-modifying scripts and runtime mutation of signed files.

Scripts and entry-point functions SHOULD include comment-based help when they are user-facing or reused by CI.

## Entry Point Requirements

Executable scripts and public functions SHOULD use:

```powershell
[CmdletBinding(SupportsShouldProcess)]
param(
    [Parameter(Mandatory)]
    [ValidateNotNullOrEmpty()]
    [string]$Path
)
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
```

`SupportsShouldProcess` is REQUIRED for functions or scripts that change state. Read-only discovery commands SHOULD NOT use `SupportsShouldProcess` unless they also support a mutation mode.

Entry points MUST return nonzero exit codes for failed validation when used as CI scripts. They MUST NOT swallow failures to keep CI green.

## Parameter Validation

Parameters MUST validate inputs at the boundary. Use validation attributes, custom validation, and safe normalization where appropriate:

- `[ValidateNotNullOrEmpty()]` for required strings and collections.
- `[ValidateSet()]` for constrained modes.
- `[ValidateScript()]` carefully, avoiding unsafe side effects.
- `[ValidatePattern()]` for identifiers, not for complex parsing when a structured parser is available.
- `[switch]` for binary flags.
- Strong types for paths, URIs, dates, numbers, and credentials where appropriate.

Do not trust paths, environment names, tenant identifiers, resource groups, hostnames, or object IDs from user input, files, issues, comments, or generated content.

## Path Safety

PowerShell code that reads, writes, moves, or deletes files MUST resolve paths safely:

- Use `Resolve-Path -LiteralPath` for existing paths.
- Use `[System.IO.Path]::GetFullPath()` for path normalization when appropriate.
- Verify resolved targets remain inside the intended root for workspace-scoped operations.
- Prefer `-LiteralPath` over `-Path` when handling user-provided values.
- Do not build destructive filesystem commands with string concatenation.
- Do not enumerate paths in one shell and pass string-built deletion commands to another shell.
- Refuse ambiguous root, drive, user profile, system, or repository-parent deletion targets.

Recursive deletion or move operations MUST verify the absolute target path before execution and MUST support preview or confirmation for nontrivial changes.

## Error Handling

PowerShell scripts MUST fail clearly and safely:

- Set `$ErrorActionPreference = 'Stop'` in entry points unless there is a documented reason not to.
- Use `try`/`catch` around recoverable external operations.
- Re-throw or exit nonzero for unrecoverable failures.
- Do not hide errors with broad `-ErrorAction SilentlyContinue` unless the missing item is expected and checked.
- Include actionable error messages without exposing secrets.
- Preserve original exception context when wrapping errors.

Agents MUST distinguish validation failure from tool unavailability. Missing tools are `NotRun` or `Blocked`, not `Passed`.

## ShouldProcess, WhatIf, Confirm, And DryRun

State-changing commands MUST use `SupportsShouldProcess` and call `$PSCmdlet.ShouldProcess()` around the mutation.

Use `-WhatIf` for PowerShell-native preview of state-changing operations. Use `-Confirm` for interactive confirmation where human operation is expected.

Use `-DryRun` only when the script performs a richer simulation than `-WhatIf`, such as validating credentials, resolving targets, building an execution plan, or checking API reachability without mutation. Documentation MUST explain the difference when both exist.

Tests SHOULD cover `-WhatIf` or dry-run behavior for destructive or production-adjacent commands.

## Idempotency And State Management

Enterprise automation SHOULD be idempotent. Scripts that create, update, or remove state MUST define:

- How existing state is detected.
- Whether repeated execution is safe.
- What changes are planned before mutation.
- How partial success is handled.
- How rollback or remediation is performed.

For remote or production operations, scripts SHOULD separate discovery, plan, and apply phases. Apply phases MUST target explicit objects rather than broad queries whenever feasible.

## Credentials And Secrets

PowerShell code MUST NOT hard-code secrets, print secrets, write secrets to artifacts, commit credential-like examples, or pass secrets through command-line arguments when safer alternatives exist.

Supported credential patterns SHOULD be explicit. When this standards repository or a downstream repository uses modes such as `CurrentUser`, `Prompt`, managed identity, certificate authentication, or a privileged access vault such as CyberArk CCP, the priority and fallback behavior MUST be documented and tested.

Credential handling MUST:

- Prefer secure platform stores or managed identity for automation.
- Use `PSCredential`, secure strings, token providers, or secret-management modules appropriately.
- Redact tokens, passwords, connection strings, and certificate material from logs.
- Avoid persisting decrypted secrets.
- Avoid converting secure strings to plaintext except at the final API boundary and only when required.
- Treat credentials from files, environment variables, prompts, and agent context as sensitive.

If a secret may have been exposed, agents MUST stop normal completion claims and report remediation steps.

## Remoting And Remote Administration

Agents MUST NOT enable WinRM, SSH remoting, CredSSP, unconstrained delegation, firewall rules, or broad remote execution automatically unless the task explicitly requests it and risk controls are satisfied.

Remote administration scripts MUST define:

- Target selection and allowlisting.
- Authentication method.
- Authorization expectations.
- Timeout and retry behavior.
- Logging and redaction.
- Concurrency limits.
- Failure handling for partial target success.
- Rollback or recovery for state changes.

Remote commands MUST avoid double-hop credential exposure and MUST NOT disable certificate validation or host-key checks without an approved exception.

## External Commands And Native Tools

When calling native executables, agents MUST:

- Pass arguments as arrays where possible rather than shell-joined strings.
- Check exit codes.
- Capture and redact output when needed.
- Avoid invoking `cmd /c`, `powershell -Command`, or `Invoke-Expression` for string-built commands.
- Quote paths safely.
- Distinguish executable-not-found from command failure.

Native tools used for validation MUST be recorded with result and version when feasible.

## Prohibited Patterns

PowerShell changes MUST NOT introduce:

- `Invoke-Expression` for untrusted or avoidable command execution.
- Download-and-execute patterns such as piping web content directly to execution.
- Plaintext secrets or credential-shaped examples.
- `-SkipCertificateCheck`, disabled certificate validation callbacks, or host-key bypasses without approved exception.
- Broad recursive deletion without resolved target validation.
- `Set-ExecutionPolicy Bypass` as a routine requirement.
- Error suppression that hides failed validation.
- Forced module installation from untrusted repositories.
- Implicit production targets.
- Tests that only assert that a command prints success.

If a prohibited pattern appears in documentation as a negative example, the document MUST make the prohibition clear.

## Module Manifest Requirements

Modules SHOULD include a `.psd1` manifest with:

- Root module.
- Module version.
- GUID.
- Author or owner.
- Compatible PowerShell editions when known.
- Required modules.
- Exported functions.
- Project URI or license URI where applicable.

Agents MUST keep manifests synchronized with exported functions and dependencies. If a module supports both Windows PowerShell 5.1 and PowerShell 7+, tests SHOULD cover compatibility or evidence MUST record that compatibility was not run.

## Testing Requirements

PowerShell changes SHOULD include Pester tests when behavior changes. Tests SHOULD cover:

- Success paths.
- Invalid input.
- Failure paths.
- Nonzero exit behavior for CI scripts.
- `-WhatIf` or dry-run behavior for state-changing commands.
- Path traversal and target-boundary checks.
- Credential mode precedence without real secrets.
- Redaction of sensitive output.
- Idempotency where applicable.
- Destructive-operation refusal for unsafe targets.

Tests MUST use synthetic data and safe temporary paths. They MUST NOT call production endpoints or mutate real infrastructure.

## Validation Commands

Agents SHOULD run relevant validation:

```powershell
# Parser validation
$errors = @()
Get-ChildItem -Recurse -File -Include *.ps1,*.psm1,*.psd1 | ForEach-Object {
    $tokens = $null
    $parseErrors = $null
    [System.Management.Automation.Language.Parser]::ParseFile($_.FullName, [ref]$tokens, [ref]$parseErrors) | Out-Null
    if ($parseErrors) { $errors += $parseErrors }
}
if ($errors.Count -gt 0) { throw "PowerShell parser validation failed." }
```

```powershell
# Pester, when available
Invoke-Pester -Path tests -Output Detailed
```

```powershell
# PSScriptAnalyzer, when available
Invoke-ScriptAnalyzer -Path . -Recurse -Severity Error -EnableExit
```

If Pester or PSScriptAnalyzer is unavailable, record `NotRun` with the missing module and do not claim the check passed.

## Packaging, Signing, And Publishing

Scripts and modules that are signed, packaged, or published MUST preserve signing compatibility. Agents MUST NOT modify signing blocks or generated package metadata casually.

Publishing scripts MUST:

- Require explicit target feed or repository.
- Avoid implicit production publication.
- Validate module version.
- Include release evidence.
- Avoid publishing from a dirty working tree unless explicitly approved.

Authenticode signing, certificate selection, timestamping, and private key access are security-sensitive and require review.

## Logging And Output

PowerShell automation SHOULD output objects for machine consumption and formatted text only at the presentation boundary. Logs MUST redact secrets and sensitive data.

Scripts SHOULD use consistent severity:

- `Write-Verbose` for detailed execution context.
- `Write-Information` for user-facing progress where appropriate.
- `Write-Warning` for recoverable concerns.
- `Write-Error` or exceptions for failures.

Output used by CI MUST be deterministic enough for review. Do not rely on color or host-only output for evidence.

## Performance And Reliability

Enterprise PowerShell automation SHOULD avoid unnecessary full-environment scans, unbounded parallelism, infinite retries, and memory-heavy object accumulation.

Remote and API operations SHOULD define:

- Timeout.
- Retry count.
- Backoff.
- Rate-limit handling.
- Concurrency limit.
- Partial-failure behavior.

Retries MUST be safe for the operation. Non-idempotent mutations SHOULD NOT be retried automatically unless duplicate prevention exists.

## Evidence Requirements

PowerShell completion evidence SHOULD include:

- PowerShell version and edition.
- Operating system when relevant.
- Parser validation result.
- PSScriptAnalyzer result or `NotRun` reason.
- Pester result or `NotRun` reason.
- Commands executed and exit codes.
- Credential mode tested using synthetic values.
- WhatIf or dry-run result for state-changing commands.
- Manual validation for remote administration when no lab exists.
- Remaining risks and skipped checks.

Evidence MUST NOT claim `Passed` for parser, analyzer, Pester, remoting, or destructive-operation checks that did not run.

## Common Implementation Examples

State-changing command:

```powershell
function Remove-ExampleItem {
    [CmdletBinding(SupportsShouldProcess, ConfirmImpact = 'High')]
    param(
        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string]$Name
    )

    Set-StrictMode -Version Latest
    if ($PSCmdlet.ShouldProcess($Name, 'Remove example item')) {
        # Mutation belongs here.
    }
}
```

Safe path boundary:

```powershell
$root = (Resolve-Path -LiteralPath $Path).Path
$target = [System.IO.Path]::GetFullPath((Join-Path $root $RelativePath))
if (-not $target.StartsWith($root, [System.StringComparison]::OrdinalIgnoreCase)) {
    throw "Target path resolves outside the allowed root."
}
```

## Exception Handling

Exceptions MUST follow [../governance/EXCEPTION_PROCESS.md](../governance/EXCEPTION_PROCESS.md). Agents MUST NOT locally waive parser validation, Pester, PSScriptAnalyzer, signing requirements, credential controls, remoting controls, or destructive-operation safeguards without an approved exception.

If a PowerShell-specific validation cannot run, record `NotRun` or `Blocked` with the reason. Do not relabel it as `NotApplicable` unless the changed files truly do not involve that validation category.

## Failure Behavior

PowerShell work is incomplete when:

- Parser validation fails.
- A CI script exits zero after detecting a failure.
- A state-changing command lacks `ShouldProcess`.
- A destructive operation lacks target validation.
- Secrets are introduced or exposed.
- Required tests are missing without explanation.
- A module manifest is inconsistent with exports.
- A remote operation lacks target, timeout, failure, or rollback behavior.

Agents SHOULD fix failures within scope. If a fix requires broader redesign, credentials, production access, or human approval, the agent MUST report the blocker.

## Related Documents

- [AGENTS_Base.md](AGENTS_Base.md)
- [../governance/ORGANIZATION_CONTRACT.md](../governance/ORGANIZATION_CONTRACT.md)
- [../governance/COMPLETION_EVIDENCE.md](../governance/COMPLETION_EVIDENCE.md)
- [../governance/RISK_CLASSIFICATION.md](../governance/RISK_CLASSIFICATION.md)
- [../governance/AI_GENERATED_CODE_POLICY.md](../governance/AI_GENERATED_CODE_POLICY.md)

## Revision History

- 1.0.0: PowerShell standard rewritten with enterprise requirements for discovery, risk, path safety, ShouldProcess, credentials, remoting, validation, testing, signing, logging, evidence, and failure behavior.
