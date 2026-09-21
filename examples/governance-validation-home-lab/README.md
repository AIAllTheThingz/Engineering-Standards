# Governance Validation Lab

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

## Documentation check

From the Engineering-Standards repository root, validate this example's required
documents with:

```powershell
pwsh -NoProfile -File scripts/Test-DocumentationCompleteness.ps1 -Path examples/governance-validation-home-lab
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
