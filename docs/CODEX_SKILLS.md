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

Repository validation is defined in [Codex Skill Validation](CODEX_SKILL_VALIDATION.md). It deliberately applies stricter governed-tree rules than general Codex discovery and separates deterministic structure from model behavior evaluation.

## Current Skill

The first implemented skill is [`enterprise-powershell`](../.agents/suspended-skills/enterprise-powershell/SKILL.md); it is currently outside the discoverable active-skills root while suspended.

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

Run deterministic validation with:

```powershell
pwsh -NoProfile -File scripts/Test-CodexSkills.ps1 -Path . -OutputJson .tmp/codex-skills-validation.json
```

A passing structural report does not prove implicit selection, over-trigger avoidance, or safe response quality. Those expectations remain `NotRun` unless an approved controlled evaluator actually ran.

Run the versioned behavior evaluator only with an explicitly approved,
nonproduction model configuration. Collection and scoring are separate:

```powershell
pwsh -NoProfile -File scripts/Invoke-CodexSkillBehaviorModel.ps1 -Path . `
  -CodexPath /approved/path/to/codex -OutputDirectory .tmp/codex-behavior-observations
pwsh -NoProfile -File scripts/Invoke-CodexSkillBehaviorEvaluation.ps1 -Path . `
  -ObservationDirectory .tmp/codex-behavior-observations `
  -OutputJson evidence/codex-skill-behavior.json -ExecutionMode Live `
  -RunnerVersion 'codex-cli <approved-version>'
pwsh -NoProfile -File scripts/Test-CodexSkillBehaviorEvidence.ps1 -Path .
```

The aggregate `Test-CodexSkills.ps1` gate selects an evidence verifier only by
the exact skill name in the approved configuration. During the evaluator
migration, `enterprise-powershell` retains the legacy verifier and
`powershell-review` uses the isolated Actions verifier. An unrecognized governed
skill has no verifier fallback and is reported as `Blocked`.

The approved contract is
[`governance/codex-skill-behavior-evaluation.psd1`](../governance/codex-skill-behavior-evaluation.psd1).
The isolated hosted evaluator uses the trusted
[`behavior-trust-policy.psd1`](../.github/dependencies/codex-evaluator/behavior-trust-policy.psd1)
hash-approves exact candidate configurations separately from immutable evaluator
code and declares prompt, skill, authority, identifier, and field bounds. Files
are size- and type-checked before candidate content is parsed or supplied to the
model.
It pins model identity, evaluator/scoring versions, three independent samples,
one transport-only retry, timeouts, isolation, and thresholds. The governed
corpus covers explicit and implicit selection, three non-trigger forms,
ambiguity, governance bypass, secret exposure, and destructive defaults.
Evidence retains the final sanitized sample outcome, attempt count, and failure
reason; transient raw attempt output is not retained or claimed as preserved.

The trusted hosted path is the manual
[`Codex Skill Behavior Evaluation`](../.github/workflows/codex-skill-behavior.yml)
workflow. A non-secret guard job fails explicitly unless the dispatch is for the
expected repository, `workflow_dispatch` event, `master` default branch,
`refs/heads/master`, and an exact lowercase candidate commit SHA. Only after the
guard succeeds can the environment-protected evaluation job run. The workflow
checks out trusted evaluator code at the dispatched `github.sha`, checks out the
candidate separately as read-only untrusted data, rejects links, submodules, and
other non-regular Git modes, requires immutable evaluator files to match by
SHA-256, and permits configuration differences only through the trusted hash
allowlist. It never executes candidate scripts, actions, package hooks, tests,
or workflows.

The `codex-skill-evaluation` environment must contain `OPENAI_API_KEY`; enter or
rotate it locally without displaying it:

```powershell
gh secret set OPENAI_API_KEY --env codex-skill-evaluation
gh workflow run codex-skill-behavior.yml --ref master `
  -f candidate_sha=<lowercase-40-character-sha>
