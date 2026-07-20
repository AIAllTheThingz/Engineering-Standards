# Validator Dependency Model

Functional Python dependencies are intentionally outside the central static
validator lock. Each governed Python project owns a fully transitive
`requirements-ci.lock` with exact versions and SHA-256 hashes and installs it
with `--only-binary=:all: --require-hashes --no-deps`. This preserves the
non-executing downstream static boundary while giving the isolated functional
workflow reviewed pytest, mypy, pip-audit, build, backend, and SBOM tooling.

| Field | Value |
| --- | --- |
| Status | Active |
| Model version | 1.0.0 |
| Owner role | Engineering Standards Maintainers |
| Last reviewed | 2026-07-15 |

## Purpose

Governance validation is only trustworthy when the environment that interprets
workflows, executes validators, runs tests, and produces evidence is itself
reviewable. This document defines the supported runner, runtime, package,
provenance, integrity, evidence, offline, and update controls for local and
GitHub-hosted validation.

The authoritative dependency lock is
`.github/dependencies/validator-dependencies.psd1`. Python installation is also
constrained by
`.github/dependencies/workflow-validation-requirements.txt`. A version appearing
only in workflow text, documentation, or a package repository is not a valid
lock.

## Selected Environment

| Component | Declared version or identity | Source and integrity control |
| --- | --- | --- |
| GitHub-hosted runner | `ubuntu-24.04`, `X64` | Versioned GitHub runner label; observed image OS and version are recorded. |
| PowerShell | `7.4.11` | Official PowerShell GitHub release archive; archive SHA-256 is locked and verified before extraction. |
| Python | `3.12.11` | `actions/setup-python` pinned by full commit SHA; exact version is verified and the executable SHA-256 is recorded. |
| Node.js | `22.17.0` | `actions/setup-node` pinned by full commit SHA; exact version is verified and the executable SHA-256 is recorded. |
| .NET SDK | `8.0.411` | `actions/setup-dotnet` pinned by full commit SHA plus root `global.json` with roll-forward and prerelease disabled; exact version is verified and the executable SHA-256 is recorded. |
| PyYAML | `6.0.2` | Binary wheel only; exact wheel SHA-256 is locked and pip uses `--require-hashes`, `--no-deps`, and a verified local cache for installation. |
| Ruff | `0.15.22` | Official Astral PyPI manylinux X64 wheel, MIT license; exact filename and SHA-256 are locked and installed binary-only from the verified local cache. |
| ShellCheck | `0.11.0` | Official `koalaman/shellcheck` Linux X64 release archive, GPL-3.0; immutable release URL and SHA-256 are verified before bounded extraction. |
| Pester | `5.7.1` | Exact PSGallery package URL, filename, version, module manifest, and package SHA-256 are locked and verified. |
| PSScriptAnalyzer | `1.22.0` | Exact PSGallery package URL, filename, version, module manifest, and package SHA-256 are locked and verified. |

PSGallery and PyPI are distribution sources, not implicit trust anchors. A file
from either source is rejected unless its content matches the independently
reviewed SHA-256 in the repository lock. A matching archive is extracted into an
isolated temporary directory; PowerShell module manifests and imported versions
must also match the lock.

## Implementation Approaches Considered

### Pinned Runtime Installation — Selected

The selected design uses `ubuntu-24.04`, full-SHA setup actions, exact runtime
versions, a separately downloaded and hash-verified PowerShell runtime, and
hash-verified validator packages. It preserves the existing sibling checkout
trust boundary and supports the real PowerShell, Python, Git, .NET, Node, and npm
commands required by the maintainer examples. Local maintainers can use the same
lock and an offline package cache.

The main limitation is that GitHub services the `ubuntu-24.04` image over time;
the label is versioned but is not an immutable image digest. The workflow
therefore verifies declared runtime versions, records observed runner-image
metadata, and records executable hashes. A changed or missing runtime fails
closed instead of being accepted as equivalent.

### Digest-Pinned Validator Container — Deferred

