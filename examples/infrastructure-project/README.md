# Infrastructure Example

This example demonstrates a governed non-mutating infrastructure plan flow. It validates a synthetic plan document, checks environment targeting and destructive-change expectations, and writes plan evidence without performing any cloud mutation.

Run validation from the repository root:

```powershell
pwsh -NoProfile -File examples/infrastructure-project/tools/Test-Example.ps1 -Path examples/infrastructure-project
```
