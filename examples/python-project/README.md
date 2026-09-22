# Governed Python project

This deterministic package validates repository-relative paths and demonstrates first-class governed Python structure, tests, strict typing, packaging, dependency auditing, SBOM generation, and evidence. It performs no network or privileged behavior; only `pip-audit` queries the PyPI advisory service.

Use exact CPython 3.12.11, create an isolated environment, then run:

```powershell
python -m pip install --no-input --only-binary=:all: --require-hashes --no-deps -r requirements-ci.lock
pwsh -NoProfile -File tools/Test-Example.ps1
```

The trusted functional validator disables ambient pytest plugins and user site packages, supplies strict mypy and pytest arguments, builds without PEP 517 dependency isolation, inspects wheel/sdist paths, installs the wheel into a fresh environment, smoke-tests outside source imports, and writes reports under `evidence/`. Audit service failure is `Blocked`; a vulnerability or validation defect is `Failed`. Static governance continues to parse source as untrusted text without importing it.

Downstream workflows must use `contents: read`, an exact 40-character standards commit, exact Python 3.12.11, and the reusable `python-ci-reusable.yml` interface. Do not pass secrets. Inspect `python-tests.json`, `python-type-check.json`, `python-dependency-audit.json`, `python-build.json`, `python-project-sbom.cdx.json`, and completion evidence in the uploaded artifact.

## Documentation check

From the Engineering-Standards repository root, validate this example's required
documents with:

```powershell
pwsh -NoProfile -File scripts/Test-DocumentationCompleteness.ps1 -Path examples/python-project
```

This checks the documentation selected by the local governance configuration.
It does not execute the example or replace its functional validation commands.
Read the local security and contribution instructions before adapting inputs
or changing the demonstrated behavior.

## Interpreting results

Keep synthetic demonstrations separate from operational evidence. A passing
local check establishes only the behavior actually exercised with those inputs.
Record missing prerequisites and unavailable checks explicitly; do not infer
hosted execution, deployment readiness, or approval. When reporting a failure,
include the command, working directory, exit code, and a sanitized reproduction
so maintainers can distinguish an example defect from an environment limitation.
