# Frameworks Home-Lab Demo

## Purpose

This sibling of `powershell-review-home-lab` demonstrates an isolated `frameworks` skill using the copied Public-Access-Agents framework package. It covers Angular, ASP.NET Core, FastAPI, React, and Spring Boot without production access, secrets, external writes, or an OpenAI API key.

The upstream package is preserved beneath `.agents/skills/frameworks/`. See [SOURCE.md](SOURCE.md) for immutable provenance, declared demo adaptations, pinned cross-package references, and Apache-2.0 notices.

## Deterministic Validation

```powershell
pwsh -NoProfile -File examples/frameworks-home-lab/tools/Test-Demo.ps1
```

The command validates package structure, prompt routing and safe refusal contracts, copied-package inventory, PowerShell parsing, Pester tests, and the example governance contract. It makes no model call and uses no secret.

## Interactive Demonstration

Open `examples/frameworks-home-lab` in an authenticated interactive Codex or ChatGPT session, then submit:

```text
$frameworks Review the synthetic FastAPI adoption example for framework and language composition, authorization, lifecycle, observability, testing, and missing evidence. Do not deploy or modify files.
```

Interactive output is demonstration material, not production behavior certification.

## Safety Boundary

All applications, dependencies, configurations, services, identities, and scenarios must remain synthetic. Implementation and deployment phases in the copied standards are design guidance only. No `OPENAI_API_KEY` is used or required.
