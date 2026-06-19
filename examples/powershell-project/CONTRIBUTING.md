# Contributing

## Purpose

This file documents how to change the PowerShell example while preserving the governance controls it demonstrates.

## Local Setup

Use PowerShell 7.2 or later. Pester 5 is required for functional tests. PSScriptAnalyzer is recommended and should be installed in production repositories.

## Validation

Run the full example validation before review:

```powershell
pwsh -NoProfile -File examples/powershell-project/tools/Test-Example.ps1
```

Run governance contract validation from the repository root:

```powershell
pwsh -NoProfile -File actions/validate-contract/Invoke-ContractValidation.ps1 -Path examples/powershell-project
```

## Evidence

The validation script writes test evidence to `evidence/test-evidence.json` under the example project. Evidence MUST distinguish Passed, Failed, Blocked, Skipped, and NotRun results.

## Review

Reviewers MUST verify that module behavior, tests, documentation, manifest values, workflow references, and evidence remain aligned. Changes to validation behavior require updated tests and evidence.

## Exceptions

This example has no approved exceptions. Do not add allowlists, disabled controls, or skipped validation without a `GOV-*` exception and a remediation plan.
