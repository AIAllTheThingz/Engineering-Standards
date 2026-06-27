# Integration Example

This example demonstrates a synthetic governed integration flow. It validates the contract shape, then executes a local webhook-style simulation that proves signature verification, replay protection, duplicate-delivery handling, partial success, bounded retry policy metadata, and redacted logging without calling a real provider.

Run validation from the repository root:

```powershell
pwsh -NoProfile -File examples/integration-project/tools/Test-Example.ps1 -Path examples/integration-project
```
