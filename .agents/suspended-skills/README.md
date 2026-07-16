# Suspended Codex Skills Catalog

This directory contains repository-scoped Codex skills maintained by `AIAllTheThingz/Engineering-Standards`.

Skills package repeatable engineering workflows. They do not replace governance, `AGENTS.md`, technology standards, validation, review, or evidence requirements. A skill must resolve and obey all applicable instructions before performing work.

## Current Skills

| Skill | Purpose | Status | Behavior gate |
| --- | --- | --- | --- |
| [`enterprise-powershell`](enterprise-powershell/SKILL.md) | Create or substantially modify governed enterprise PowerShell automation and its supporting project files. | Suspended | Current controlled evaluation is `Blocked`; implicit and explicit invocation remain suspended until a passing unchanged-input live run and attributable human approval. |

## Planned Skills

The following skills are planned but are not represented by placeholder directories or incomplete `SKILL.md` files:

1. [`build-pester-tests` (#44)](https://github.com/AIAllTheThingz/Engineering-Standards/issues/44)
2. [`safe-automation` (#45)](https://github.com/AIAllTheThingz/Engineering-Standards/issues/45)
3. [`governance-validation` (#46)](https://github.com/AIAllTheThingz/Engineering-Standards/issues/46)
4. [`completion-evidence` (#47)](https://github.com/AIAllTheThingz/Engineering-Standards/issues/47)
5. [`vendor-documentation-analysis` (#48)](https://github.com/AIAllTheThingz/Engineering-Standards/issues/48)
6. [`infrastructure-automation-design` (#49)](https://github.com/AIAllTheThingz/Engineering-Standards/issues/49)

A planned skill becomes active only after its instructions, references,
deterministic validation, passing controlled behavior evaluation, attributable
human adjudication, documentation, and review are complete.

## Authority

Skills are subordinate to the repository instruction hierarchy defined by:

1. [`../../AGENTS.md`](../../AGENTS.md)
2. [`../../agents/AGENTS_Base.md`](../../agents/AGENTS_Base.md)
3. Applicable technology-specific standards in [`../../agents/`](../../agents/)
4. Governance documents in [`../../governance/`](../../governance/)
5. More-specific downstream repository and directory instructions
6. Task-specific instructions that do not weaken mandatory controls

A skill may make an approved workflow easier to invoke. It may not bypass risk classification, dry-run requirements, security controls, testing, evidence, review, or exception handling.

## Invocation

Codex can invoke skills explicitly or implicitly.

Explicit invocation example:

```text
$enterprise-powershell Create a certificate-expiration reporting solution.
```

Implicit invocation may occur when a task matches the skill description. Descriptions therefore must state both when a skill should trigger and when it should not.

## Repository Scope And Distribution

Codex discovers repository skills under `.agents/skills`. These skills are available when Codex is launched inside this repository or a descendant directory.

For use in downstream repositories, install the approved skill through the supported Codex skill installation mechanism or package the approved collection as a Codex plugin. Downstream adoption must preserve immutable versioning or another controlled update mechanism so skill behavior does not drift silently.

See [`../../docs/CODEX_SKILLS.md`](../../docs/CODEX_SKILLS.md) for lifecycle, adoption, validation, and distribution guidance.

## Authoring Requirements

Every skill must:

- Contain a valid `SKILL.md` with `name` and `description` frontmatter.
- Have one focused job and explicit trigger boundaries.
- Use imperative, testable instructions.
- Prefer instructions over scripts unless deterministic execution is required.
- Identify required inputs and outputs.
- Resolve applicable `AGENTS.md` and governance before acting.
- Preserve safe defaults and prohibit false completion claims.
- Include references only when they reduce duplication or keep the main workflow concise.
- Avoid secrets, production identifiers, credential-shaped examples, and untrusted executable content.
- Be reviewed and validated before being marked Active.

## Change Control

Skill changes can alter how Codex performs engineering work and therefore require focused review. Reviewers must evaluate:

- Trigger accuracy and accidental over-triggering.
- Conflicts with governance or technology standards.
- Unsafe defaults or missing approval gates.
- Scope expansion.
- Validation and evidence requirements.
- Distribution and versioning impact.
- Backward compatibility for existing users of the skill.

Incomplete, experimental, or deprecated skills must not be described as production-ready.
