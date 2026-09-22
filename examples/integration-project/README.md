# Integration Example

This example demonstrates a synthetic governed integration flow. It validates the contract shape, then executes a local webhook-style simulation that proves signature verification, replay protection, duplicate-delivery handling, partial success, bounded retry policy metadata, and redacted logging without calling a real provider.

Run validation from the repository root:

```powershell
pwsh -NoProfile -File examples/integration-project/tools/Test-Example.ps1 -Path examples/integration-project
```

## Documentation check

From the Engineering-Standards repository root, validate this example's required
documents with:

```powershell
pwsh -NoProfile -File scripts/Test-DocumentationCompleteness.ps1 -Path examples/integration-project
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
