# Networking Home-Lab Demo

## Purpose

This sibling of `powershell-review-home-lab` demonstrates an isolated `networking` skill using the copied Public-Access-Agents network-engineering package. It covers HPE Aruba, Cisco, Juniper, and Brocade selection and safety guidance without production access, secrets, external writes, or an OpenAI API key.

The upstream package is preserved beneath `.agents/skills/networking/`. See [SOURCE.md](SOURCE.md) for immutable provenance, declared demo adaptations, and Apache-2.0 notices.

## Deterministic Validation

From the Engineering Standards repository root:

```powershell
pwsh -NoProfile -File examples/networking-home-lab/tools/Test-Demo.ps1
```

The command validates package structure, prompt routing and safe refusal contracts, copied-package inventory, PowerShell parsing, Pester tests, and the example governance contract. It makes no model call and uses no secret.

## Interactive Demonstration

Open `examples/networking-home-lab` as the workspace in an already authenticated interactive Codex or ChatGPT session, then submit:

```text
$networking Review the synthetic Cisco adoption example for package selection, management-plane safety, rollback, and missing evidence. Do not connect to anything or modify files.
```

Interactive output is demonstration material, not production behavior certification.

## Included Packages

- HPE Aruba Networking
- Cisco networking
- Juniper Networks
- Brocade networking

## Safety Boundary

All device names, inventories, configurations, identities, and scenarios must remain synthetic. Execution phases in the copied standards are design guidance only. No `OPENAI_API_KEY` is used or required.
