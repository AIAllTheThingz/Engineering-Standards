# PowerShell Review Output

Use this contract for every `powershell-review` result. Keep evidence sanitized and do not reproduce secret values or production identifiers.

## Required Structure

```markdown
## Review status

<Passed | Failed | Blocked | NotRun | NotApplicable>

## Scope

- Comparison: <base and head, commit range, working tree, or named paths>
- Reviewed: <paths>
- Authority: <applicable AGENTS and standards>
- Risk: <classification and rationale>

## Blocking findings

### PSR-001 — <short defect title>

- Severity: <Critical | High | Moderate | Low>
- Confidence: <High | Medium | Low>
- Evidence: `<path:line>` — <sanitized observation>
- Impact: <concrete failure or governance consequence>
- Required correction: <smallest defensible change>

## Recommendations

- REC-001 — <non-blocking improvement and rationale>

## Assumptions

- <material fact not proven by reviewed evidence>

## Checks run

| Check | Working directory | Result | Exit code | Notes |
| --- | --- | --- | ---: | --- |
| `<exact command or manual inspection>` | `<relative path>` | Passed | 0 | <bounded summary> |

## Checks not run

| Check | Status | Reason |
| --- | --- | --- |
| `<check>` | NotRun | <tool unavailable or outside safe review boundary> |

## Residual risks

- <risk not eliminated by the review>
```

Omit empty finding and recommendation subsections only when the result clearly states `No findings` and `No recommendations`.

## Finding Rules

- Assign one stable ID to one independently actionable problem.
- Cite the narrowest useful path and line. Use a path-only citation when line evidence is unavailable.
- Explain the runtime or operator-visible consequence; do not report bare rule names.
- Separate multiple consequences only when they require different corrections.
- Do not claim exploitability, data loss, production impact, or test failure without supporting evidence.
- Do not include a patch unless the user separately requests remediation through an implementation workflow.

## Sanitized Blocking Example

```markdown
### PSR-001 — Execute mode bypasses PowerShell confirmation

- Severity: High
- Confidence: High
- Evidence: `src/Invoke-SyntheticCleanup.ps1:118` calls the mutating provider command directly after mode selection; the call is outside `$PSCmdlet.ShouldProcess()`.
- Impact: `-WhatIf` cannot prevent the external mutation, so an operator can receive a preview while the target is still changed.
- Required correction: Place the mutating call inside `ShouldProcess`, retain exact-target validation immediately before it, and add a synthetic test proving `-WhatIf` performs zero provider mutations.
```

## Sanitized No-Findings Example

```markdown
## Review status

Passed

## Blocking findings

No findings.

## Recommendations

No recommendations.

## Checks not run

| Check | Status | Reason |
| --- | --- | --- |
| Windows PowerShell 5.1 compatibility | NotRun | The review environment provided PowerShell 7 only. |

## Residual risks

- Live vendor integration behavior was not exercised; the review covered static code and synthetic unit tests only.
```

## Sanitized Blocked Example

```markdown
## Review status

Blocked

## Scope

- Comparison: unavailable
- Reviewed: repository instructions only

## Blocking findings

No code findings were produced because the requested pull-request diff was unavailable.

## Checks not run

| Check | Status | Reason |
| --- | --- | --- |
| PowerShell change review | Blocked | The comparison head could not be resolved from the supplied reference. |

## Residual risks

- The unreviewed change may contain correctness, safety, security, or compatibility defects.
```
