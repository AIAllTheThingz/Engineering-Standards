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
