# Platforms Home-Lab Demo

## Purpose

This sibling of `powershell-review-home-lab` demonstrates an isolated `platforms` skill using the copied Public-Access-Agents platform package. It covers containers, Kubernetes, Terraform/OpenTofu, Azure, AWS, and GCP without production access, secrets, external writes, or an OpenAI API key.

The upstream package is preserved beneath `.agents/skills/platforms/`. See [SOURCE.md](SOURCE.md) for immutable provenance, declared demo adaptations, pinned cross-package references, and Apache-2.0 notices.

## Deterministic Validation

```powershell
pwsh -NoProfile -File examples/platforms-home-lab/tools/Test-Demo.ps1
```

The command validates package structure, prompt routing and safe refusal contracts, copied-package inventory, PowerShell parsing, Pester tests, and the example governance contract. It makes no model call and uses no secret.

## Interactive Demonstration

Open `examples/platforms-home-lab` in an authenticated interactive Codex or ChatGPT session, then submit:

```text
$platforms Review the synthetic Kubernetes adoption example for package composition, identity, network exposure, rollback, and missing evidence. Do not authenticate, deploy, or modify files.
```

Interactive output is demonstration material, not production behavior certification.

## Safety Boundary

All accounts, subscriptions, projects, clusters, state, identities, and scenarios must remain synthetic. Execution phases in the copied standards are design guidance only. No `OPENAI_API_KEY` is used or required.
