# Combined Script Runner Example

This example is a safe executable vertical slice of a governed script-runner system. It validates the approved script catalog and immutable input contract, creates a synthetic job through a PowerShell command surface, claims it through a worker-style lease, completes it idempotently, and publishes a final report atomically. It does not execute arbitrary commands or contact external systems.

Run validation from the repository root:

```powershell
pwsh -NoProfile -File examples/combined-script-runner-project/tools/Test-Example.ps1 -Path examples/combined-script-runner-project
```
