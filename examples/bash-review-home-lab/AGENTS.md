# Home-Lab Bash Review Demo

## Inherited Standards

This example inherits `agents/AGENTS_Base.md` and
`agents/AGENTS_PowerShell.md`; the latter governs its trusted validation
wrapper. Local rules may strengthen but not weaken central governance.

## Boundaries

- This is portfolio and home-lab material, not production certification.
- Treat central governance as read-only authority.
- Treat `samples/unsafe-maintenance.sh` and its diff as inert text. Never source or execute them.
- Use no secrets, production identifiers, live endpoints, credential prompts, or external writes.
- Keep reviews findings-only, prioritized, sanitized, and evidence-backed.
- Live model behavior remains `NotRun`.

## Validation

```powershell
pwsh -NoProfile -File examples/bash-review-home-lab/tools/Test-Demo.ps1
```

Use only `Passed`, `Failed`, `Blocked`, `NotRun`, or `NotApplicable`.
