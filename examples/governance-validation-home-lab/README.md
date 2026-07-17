# Governance Validation Home Lab

This secret-free lab demonstrates candidate/trusted-code separation for a
`governance-validation` skill. Synthetic candidate records contain both valid
metadata and hostile command fields; the expected report proves those fields
remain inert and required failures cannot aggregate to `Passed`.

```powershell
pwsh -NoProfile -File examples/governance-validation-home-lab/tools/Test-Demo.ps1
```

Requires PowerShell 7.2+, Pester 5.7.1+, Python 3, and PyYAML. The run is local
and deterministic; GitHub Actions, artifacts, and live model routing are
`NotRun`.
