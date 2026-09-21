# Contributing

Keep this example synthetic, deterministic, review-only, and secret-free.
Never pass `samples/main.tf` to Terraform, OpenTofu, a provider helper, plan,
or apply. Update fixtures and illustrative contracts together, then run:

```powershell
pwsh -NoProfile -File examples/terraform-review-home-lab/tools/Test-Demo.ps1
```

Terraform is not a dependency. Report unavailable live checks as `NotRun`.

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
