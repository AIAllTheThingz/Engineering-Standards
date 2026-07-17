# Build Pester Tests Home Lab

This secret-free example demonstrates an isolated `build-pester-tests` skill
against a small synthetic PowerShell module. The lab makes requirements
traceable to positive and negative Pester cases while keeping all writes in
Pester's `TestDrive:`.

## Scenario

`samples/SafePath.psm1` resolves a child path beneath a supplied root.
`samples/requirements.json` defines the observable contract, including rooted,
traversal, and empty-path rejection. `demo-output/expected-test-plan.json`
records the illustrative requirement-to-test mapping.

## Run

From the Engineering Standards repository root:

```powershell
pwsh -NoProfile -File examples/build-pester-tests-home-lab/tools/Test-Demo.ps1
```

The runner parses PowerShell, validates the isolated skill and nine routing
fixtures, runs focused Pester tests, and validates the downstream contract. It
does not make a model call or contact a production service.

## Requirements

- PowerShell 7.2 or later.
- Pester 5.7.1 or later.
- Python 3 with PyYAML.

## Evidence meaning

A pass proves only the deterministic package contract. Live model behavior,
GitHub-hosted execution, and production behavior are `NotRun` unless separately
executed and independently verified.
