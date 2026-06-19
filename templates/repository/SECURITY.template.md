# Security

## Supported Versions

List supported release branches, versions, or deployment tracks. State how long security fixes are provided.

| Version or branch | Supported | Notes |
| --- | --- | --- |
| `<version>` | Yes | `<support-policy>` |

## Reporting Process

Report security issues through the approved private intake: `<security-contact>`.

Do not open public issues that contain credentials, exploit details, customer data, private endpoints, or vulnerability proof that could be abused.

## Response Expectations

The security owner will acknowledge reports, triage severity, assign an owner, define remediation, and document evidence. Critical issues require immediate escalation through `<escalation-path>`.

## Sensitive Data Rules

Do not include credentials, tokens, customer data, production endpoints, private keys, session identifiers, or regulated data in issues, pull requests, prompts, logs, examples, screenshots, artifacts, or evidence.

Use sanitized reproduction steps and generated test data.

## Secrets

Secrets MUST come from the approved secrets provider: `<secrets-provider>`. Local `.env` files, shell history, CI logs, generated evidence, and screenshots must not contain secret values.

If a secret is exposed, rotate it and follow the incident process before continuing normal work.

## Dependency Concerns

Report compromised dependencies, suspicious package behavior, vulnerable transitive dependencies, or workflow action concerns through the same private security intake.

Dependency updates must include validation evidence and rollback notes.

## Governance

Security work MUST follow the organization contract, AI-generated code policy, exception process, completion evidence policy, and applicable agent standards.

Exceptions require an approved `GOV-*` record and compensating controls.
