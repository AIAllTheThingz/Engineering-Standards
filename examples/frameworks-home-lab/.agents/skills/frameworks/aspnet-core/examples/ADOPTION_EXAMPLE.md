---
id: ASPNET-EX-001
title: ASP.NET Core Adoption Example
version: 0.1.0
status: baseline
---

# ASP.NET Core Adoption Example

## Fictitious project

This example models a non-production project using ASP.NET Core with the [.NET language package](https://github.com/AIAllTheThingz/Public-Access-Agents/tree/af649326961de32adcd2c5644c4305fa893d4ade/languages/dotnet).

No production endpoints, credentials, identities, data stores, or infrastructure values are included.

## Selected packages

- Governance baseline
- [.NET](https://github.com/AIAllTheThingz/Public-Access-Agents/tree/af649326961de32adcd2c5644c4305fa893d4ade/languages/dotnet)
- [ASP.NET Core](../README.md)
- [Application Security](https://github.com/AIAllTheThingz/Public-Access-Agents/tree/af649326961de32adcd2c5644c4305fa893d4ade/disciplines/application-security)
- [API Engineering](https://github.com/AIAllTheThingz/Public-Access-Agents/tree/af649326961de32adcd2c5644c4305fa893d4ade/disciplines/api-engineering)
- [Testing and Quality Engineering](https://github.com/AIAllTheThingz/Public-Access-Agents/tree/af649326961de32adcd2c5644c4305fa893d4ade/disciplines/testing)
- [Observability](https://github.com/AIAllTheThingz/Public-Access-Agents/tree/af649326961de32adcd2c5644c4305fa893d4ade/disciplines/observability)

## Project-specific tailoring

The adopting project would declare:

- exact supported framework and language versions
- selected architectural patterns
- configuration and secret sources
- authentication and authorization model
- lifecycle, async, cleanup, and shutdown behavior
- data and external dependency boundaries
- test commands and representative environments
- deployment and operational ownership
- compatibility and migration commitments
- evidence and review requirements

## Example root instruction excerpt

> Use the ASP.NET Core package as a framework overlay. Preserve parent governance, language, discipline, platform, virtualization, operating-system, and networking requirements. Do not invent environment values. Validate configuration and trust-boundary input. Add tests and documentation with behavior changes. Record exact evidence and limitations.

## Validation

Use the adopting repository's actual commands. Never copy illustrative commands or outcomes as proof.

## Non-production warning

This example demonstrates composition only. It does not configure, test, approve, certify, or deploy an ASP.NET Core application.
