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

List bounded remediation recommendations, or state that none were identified.

## Assumptions

List review assumptions, or state that none were required.

## Checks run

List deterministic checks that actually ran with their outcomes.

## Checks not run

List checks that did not run and use the applicable `NotRun` or `Blocked` status.

## Residual risks

List remaining risks without claiming production certification.
```

Do not include a patch. Distinguish absent evidence from a proven defect, and
do not describe illustrative or deterministic output as live model evidence.