A container pinned by OCI digest would provide stronger base-filesystem
reproducibility and a single distributable validator unit. It would also require
building, signing, scanning, publishing, retaining, and rotating a multi-runtime
image containing PowerShell, Python, Git, .NET, Node, and npm. GitHub job
container behavior, checkout compatibility, artifact tooling, local Windows
administration, and the external canary would all need separate validation.

No container registry publication, package publication, or signing identity was
authorized by Issue #23. Publishing an image merely to obtain a digest would
create a new supply-chain service and release obligation. A container may be
adopted later through a separately approved high-risk change after provenance,
signature, vulnerability scanning, retention, and rollback controls exist.

## Trusted Installation Flow

1. Check out caller content and immutable trusted standards into separate paths.
2. Validate the trusted workflow repository and full workflow SHA.
3. Install exact Python, Node, and .NET versions through setup actions pinned by
   full commit SHA. Root `global.json` selects .NET SDK `8.0.411` with
   `rollForward: disable` so a newer runner-preinstalled SDK cannot win normal
   SDK resolution.
4. Run `scripts/Install-ValidatorRuntime.ps1` from the trusted standards or
   harness checkout. Verify the PowerShell archive SHA-256 before extraction.
5. Run `scripts/Install-ValidatorDependencies.ps1` with that pinned PowerShell.
6. Download missing package files only from their declared HTTPS sources, then
   verify every SHA-256 before installation or import.
7. Install packages from the verified cache into isolated temporary directories.
8. Verify actual runtime and module versions, write provenance evidence, and
   generate the CycloneDX SBOM.
9. Run the authoritative aggregate validator only when runtime and dependency
   bootstrap steps passed.
10. Upload failure evidence before final enforcement.

The candidate workflow checks out a second immutable `harness/` workspace at
`job.workflow_sha` and runs bootstrap scripts and locks only from that trusted
checkout. Candidate code is executed only after the harness has established the
environment, without secrets or write permissions.

## Online, Offline, and Degraded Operation

Online installation may populate a new isolated cache. It never installs an
unverified download. Offline installation uses `-Offline` and requires all exact
filenames from the lock in `-PackageCachePath`.

```powershell
pwsh -NoProfile -File scripts/Install-ValidatorRuntime.ps1 `
  -RepositoryPath . `
  -PackageCachePath .cache/validator `
  -InstallRoot .tmp/pwsh-7.4.11 `
  -EvidencePath .tmp/runtime-bootstrap.json `
  -Offline
```

Then invoke the installed `pwsh` path:

```powershell
.tmp/pwsh-7.4.11/pwsh -NoProfile -File scripts/Install-ValidatorDependencies.ps1 `
  -RepositoryPath . `
  -PackageCachePath .cache/validator `
  -ModuleRoot .tmp/validator-modules `
  -PythonPackageRoot .tmp/validator-python `
  -ToolRoot .tmp/validator-tools `
  -EvidencePath .tmp/dependencies.json `
  -SbomPath .tmp/validator-sbom.cdx.json `
  -RuntimeEvidencePath .tmp/runtime-bootstrap.json `
  -Offline
```

Failure semantics are mandatory:

- A missing offline package or unavailable reviewed remote source is `Blocked`
  and exits `3`.
- A missing lock, malformed declaration, unexpected version, wrong hash,
  tampered cache file, unsafe archive entry, or invalid module manifest is
  `Failed` and exits `1`.
- Dependency bootstrap never converts either state into `Passed`.
- The aggregate report and final workflow enforcement treat `Failed`, `Blocked`,
  and `NotRun` as non-passing.

Local validation that cannot obtain the locked environment must record
`Blocked` or `NotRun`; it must not install convenient unreviewed replacements.

## Evidence and SBOM

Hosted governance artifacts contain:

- `environment.json`: caller and standards identity, runner label and observed
  image, actual runtime versions, executable hashes, and lock-file hashes.
- `runtime-bootstrap.json`: PowerShell source, declared and actual version,
  expected and actual archive hash, and bootstrap status.
- `dependencies.json`: online/offline mode, lock and requirements hashes,
  runtime inventory, package provenance, expected and actual package hashes,
  versions, status, and failure reason.
- `validator-sbom.cdx.json`: CycloneDX 1.5 runtime and package inventory with
  versions, purls, sources, and hashes.

