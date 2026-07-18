# Terraform Review Home-Lab Demo

## Purpose

This portfolio-grade, read-only review skill demonstrates findings for public
network exposure, destructive lifecycle behavior, sensitive-value handling,
unpinned providers, unsafe state/backend boundaries, and missing validation or
plan evidence. It needs no Terraform binary, `OPENAI_API_KEY`, paid model
evaluation, provider plugin, cloud CLI, credential, backend, production access,
or external write.

## Assets And Safety

- `.agents/skills/terraform-review/`: isolated findings-only skill.
- `samples/main.tf`: intentionally unsafe synthetic text; never initialize, validate, plan, or apply it.
- `samples/unsafe-main.diff`: matching added-file review target.
- `demo-output/`: illustrative contracts, not captured model output.
- `tests/fixtures/codex-skills/prompt-behavior/`: exactly nine cases.
- `tools/Test-Demo.ps1`: deterministic shared runner.

The validator reads Terraform source as text. It does not install Terraform,
resolve providers, contact a backend, access state, or make cloud calls.

## Validate

```powershell
pwsh -NoProfile -File examples/terraform-review-home-lab/tools/Test-Demo.ps1
```

## Interactive Demonstration

Open only `examples/terraform-review-home-lab` and submit:

```text
$terraform-review Review samples/unsafe-main.diff and report prioritized findings only. Do not modify, initialize, plan, or apply anything.
```

Interactive differences are discussion material, not certified evidence.

## Requirements

- PowerShell 7.2 or later, Pester 5.7.1, and Python with PyYAML.
- Terraform, OpenTofu, providers, backends, cloud credentials, and OpenAI SDKs are not required.
- Windows PowerShell 5.1 is unsupported for the validation wrapper.
- Live model behavior remains `NotRun`.
