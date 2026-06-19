# Security Policy

| Field | Value |
| --- | --- |
| Status | Active |
| Version | 1.0.0 |
| Owner role | Security Maintainers |
| Last reviewed | 2026-06-19 |
| Changelog | See [CHANGELOG.md](CHANGELOG.md) unless this file is at repository root. |

## Normative Terminology

`MUST` and `MUST NOT` define mandatory requirements. `SHOULD` and `SHOULD NOT` define expected practices that require a documented reason when not followed. `MAY` defines optional behavior. Every mandatory statement is intended to be testable by automation, review, or recorded evidence.

## Purpose

This document explains how to report vulnerabilities in the standards repository, validation actions, workflows, schemas, examples, and documentation.

## Supported Versions

The current major version and one previous major version receive security fixes. Unsupported versions SHOULD be upgraded unless an approved exception exists.

## Reporting Process

Report vulnerabilities through the organization's private security intake. Do not open public issues for exploitable validation bypasses, secret exposure, workflow injection, compromised dependencies, or false negatives that would allow unsafe code to pass validation.

## Sensitive Data Rules

Reports MUST NOT include live secrets, customer data, production endpoints, private keys, or exploit payloads beyond what is necessary to reproduce the problem safely.

## Incident Handling

Maintainers triage reports, assess downstream exposure, rotate compromised references, publish advisories when needed, and update completion evidence for emergency fixes.

## Dependency And Workflow Concerns

Report compromised pinned actions, unsafe workflow permissions, action-output injection, artifact poisoning, or cache poisoning concerns. False positives that encourage unsafe bypasses are also security-relevant.

## Related Documents

- `docs/ACTION_SECURITY.md`
- `governance/EXCEPTION_PROCESS.md`
- `docs/RELEASE_PROCESS.md`


## Operating Controls

Contributors MUST treat this file as an enforceable governance document rather than advisory prose. Validation includes documentation completeness checks, schema checks, Markdown link checks, repository health checks, and relevant example project tests. Evidence MUST identify the command, environment, result, and reason for any skipped or blocked validation. Exceptions MUST reference `governance/EXCEPTION_PROCESS.md`, include a `GOV-*` identifier, name a compensating control, and define an expiry date. Related documents include `governance/ORGANIZATION_CONTRACT.md`, `governance/COMPLETION_EVIDENCE.md`, and `docs/MAINTAINER_GUIDE.md`.
