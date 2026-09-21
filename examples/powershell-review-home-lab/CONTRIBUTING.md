# Contributing

Keep this example deterministic, synthetic, read-only, and secret-free.

Before proposing changes:

1. Do not execute `samples/UnsafeMaintenance.ps1`; it intentionally demonstrates unsafe patterns.
2. Use only `example.invalid`, placeholder identifiers, and synthetic data.
3. Keep the demo skill findings-only and preserve its no-write boundary.
4. Update fixtures, expected findings, illustrative output, and documentation together.
5. Run:

```powershell
pwsh -NoProfile -File examples/powershell-review-home-lab/tools/Test-Demo.ps1
```

Report unavailable checks as `NotRun`. Never substitute an illustrative transcript for controlled model evidence.

## Preparing a change

Read this example's README and agent instructions before editing. Keep fixtures,
expected outcomes, and documentation synchronized with the behavior being
changed. Preserve the restrictions stated above and use synthetic inputs for
reproductions. If validation needs an unavailable dependency, report that
limitation instead of replacing the check with an unconditional success.

## Review evidence

In the pull request, identify the affected example, explain the behavior change,
and list the exact commands run from their working directories. Include exit
codes and meaningful results, including negative cases where applicable.
Separate illustrative output from current validation evidence. Review the diff
for accidental generated files and sensitive data before submission. Follow the
parent [contribution process](../../CONTRIBUTING.md) for risk classification,
required review, and acceptance.
