# Codex Skill Validation

## Purpose And Boundary

`scripts/Test-CodexSkills.ps1` treats repository skills as untrusted, code-adjacent supply-chain inputs. It validates structure, bounded metadata, local references, optional scripts, lifecycle declarations, and prompt-corpus structure without importing or executing skill content, invoking declared tools, contacting dependency services, or calling a model.

Deterministic checks can pass while model selection and response-quality evaluation remains `NotRun`. Maintainers must review real prompt behavior separately; fixture labels and keyword checks are not proof of model behavior.

The [`powershell-review` home-lab example](../examples/powershell-review-home-lab/README.md)
uses this boundary intentionally: deterministic automation validates its
isolated package and synthetic contracts, while interactive output remains a
demonstration rather than production behavior evidence.

## Rule Matrix

| Rule | Required input | Positive example | Negative example | Failure status | Severity | Kind |
| --- | --- | --- | --- | --- | --- | --- |
| SKL001 | `.agents/skills/<name>` | `enterprise-powershell` | `PowerShell_Tools`, linked directory | `Failed` or `Blocked` for inaccessible traversal | error | Deterministic |
| SKL002 | Skill directory | One regular bounded `SKILL.md` | missing, empty, linked, duplicate-by-case | `Failed` | error | Deterministic |
| SKL003 | Frontmatter | Closed mapping parsed by safe YAML loader | malformed YAML, duplicate keys, tags, excess depth | `Failed` | error | Deterministic |
| SKL004 | `name` | Exact lowercase directory match | normalization, missing name, mismatch | `Failed` | error | Deterministic |
| SKL005 | `description` | Bounded use and non-trigger boundaries | placeholder, oversized, no boundary | `Failed` | error | Deterministic plus corpus review |
| SKL006 | Optional `agents/openai.yaml` | Known typed `interface`, `policy`, `dependencies` | traversal, wrong Boolean, unsafe URL, wrong skill prompt | `Failed` | error | Deterministic |
| SKL007 | Markdown/local references | Existing file within skill or approved authority | absolute path, traversal, missing or linked target | `Failed` | error | Deterministic |
| SKL008 | Optional directories | Nonempty useful files | empty, `.gitkeep`, placeholder, generated output | `Failed` | error | Deterministic |
| SKL009 | Optional scripts | Existing parser-valid script | fictional or parser-invalid script | `Failed` | error | Deterministic; never executed |
| SKL010 | Skill instructions | Stable paths to inherited governance | copied policy with missing authority references | `Failed` | error | Deterministic |
| SKL011 | Optional compatibility | Supported semantic version | malformed, impossible, placeholder version | `Failed` | error | Deterministic |
| SKL012 | Optional lifecycle | Active, or complete deprecation/migration contract | silently active deprecated skill | `Failed` | error | Deterministic |
| SKL013 | All declared names | Unique names | duplicate declaration in different directories | `Failed` | error | Deterministic |
| SKL014 | Demo-resolved skill names | No empty or placeholder production directory | demo-only name reintroduced as an incomplete Active skill | `Failed` | error | Deterministic |
| SKL015 | Instruction body | “Do not bypass governance” | affirmative bypass, fabricated evidence, destructive default | `Failed` | error | Deterministic, scoped patterns |
| SKL016 | Skill metadata/content | Clearly synthetic examples | obvious embedded credential/production identifier | `Failed` | error | Deterministic advisory control; not a complete secret scan |
| SKL017 | Prompt fixtures | Eight required categories with unique IDs and enums | missing category, duplicate ID, unknown expectation | `Failed` | error | Deterministic structure only |
| SKL018 | Model expectation | Model-required case reported `NotRun` with reason | local regex reported as model success | `NotRun` | warning | Model evaluation |
| SKL019 | All inputs | Counts, sizes, depth, references, output bounded | oversized or excessive collection | `Failed` or `Blocked` | error | Deterministic fail-closed |

Canonical statuses are `Passed`, `Failed`, `Blocked`, `NotRun`, and `NotApplicable`. Malformed required input never becomes implicit success.

## Supported Layout And Metadata

