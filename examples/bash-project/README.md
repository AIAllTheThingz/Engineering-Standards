# Governed Bash Project

This is a safe functional governed Bash example. It validates a relative path
against an explicit repository root and prints the normalized path. It does not
perform networking, package installation, privilege escalation, service
control, production operations, or destructive filesystem changes.

The supported runtime is GNU Bash 5.2 on Ubuntu 24.04 x86-64. The functional
baseline uses exact, hash-verified ShellCheck 0.11.0, shfmt 3.13.1, and Bats
1.13.0 from `bash-toolchain.lock.json`. GNU `realpath`, `pwd`, and standard file
tests are required. Other operating systems, Bash versions, and BSD utility
semantics are not claimed as supported.

## Usage

Resolve an existing or not-yet-created repository-relative path:

```bash
./cmd/governed-path ./fixtures/repository nested/new-file.txt
```

Require an existing regular file:

```bash
./cmd/governed-path --require-file ./fixtures/repository "nested/space name.txt"
```

Absolute paths, empty components, `.` and `..` components, symlink escapes,
missing required files, unsupported options, and failed child commands return a
nonzero status. Arguments remain arrays or individually quoted expansions;
the example does not use `eval` or predictable temporary paths.

## Validation

Run the local wrapper from Linux with PowerShell 7 and Python 3.12:

```powershell
pwsh -NoProfile -File tools/Test-Example.ps1
```

The wrapper uses the same standards-owned installer, trusted driver, exact
commands, isolated copy, and evidence normalization as hosted CI. Local
evidence remains `NotRun` overall for GitHub-hosted execution; it never claims
hosted validation. The hosted workflow uploads evidence before final
enforcement and keeps caller and standards identity separate.

When `-Offline` cannot find an exact locked artifact, the wrapper exits
nonzero after preserving the installer's truthful `Blocked` record at
`evidence/bash-toolchain-bootstrap.json`. It does not create functional phase
or completion evidence for a validation that never started, and removes stale
records from an earlier completed run.

Caller Bats execution requires Linux Landlock. Local runs require ABI 1 or
newer for filesystem isolation; hosted runs require ABI 4 or newer and also
deny TCP connect and bind. The driver sets `no_new_privs`, permits writes only
inside its isolated home and temporary roots, makes the project copy read-only,
and reaps detached descendants after timeout or completion. UDP and other
network families are not claimed to be isolated.

Downstream repositories must call
`.github/workflows/bash-ci-reusable.yml` at a full immutable 40-character
standards commit SHA with `contents: read` and without secrets or environments.

## Evidence

The `evidence/` directory contains local syntax, ShellCheck, formatting, Bats,
toolchain, CycloneDX 1.5 SBOM, aggregate test, and completion records. Hosted
artifacts use `completion-result.json`, `evidence-validation.json`, and
`step-outcomes.json` in addition to the phase records. Missing, failed,
blocked, cancelled, or unexpectedly skipped mandatory evidence fails closed.

## Rollback

Revert the Bash functional-support implementation and its separate pin commit,
then restore downstream callers to the previously reviewed governance workflow.
The example has no external state or irreversible effects.
