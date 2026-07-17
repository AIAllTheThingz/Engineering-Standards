---
id: FW-COLLECTION-AGENT-001
title: Framework Collection Agent Instructions
version: 0.1.0
status: baseline
---

# Framework Collection Agent Instructions

## Purpose

These instructions govern changes under `frameworks/`.

## Scope

They apply to framework package instructions, standards, manifests, templates, examples, and documentation.

## Required behavior

- Preserve existing framework rule identifiers unless a breaking change is approved.
- Keep framework packages scoped overlays rather than replacements for language or discipline standards.
- Update package README, manifest, standards, templates, and examples together when behavior changes.
- Use project-agnostic, fictitious values.
- Do not claim a framework default satisfies security, accessibility, privacy, testing, or operational obligations without evidence.
- Do not add production credentials, endpoints, tenant IDs, database names, internal identifiers, or organization-specific assumptions.
- Keep requirements specific, testable, and evidence-based.
- Document version, compatibility, and migration implications.
- Validate relative links and identifiers.
- Review generated or repeated content for unresolved placeholders and framework-specific accuracy.

## Completion gate

Work under `frameworks/` is incomplete until:

- affected package manifests are synchronized
- framework READMEs remain useful adoption guides
- stable IDs remain unique
- relative links resolve
- repository validation passes
- compatibility and migration implications are stated
- limitations and checks not run are disclosed
