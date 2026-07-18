# Contributing

Keep this example synthetic, deterministic, review-only, and secret-free.
Never pass `samples/main.tf` to Terraform, OpenTofu, a provider helper, plan,
or apply. Update fixtures and illustrative contracts together, then run:

```powershell
pwsh -NoProfile -File examples/terraform-review-home-lab/tools/Test-Demo.ps1
```

Terraform is not a dependency. Report unavailable live checks as `NotRun`.
