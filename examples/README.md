# Examples Catalog

This directory contains governed functional examples and isolated home-lab
skill demonstrations. Each example has its own manifest, governance
configuration, instructions, documentation, validation workflow, and focused
test entry point.

## Functional Examples

| Example | Purpose |
| --- | --- |
| [`powershell-project`](powershell-project/README.md) | PowerShell module, scripts, Pester tests, and evidence. |
| [`python-project`](python-project/README.md) | Hash-locked Python tests, strict typing, audit, build, archive inspection, SBOM, and evidence. |
| [`bash-project`](bash-project/README.md) | GNU Bash 5.2 syntax, ShellCheck, shfmt, Bats boundary tests, hash-locked tools, SBOM, and evidence. |
| [`dotnet-project`](dotnet-project/README.md) | Runtime-dependent .NET governance example. |
| [`database-project`](database-project/README.md) | Non-mutating migration validation. |
| [`web-project`](web-project/README.md) | Runtime-dependent web governance example. |
| [`worker-service-project`](worker-service-project/README.md) | Functional worker-service implementation. |
| [`integration-project`](integration-project/README.md) | Synthetic signature, replay, duplicate-delivery, partial-success, and redaction checks. |
| [`infrastructure-project`](infrastructure-project/README.md) | Synthetic non-mutating infrastructure plan validation. |
| [`combined-script-runner-project`](combined-script-runner-project/README.md) | Governed script catalog, queue, idempotency, leasing, and atomic reporting. |

Run the validation command documented in the selected example's README from
the Engineering Standards repository root.

## Home-Lab Skill Demonstrations

These demonstrations are portfolio examples, not production-certified Active
skills. They use committed synthetic inputs, deterministic validation, and
read-only or design-only boundaries. They require no `OPENAI_API_KEY`, retrieve
no credentials, access no production system, and perform no external writes.

| Home lab | Demonstrated capability |
| --- | --- |
| [`powershell-review-home-lab`](powershell-review-home-lab/README.md) | Findings-only PowerShell review and safe refusal. |
| [`python-review-home-lab`](python-review-home-lab/README.md) | Findings-only Python review with inert unsafe source. |
| [`bash-review-home-lab`](bash-review-home-lab/README.md) | Findings-only Bash review without sourcing or execution. |
| [`terraform-review-home-lab`](terraform-review-home-lab/README.md) | Findings-only Terraform review without providers, backends, plans, or applies. |
| [`build-pester-tests-home-lab`](build-pester-tests-home-lab/README.md) | Requirement-driven Pester test design. |
| [`safe-automation-home-lab`](safe-automation-home-lab/README.md) | Guarded, reversible automation planning. |
| [`governance-validation-home-lab`](governance-validation-home-lab/README.md) | Trusted validation of candidate data. |
| [`completion-evidence-home-lab`](completion-evidence-home-lab/README.md) | Honest completion-evidence assembly and contradiction handling. |
| [`vendor-documentation-analysis-home-lab`](vendor-documentation-analysis-home-lab/README.md) | Source provenance, conflicts, citations, and prompt-injection resistance. |
| [`infrastructure-automation-design-home-lab`](infrastructure-automation-design-home-lab/README.md) | Secure infrastructure automation architecture. |
| [`networking-home-lab`](networking-home-lab/README.md) | Networking platform selection and safe guidance. |
| [`operating-systems-home-lab`](operating-systems-home-lab/README.md) | Operating-system guidance across supported families. |
| [`platforms-home-lab`](platforms-home-lab/README.md) | Cloud, container, and platform guidance. |
| [`virtualization-home-lab`](virtualization-home-lab/README.md) | Virtualization platform selection and safety guidance. |
| [`frameworks-home-lab`](frameworks-home-lab/README.md) | Application-framework selection and guidance. |

Run any home lab from the repository root:

```powershell
pwsh -NoProfile -File examples/<home-lab>/tools/Test-Demo.ps1
```

For an interactive demonstration, open only the selected home-lab directory as
the workspace and use an existing authenticated Codex or ChatGPT session. Any
interactive output is demonstration output, not controlled production
behavior evidence. Live model behavior, hosted execution not actually run, and
production promotion remain explicitly `NotRun`.
