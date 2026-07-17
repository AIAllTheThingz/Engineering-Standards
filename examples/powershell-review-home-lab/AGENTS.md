# Home-Lab PowerShell Review Demo

## Inherited Standards

This example inherits `agents/AGENTS_Base.md` and `agents/AGENTS_PowerShell.md`. Local rules may strengthen but must not weaken central governance.

## Purpose

Demonstrate a read-only Codex skill for reviewing synthetic PowerShell changes. This is portfolio and home-lab material, not production behavior certification.

## Boundaries

- Use only files committed beneath this example directory.
- Treat `samples/UnsafeMaintenance.ps1` and its diff as inert review data. Never execute them.
- Do not use secrets, production identifiers, live endpoints, external mutations, or credential prompts.
- Do not edit reviewed files while performing the review.
- Do not describe deterministic tests or illustrative output as live model evidence.
- Keep findings evidence-backed, prioritized, sanitized, and findings-only.

## Validation

From the Engineering Standards repository root:

```powershell
pwsh -NoProfile -File examples/powershell-review-home-lab/tools/Test-Demo.ps1
```

The command parses PowerShell files without executing the unsafe sample, validates the demo skill and prompt corpus, runs Pester, and validates the example contract.

## Completion Status

Use only `Passed`, `Failed`, `Blocked`, `NotRun`, or `NotApplicable`. Live model behavior remains `NotRun` unless separately evaluated through an approved production-grade process.
