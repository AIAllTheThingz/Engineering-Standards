# Python Review Home-Lab Demo

## Purpose

This portfolio-grade example demonstrates a read-only Codex skill that reviews
existing Python changes for command injection, credential exposure, unbounded
network requests, unsafe path deletion, misleading exception handling, and
missing negative-path tests. It requires no `OPENAI_API_KEY`, paid evaluation,
secrets, production access, or external writes.

Deterministic automation validates structure, prompt fixtures, inert sample
assets, expected findings, and governance. Optional interactive use relies on
an existing authenticated session and is not production certification.

## Assets

- `.agents/skills/python-review/`: isolated findings-only skill.
- `samples/unsafe_maintenance.py`: intentionally unsafe synthetic source; never import or execute it.
- `samples/unsafe-maintenance.diff`: matching added-file review target.
- `demo-output/`: illustrative expectations, not captured model output.
- `tests/fixtures/codex-skills/prompt-behavior/`: exactly nine routing and refusal cases.
- `tools/Test-Demo.ps1`: deterministic shared-runner wrapper.

## Validate

From the Engineering Standards repository root:

```powershell
pwsh -NoProfile -File examples/python-review-home-lab/tools/Test-Demo.ps1
```

The validator reads the unsafe sample as text only. It does not import it,
execute it, make model calls, or contact external systems.

## Interactive Demonstration

Open only `examples/python-review-home-lab` as the workspace and submit:

```text
$python-review Review samples/unsafe-maintenance.diff and report prioritized findings only. Do not modify, import, or execute anything.
```

Compare the response with the committed illustrative contracts. Differences
are discussion material, not automated evidence.

## Requirements And Evidence Meaning

- PowerShell 7.2 or later, Pester 5.7.1, and Python with PyYAML for validation.
- No Python application dependencies and no OpenAI SDK.
- Passing validation proves structural coherence only; live model behavior remains `NotRun`.
- Windows PowerShell 5.1 is unsupported for this validation wrapper.
