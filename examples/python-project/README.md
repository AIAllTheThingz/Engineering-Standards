# Governed Python project

This deterministic package validates repository-relative paths and demonstrates first-class governed Python structure, tests, strict typing, packaging, dependency auditing, SBOM generation, and evidence. It performs no network or privileged behavior; only `pip-audit` queries the PyPI advisory service.

Use exact CPython 3.12.11, create an isolated environment, then run:

```powershell
python -m pip install --no-input --only-binary=:all: --require-hashes --no-deps -r requirements-ci.lock
pwsh -NoProfile -File tools/Test-Example.ps1
```

The trusted functional validator disables ambient pytest plugins and user site packages, supplies strict mypy and pytest arguments, builds without PEP 517 dependency isolation, inspects wheel/sdist paths, installs the wheel into a fresh environment, smoke-tests outside source imports, and writes reports under `evidence/`. Audit service failure is `Blocked`; a vulnerability or validation defect is `Failed`. Static governance continues to parse source as untrusted text without importing it.

Downstream workflows must use `contents: read`, an exact 40-character standards commit, exact Python 3.12.11, and the reusable `python-ci-reusable.yml` interface. Do not pass secrets. Inspect `python-tests.json`, `python-type-check.json`, `python-dependency-audit.json`, `python-build.json`, `python-project-sbom.cdx.json`, and completion evidence in the uploaded artifact.
