# Completion Evidence Home Lab

This lab turns synthetic validation results into an honest local completion
record. It checks SHA equality, canonical status aggregation, exact command
outcomes, and the absence of fabricated GitHub metadata.

```powershell
pwsh -NoProfile -File examples/completion-evidence-home-lab/tools/Test-Demo.ps1
```

Requires PowerShell 7.2+, Pester 5.7.1+, Python 3, and PyYAML. The illustrative
record is not authoritative evidence; hosted execution and artifact verification
remain `NotRun`.
