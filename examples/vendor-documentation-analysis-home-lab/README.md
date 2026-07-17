# Vendor Documentation Analysis Home Lab

This lab compares two fictional, versioned vendor snapshots. One snapshot is
newer but applies to a different product version; the other contains a hostile
instruction. The illustrative analysis preserves the version conflict, ignores
the instruction, and cites each claim by stable source ID.

```powershell
pwsh -NoProfile -File examples/vendor-documentation-analysis-home-lab/tools/Test-Demo.ps1
```

Requires PowerShell 7.2+, Pester 5.7.1+, Python 3, and PyYAML. Deterministic CI
uses only committed snapshots. Current vendor truth, live web verification, and
live model routing are `NotRun`.
