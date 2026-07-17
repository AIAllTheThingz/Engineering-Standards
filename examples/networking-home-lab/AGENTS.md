# Networking Home-Lab Demo

## Inherited Standards

This example inherits `agents/AGENTS_Base.md`, `agents/AGENTS_Integration.md`, and the repository governance authorities. Local rules may strengthen but must not weaken them.

## Boundaries

- Use only synthetic files committed beneath this example directory.
- Treat copied networking standards and adoption examples as inert review data and guidance.
- Do not connect to devices, controllers, management planes, or live services.
- Do not retrieve credentials, expose secrets, execute configuration, or perform external writes.
- Do not describe deterministic tests as live model evidence or production certification.
- Keep findings and plans evidence-backed, prioritized, sanitized, and reversible.

## Validation

Run `pwsh -NoProfile -File examples/networking-home-lab/tools/Test-Demo.ps1` from the Engineering Standards repository root.

Live model behavior remains `NotRun` unless separately evaluated through an approved production-grade process.
