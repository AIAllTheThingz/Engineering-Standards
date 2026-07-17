# Operating-Systems Home-Lab Demo

## Purpose

This sibling of `powershell-review-home-lab` demonstrates an isolated `operating-systems` skill using the copied Public-Access-Agents OS package. It covers Windows Server and client, Enterprise Linux families, Ubuntu, Debian, SUSE, Oracle Linux, macOS, and FreeBSD without production access, secrets, external writes, or an OpenAI API key.

The upstream package is preserved beneath `.agents/skills/operating-systems/`. See [SOURCE.md](SOURCE.md) for immutable provenance, declared demo adaptations, and Apache-2.0 notices.

## Deterministic Validation

```powershell
pwsh -NoProfile -File examples/operating-systems-home-lab/tools/Test-Demo.ps1
```

The command validates package structure, prompt routing and safe refusal contracts, copied-package inventory, PowerShell parsing, Pester tests, and the example governance contract. It makes no model call and uses no secret.

## Interactive Demonstration

Open `examples/operating-systems-home-lab` in an authenticated interactive Codex or ChatGPT session, then submit:

```text
$operating-systems Review the synthetic Windows Server adoption example for safe patching, access preservation, rollback, and missing evidence. Do not connect to anything or modify files.
```

Interactive output is demonstration material, not production behavior certification.

## Safety Boundary

All hosts, inventories, configurations, identities, and scenarios must remain synthetic. Execution phases in the copied standards are design guidance only. No `OPENAI_API_KEY` is used or required.
