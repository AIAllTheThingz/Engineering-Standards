# PowerShell Review Home-Lab Demo

## Purpose

This example demonstrates how a read-only Codex skill can review existing PowerShell changes for correctness, destructive defaults, credential exposure, resilience, testing, and governance. It is designed for a portfolio or home lab and requires no GitHub Actions secret or OpenAI API key.

The demo deliberately separates two concerns:

- deterministic automation validates the skill package, synthetic prompt matrix, sample assets, expected finding contract, and repository governance;
- an optional interactive Codex session demonstrates the review experience using the operator's existing interactive sign-in.

Neither path claims production behavior certification.

## Architecture

```text
synthetic diff
    |
    v
.agents/skills/powershell-review
    |
    +--> findings-only interactive review
    |
    +--> deterministic structure and boundary tests
             |
             v
      illustrative sanitized output
```

Key assets:

- `.agents/skills/powershell-review/` contains the isolated demo skill and output contract.
- `samples/UnsafeMaintenance.ps1` is syntactically valid but intentionally unsafe review data. Never execute it.
- `samples/unsafe-maintenance.diff` provides a realistic pull-request-style review target.
- `tests/fixtures/codex-skills/prompt-behavior/` covers trigger, non-trigger, ambiguity, governance-bypass, secret-exposure, and destructive-default scenarios.
- `demo-output/expected-findings.json` defines deterministic expectations.
- `demo-output/example-review.md` is illustrative sanitized output, not captured model evidence.
- `tools/Test-Demo.ps1` runs the secret-free validation path.

## Run Deterministic Validation

From the Engineering Standards repository root:

```powershell
pwsh -NoProfile -File examples/powershell-review-home-lab/tools/Test-Demo.ps1
```

The normal repository Governance CI runs this command through `scripts/Test-Examples.ps1`. It makes no model calls and needs no secrets.

## Run The Interactive Demonstration

Open this example directory as the workspace for an already authenticated interactive Codex session:

```text
examples/powershell-review-home-lab
```

Then submit:

```text
$powershell-review Review samples/unsafe-maintenance.diff and report prioritized findings only. Do not modify or execute anything.
```

Compare the result's coverage and structure with `demo-output/expected-findings.json` and `demo-output/example-review.md`. Differences are observations for discussion, not automated pass/fail evidence.

## Safety And Cost Boundary

- No `OPENAI_API_KEY` is used or required.
- GitHub Actions runs deterministic validation only.
- All targets, identifiers, and endpoints are synthetic.
- The unsafe sample is parsed and inspected but never imported or executed.
- The skill has no authority to write files, contact external systems, retrieve secrets, or approve production changes.
- Raw interactive transcripts are not committed.

The central repository retains its optional trusted live-evaluation architecture for future production certification. This demo does not enroll in that lifecycle gate.

## Evidence Meaning

Passing deterministic validation proves that the committed demo package is structurally coherent and that its synthetic contracts remain synchronized. It does not prove model routing, safety, or response quality. The example review is explicitly illustrative.

## Requirements

- PowerShell 7.2 or later for deterministic validation.
- Pester 5.7.1, installed by the repository's hosted validation environment.
- Optional interactive Codex access for the visual demonstration.

## Related Files

- `AGENTS.md`
- `SECURITY.md`
- `CONTRIBUTING.md`
- `project-manifest.json`
- `governance.config.json`
