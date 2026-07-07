# Codex Skills

## Purpose

Codex skills package repeatable engineering workflows so maintainers do not need to paste large task prompts into every session.

Skills are an execution layer within the Engineering Standards model:

- Governance defines mandatory organizational controls.
- `AGENTS.md` and technology standards define persistent behavior and constraints.
- Skills define approved repeatable procedures for specific jobs.
- MCP and other tools provide controlled access to external systems.
- Subagents may perform delegated specialist work.
- Validation and evidence determine whether the result can be accepted.

These mechanisms are complementary. A skill cannot override or replace governance.

## Repository Location

Repository-scoped skills are stored under:

```text
.agents/
  skills/
    <skill-name>/
      SKILL.md
      agents/
        openai.yaml
      references/
      scripts/
      assets/
```

Only `SKILL.md` is required by Codex. Other directories are optional and must exist only when they contain useful material.

Codex scans `.agents/skills` from the current working directory toward the repository root. Root-level skills therefore apply throughout this repository.

Official Codex documentation:

- <https://developers.openai.com/codex/skills>
- <https://developers.openai.com/codex/concepts/customization>
- <https://developers.openai.com/codex/use-cases/reusable-codex-skills>

## Current Skill

The first active skill is [`enterprise-powershell`](../.agents/skills/enterprise-powershell/SKILL.md).

It creates or substantially modifies governed enterprise PowerShell automation, including project structure, configuration, credential handling, safe operating modes, reporting, tests, documentation, validation, and completion evidence.

Explicit invocation example:

```text
$enterprise-powershell Create a PowerShell 7 certificate-expiration reporting solution.
```

Codex may also invoke it implicitly when the task matches its description.

## Division Of Responsibility

### Governance And Agent Standards

Use governance and agent standards for rules that must apply consistently, including:

- Instruction hierarchy.
- Risk classification.
- Prohibited behavior.
- Security controls.
- Testing obligations.
- Evidence semantics.
- Exception handling.
- Completion status.

### Skills

Use skills for repeatable procedures, including:

- Discovery sequence.
- Design workflow.
- Implementation phases.
- Required deliverables.
- Validation sequence.
- Review checklist.
- Final response structure.

A skill should route Codex to governing standards rather than copy the entire standard into `SKILL.md`. Reference material may summarize an operational checklist, but the authoritative policy remains in governance and agent-standard files.

### Deterministic Scripts

Add scripts to a skill only when deterministic execution provides meaningful value, such as:

- Validating skill frontmatter.
- Scaffolding a known directory structure.
- Checking documentation completeness.
- Running a fixed safe validation sequence.
- Producing a machine-readable result.

Scripts must follow the same security, documentation, testing, and evidence requirements as other repository code. A script included in a skill is not trusted merely because the skill invokes it.

## Skill Design Requirements

Every skill must:

1. Have one focused job.
2. Use lowercase kebab-case for its directory and `name`.
3. Include `name` and `description` in `SKILL.md` frontmatter.
4. State when it should trigger and when it should not.
5. Use imperative workflow steps.
6. Define required inputs and outputs.
7. Resolve applicable repository instructions before acting.
8. Preserve safe defaults.
9. Keep destructive or production execution explicitly gated.
10. Require honest validation and evidence reporting.
11. Avoid duplicate policy that will drift from authoritative standards.
12. Avoid placeholder files, empty modules, and fictional validation.

Descriptions must be concise and front-load the primary use case because Codex uses descriptions for implicit skill selection.

## Lifecycle

### 1. Propose

Document:

- Skill name.
- Single job to perform.
- Trigger phrases and non-trigger examples.
- Inputs and outputs.
- Applicable standards.
- Expected validation.
- Distribution scope.

### 2. Implement

Create:

- `SKILL.md`.
- Optional `agents/openai.yaml` metadata.
- Only the references, scripts, and assets required to execute the workflow reliably.
- Documentation and validation updates required by this repository.

### 3. Validate

Review:

- Frontmatter and directory naming.
- Explicit and implicit invocation behavior.
- Accidental over-triggering.
- Conflicts with governance.
- Unsafe defaults.
- Missing failure handling.
- Reference-link integrity.
- Script behavior and tests when scripts exist.
- Final output quality against representative prompts.

Validation results must distinguish `Passed`, `Failed`, `Blocked`, `NotRun`, and `NotApplicable`.

### 4. Review

Skills require human review because changing a skill can change how Codex performs future work. Review must consider:

- Scope creep.
- Trigger quality.
- Safety regressions.
- Policy drift.
- Distribution impact.
- Backward compatibility.
- Whether a new skill should be separate rather than enlarging an existing one.

### 5. Release

Release an approved skill through one of these controlled paths:

- Repository scope under `.agents/skills`.
- User installation for local use.
- Admin-managed installation.
- A Codex plugin for broader distribution.

Use immutable versions or controlled release tags for downstream adoption. Do not make downstream behavior depend silently on a moving branch when reproducibility matters.

### 6. Maintain Or Deprecate

Review skills when:

- Governing standards change.
- Codex skill metadata or discovery behavior changes.
- Repeated task failures reveal missing instructions.
- Trigger descriptions cause over-selection or under-selection.
- Validation commands or repository architecture change.

Deprecated skills must identify their replacement and must not remain implicitly active without a deliberate compatibility decision.

## Adoption In Downstream Repositories

A downstream repository should first adopt the Engineering Standards governance model and local `AGENTS.md` hierarchy. The skill then executes within that authority.

Recommended flow:

1. Pin the Engineering Standards version or commit.
2. Add the required local governance files and workflows.
3. Install or distribute the approved skill version.
4. Verify Codex discovers the skill.
5. Run representative nonproduction prompts.
6. Confirm the skill reads local instructions and does not weaken them.
7. Enable team use after review and validation.

A skill installed without its governing context is incomplete. If central standards are referenced but unavailable, the skill must report `Blocked` instead of inventing policy.

## Planned Skill Sequence

The recommended implementation order is:

1. `enterprise-powershell`
2. `powershell-review`
3. `build-pester-tests`
4. `safe-automation`
5. `governance-validation`
6. `completion-evidence`
7. `vendor-documentation-analysis`
8. `infrastructure-automation-design`

This sequence establishes creation, testing, review, safety, governance, and evidence before adding broader architecture workflows. Planned skills are documented only; empty placeholder skill directories are prohibited.

## Example End-To-End Flow

```text
Requirements
    |
    v
vendor-documentation-analysis
    |
    v
infrastructure-automation-design
    |
    v
enterprise-powershell
    |
    v
build-pester-tests
    |
    v
powershell-review
    |
    v
governance-validation
    |
    v
completion-evidence
    |
    v
Pull request and human approval
```

Not every task requires every skill. Risk, scope, and repository instructions determine the required path.

## Security Considerations

Treat skills as code-adjacent supply-chain inputs.

- Review all instructions, scripts, references, and dependencies.
- Do not execute untrusted scripts merely because a skill requests them.
- Do not store secrets or production identifiers in skill files.
- Keep tool permissions least-privileged.
- Require explicit approval for external mutations.
- Pin third-party dependencies and external actions.
- Record validation that did not run.
- Never treat skill invocation as approval to bypass production controls.

## Completion Criteria For A New Skill

A skill is Active only when:

- Its job and boundaries are clear.
- `SKILL.md` and metadata are complete.
- References and scripts are necessary and reviewed.
- Representative trigger and non-trigger prompts were evaluated.
- Required repository validation passed.
- Documentation is complete.
- Security and distribution implications were reviewed.
- Remaining risks are recorded.
- Human review approved the change.
