# Unreleased Consolidation And Release Readiness

| Field | Value |
| --- | --- |
| Status | Unreleased |
| Published baseline | 1.1.0 |
| Audited master commit | `dee27948aafbc6f7dcb646921e8e1c9c9c4add56` |
| Final validated equivalent tree | `3f80d71d780ddd04c66329c8452c3c97ea50deef` |
| Last reviewed | 2026-07-26 |

## Summary

This record consolidates the post-`v1.1.0` development completed through PR #88 and the focused correction of its post-merge review findings. It is release-preparation documentation only. It does not select a new semantic version, authorize a tag, publish a GitHub Release, or add current development to historical `v1.1.0`.

## Included Unreleased Work

- First-class Python and Bash central standards.
- Trusted non-executing Python and Bash static analysis.
- Hash-locked Python functional validation, package inspection, dependency audit, SBOM, and evidence.
- Hash-locked Bash toolchain validation, bounded functional execution, SBOM, and evidence.
- Pull-request body governance and trusted reusable validation.
- Release lifecycle and downstream compatibility contracts.
- Reconciled functional-example and home-lab demonstration catalogs.
- Controlled Codex skill behavior-evaluation architecture and the suspended `enterprise-powershell` lifecycle state.
- Exact validator dependency locking and provenance.
- PyYAML `6.0.3` with one reviewed CPython 3.12 Linux X64 wheel hash.
- Coordinated immutable self-CI pin rotation.
- Full trusted Git history for checked-in evidence validation.
- Corrected Bash evidence-freshness boundaries for unrelated central governance changes.
- Explicit machine-readable Python and Bash functional workflow compatibility authorities.
- Restored mandatory cross-standard handoff relationships in the standards consistency matrix.
- Separate published-release state and next-release readiness records.

## Compatibility

The central governance workflow interface remains `1.0.0`.

Published `v1.1.0` remains supported at immutable commit `2704049d7e826975d956611b194214dd79ea3686`. Current development retains project-manifest schemas `1.0.0` and `1.1.0` and adds schema `1.2.0` as Preview. Test-evidence and completion-result schemas remain `1.0.0` and `1.1.0`.

The independently canary-validated central downstream workflow remains `de32b77e2043f5336a54b92ab9ed867abe93ba7e`. The newer self-CI implementation `a9158d0c7dc37db966da3a518c6155645e985b0c` is not promoted to downstream compatibility authority without a fresh external canary.

The Preview functional workflow authorities are recorded separately:

- Python: `.github/workflows/python-ci-reusable.yml@e066df32a0deaee38fed4a4cd477d1f4b4b549ed`, interface `1.0.0`.
- Bash: `.github/workflows/bash-ci-reusable.yml@d55bb8e6778030f5490e900ba52ba99ac6403827`, interface `1.0.0`.

These are first-party validated distribution authorities. No five-scenario functional external canary is claimed.

## Verified Baseline

Final PR #88 head `3f80d71d780ddd04c66329c8452c3c97ea50deef` passed:

- Pull Request Governance.
- Python example CI.
- Bash example CI.
- Trusted Governance validation.
- Candidate implementation validation.
- Evidence generation, normalization, validation, upload, and mandatory enforcement.

PR #88 merged as `dee27948aafbc6f7dcb646921e8e1c9c9c4add56`.

## Corrective Review Findings

The post-merge review identified three semantic defects not detected by the existing green checks:

1. Functional Python and Bash workflow authorities were described as compatibility dimensions but absent from the machine-readable matrix.
2. The standards consistency rebuild had emptied mandatory technology handoff arrays and flattened Integration's direct governance parents.
3. Published `v1.1.0` data was mixed into the `NotRun` next-release readiness object.

The corrective change updates both schemas, both owned JSON records, compatibility documentation, and focused regression tests. It does not alter executable workflow behavior, permissions, secrets, packages, production paths, tags, or releases.

## Lifecycle Limitations

- `enterprise-powershell` remains `Suspended`.
- Controlled model behavior remains `Blocked` because no paid live model evaluation or `OPENAI_API_KEY` was used.
- Home-lab demonstrations are not production skill evidence.
- No next release candidate has been selected.
- No fresh exact-candidate controlled-failure run or downstream canary has been performed for a new release.
- No new tag or publication authorization has been granted.

## Required Before Publication

1. Select a semantic version and unchanged candidate SHA.
2. Update `VERSION`, changelog, release notes, compatibility matrix, and lifecycle record in the same candidate.
3. Pass the full aggregate, Python, Bash, and PR-governance workflows.
4. Run and independently verify a controlled-failure proof.
5. Run and independently verify all five downstream canary scenarios.
6. Confirm every artifact identity and hash.
7. Obtain attributable approvals and explicit tag/publication authorization.
8. Publish only from the approved immutable tag.
9. Complete post-release verification.

## Consumer Guidance

No immediate migration is required for supported `v1.1.0` consumers. Consumers adopting unreleased Python, Bash, project-manifest `1.2.0`, or later validator behavior must pin the exact authority from the machine-readable compatibility record and accept Preview support boundaries. Moving branches are not compatibility records.
