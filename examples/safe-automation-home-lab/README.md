# Safe Automation Home Lab

This lab demonstrates a plan-only `safe-automation` skill. A synthetic patch
request is converted into a bounded five-phase plan with approval, dry-run,
idempotency, verification, rollback, and sanitized event requirements.

Run:

```powershell
pwsh -NoProfile -File examples/safe-automation-home-lab/tools/Test-Demo.ps1
```

The command uses PowerShell 7.2+, Pester 5.7.1+, Python 3, and PyYAML. It does
not execute the maintenance action, call a model, use secrets, or write outside
the example. Deterministic success does not prove production execution.
