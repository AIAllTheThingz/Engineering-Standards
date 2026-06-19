# AGENTS.md

## Inherited Standards

This example inherits:

- `agents/AGENTS_Base.md`
- `agents/AGENTS_PowerShell.md`

Local rules may strengthen but MUST NOT weaken central governance.

## Repository Purpose

This directory is a functional PowerShell example for downstream governance adoption. It demonstrates a small advanced function, module manifest, Pester tests, local validation script, CI wiring, and evidence generation.

## Allowed Work

Agents may update the example module, tests, documentation, manifest, governance configuration, workflow sample, and local validation script when the change improves the example or keeps it aligned with central standards.

## Restricted Work

Agents MUST NOT add secrets, production endpoints, network dependencies, destructive operations, credential prompts, hidden external service calls, or fake validation commands.

## Commands

Run the functional validation:

```powershell
pwsh -NoProfile -File examples/powershell-project/tools/Test-Example.ps1
```

Run the contract validator:

```powershell
pwsh -NoProfile -File actions/validate-contract/Invoke-ContractValidation.ps1 -Path examples/powershell-project
```

## Evidence

Substantive changes to this example SHOULD refresh `examples/powershell-project/evidence/test-evidence.json` by running the local validation script. If a tool is unavailable, record the result as `NotRun` instead of claiming success.

## Exceptions

No local exceptions are approved. A new exception requires a `GOV-*` reference, owner, expiration, compensating control, and remediation plan.
