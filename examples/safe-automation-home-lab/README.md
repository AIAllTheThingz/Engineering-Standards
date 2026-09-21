# Safe Automation Lab

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

## Documentation check

From the Engineering-Standards repository root, validate this example's required
documents with:

```powershell
pwsh -NoProfile -File scripts/Test-DocumentationCompleteness.ps1 -Path examples/safe-automation-home-lab
```

This checks the documentation selected by the local governance configuration.
It does not execute the example or replace its functional validation commands.
Read the local security and contribution instructions before adapting inputs
or changing the demonstrated behavior.

## Interpreting results

Keep synthetic demonstrations separate from operational evidence. A passing
local check establishes only the behavior actually exercised with those inputs.
Record missing prerequisites and unavailable checks explicitly; do not infer
hosted execution, deployment readiness, or approval. When reporting a failure,
include the command, working directory, exit code, and a sanitized reproduction
so maintainers can distinguish an example defect from an environment limitation.
