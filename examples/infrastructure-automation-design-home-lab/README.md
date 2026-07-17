# Infrastructure Automation Design Home Lab

This lab maps fictional multi-environment automation requirements to a secure
design: isolated candidate validation, trusted apply, short-lived identity,
immutable dependencies, remote locked state, staged rollout, observability, and
recovery.

```powershell
pwsh -NoProfile -File examples/infrastructure-automation-design-home-lab/tools/Test-Demo.ps1
```

Requires PowerShell 7.2+, Pester 5.7.1+, Python 3, and PyYAML. No cloud account,
secret, live state, plan, or apply is used. Deployment remains `NotRun`.