Each active directory under `.agents/skills/` requires one `SKILL.md` with `name` and `description` frontmatter. Optional `agents/`, `references/`, `scripts/`, and `assets/` directories must contain useful nonempty files. This repository rejects symlinks, junctions, and reparse points even though Codex discovery can follow symlinked skills; the stricter rule protects governed supply-chain inputs.

Supported `agents/openai.yaml` top-level mappings are `interface`, `policy`, and `dependencies`. Repository lifecycle and governance extensions belong in `SKILL.md` frontmatter. Supported official interface fields include `display_name`, `short_description`, `icon_small`, `icon_large`, `brand_color`, and `default_prompt`. `policy.allow_implicit_invocation` is Boolean. Dependency tools declare a bounded `type`, `value`, and optional descriptive transport metadata. Validation never contacts dependencies.

The contract was verified against the current OpenAI Codex manual section “Build skills” on 2026-07-13. When official metadata changes, maintainers must review the source, update this contract deliberately, add positive and negative fixtures, run the full validation matrix, and use the immutable workflow bootstrap process. External documentation cannot weaken repository governance.

## Reference And Lifecycle Rules

Local links must remain inside the current skill or explicitly approved repository authority (`AGENTS.md`, `agents/**`, `governance/**`, or reviewed `docs/**`). Absolute workstation paths, traversal, missing files, case conflicts, and linked targets fail. External HTTP links are not treated as locally verified.

Compatibility metadata is optional because repository inheritance supplies the current governance contract. If declared, `governanceCompatibility` must use semantic-version syntax supported by the repository. Deprecated skills must declare migration behavior, replacement or an indefinite-support rationale, removal target or rationale, and Boolean `lifecycle.implicitInvocationAllowed` as a deliberate invocation decision.

## Prompt Corpus

JSON cases under `tests/fixtures/codex-skills/prompt-behavior/` contain `caseId`, `skillName`, `category`, `prompt`, `expectedSelection`, `expectedSafetyOutcome`, `deterministicAssertions`, `modelEvaluationRequired`, and `rationale`. Required categories cover explicit and implicit invocation, three non-trigger forms, ambiguity, governance bypass, and secret/destructive defaults.

The validator proves only bounded structure, IDs, known enums, skill existence, category coverage, and explicit invocation syntax. Actual routing, over-trigger avoidance, response safety, and response quality remain `NotRun` until a separately approved controlled evaluator is run. CI does not call a live model.

## Operation And Output

```powershell
pwsh -NoProfile -File scripts/Test-CodexSkills.ps1 -Path . -OutputJson .tmp/codex-skills-validation.json
```

Exit `0` means required deterministic validation passed; advisory model evaluation may still be `NotRun`. Exit `1` means deterministic failure or blockage, and exit `2` means the wrapper itself was blocked. JSON contains repository and skills roots, discovered names, deterministic/model statuses, rule results, prompt results, and canonical counts. Reports identify safe case IDs/categories but omit raw prompt bodies and skill contents.

## Threat Model, Review, And Rollback

Untrusted Markdown, YAML, JSON, filenames, references, and prompt text can attempt traversal, parser abuse, secret disclosure, instruction injection, or execution. Controls include safe YAML loading, duplicate-key rejection, depth/size/count bounds, path-boundary and reparse checks, sanitized output, inert parsing, least-privilege CI, and continued repository-wide forbidden-pattern scanning.

Maintainers review trigger quality with representative prompts outside deterministic CI and record honest `NotRun` results where no approved evaluator ran. Roll back through a reviewed pull request: revert the Issue #20 merge, restore prior trusted/candidate pins, remove only the `CodexSkills` category and candidate command, retain Issue #18/#19 controls, rerun governance validation, and preserve historical runs and artifacts.

## Troubleshooting

- `Blocked` for YAML parsing: verify Python and pinned PyYAML are available; do not substitute unsafe parsing.
- SKL007: resolve the link relative to the skill, remove traversal, and keep authority links within approved roots.
- SKL017: add the missing category or correct the safe enum/unique case ID; do not relabel behavior as evaluated.
- Candidate architecture failure: keep aggregate output in the external runner temporary directory, permissions read-only, and both self-CI references pinned to the same reviewed full SHA.
