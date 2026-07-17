# Virtualization Home-Lab Demo

## Purpose

This sibling of `powershell-review-home-lab` demonstrates an isolated `virtualization` skill using the copied Public-Access-Agents virtualization package. It covers vSphere/ESXi, XenServer, Proxmox, XCP-ng, KVM/libvirt, Nutanix AHV, Hyper-V, RHV, and Oracle Linux KVM without production access, secrets, external writes, or an OpenAI API key.

The upstream package is preserved beneath `.agents/skills/virtualization/`. See [SOURCE.md](SOURCE.md) for immutable provenance, declared demo adaptations, pinned cross-package references, and Apache-2.0 notices.

## Deterministic Validation

```powershell
pwsh -NoProfile -File examples/virtualization-home-lab/tools/Test-Demo.ps1
```

The command validates package structure, prompt routing and safe refusal contracts, copied-package inventory, PowerShell parsing, Pester tests, and the example governance contract. It makes no model call and uses no secret.

## Interactive Demonstration

Open `examples/virtualization-home-lab` in an authenticated interactive Codex or ChatGPT session, then submit:

```text
$virtualization Review the synthetic vSphere adoption example for target identity, snapshot assumptions, rollback, migration risk, and missing evidence. Do not connect to a manager or modify files.
```

Interactive output is demonstration material, not production behavior certification.

## Safety Boundary

All managers, hosts, guests, clusters, storage, networks, identities, and scenarios must remain synthetic. Execution phases in the copied standards are design guidance only. No `OPENAI_API_KEY` is used or required.
