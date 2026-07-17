---
id: REACT-STD-004
title: Security Standard
version: 0.1.0
status: baseline
---

# Security Standard

## Purpose

Treat browser state as untrusted, avoid unsafe HTML injection, do not expose secrets, and enforce authorization on the server.

## Requirements

- Treat browser state as untrusted, avoid unsafe HTML injection, do not expose secrets, and enforce authorization on the server.
- Inspect existing framework conventions and supported-version constraints before changing behavior.
- Define project-specific configuration, ownership, failure behavior, and evidence rather than relying on undocumented defaults.
- Keep security, compatibility, cancellation, cleanup, and operational impact explicit.
- Add or update tests and documentation proportional to risk.
- Do not introduce production-specific values, secrets, or unsupported claims.

## Required evidence

- affected components and framework boundaries
- relevant configuration or contract changes
- exact tests, build checks, or reviews performed
- compatibility and migration impact
- checks not run and the reason
- remaining limitations and owners

## Review questions

- Does the change use framework-supported extension points?
- Are defaults and overrides understood?
- Are trust boundaries and failure paths covered?
- Are cleanup, cancellation, and lifecycle effects explicit?
- Is the validation proportionate to risk?
- Are claims limited to what the evidence demonstrates?

## Completion gate

This standard is incomplete until its applicable requirements are implemented, tested or reviewed in a stated environment, and supported by recorded evidence.
