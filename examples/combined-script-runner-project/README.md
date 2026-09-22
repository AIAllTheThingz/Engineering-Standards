# Combined Script Runner Example

This example is a safe executable vertical slice of a governed script-runner system. It validates the approved script catalog and immutable input contract, creates a synthetic job through a PowerShell command surface, claims it through a worker-style lease, completes it idempotently, and publishes a final report atomically. It does not execute arbitrary commands or contact external systems.

Run validation from the repository root:

```powershell
pwsh -NoProfile -File examples/combined-script-runner-project/tools/Test-Example.ps1 -Path examples/combined-script-runner-project
```

## Documentation check

From the Engineering-Standards repository root, validate this example's required
documents with:

```powershell
pwsh -NoProfile -File scripts/Test-DocumentationCompleteness.ps1 -Path examples/combined-script-runner-project
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
