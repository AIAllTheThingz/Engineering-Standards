# Infrastructure Example

This example demonstrates a governed non-mutating infrastructure plan flow. It validates a synthetic plan document, checks environment targeting and destructive-change expectations, and writes plan evidence without performing any cloud mutation.

Run validation from the repository root:

```powershell
pwsh -NoProfile -File examples/infrastructure-project/tools/Test-Example.ps1 -Path examples/infrastructure-project
```

## Documentation check

From the Engineering-Standards repository root, validate this example's required
documents with:

```powershell
pwsh -NoProfile -File scripts/Test-DocumentationCompleteness.ps1 -Path examples/infrastructure-project
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
