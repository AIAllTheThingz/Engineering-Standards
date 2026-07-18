# Python Review Output

Use this findings-only structure for every result. Keep evidence sanitized and
never reproduce authentication material or production identifiers.

```markdown
## Review status
<Passed | Failed | Blocked | NotRun | NotApplicable>

## Scope
- Comparison: <base and head, diff, or named paths>
- Reviewed: <paths>
- Authority: <applicable instructions and standards>
- Risk: <classification and rationale>

## Blocking findings
### PYR-001 — <title>
- Severity: <Critical | High | Moderate | Low>
- Confidence: <High | Medium | Low>
- Evidence: `<path:line>` — <sanitized observation>
- Impact: <concrete consequence>
- Required correction: <smallest defensible change>

## Recommendations
## Assumptions
## Checks run
## Checks not run
## Residual risks
```

Do not include a patch. Distinguish absent evidence from a proven defect, and
do not describe illustrative or deterministic output as live model evidence.
