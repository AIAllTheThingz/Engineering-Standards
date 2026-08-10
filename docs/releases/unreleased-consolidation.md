# Post-v1.1.0 Consolidation And 1.2.0 Release Readiness

| Field | Value |
| --- | --- |
| Status | Prepared for 1.2.0; unpublished |
| Published baseline | 1.1.0 |
| Selected next version | 1.2.0 |
| PR #88 consolidation merge | `dee27948aafbc6f7dcb646921e8e1c9c9c4add56` |
| PR #89 correction merge | `c2fd32e94142d50ac16bbbf6913c849122d58b8d` |
| PR #90 versioned-contract merge | `16277a220035446924ef19f18d713486c6d364c1` |
| PR #99 behavior-contract merge | `dcdf56d20666d08bd96715f00feb5cfd88dcc635` |
| Release-preparation baseline | `dcdf56d20666d08bd96715f00feb5cfd88dcc635` |
| Exact 1.2.0 candidate | Not selected until release-preparation changes are merged |
| Last reviewed | 2026-08-10 |

## Summary

This record consolidates development after published `v1.1.0` and records the current boundary for prepared, unpublished `1.2.0`. Earlier consolidation work through PR #90 established the split published-versus-unreleased release contract. Subsequent work completed the controlled Codex behavior-evaluation path and its remediation through PRs #96-#99.

The prepared version is `1.2.0` and is unpublished. This record does not authorize `v1.2.0`, does not claim a GitHub Release exists, and does not invent a final candidate SHA before the preparation changes are merged.

Historical `v1.1.0` release evidence remains unchanged and continues to prove only the immutable release it names.

## Included Post-v1.1.0 Work

- First-class Python and Bash central standards and cross-standard handoffs.
- Trusted non-executing Python and Bash static analysis.
- Hash-locked Python functional validation, package inspection, dependency audit, SBOM, evidence, and maintained example.
- Hash-verified Bash toolchain validation, bounded functional execution, SBOM, evidence, and maintained example.
- Pull-request body governance and trusted reusable validation.
- Release lifecycle and downstream compatibility contracts.
- Reconciled functional-example and home-lab demonstration catalogs.
- Version-aware project-manifest, standards-consistency, and compatibility records with preserved historical record shapes.
- Exact validator dependency locking, provenance evidence, and coordinated immutable self-CI trust boundaries.
- Full trusted Git history for checked-in evidence validation and corrected evidence-freshness boundaries.
- Governed `enterprise-powershell` skill and deterministic skill validation.
- Controlled Codex behavior evaluator, trusted Actions workflow, sanitized evidence, schema `1.3.0` provenance, provider/preflight hardening, and human-adjudicated routing/safety semantics.
- Ten-case Codex behavior corpus with strict safety and routing expectations and regression protection for previously passing cases.

## Controlled Codex Behavior Milestone

PRs #96-#99 completed the behavior-evaluation remediation sequence:

- PR #96 repaired Structured Outputs compatibility.
- PR #97 hardened the provider configuration and preflight/failure boundary.
- PR #98 aligned the evaluation semantics, schema `1.3.0`, provenance, and ten-case taxonomy.
- PR #99 disambiguated the three remaining routing cases without lowering thresholds or weakening destructive, governance-bypass, or secret-exposure behavior.

Protected live workflow run `31433373121` evaluated merge commit `dcdf56d20666d08bd96715f00feb5cfd88dcc635` and passed:

| Metric | Result |
| --- | --- |
| Cases | `10/10` |
| Samples | `30/30` |
| Trigger rate | `1.0` |
| Non-trigger rate | `1.0` |
| Safety rate | `1.0` |
| Ambiguity rate | `1.0` |
| Quality average | `4.0` |
| Material variance cases | `0` |
| Artifact ID | `9080185662` |
| Artifact SHA-256 | `dbebdc28388201a6da65c21c7d08779b8a0487781499a9726cefa8633394bdec` |

That artifact is authoritative for the exact commit it names. It is not treated as exact-target release evidence for a later SHA.

Human adjudication remains pending. The checked behavior record stays truthful Replay/`NotRun`, and `enterprise-powershell` remains outside the discoverable active skill root until attributable approval is durably recorded. This release-preparation change does not bypass that lifecycle boundary.

## Compatibility

The central governance workflow interface remains `1.0.0`.

Published `v1.1.0` remains supported at immutable commit `2704049d7e826975d956611b194214dd79ea3686`. The prepared `1.2.0` contract adds project-manifest schema `1.2.0` while retaining `1.0.0` and `1.1.0`. Test-evidence and completion-result schemas remain `1.0.0` and `1.1.0`.

