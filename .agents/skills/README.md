# Active Codex Skills Catalog

This directory contains discoverable repository-scoped Codex skills maintained by `AIAllTheThingz/Engineering-Standards`. Skills remain subordinate to repository governance, `AGENTS.md`, technology standards, validation, evidence, and human review.

## Current Skills

| Skill | Purpose | Status | Authoritative issue |
| --- | --- | --- | --- |
| [`powershell-review`](powershell-review/SKILL.md) | Review existing PowerShell changes and report prioritized evidence-backed findings without modifying reviewed files. | Active | [#43](https://github.com/AIAllTheThingz/Engineering-Standards/issues/43) |

## Invocation

Explicit invocation example:

```text
$powershell-review Review this PowerShell pull request and report findings only.
```

Implicit invocation may occur when a request clearly asks for review of existing PowerShell work. Explanation-only questions, isolated one-liners, non-PowerShell reviews, implementation requests, secret exposure, and production execution remain outside the skill's trigger boundary.

## Lifecycle And Distribution

Active skills require deterministic validation, passing controlled behavior evaluation, attributable human approval, documentation, and reviewed change control. Suspended skills remain outside this discoverable root under [`../suspended-skills/`](../suspended-skills/).

For lifecycle, adoption, validation, and distribution guidance, see [`../../docs/CODEX_SKILLS.md`](../../docs/CODEX_SKILLS.md).
