from __future__ import annotations

import importlib.util
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
    command = validator.module_command(Path("/trusted/python"), "pytest", "tests")
    require(command[:4] == ["/trusted/python", "-I", "-m", "pytest"], "trusted tool command omitted isolated mode")