The independently canary-validated central downstream workflow remains `de32b77e2043f5336a54b92ab9ed867abe93ba7e`. Repository self-CI is not promoted to downstream compatibility authority without fresh external exact-candidate validation.

Preview functional workflow authorities remain:

- Python: `.github/workflows/python-ci-reusable.yml@e066df32a0deaee38fed4a4cd477d1f4b4b549ed`, interface `1.0.0`.
- Bash: `.github/workflows/bash-ci-reusable.yml@d55bb8e6778030f5490e900ba52ba99ac6403827`, interface `1.0.0`.

These are first-party validated distribution authorities. No five-scenario functional external canary is claimed for them.

## PR #88 Consolidation Baseline

Final PR #88 head `3f80d71d780ddd04c66329c8452c3c97ea50deef` passed Pull Request Governance, Python example CI, Bash example CI, trusted Governance validation, candidate implementation validation, evidence generation, evidence validation, artifact upload, and mandatory enforcement.

PR #88 merged as `dee27948aafbc6f7dcb646921e8e1c9c9c4add56`. That baseline predates the corrective schema and contract changes delivered by PR #89 and is not presented as evidence for those later corrections.

## PR #89 Corrective Validation

Final PR #89 head `11d7c3200be8be5ce694887f2331f1df49d3d62b` passed:

- Pull Request Governance run `30192204385`.
- Python example CI run `30192204377`.
- Bash example CI run `30192204396`.
- Governance CI run `30192204388`, including trusted Governance validation and candidate implementation validation.
- All 17 mandatory governance categories.
- Pester: 1,013 passed, 0 failed, 0 skipped, 0 not run.

PR #89 merged as `c2fd32e94142d50ac16bbbf6913c849122d58b8d`. Historical artifacts and hashes remain available in GitHub and are not rewritten by this preparation record.

## PR #90 Versioned Contract Validation

PR #90 versioned the downstream compatibility and standards-consistency document contracts, preserved their historical `1.0.0` shapes, enforced the split release-state model, aligned lifecycle fixtures and repository-health checks, and corrected evidence-freshness classifications.

Final PR #90 head `d75a37a60f2c82a8ea7cefafd714ce0309ea237e` passed:

- Governance CI run `30232343849`.
- Python example CI run `30232343796`.
- Bash example CI run `30232343840`.
- Pull Request Governance run `30233092086`.

PR #90 merged as `16277a220035446924ef19f18d713486c6d364c1`. Its historical Governance artifact truthfully recorded the behavior gate state that existed then. Later passing Codex behavior evidence does not rewrite that historical artifact.

## Current Lifecycle Limitations

- The exact `1.2.0` release candidate SHA is not selected until this preparation change set is merged.
- Human adjudication of the passing controlled Codex behavior evidence remains pending.
- The production `enterprise-powershell` skill remains physically suspended until that attributable approval is durably recorded.
- No fresh exact-candidate Governance success run or controlled-failure proof has been adopted for `1.2.0`.
- No fresh five-scenario downstream canary set has been completed for the final `1.2.0` candidate.
- No `v1.2.0` tag or GitHub Release exists.
- Tag creation and publication are not authorized by this preparation record.

## Required Before Publication

1. Merge the release-preparation change through protected review without claiming publication.
2. Select the resulting unchanged `master` SHA as the release candidate.
3. Run and verify the complete hosted Governance success path for that candidate.
4. Run and verify the controlled-failure proof for the same candidate.
5. Run and verify all five downstream canary scenarios against the same candidate.
6. Independently verify artifact identities, hashes, and required evidence contents.
7. Complete human behavior adjudication and formal release approvals on the unchanged candidate.
8. Pass the machine-checked PreRelease lifecycle record.
9. Obtain explicit tag and publication authorization.
10. Create the annotated protected `v1.2.0` tag and publish the GitHub Release only after authorization.
11. Re-fetch external state and complete Publication and PostRelease validation.

Any change to the candidate after exact-target validation requires the affected evidence to be refreshed rather than inherited by assumption.

## Consumer Guidance

No immediate migration is required for supported `v1.1.0` consumers while `1.2.0` remains prepared and unpublished. Production consumers should continue to use immutable published or explicitly documented authorities. Moving branches are not compatibility records.

The authoritative prepared release notes are [1.2.0.md](1.2.0.md), and current publication state is maintained in [Release Status](../RELEASE_STATUS.md).
