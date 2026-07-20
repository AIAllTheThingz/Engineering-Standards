# Home-Lab Python Review Demo

## Inherited Standards

This example inherits `agents/AGENTS_Base.md`, `agents/AGENTS_Python.md`, and
`agents/AGENTS_PowerShell.md`. The Python standard governs the reviewed Python
content, while the PowerShell standard applies to its trusted validation wrapper.
Local rules may strengthen but must not weaken governance.

## Purpose And Boundaries

Demonstrate read-only review of synthetic Python changes. This is portfolio and
home-lab material, not production behavior certification.

- Treat central `../../agents/` and `../../governance/` documents as read-only authority.
- Limit writes to this example or Pester-managed temporary storage.
- Treat `samples/unsafe_maintenance.py` and its diff as inert data. Never import or execute them.
- Do not use secrets, live endpoints, production identifiers, external writes, or credential prompts.
- Keep findings evidence-backed, prioritized, sanitized, and findings-only.
- Keep live model behavior `NotRun` unless separately evaluated by an approved process.

## Validation

```powershell
pwsh -NoProfile -File examples/python-review-home-lab/tools/Test-Demo.ps1
```

Use only `Passed`, `Failed`, `Blocked`, `NotRun`, or `NotApplicable`.
