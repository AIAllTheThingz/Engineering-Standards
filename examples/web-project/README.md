# web-project

## Purpose

This example demonstrates real adoption of the Engineering Standards repository for a `web` project.

## Validation Commands

Run governance validation from the repository root and the project-specific commands below.

## Evidence

Completion evidence is written to `evidence/completion-result.json`.

## Security

The example uses no secrets, no production endpoints, and only local test data.

## Documentation check

From the Engineering-Standards repository root, validate this example's required
documents with:

```powershell
pwsh -NoProfile -File scripts/Test-DocumentationCompleteness.ps1 -Path examples/web-project
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
