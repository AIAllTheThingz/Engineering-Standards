# Threat Model

## System Overview

Describe the system, users, business purpose, and production impact.

## Trust Boundaries

List boundaries between users, services, networks, cloud accounts, data stores, CI systems, and third parties.

## Assets

Identify code, credentials, data, infrastructure, audit logs, release artifacts, and operational capabilities that require protection.

## Actors

List trusted users, administrators, services, automation accounts, external users, and likely adversaries.

## Entry Points

List APIs, UI surfaces, webhooks, queues, scheduled jobs, CI workflows, prompts, admin tools, and deployment paths.

## Data Flows

Describe where data enters, transforms, persists, logs, and leaves the system. Include classification for sensitive flows.

## Dependencies

List packages, actions, services, APIs, databases, cloud resources, and trust assumptions.

## Threats

Use STRIDE where helpful: spoofing, tampering, repudiation, information disclosure, denial of service, and elevation of privilege.

## Mitigations

Map each material threat to controls, validation, monitoring, and owner.

## Residual Risk

Document accepted risk, rejected mitigations, compensating controls, and required exceptions.

## Security Assumptions

State assumptions that must remain true for the threat model to hold.

## Abuse Cases

List realistic misuse scenarios, including prompt injection, credential misuse, malicious dependencies, and destructive operations where applicable.

## Review History

Record reviewer, date, scope, evidence, and next review trigger.