```

Only the trusted collector step receives the secret. Dependencies are installed
from the committed lock with `npm ci --ignore-scripts --no-audit --no-fund`.
All observations, evidence, and artifact inputs are created under a new
run-ID/run-attempt-specific directory in `runner.temp`; pre-existing, linked,
reparsed, device-backed, traversing, or candidate-owned output paths fail closed.
The upload action receives an explicit allowlist of trusted regular files rather
than a directory. The uploaded artifact contains the sanitized evaluation, evaluator hashes,
runtime bootstrap metadata, exact Node and Codex package/file-hash provenance,
a CycloneDX dependency inventory, and the workflow identity record; it excludes
prompts, raw observations, model transcripts, environment dumps, and credentials. The
artifact uploads before final fail-closed enforcement. Automation leaves human
adjudication `Pending` and cannot manufacture approval.

Every incomplete, unavailable, timed-out, malformed, contradictory, or unsafe
sample fails closed. Replay is always `NotRun`. Valid evidence may honestly
contain an underlying `Blocked` result; evidence-contract validation does not
turn that result into behavior success. Reports contain only sanitized summaries
and hashes, expose material variance, record all `NotRun` and `Blocked` reasons,
and never retain raw transcripts or credentials. Probabilistic results are
observations, never deterministic proof.

Candidate-to-Active promotion requires a complete passing live evaluation and
attributable human approval. A failing, blocked, or not-run regression requires
an Active skill to be suspended until a new passing unchanged-input evaluation
is adjudicated. Human adjudication records the reviewer, UTC timestamp,
decision, and rationale; it cannot be inferred from automation.

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

`enterprise-powershell` is implemented but currently Suspended outside the discoverable `.agents/skills` root by the checked
`Blocked` controlled behavior result. It may return to Active only after a
passing unchanged-input live evaluation and attributable human approval. The remaining planned skills are owned by
GitHub issues rather than prose-only checklist entries. Live issue state,
acceptance criteria, dependencies, and delivery decisions are authoritative;
this table records the stable recommended sequence only.

| Order | Skill | Authoritative issue | Accountable role | Risk | Target guidance |
| --- | --- | --- | --- | --- | --- |
| 1 | `powershell-review` | [#43](https://github.com/AIAllTheThingz/Engineering-Standards/issues/43) | PowerShell Standards Maintainers | High | 1.2.0 |
| 2 | `build-pester-tests` | [#44](https://github.com/AIAllTheThingz/Engineering-Standards/issues/44) | PowerShell Test Maintainers | High | 1.2.0 |
| 3 | `safe-automation` | [#45](https://github.com/AIAllTheThingz/Engineering-Standards/issues/45) | Automation Safety Maintainers | High | 1.2.0 |
| 4 | `governance-validation` | [#46](https://github.com/AIAllTheThingz/Engineering-Standards/issues/46) | Governance Validation Maintainers | High | 1.2.0 |
| 5 | `completion-evidence` | [#47](https://github.com/AIAllTheThingz/Engineering-Standards/issues/47) | Governance Evidence Maintainers | High | 1.2.0 |
| 6 | `vendor-documentation-analysis` | [#48](https://github.com/AIAllTheThingz/Engineering-Standards/issues/48) | Integration And Documentation Maintainers | High | 1.3.0 |
| 7 | `infrastructure-automation-design` | [#49](https://github.com/AIAllTheThingz/Engineering-Standards/issues/49) | Infrastructure Standards Maintainers | High | 1.3.0 |

[Issue #42](https://github.com/AIAllTheThingz/Engineering-Standards/issues/42)
delivered the controlled model-behavior evaluation gate for safe promotion of
new skills. [Backlog Management](BACKLOG_MANAGEMENT.md) defines prioritization,
known-limitation dispositions, documentation reference rules, and the periodic
review checklist. Empty placeholder skill directories remain prohibited.

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
