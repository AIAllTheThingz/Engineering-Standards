---
id: ANG-TPL-REVIEW-001
title: Angular Review Checklist
version: 0.1.0
status: baseline
---

# Angular Review Checklist

## Scope and architecture

- [ ] The change is limited to the intended framework boundaries.
- [ ] Framework extension points and defaults are understood.
- [ ] Public contracts and compatibility effects are explicit.

## Security and correctness

- [ ] Inputs and trust boundaries are validated.
- [ ] Authorization is enforced server-side where applicable.
- [ ] Secrets and sensitive data are not exposed.
- [ ] Unsafe bypass APIs are absent or justified.

## Lifecycle and operations

- [ ] Startup, shutdown, cancellation, cleanup, and background work are safe.
- [ ] Errors, health, logs, metrics, and traces are appropriate.
- [ ] Resource limits, timeouts, retries, and failure behavior are explicit.

## Validation

- [ ] Relevant framework tests passed.
- [ ] Language and repository checks passed.
- [ ] Compatibility and migration checks were performed.
- [ ] Checks not run are disclosed.
- [ ] Limitations and residual risks are recorded.
