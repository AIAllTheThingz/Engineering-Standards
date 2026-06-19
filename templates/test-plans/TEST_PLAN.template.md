# Test Plan

## Scope

Describe the change under test, affected systems, environments, and risk classification.

## Requirements

List functional, security, reliability, compliance, and governance requirements being validated.

## Preconditions

List required tools, permissions, configuration, seeded data, feature flags, and service dependencies.

## Environment

Identify local, CI, staging, or production-like environments. Do not include live secrets.

## Test Data

Use sanitized or generated test data. Production data requires explicit approval, data minimization, and evidence of handling controls.

## Positive Cases

List expected-success cases and expected outcomes.

## Negative Cases

List validation failures, malformed inputs, denied access, dependency failures, and boundary cases.

## Security Cases

Include authorization, secrets, logging redaction, dependency, injection, prompt-injection, and destructive-operation cases when applicable.

## Failure Recovery

Describe retries, rollback, compensation, alerting, and cleanup validation.

## Rollback Validation

Describe how rollback is tested and what evidence proves it worked.

## Evidence Collection

List commands, artifacts, logs, screenshots, hashes, and manual reviewer notes to collect.

## Exit Criteria

Define required Passed results, acceptable warnings, approved exceptions, and conditions that block release.
