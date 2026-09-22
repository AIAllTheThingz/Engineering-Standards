# Contributing

Keep this example deterministic, synthetic, read-only, and secret-free.

1. Never import or execute `samples/unsafe_maintenance.py`.
2. Use only `example.invalid`, placeholder identifiers, and synthetic data.
3. Preserve the skill's no-write and findings-only boundary.
4. Update fixtures, findings, illustrative output, and documentation together.
5. Run `pwsh -NoProfile -File examples/python-review-home-lab/tools/Test-Demo.ps1`.

Report unavailable checks as `NotRun`; illustrative output is not model evidence.

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
