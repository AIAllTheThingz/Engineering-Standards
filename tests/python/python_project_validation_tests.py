from __future__ import annotations

import importlib.util
import json
import re
import runpy
import stat
import sys
import zipfile
from pathlib import Path

VALIDATOR = Path(__file__).resolve().parents[2] / "scripts" / "python-project-validation.py"
spec = importlib.util.spec_from_file_location("python_project_validation", VALIDATOR)
if spec is None or spec.loader is None:
    raise RuntimeError("could not load the governed Python validator")
validator = importlib.util.module_from_spec(spec)
spec.loader.exec_module(validator)


def require(condition: bool, message: str) -> None:
    if not condition:
        raise AssertionError(message)


def test_isolated_python_ignores_caller_module_shadowing(tmp_path: Path) -> None:
    caller = tmp_path / "caller"
    caller.mkdir()
    sentinel = tmp_path / "sentinel"
    (caller / "json.py").write_text(
        f"from pathlib import Path\nPath({str(sentinel)!r}).write_text('executed')\n",
        encoding="utf-8",
    )
    env = validator.trusted_env(tmp_path / "home")
    env["PYTHONPATH"] = str(caller)
    command = [sys.executable, "-I", "-c", "import json; print(json.__file__)"]
    code, output, _ = validator.run(command, caller, env, 60)
    require(code == 0, "isolated Python command failed")
    require(not sentinel.exists(), "caller shadow module executed")
    require(str(caller) not in output, "caller path affected isolated module resolution")


def test_trusted_environment_removes_python_and_tool_overrides(tmp_path: Path, monkeypatch) -> None:
    for name in ("PYTHONPATH", "PYTHONSTARTUP", "PYTEST_ADDOPTS", "MYPY_CONFIG_FILE", "RUFF_CACHE_DIR"):
        monkeypatch.setenv(name, "caller-controlled")
    env = validator.trusted_env(tmp_path / "home")
    require("PYTHONPATH" not in env, "PYTHONPATH remained in trusted environment")
    require("PYTHONSTARTUP" not in env, "PYTHONSTARTUP remained in trusted environment")
    require("PYTEST_ADDOPTS" not in env, "PYTEST_ADDOPTS remained in trusted environment")
    require("MYPY_CONFIG_FILE" not in env, "MYPY_CONFIG_FILE remained in trusted environment")
    require("RUFF_CACHE_DIR" not in env, "RUFF_CACHE_DIR remained in trusted environment")
    require(env["PYTEST_DISABLE_PLUGIN_AUTOLOAD"] == "1", "pytest plugin autoload was not disabled")


def test_wheel_symlink_is_rejected(tmp_path: Path) -> None:
    wheel = tmp_path / "example-1.0.0-py3-none-any.whl"
    info = zipfile.ZipInfo("unsafe-link")
    info.create_system = 3
    info.external_attr = (stat.S_IFLNK | 0o777) << 16
    with zipfile.ZipFile(wheel, "w") as archive:
        archive.writestr(info, "target")
    metadata = {"normalizedDistribution": "example", "version": "1.0.0", "distribution": "example"}
    try:
        validator.inspect_wheel(wheel, metadata)
    except ValueError as exc:
        require("link or special" in str(exc), "wheel link rejection returned the wrong error")
    else:
        raise AssertionError("wheel symlink was accepted")


def test_project_tree_rejects_nested_symlink(tmp_path: Path) -> None:
    project = tmp_path / "project"
    project.mkdir()
    target = tmp_path / "outside.txt"
    target.write_text("outside", encoding="utf-8")
    link = project / "linked.txt"
    try:
        link.symlink_to(target)
    except OSError:
        return
    try:
        validator.inspect_project_tree(project)
    except ValueError as exc:
        require("symbolic link" in str(exc), "nested link rejection returned the wrong error")
    else:
        raise AssertionError("nested symbolic link was accepted")


def test_module_command_always_uses_isolated_mode() -> None:
    python = Path("/trusted/python")
    command = validator.module_command(python, "pytest", "tests")
    require(command[:4] == [str(python), "-I", "-m", "pytest"], "trusted tool command omitted isolated mode")


def test_requirements_lock_accepts_current_input_and_lock() -> None:
    root = Path(__file__).resolve().parents[2]
    validator.validate_requirements_lock(
        root / "examples" / "python-project" / "requirements-ci.in",
        root / "examples" / "python-project" / "requirements-ci.lock",
    )


def test_requirements_lock_accepts_multiline_direct_provenance(tmp_path: Path) -> None:
    """A pip-compile multiline ``# via`` block still identifies a direct pin."""
    requirements_input = tmp_path / "requirements-ci.in"
    requirements_input.write_text("build==1.6.1\n", encoding="utf-8")
    lock = tmp_path / "requirements-ci.lock"
    lock.write_text(
        "build==1.6.1 \\\n"
        "    --hash=sha256:" + "0" * 64 + "\n"
        "    # via\n"
        "    #   -r requirements-ci.in\n",
        encoding="utf-8",
    )

    validator.validate_requirements_lock(requirements_input, lock)


