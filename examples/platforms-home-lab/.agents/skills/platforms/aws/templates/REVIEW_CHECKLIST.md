---
id: AWS-TPL-REVIEW-001
title: Amazon Web Services Platform Review Checklist
version: 0.2.0
status: baseline
---
# Amazon Web Services Platform Review Checklist

## Scope and authority

- [ ] Target identity and environment are unambiguous.
- [ ] Actor identity and authorization are recorded.
- [ ] Risk classification matches blast radius and reversibility.
- [ ] The change is limited to approved scope.

## Technical review

- [ ] Current state and drift were inspected.
- [ ] Identity and policy changes are least privilege.
- [ ] Public and private network effects are understood.
- [ ] Data, secrets, keys, certificates, and state are protected.
- [ ] Replacements and destructive actions are explicit.
- [ ] Logging, monitoring, alerts, and operations are addressed.
- [ ] Recovery behavior is defined.
- [ ] Cost, capacity, and quota impact is reviewed.

## Evidence

- [ ] Plan, manifest, image, or configuration is traceable.
- [ ] Validation commands and outcomes are recorded.
- [ ] Actual state was verified.
- [ ] Allowed and denied paths were tested where applicable.
- [ ] Checks not run are visible.
- [ ] Limitations and residual risks have owners.
- [ ] Approval applies to the reviewed artifact and scope.

## Decision

- [ ] Approve
- [ ] Request changes
- [ ] Reject
- [ ] Escalate