Ruff is invoked through its exact isolated executable with `--isolated`,
`--no-cache`, an explicit `E9,F,B,S` baseline, `--ignore-noqa`, and no fixes.
The standards-maintainer profile has two repository-owned, path-specific
exceptions: `S101` for the governed Python example's pytest files and `S603`
for the trusted functional validator's shell-free subprocess runner. These
exceptions are selected by the trusted profile and are not applied to
downstream callers; caller Ruff configuration and inline suppressions remain
ignored.
ShellCheck uses the exact extracted executable, `/dev/null` as its rc file,
external-source loading disabled, and warning-or-higher findings. Bash syntax is
checked with the observed runner Bash in `--noprofile --norc -n` mode after
clearing startup variables. The `ubuntu-24.04` label is versioned but is not an
immutable image digest, so Bash version and executable SHA-256 are evidence.

The offline cache now requires the exact Ruff wheel and ShellCheck archive in
addition to the existing packages. Missing offline artifacts are `Blocked`;
hash mismatch, unsafe archive layout or links, destination reuse, and installed
version mismatch are `Failed`. Python unit tests, Bash functional tests, and
language workflow families remain deferred.

These files describe the environment that actually ran. Checked-in local
evidence does not prove a GitHub-hosted run. GitHub evidence becomes release
proof only after the workflow artifact is downloaded and independently verified
under the release process.

## Dependency Review and Update Policy

Dependabot checks GitHub Actions and the Python requirements directory weekly.
Its pull requests are update signals, not automatic approval. PowerShell release
archives and PSGallery modules require a maintainer-created update pull request
because their hashes, source metadata, compatibility, and module contents are
reviewed together.

For any runner, runtime, action, or package update:

1. Open a focused dependency-update pull request and classify it as
   security-sensitive and High risk.
2. Confirm the publisher, official source, release notes, support lifecycle,
   license, vulnerability status, and exact release artifact.
3. Obtain the digest from the publisher's release metadata or calculate it from
   an independently downloaded artifact. Record how the value was obtained.
4. Update the PSD1 lock, requirements hash when applicable, setup-action full
   SHA, workflow version, documentation table, and tests together.
5. Run `scripts/Test-ValidatorDependencies.ps1`, YAML and workflow architecture
   validation, the positive offline-cache test, missing-package test, tamper/hash
   test, Pester, PSScriptAnalyzer, and the authoritative aggregate validator.
6. Review the generated dependency evidence and CycloneDX inventory for the
   exact intended versions and hashes.
7. Run real GitHub success and controlled-failure paths against the exact
   candidate SHA. Run the external downstream canary when the reusable workflow
   or authoritative pin changes.
8. Obtain required human approval before merging or rotating the self-CI pin.

Emergency updates follow the same hash and evidence rules. A time constraint may
require an approved exception for deferred compatibility testing, but never for
false evidence, accepting a hash mismatch, or silently using an unreviewed
package.

## Signed Module or Release Bundle

A signed, versioned Engineering Standards validator module or release bundle
could reduce repeated package retrieval and provide an additional publisher
identity. It is deferred because publishing and signing were not authorized and
the current validator spans scripts, actions, schemas, tests, examples, and
multiple third-party runtimes rather than a single PowerShell module. A future
proposal must define the signing key owner, protected build environment,
provenance attestation, timestamping, verification command, revocation,
retention, and offline distribution process before publication.

## Rollback

Rollback uses a reviewed pull request that restores the prior runner, runtime,
action SHAs, lock, requirements file, installer scripts, and workflow self-pins
as one consistent set. Rerun lock validation, the full aggregate suite, hosted
success and controlled-failure paths, artifact verification, and the downstream
canary before declaring the prior environment restored. Historical artifacts and
release evidence remain immutable.

## Related

- [Action Security](ACTION_SECURITY.md)
- [Maintainer Guide](MAINTAINER_GUIDE.md)
- [Release Process](RELEASE_PROCESS.md)
- [Troubleshooting](TROUBLESHOOTING.md)
- [Downstream Governance Canary](DOWNSTREAM_CANARY.md)
