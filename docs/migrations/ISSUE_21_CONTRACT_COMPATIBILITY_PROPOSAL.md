# Issue 21 Governance Contract Compatibility Proposal

## Status and decision

Accepted for implementation on `feature/issue-21-governance-contract-semantics`.

This proposal freezes the Issue #21 contract before schema, validator, manifest,
configuration, template, example, or workflow changes. The migration is High
risk because these contracts are consumed by downstream repositories. It is an
additive document-version migration to `1.2.0`; it does not redesign aggregate
validation, which remains reserved for Issue #22.

The starting standards commit is
`733e7b072009e013ed98308b22f17e9e99cdf49c` (the merge of PR #35).

## Current contract inventory

| Contract | Current state |
| --- | --- |
| Project manifest | One Draft 2020-12 schema accepts document versions `1.0.0` and `1.1.0`; the repository currently declares `1.0.0`. |
| Governance configuration | One Draft 2020-12 schema accepts document versions `1.0.0` and `1.1.0`; the repository currently declares `1.0.0`. |
| Governance identity | `governanceVersion` is a semantic release version. No manifest field records the immutable standards commit. Workflow callers separately pin a full commit SHA. |
| Workflow interface | The reusable workflow path, inputs, outputs, job name, artifact naming, and required check are implemented but not represented as one versioned configuration contract. |
| Ownership | Manifest owners are strings containing a GitHub user, organization team, or email-like contact. Type, responsibility, and escalation semantics are not explicit. |
| Standards consumption | Manifest and configuration contain path lists but do not say whether paths are central references, vendored copies, or local authority. |
| Validation categories | The root configuration declares seven categories. Maintainer execution also runs YAML syntax, workflow architecture, Pester, ScriptAnalyzer, examples, and evidence processing outside that list. |
| Evidence paths | Manifest fields identify local JSON paths. Hosted evidence is generated in the workflow evidence workspace and uploaded as `governance-evidence-${run_id}`, but that distinction is not modeled. |
| Exceptions | Manifest and configuration contain exception identifier strings. Disabled controls reference those strings, but approval, status, dates, scope, and compensating controls are not locally structured. |
| Branch protection | Live `master` protection requires `Governance / Governance validation` and `Candidate implementation validation / Candidate implementation validation`. Only one nullable check-name field exists in the configuration schema. |
| Schema identifiers | All seven schema `$id` values use `https://schemas.aiallthethingz.example/...`. Completion-result uses relative `$ref` values for test evidence and artifact records. |

## Supported schema versions

The validators will explicitly support `1.0.0`, `1.1.0`, and `1.2.0` for project
manifest and governance configuration documents.

- Existing structurally and semantically valid `1.0.0` documents remain valid.
- Existing structurally and semantically valid `1.1.0` documents remain valid.
- New required fields and structured records apply only to `1.2.0`.
- Templates, examples, and this repository migrate to `1.2.0`.
- A future major version may remove the legacy bridge only through a separately
  documented breaking migration.

The evidence schemas retain their existing supported document versions in this
issue. Their `$id` namespace changes, but their instance contracts do not gain
new required fields.

## Current semantic-validator behavior

`Test-GovernanceJsonDocument` performs bounded offline checks for required
members, supported versions, relative paths, owner string syntax, duplicate
values, evidence status semantics, and disabled-control exception references.
`Invoke-ContractValidation.ps1` resolves required files and paths. The aggregate
entry point selects validation scripts by category and adds maintainer-only
Pester, ScriptAnalyzer, and example checks.

The current implementation does not authoritatively cross-validate repository
identity, owner type, manifest/config standards, technology mappings, workflow
interface fields, declared versus executed categories, hosted evidence
semantics, dated exception approval, or branch-protection names. Issue #21 adds
one authoritative cross-document semantic function and keeps orchestration
changes out of scope.

## Governance identity decision

- `governanceVersion` means only the semantic release version of the governance
  contract, for example `1.1.0`. A commit SHA in this field is invalid.
- `governanceCommitSha` means the exact immutable 40-character hexadecimal
  commit containing the consumed standards and reusable workflow.
- A downstream `central-reference` consumer records the same SHA that appears
  after `@` in its reusable-workflow reference.
- The central repository records the immutable SHA of the trusted reusable
  workflow used by its wrapper. It does not claim that the current commit can
  contain a reference to itself. Pin rotation therefore remains a subsequent
  commit, and validation compares the declaration to the existing wrapper pin,
  not to `HEAD`.

This separation is corrective for all versions and required in `1.2.0`.

## Workflow-interface contract

The initial interface version is `1.0.0` and describes:

| Element | Frozen value |
| --- | --- |
| Reusable workflow path | `.github/workflows/governance-ci-reusable.yml` |
| Inputs | `project-path`, `governance-version`, `artifact-retention-days`, `controlled-failure-test` |
| Outputs | `evidence-path`, `artifact-name` |
| Reusable job ID | `governance` |
| Reusable job name | `Governance validation` |
| Artifact pattern | `governance-evidence-${run_id}` |
| Standard required check | `Governance / Governance validation` |
| Maintainer candidate check | `Candidate implementation validation / Candidate implementation validation` |
| Profiles | `downstream`, `standards-maintainer` |

`workflowInterfaceVersion` is required in `1.2.0`. The governance configuration
contains the detailed interface declaration and selected `workflowProfile`.

- Major: removes or incompatibly changes a path, required input, output, job,
  artifact contract, required check, or profile meaning.
- Minor: adds a backward-compatible optional input/output/profile capability.
- Patch: clarifies or repairs behavior without changing the callable surface.

`governanceVersion` and `workflowInterfaceVersion` are independent. Neither may
be substituted for the other.

## Structured owner model

Version `1.2.0` owner records contain:

- `type`: `github-user`, `github-team`, or `email-contact`.
- `identifier`: `@user`, `@organization/team`, or an email address matching the
  selected type.
- `responsibility`: substantive accountable responsibility.
- `escalation`: required for High/Critical repositories and team/contact owners;
  a GitHub identity, email contact, or repository-relative escalation path.
- `displayName`: optional.

`repositoryOwnerType` is `User` or `Organization`. A user-owned repository may
use GitHub users but cannot claim that an organization team is enforceable. A
team owner requires an organization-owned repository and an `@org/team`
identifier. Email contacts are informational and cannot be the only enforceable
owner of protected code. Duplicate identifiers compare case-insensitively.

Syntax validation never claims that an identity exists or has write access.
That remains a live GitHub verification result and must be reported separately.
Legacy `1.0.0` and `1.1.0` owner strings remain supported.

## Standards-consumption model

Version `1.2.0` requires a `standardsConsumption` object:

| Mode | Required semantics |
| --- | --- |
| `central-reference` | `sourceRepository` and full `sourceCommitSha` are required and must match the trusted workflow repository/SHA; `sourceCommitSha` must also equal `governanceCommitSha`; paths resolve in the immutable central checkout; missing or contradictory source identity fails closed. |
| `vendored` | `sourceRepository`, full `sourceCommitSha`, and repository-relative `localPath` are required; local files are authoritative for the run and drift from the recorded source fails validation. |
| `local` | repository-relative `localPath` is required; the current repository is authoritative; source repository/SHA are omitted; missing files fail closed. |

For `vendored` and `local`, `localPath` identifies the authoritative subtree in
the caller repository. Each `applicableStandards` value remains caller-root-relative
(for example, `agents/AGENTS_Base.md`) and must resolve as a regular file beneath
that subtree. An empty or partial subtree fails closed; files in the trusted central
checkout never satisfy a missing local or vendored declaration.

All modes require the base standard. Technology mappings are centralized:
PowerShell, .NET, Web Frontend, Database, Worker Service, Integration, and
Infrastructure map to their corresponding agent standards. `governance` and
`github-actions` require Base, PowerShell, Integration, and Infrastructure for
this repository. Manifest, configuration, and root `AGENTS.md` declarations
must agree. Modes are never silently interchangeable, and path resolution is
bounded beneath the applicable checkout root.

## Evidence-path model

Version `1.2.0` separates:

- `local.completion`: repository-relative local completion JSON.
- `local.tests`: repository-relative local test-evidence JSON.
- `hosted.completion`: path relative to the workflow evidence workspace.
- `hosted.tests`: path relative to the workflow evidence workspace.
- `hosted.workspace`: the workflow-local evidence directory name.
- `hosted.artifactNamePattern`: the uploaded artifact name or bounded pattern.

Local paths must remain below the caller repository. Hosted paths resolve in the
workflow evidence workspace and are not required to exist in the caller
checkout. Local declarations may not claim GitHub-hosted output. Traversal,
absolute paths, drive-qualified paths, and workspace overlap fail closed.
Historical optional evidence absence is not by itself a current-run failure.

## Structured exception model

Version `1.2.0` exception records contain:

- `identifier`, `status`, `scope`, `owner`, and `approver`;
- `approvalDate`, `expiration`, and `affectedControl`;
- nonempty `compensatingControls`;
- `remediationPlan`; and
- repository-relative `evidenceReference`.

Valid statuses are `Approved`, `Rejected`, `Revoked`, and `Expired`; only an
approved, in-scope, unexpired record is active. Dates are interpreted in UTC and
tests inject a fixed validation date. Manifest and configuration records form
one exception inventory; duplicate identifiers across either document are
invalid. Disabled mandatory controls must reference an active exception covering
that exact control. Schema `1.2.0` rejects legacy string entries, malformed
records, inactive statuses, future approvals, and expired records. Legacy
versions retain exception identifier strings.

## Schema identifier namespace

Every schema moves from the uncontrolled `.example` host to:

`urn:aiallthethingz:engineering-standards:schema:<schema-name>`

Examples include
`urn:aiallthethingz:engineering-standards:schema:project-manifest` and
`urn:aiallthethingz:engineering-standards:schema:completion-result`.
Relative sibling `$ref` values remain relative so local/offline resolution and
bundled validation continue to work. Validators reject `.example` schema IDs in
the shipped schema inventory. Instance documents are not required to embed a
schema ID, so supported `1.0.0`/`1.1.0` instances remain compatible.

## Field-by-field migration matrix

| Area | `1.0.0` / `1.1.0` | `1.2.0` | Classification |
| --- | --- | --- | --- |
| `schemaVersion` | Existing value | `1.2.0` | Additive |
| `governanceVersion` | Required SemVer | Required SemVer | Corrective clarification |
| `governanceCommitSha` | Optional compatibility bridge | Required full SHA | Additive by version |
| `workflowInterfaceVersion` | Optional/null | Required SemVer | Additive by version |
| `repositoryOwnerType` | Absent | Required `User`/`Organization` | Additive by version |
| `owners` | Unique strings | Unique structured records | Breaking only for opt-in `1.2.0` |
| `standardsConsumption` | Absent | Required structured mode | Additive by version |
| `applicableStandards` | Path strings | Path strings, cross-validated | Corrective semantic enforcement |
| `requiredWorkflows` | Free strings | Supported interface/profile names | Corrective semantic enforcement |
| `evidence` | Two local paths plus optional manifest | Structured local and hosted declarations | Breaking only for opt-in `1.2.0` |
| `exceptions` | Identifier strings | Structured records | Breaking only for opt-in `1.2.0` |
| `workflowInterfaces` config | Optional string list | Replaced by required detailed interface declaration | Breaking only for opt-in `1.2.0` |
| `workflowProfile` | Absent | Required supported profile | Additive by version |
| `requiredCheckNames` | One nullable field | Required unique check-name list | Additive by version |
| `validationCategories` | Existing enum/list | Profile-consistent controlled list | Corrective semantic enforcement |
| Schema `$id` | `.example` HTTPS URI | Controlled URN | Corrective metadata change |

Unknown properties continue to fail in every version.

## Downstream migration examples

Central-reference consumers migrate by retaining their semantic governance
release, recording the exact workflow pin separately, selecting interface
`1.0.0`, and declaring hosted evidence independently from local evidence:

```json
{
  "schemaVersion": "1.2.0",
  "governanceVersion": "1.1.0",
  "governanceCommitSha": "1111111111111111111111111111111111111111",
  "workflowInterfaceVersion": "1.0.0",
  "repositoryOwnerType": "Organization",
  "owners": [
    {
      "type": "github-team",
      "identifier": "@ExampleOrg/platform",
      "responsibility": "Approves governance-sensitive repository changes.",
      "escalation": "SECURITY.md"
    }
  ],
  "standardsConsumption": {
    "mode": "central-reference",
    "sourceRepository": "AIAllTheThingz/Engineering-Standards",
    "sourceCommitSha": "1111111111111111111111111111111111111111"
  }
}
```

Vendored consumers additionally record `localPath`; local consumers omit the
source repository and SHA and identify the authoritative `localPath`.

## Validation categories and profiles

The controlled category inventory is `Contract`, `JsonSchemas`, `YamlSyntax`,
`WorkflowArchitecture`, `MarkdownLinks`, `DocumentationCompleteness`,
`ForbiddenPatterns`, `RepositoryHealth`, `CodexSkills`, `Evidence`, `Examples`,
`Pester`, `PSScriptAnalyzer`, and `PowerShellParser`.

The `standards-maintainer` profile declares every category actually executed by
candidate validation. The `downstream` profile is limited to `Contract`,
`MarkdownLinks`, `DocumentationCompleteness`, `ForbiddenPatterns`, and
`CodexSkills`; maintainer-only categories fail semantic validation before the
reusable workflow dispatches tools. Issue #21 detects unsupported,
declared-but-never-executed, and required-but-omitted categories; it does not
redesign how Issue #22 aggregates or schedules them.

## Backward compatibility and enforcement timeline

1. Merge Issue #21 with validators accepting `1.0.0`, `1.1.0`, and `1.2.0`.
2. Publish templates, examples, and central declarations at `1.2.0`.
3. Document legacy string owners, unstructured exceptions, and implicit
   consumption as deprecated but supported.
4. Announce any removal only in a future major schema proposal with fixtures,
   migration tooling or examples, and an enforcement date.

Corrective checks that prevent contradictions may fail legacy documents only
when the contradiction was never a supported semantic promise—for example a
SHA in `governanceVersion`, path traversal, a disabled control without its
listed exception, or a declared standard that does not exist.

## Rollback strategy

Rollback reverts the Issue #21 implementation commit and restores repository,
template, and example documents to their prior supported versions. No persisted
external data is mutated. Downstream `1.2.0` adoption must not be recommended
until the new validators and hosted workflow pass. Once consumers adopt
`1.2.0`, rollback requires either retaining the `1.2.0` validator bridge or
coordinating those consumers back to a supported older document version.

The central wrapper's immutable self-CI pin is rotated only after an
implementation commit exists. Reverting that rotation restores the previously
reviewed pin without rewriting history.

## Rejected alternatives

- Adding required fields to `1.0.0` or `1.1.0`: rejected because it silently
  breaks supported consumers.
- Treating the governance release version as an immutable reference: rejected
  because tags and releases do not replace commit identity.
- Treating a commit SHA as the workflow interface version: rejected because
  implementation identity and compatibility semantics are different axes.
- Keeping owner strings for the current version: rejected because type,
  responsibility, and escalation cannot be enforced reliably.
- Requiring hosted artifact paths inside caller checkouts: rejected because the
  reusable workflow intentionally owns a separate evidence workspace.
- Live GitHub API calls inside deterministic semantic validation: rejected
  because offline validation must be reproducible and must not claim access was
  verified.
- Rebuilding aggregate orchestration: rejected as Issue #22 scope.

## Expected implementation surface

- Project-manifest and governance-config schemas plus all schema IDs.
- Valid, invalid, and compatibility fixtures.
- Root declarations, repository templates, and all examples.
- `GovernanceValidation.psm1`, contract validation entry point, and focused
  semantic tests.
- Workflow/configuration/adoption/branch-protection/security/troubleshooting
  documentation and changelog.
- Minimal workflow-interface declarations and immutable pin rotation required
  to make the frozen contract truthful.

## Remaining risks and coordinator decisions

- Live identity existence/access remains externally verified, never inferred.
- Branch-protection settings can drift after local validation; hosted evidence
  must record the observed check names.
- The self-CI pin cannot point at the commit containing its own pin. The accepted
  two-commit rotation model avoids impossible self-reference.
- Full category orchestration remains Issue #22. Issue #21 validates the frozen
  declarations against the current execution surface only.

Coordinator decision: **accepted**. Implement schema version `1.2.0` using the
compatibility bridge and contracts above.
