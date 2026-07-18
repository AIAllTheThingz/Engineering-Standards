# Bash Review Home-Lab Demo

## Purpose

This portfolio-grade, read-only review skill demonstrates findings for
unquoted expansion, destructive empty/root targets, missing strict/error
behavior, authentication-material output, unbounded network calls, and ignored
command failures. It needs no `OPENAI_API_KEY`, paid evaluation, secrets,
production access, external writes, or Bash execution.

## Assets And Safety

- `.agents/skills/bash-review/`: isolated findings-only skill.
- `samples/unsafe-maintenance.sh`: intentionally unsafe synthetic text; never source or execute it.
- `samples/unsafe-maintenance.diff`: matching added-file review target.
- `demo-output/`: illustrative contracts, not captured model output.
- `tests/fixtures/codex-skills/prompt-behavior/`: exactly nine cases.
- `tools/Test-Demo.ps1`: deterministic shared runner.

The validator reads shell assets as text. It makes no model calls, network
requests, or external mutations.

## Validate

```powershell
pwsh -NoProfile -File examples/bash-review-home-lab/tools/Test-Demo.ps1
```

## Interactive Demonstration

Open only `examples/bash-review-home-lab` and submit:

```text
$bash-review Review samples/unsafe-maintenance.diff and report prioritized findings only. Do not modify, source, or execute anything.
```

Interactive differences are discussion material, not pass/fail evidence.

## Requirements

- PowerShell 7.2 or later, Pester 5.7.1, and Python with PyYAML.
- No Bash runtime execution, application dependency, OpenAI SDK, or cloud CLI.
- Windows PowerShell 5.1 is unsupported for the validation wrapper.
- Live model behavior remains `NotRun`.
