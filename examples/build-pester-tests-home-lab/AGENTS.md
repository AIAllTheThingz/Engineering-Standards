# Build Pester Tests Home Lab

## Inherited standards

This example inherits `agents/AGENTS_Base.md` and
`agents/AGENTS_PowerShell.md`. When opened independently, treat the central
`../../agents/` and `../../governance/` paths as read-only governing authority.

## Boundaries

- Use only synthetic inputs committed beneath this example.
- Limit writes to this example or Pester-managed temporary storage.
- Never execute downloaded or untrusted content.
- Do not weaken assertions, suppress failures, or fabricate evidence.
- Do not use secrets, production identifiers, live endpoints, or external writes.

## Validation

Run `pwsh -NoProfile -File tools/Test-Demo.ps1` from this example, or run the
same path from the repository root. Live model behavior remains `NotRun`.
