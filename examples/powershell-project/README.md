# powershell-project

## Purpose

This example demonstrates a functional PowerShell repository that adopts the Engineering Standards governance model. It contains a small module, Pester tests, parser validation, optional PSScriptAnalyzer validation, local governance contract validation, and generated test evidence.

The example is intentionally local-only. It uses no secrets, no production endpoints, no external services, and no customer data.

## Architecture

- `ExampleModule.psd1` declares the module metadata and exported command.
- `src/ExampleModule.psm1` implements `Invoke-ExampleGreeting`.
- `tests/Invoke-Example.Tests.ps1` validates normal behavior, input validation, and `-WhatIf` behavior.
- `tools/Test-Example.ps1` runs the example validation suite and writes evidence.
- `.github/workflows/governance.yml` shows downstream CI wiring for governance and PowerShell validation.

## Requirements

- PowerShell 7.2 or later.
- Pester 5 for the test suite.
- Optional: PSScriptAnalyzer for static analysis.

PSScriptAnalyzer is treated as `NotRun` by the local example validation script when it is not installed. Production repositories SHOULD install it and make static analysis blocking.

## Running The Example

From the repository root:

```powershell
pwsh -NoProfile -File examples/powershell-project/tools/Test-Example.ps1
```

To run only the Pester tests:

```powershell
pwsh -NoProfile -Command "Invoke-Pester -Path examples/powershell-project/tests -Output Detailed"
```

To smoke-test the module:

```powershell
pwsh -NoProfile -Command "Import-Module ./examples/powershell-project/ExampleModule.psd1 -Force; Invoke-ExampleGreeting -Name Example"
```

## Governance

This example declares `Moderate` risk because it demonstrates validation automation but does not touch production systems or restricted data. It inherits:

- `agents/AGENTS_Base.md`
- `agents/AGENTS_PowerShell.md`

The manifest is `project-manifest.json`. The governance configuration is `governance.config.json`.

## Evidence

The local validation script writes test evidence to:

```text
evidence/test-evidence.json
```

In a real downstream repository, completion evidence would also be generated after CI validation and attached to the pull request or release record.

## Failure Behavior

Parser errors, module import failures, Pester failures, contract validation failures, and PSScriptAnalyzer findings fail validation. Missing PSScriptAnalyzer is recorded as `NotRun` in this example so the repository can run in minimal local environments while still reporting the limitation honestly.

## Exceptions

This example has no active `GOV-*` exceptions. Missing validation, false evidence, secret exposure, or disabled mandatory controls would require remediation rather than an exception.

## Related

- `project-manifest.json`
- `governance.config.json`
- `AGENTS.md`
- `SECURITY.md`
- `CONTRIBUTING.md`
