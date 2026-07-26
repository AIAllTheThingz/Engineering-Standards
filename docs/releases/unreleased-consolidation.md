# Unreleased Consolidation And Release Readiness

| Field | Value |
| --- | --- |
| Status | Unreleased |
| Published baseline | 1.1.0 |
| Audited master commit | `e9fa50a0df28982b12ffc1ca55d40ac51d6e0ed3` |
| Final validated equivalent tree | `66c868ad157e34449435685cb961c8bade646ffe` |
| Last reviewed | 2026-07-25 |

## Summary

This record consolidates the post-`v1.1.0` development completed through PR #84. It is release-preparation documentation only. It does not select a new semantic version, authorize a tag, publish a GitHub Release, or add current development to historical `v1.1.0`.

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

## Compatibility

The central governance workflow interface remains `1.0.0`.

Published `v1.1.0` remains supported at immutable commit `2704049d7e826975d956611b194214dd79ea3686`. Current development retains project-manifest schemas `1.0.0` and `1.1.0` and adds schema `1.2.0` as Preview. Test-evidence and completion-result schemas remain `1.0.0` and `1.1.0`.

The independently canary-validated downstream workflow remains `de32b77e2043f5336a54b92ab9ed867abe93ba7e`. The newer self-CI implementation `a9158d0c7dc37db966da3a518c6155645e985b0c` is not promoted to downstream compatibility authority without a fresh external canary.

## Verified Baseline

Final PR #84 head `66c868ad157e34449435685cb961c8bade646ffe` passed:

- Governance CI run `30184347651`.
- Bash example CI run `30184347667`.
- Python example CI run `30184347650`.
- Pull Request Governance run `30184347707`.

Merge commit `e9fa50a0df28982b12ffc1ca55d40ac51d6e0ed3` has no file differences from the validated head.

All four artifacts were downloaded, independently SHA-256 hashed, opened, and JSON parsed. Exact artifact identities and hashes are recorded in [`evidence/latest-verified-run.json`](../../evidence/latest-verified-run.json) and [Governance Consolidation Audit](../GOVERNANCE_CONSOLIDATION_AUDIT.md).

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

No immediate migration is required for supported `v1.1.0` consumers. Consumers adopting unreleased Python, Bash, project-manifest `1.2.0`, or later validator behavior must pin an explicitly reviewed immutable commit and accept Preview support boundaries. Moving branches are not compatibility records.