def test_requirements_lock_rejects_stale_input(tmp_path: Path) -> None:
    requirements_input = tmp_path / "requirements-ci.in"
    requirements_input.write_text("build==1.6.1\n", encoding="utf-8")
    lock = tmp_path / "requirements-ci.lock"
    lock.write_text(
        "build==1.5.0 \\\n"
        "    --hash=sha256:" + "0" * 64 + "\n"
        "    # via -r requirements-ci.in\n",
        encoding="utf-8",
    )

    try:
        validator.validate_requirements_lock(requirements_input, lock)
    except ValueError as exc:
        message = str(exc)
        require("version mismatch" in message, "stale lock did not report a version mismatch")
        require("build==1.6.1" in message, "stale lock error omitted the input version")
    else:
        raise AssertionError("stale requirements lock was accepted")


def test_requirements_lock_rejects_unresolved_transitive_pin(tmp_path: Path) -> None:
    """A forged ``# via`` comment cannot authorize an unrelated lock entry."""
    requirements_input = tmp_path / "requirements-ci.in"
    requirements_input.write_text("build==1.6.1\n", encoding="utf-8")
    lock = tmp_path / "requirements-ci.lock"
    lock.write_text(
        "build==1.6.1 \\\n"
        "    --hash=sha256:" + "0" * 64 + "\n"
        "    # via -r requirements-ci.in\n"
        "evil==1.0 \\\n"
        "    --hash=sha256:" + "1" * 64 + "\n"
        "    # via build\n",
        encoding="utf-8",
    )
    report = tmp_path / "resolution.json"
    report.write_text(
        json.dumps(
            {
                "install": [
                    {"metadata": {"name": "build", "version": "1.6.1"}},
                ]
            }
        ),
        encoding="utf-8",
    )

    try:
        validator.validate_resolved_requirements_lock(requirements_input, lock, report)
    except ValueError as exc:
        require("unexpected locked packages" in str(exc), "injected lock package was not identified")
        require("evil==1.0" in str(exc), "injected package was omitted from the diagnostic")
    else:
        raise AssertionError("injected transitive lock entry was accepted")


def test_requirements_lock_accepts_reviewed_platform_only_pin(tmp_path: Path) -> None:
    requirements_input = tmp_path / "requirements-ci.in"
    requirements_input.write_text("build==1.6.1\n", encoding="utf-8")
    lock = tmp_path / "requirements-ci.lock"
    lock.write_text(
        "build==1.6.1 \\\n"
        "    --hash=sha256:" + "0" * 64 + "\n"
        "    # via -r requirements-ci.in\n"
        "colorama==0.4.6 \\\n"
        "    --hash=sha256:" + "1" * 64 + "\n"
        "    # via build\n",
        encoding="utf-8",
    )
    report = tmp_path / "resolution.json"
    report.write_text(
        json.dumps({"install": [{"metadata": {"name": "build", "version": "1.6.1"}}]}),
        encoding="utf-8",
    )
    validator.validate_resolved_requirements_lock(requirements_input, lock, report)


def test_toolchain_sbom_matches_governed_lock_requirements() -> None:
    """A stale inventory must not report prior build-backend versions or hashes."""
    root = Path(__file__).resolve().parents[2]
    lock_text = (root / "examples" / "python-project" / "requirements-ci.lock").read_text(encoding="utf-8")
    sbom = json.loads(
        (root / "examples" / "python-project" / "evidence" / "python-project-sbom.cdx.json").read_text(
            encoding="utf-8"
        )
    )
    components = {
        validator.normalized_requirement_name(component["name"]): component
        for component in sbom["components"]
    }

    for package in ("build", "hatchling", "pip"):
        lock_match = re.search(
            rf"(?ms)^{re.escape(package)}==([^\s\\]+)(.*?)(?=^[A-Za-z0-9_.-]+==|\Z)", lock_text
        )
        require(lock_match is not None, f"{package} is missing from the governed lock")
        component = components.get(package)
        require(component is not None, f"{package} is missing from the checked-in SBOM")
        require(component["version"] == lock_match.group(1), f"{package} SBOM version is stale")
        expected_hashes = set(re.findall(r"--hash=sha256:([0-9a-f]{64})", lock_match.group(0)))
        actual_hashes = {
            item["content"]
            for reference in component.get("externalReferences", [])
            for item in reference.get("hashes", [])
            if item.get("alg") == "SHA-256"
        }
        require(actual_hashes == expected_hashes, f"{package} SBOM hashes are stale")


def test_project_metadata_requires_governed_hatchling_version(tmp_path: Path) -> None:
    project = tmp_path / "project"
    package = project / "src" / "example_package"
    package.mkdir(parents=True)
    (package / "__init__.py").write_text("", encoding="utf-8")
    (project / "pyproject.toml").write_text(
        "[build-system]\n"
        "requires = [\"hatchling==1.32.4\"]\n"
        "build-backend = \"hatchling.build\"\n\n"
        "[project]\n"
        "name = \"example-package\"\n"
        "version = \"1.0.0\"\n",
        encoding="utf-8",
    )
    validator.parse_project_metadata(project)

    (project / "pyproject.toml").write_text(
        (project / "pyproject.toml").read_text(encoding="utf-8").replace("1.32.4", "1.32.0"),
        encoding="utf-8",
    )
    try:
        validator.parse_project_metadata(project)
    except ValueError as exc:
        require("hatchling==1.32.4" in str(exc), "old Hatchling error omitted governed version")
    else:
        raise AssertionError("ungoverned Hatchling version was accepted")
