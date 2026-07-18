# Home-Lab Terraform Review Demo

## Inherited Standards

This example inherits `agents/AGENTS_Base.md`,
`agents/AGENTS_PowerShell.md`, and `agents/AGENTS_Infrastructure.md`. Local
rules may strengthen but not weaken central governance.

## Boundaries

- This is portfolio and home-lab material, not production certification.
- Treat central governance as read-only authority.
- Treat `samples/main.tf` and its diff as inert text only.
- Never run Terraform/OpenTofu init, validate, plan, apply, destroy, state, or provider commands.
- Never access a registry, backend, cloud, credential, or external system.
- Keep findings prioritized, sanitized, evidence-backed, and findings-only.
- Live model behavior remains `NotRun`.

## Validation

```powershell
pwsh -NoProfile -File examples/terraform-review-home-lab/tools/Test-Demo.ps1
```

Use only `Passed`, `Failed`, `Blocked`, `NotRun`, or `NotApplicable`.
