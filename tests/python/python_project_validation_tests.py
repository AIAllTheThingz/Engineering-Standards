from __future__ import annotations

import importlib.util
import inspect
import json
import re
import runpy
import stat
import sys
import tomllib
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


def test_toolchain_sbom_metadata_is_standards_owned(tmp_path: Path, monkeypatch) -> None:
    monkeypatch.chdir(tmp_path.parent)
    metadata_path = validator.write_toolchain_sbom_pyproject(Path(tmp_path.name))
    require(metadata_path.is_absolute(), "toolchain SBOM metadata path must be absolute")
    require(
        metadata_path.is_relative_to(tmp_path.resolve()),
        "toolchain SBOM metadata must remain inside the trusted work root",
    )
    metadata = tomllib.loads(metadata_path.read_text(encoding="utf-8"))
    project = metadata.get("project", {})
    require(
        project.get("name") == "engineering-standards-python-toolchain",
        "toolchain SBOM metadata must use the standards-owned root name",
    )
    require(
        project.get("requires-python") == ">=3.13,<3.14",
        "toolchain SBOM metadata must remain tied to the governed resolver range",
    )


def test_toolchain_sbom_root_references_every_toolchain_component(tmp_path: Path) -> None:
    """The standards-owned SBOM root must expose the governed toolchain closure."""
    sbom_path = tmp_path / "python-toolchain-sbom.cdx.json"
    sbom_path.write_text(
        json.dumps(
            {
                "metadata": {"component": {"bom-ref": "root-component"}},
                "components": [
                    {"bom-ref": "requirements-L7", "name": "build"},
                    {"bom-ref": "requirements-L11", "name": "hatchling"},
                ],
                "dependencies": [
                    {"ref": "requirements-L7"},
                    {"ref": "requirements-L11"},
                    {"ref": "root-component"},
                ],
            }
        ),
        encoding="utf-8",
    )

    validator.attach_sbom_root_dependencies(sbom_path)

    sbom = json.loads(sbom_path.read_text(encoding="utf-8"))
    root_dependency = next(item for item in sbom["dependencies"] if item["ref"] == "root-component")
    require(
        root_dependency.get("dependsOn") == ["requirements-L7", "requirements-L11"],
        "toolchain SBOM root must depend on every toolchain component",
    )


def test_project_sbom_root_references_every_runtime_component(tmp_path: Path) -> None:
    """The project SBOM root must expose the governed runtime closure too."""
    sbom_path = tmp_path / "python-project-sbom.cdx.json"
    sbom_path.write_text(
        json.dumps(
            {
                "metadata": {"component": {"bom-ref": "project-root"}},
                "components": [{"bom-ref": "runtime-L7", "name": "requests"}],
                "dependencies": [{"ref": "runtime-L7"}, {"ref": "project-root"}],
            }
        ),
        encoding="utf-8",
    )

    validator.attach_sbom_root_dependencies(sbom_path)

    sbom = json.loads(sbom_path.read_text(encoding="utf-8"))
    root_dependency = next(item for item in sbom["dependencies"] if item["ref"] == "project-root")
    require(
        root_dependency.get("dependsOn") == ["runtime-L7"],
        "project SBOM root must depend on every runtime component",
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


def test_requirements_lock_accepts_dependency_resolved_on_another_target(tmp_path: Path) -> None:
    """A universal lock retains pins resolved by at least one real target report."""
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
    linux_report = tmp_path / "linux-resolution.json"
    linux_report.write_text(
        json.dumps(
            {
                "install": [
                    {
                        "metadata": {
                            "name": "build",
                            "version": "1.6.1",
                        }
                    },
                ]
            }
        ),
        encoding="utf-8",
    )
    windows_report = tmp_path / "windows-resolution.json"
    windows_report.write_text(
        json.dumps(
            {
                "install": [
                    {"metadata": {"name": "build", "version": "1.6.1"}},
                    {"metadata": {"name": "colorama", "version": "0.4.6"}},
                ]
            }
        ),
        encoding="utf-8",
    )

    validator.validate_resolved_requirements_lock(
        requirements_input,
        lock,
        (linux_report, windows_report),
    )


def test_requirements_lock_rejects_marker_package_omitted_from_unverified_report(
    tmp_path: Path,
) -> None:
    """A marker package needs a supplemental target-specific closure report."""
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
    cross_target_report = tmp_path / "cross-target-resolution.json"
    cross_target_report.write_text(
        json.dumps(
            {
                "install": [
                    {
                        "metadata": {
                            "name": "build",
                            "version": "1.6.1",
                            "requires_dist": ["colorama==0.4.6; sys_platform == 'win32'"],
                        }
                    },
                ]
            }
        ),
        encoding="utf-8",
    )

    try:
        validator.validate_resolved_requirements_lock(requirements_input, lock, cross_target_report)
    except ValueError as exc:
        message = str(exc)
        require("unexpected locked packages" in message, "unverified marker package was accepted")
        require("colorama==0.4.6" in message, "marker package was omitted from the diagnostic")
    else:
        raise AssertionError("marker package omitted from its closure report was accepted")


def test_marker_closure_keeps_dependency_with_active_non_extra_condition() -> None:
    """An active condition must not be discarded merely because a marker also mentions extras."""
    records = [
        {
            "metadata": {
                "name": "build",
                "version": "1.6.1",
                "requires_dist": [
                    "marker-parent==1.0.0; sys_platform == 'win32' or extra == 'feature'"
                ],
            }
        }
    ]

    marker_requirements = validator.marker_gated_requirements_for_target(
        records,
        {"marker-parent": "1.0.0"},
        validator.LOCK_RESOLUTION_TARGET_MARKER_ENVIRONMENTS[1],
        "windows-cpython-3.13.2-x86_64",
    )

    require(
        marker_requirements == {"marker-parent": ("1.0.0", ())},
        "an active non-extra marker condition was discarded",
    )


def test_marker_closure_does_not_evaluate_empty_extra_when_an_extra_is_active() -> None:
    """A requested extra must not also activate dependencies for the empty-extra context."""
    records = [
        {
            "metadata": {
                "name": "marker-parent",
                "version": "1.0.0",
                "requires_dist": ["marker-child==2.0.0; extra != 'feature'"],
            }
        }
    ]

    marker_requirements = validator.marker_gated_requirements_for_target(
        records,
        {"marker-child": "2.0.0"},
        validator.LOCK_RESOLUTION_TARGET_MARKER_ENVIRONMENTS[0],
        "linux-cpython-3.13.2-manylinux_2_17_x86_64",
        {"marker-parent": ("feature",)},
    )

    require(
        marker_requirements == {},
        "an active extra was incorrectly evaluated together with the empty-extra context",
    )


def test_marker_closure_rejects_oscillating_extra_activation(tmp_path: Path) -> None:
    """A self-requested extra must fail explicitly rather than spin until workflow timeout."""
    child_program = f"""
import runpy

validator = runpy.run_path({str(VALIDATOR)!r})
try:
    validator["marker_gated_requirements_for_target"](
        [
            {{
                "metadata": {{
                    "name": "a",
                    "version": "1.0.0",
                    "requires_dist": ["a[feature]==1.0.0; extra != 'feature'"],
                }}
            }}
        ],
        {{"a": "1.0.0"}},
        validator["LOCK_RESOLUTION_TARGET_MARKER_ENVIRONMENTS"][0],
        "linux-cpython-3.13.2-manylinux_2_17_x86_64",
    )
except ValueError as exc:
    if "extra activation state did not converge" not in str(exc):
        raise AssertionError(f"unexpected oscillation error: {{exc}}") from exc
else:
    raise AssertionError("oscillating extra activation was accepted")
"""
    code, output, _ = validator.run(
        [sys.executable, "-I", "-c", child_program],
        tmp_path,
        validator.trusted_env(tmp_path / "home"),
        3,
    )

    require(code != 124, "oscillating extra activation did not terminate")
    require(
        code == 0,
        f"oscillating extra activation was not rejected explicitly:\n{output}",
    )


def test_windows_marker_environment_matches_declared_amd64_target() -> None:
    """The synthetic Windows markers must match the declared win_amd64 target."""
    records = [
        {
            "metadata": {
                "name": "build",
                "version": "1.6.1",
                "requires_dist": ["marker-parent==1.0.0; platform_machine == 'AMD64'"],
            }
        }
    ]

    marker_requirements = validator.marker_gated_requirements_for_target(
        records,
        {"marker-parent": "1.0.0"},
        validator.LOCK_RESOLUTION_TARGET_MARKER_ENVIRONMENTS[1],
        "windows-cpython-3.13.2-x86_64",
    )

    require(
        marker_requirements == {"marker-parent": ("1.0.0", ())},
        "the Windows marker environment does not model win_amd64",
    )


def test_windows_marker_environment_models_declared_release() -> None:
    """The synthetic Windows target must cover release-gated dependencies."""
    records = [
        {
            "metadata": {
                "name": "build",
                "version": "1.6.1",
                "requires_dist": [
                    "marker-parent==1.0.0; sys_platform == 'win32' and platform_release == '10'"
                ],
            }
        }
    ]

    marker_requirements = validator.marker_gated_requirements_for_target(
        records,
        {"marker-parent": "1.0.0"},
        validator.LOCK_RESOLUTION_TARGET_MARKER_ENVIRONMENTS[1],
        "windows-cpython-3.13.2-x86_64",
    )

    require(
        marker_requirements == {"marker-parent": ("1.0.0", ())},
        "the Windows marker environment does not model platform_release 10",
    )


def test_windows_marker_environment_models_declared_platform_version() -> None:
    """The synthetic Windows target must cover its declared platform-version baseline."""
    records = [
        {
            "metadata": {
                "name": "build",
                "version": "1.6.1",
                "requires_dist": [
                    "marker-parent==1.0.0; "
                    "sys_platform == 'win32' and platform_version == '10.0.19045'"
                ],
            }
        }
    ]

    marker_requirements = validator.marker_gated_requirements_for_target(
        records,
        {"marker-parent": "1.0.0"},
        validator.LOCK_RESOLUTION_TARGET_MARKER_ENVIRONMENTS[1],
        "windows-cpython-3.13.2-x86_64",
    )

    require(
        marker_requirements == {"marker-parent": ("1.0.0", ())},
        "the Windows marker environment does not model platform_version 10.0.19045",
    )


def test_marker_closure_preserves_and_merges_requested_extras() -> None:
    """Marker-active extras must survive into one deterministic supplemental request."""
    records = [
        {
            "metadata": {
                "name": "build",
                "version": "1.6.1",
                "requires_dist": [
                    "marker-parent[feature-one]==1.0.0; sys_platform == 'win32'",
                    "marker-parent[feature-two]==1.0.0; sys_platform == 'win32'",
                ],
            }
        }
    ]

    marker_requirements = validator.marker_gated_requirements_for_target(
        records,
        {"marker-parent": "1.0.0"},
        validator.LOCK_RESOLUTION_TARGET_MARKER_ENVIRONMENTS[1],
        "windows-cpython-3.13.2-x86_64",
    )

    require(
        marker_requirements == {"marker-parent": ("1.0.0", ("feature-one", "feature-two"))},
        "marker-gated extras were not preserved and merged",
    )
    require(
        validator.marker_resolution_requirement(
            "marker-parent", "1.0.0", ("feature-one", "feature-two")
        )
        == "marker-parent[feature-one,feature-two]==1.0.0",
        "supplemental marker resolution discarded requested extras",
    )


def test_marker_gated_requirements_reject_direct_url_dependencies() -> None:
    """Closure validation must not rewrite a direct artifact URL as a registry pin."""
    records = [
        {
            "metadata": {
                "name": "build",
                "version": "1.6.1",
                "requires_dist": [
                    "marker-child @ https://example.invalid/marker-child-2.0.0.whl ; "
                    "sys_platform == 'win32'"
                ],
            }
        }
    ]

    try:
        validator.marker_gated_requirements_for_target(
            records,
            {"marker-child": "2.0.0"},
            validator.LOCK_RESOLUTION_TARGET_MARKER_ENVIRONMENTS[1],
            "windows-cpython-3.13.2-x86_64",
        )
    except ValueError as exc:
        require("direct URL" in str(exc), "direct URL rejection returned the wrong diagnostic")
    else:
        raise AssertionError("direct URL dependency was rewritten as a registry pin")


def test_macos_marker_environment_models_declared_release_and_version() -> None:
    """The macOS 13.0 target must evaluate its declared Darwin marker values."""
    records = [
        {
            "metadata": {
                "name": "build",
                "version": "1.6.1",
                "requires_dist": [
                    "marker-release==1.0.0; "
                    f"sys_platform == 'darwin' and platform_release == '{validator.MACOS_13_0_PLATFORM_RELEASE}'",
                    "marker-version==1.0.0; "
                    f"sys_platform == 'darwin' and platform_version == '{validator.MACOS_13_0_PLATFORM_VERSION}'",
                ],
            }
        }
    ]

    marker_requirements = validator.marker_gated_requirements_for_target(
        records,
        {"marker-release": "1.0.0", "marker-version": "1.0.0"},
        validator.LOCK_RESOLUTION_TARGET_MARKER_ENVIRONMENTS[2],
        "macos-cpython-3.13.2-x86_64",
    )

    require(
        marker_requirements
        == {"marker-release": ("1.0.0", ()), "marker-version": ("1.0.0", ())},
        "the macOS marker environment does not model its declared Darwin release and version",
    )


def test_linux_marker_environment_rejects_unmodeled_release_and_version() -> None:
    """Linux marker closure must fail closed instead of treating unknown values as inactive."""
    for field, value in (("platform_release", "6.8.0"), ("platform_version", "Linux 6.8.0")):
        records = [
            {
                "metadata": {
                    "name": "build",
                    "version": "1.6.1",
                    "requires_dist": [
                        f"marker-parent==1.0.0; sys_platform == 'linux' and {field} == '{value}'"
                    ],
                }
            }
        ]

        try:
            validator.marker_gated_requirements_for_target(
                records,
                {"marker-parent": "1.0.0"},
                validator.LOCK_RESOLUTION_TARGET_MARKER_ENVIRONMENTS[0],
                "linux-cpython-3.13.2-manylinux_2_17_x86_64",
            )
        except ValueError as exc:
            message = str(exc)
            require(field in message, f"the {field} diagnostic omitted the unmodeled marker")
            require("linux-cpython-3.13.2-manylinux_2_17_x86_64" in message, "the target was omitted")
        else:
            raise AssertionError(f"an unmodeled Linux {field} marker was treated as inactive")


def test_linux_marker_environment_skips_target_excluding_unmodeled_release_and_version() -> None:
    """A target-excluding clause must short-circuit an otherwise unmodeled field."""
    for field, value in (("platform_release", "10"), ("platform_version", "10.0.19045")):
        records = [
            {
                "metadata": {
                    "name": "build",
                    "version": "1.6.1",
                    "requires_dist": [
                        f"marker-parent==1.0.0; sys_platform == 'win32' and {field} == '{value}'"
                    ],
                }
            }
        ]

        marker_requirements = validator.marker_gated_requirements_for_target(
            records,
            {"marker-parent": "1.0.0"},
            validator.LOCK_RESOLUTION_TARGET_MARKER_ENVIRONMENTS[0],
            "linux-cpython-3.13.2-manylinux_2_17_x86_64",
        )

        require(
            marker_requirements == {},
            f"a target-excluding Linux {field} marker was not short-circuited",
        )


def test_requirements_lock_metadata_parser_rejects_an_unpinned_pip(monkeypatch) -> None:
    """PEP 508 parsing must not silently inherit the workflow interpreter's pip."""
    fake_pip = type("FakePip", (), {"__version__": "26.2.0"})
    monkeypatch.setitem(sys.modules, "pip", fake_pip)

    try:
        validator.require_pinned_lock_metadata_parser()
    except ValueError as exc:
        require("pip==26.2.1" in str(exc), "the unpinned parser diagnostic omitted the governed pip")
    else:
        raise AssertionError("an unpinned metadata parser was accepted")


def test_bootstrap_lock_metadata_parser_records_the_verified_parser_path(
    tmp_path: Path, monkeypatch
) -> None:
    """The workflow bootstrap must hand verification only an exact-pip parser runtime."""
    lock = tmp_path / "requirements-ci.lock"
    lock.write_text("pip==26.2.1 \\\n    --hash=sha256:" + "0" * 64 + "\n", encoding="utf-8")
    source_python = tmp_path / "source-python"
    source_python.touch()
    parser_python = tmp_path / "lock-metadata-parser" / "python"
    parser_python.parent.mkdir()
    parser_python.touch()
    output_path = tmp_path / "parser-path.txt"
    calls: list[tuple[Path, str, Path]] = []

    def fake_pinned_resolver(
        source: Path, label: str, _lock: Path, environment: Path, _env: dict[str, str]
    ) -> Path:
        calls.append((source, label, environment))
        return parser_python

    monkeypatch.setattr(validator, "pinned_lock_resolver", fake_pinned_resolver)
    validator.bootstrap_pinned_lock_metadata_parser(
        source_python,
        lock,
        tmp_path / "work",
        output_path,
    )

    require(calls == [(source_python, "lock metadata parser", tmp_path / "work" / "lock-metadata-parser")], "the parser bootstrap did not use the dedicated pinned resolver")
    require(output_path.read_text(encoding="utf-8").strip() == str(parser_python.resolve()), "the parser bootstrap did not record the verified interpreter")


def test_pinned_lock_resolver_bootstraps_the_hash_pinned_pip(tmp_path: Path, monkeypatch) -> None:
    """Closure resolution must replace an interpreter's bundled pip with the governed pin."""
    lock = tmp_path / "requirements-ci.lock"
    first_hash = "1" * 64
    second_hash = "2" * 64
    lock.write_text(
        "pip==26.2.1 \\\n"
        f"    --hash=sha256:{first_hash} \\\n"
        f"    --hash=sha256:{second_hash}\n",
        encoding="utf-8",
    )
    source_python = tmp_path / "source-python"
    source_python.touch()
    environment = tmp_path / "resolver"
    resolver_python = environment / ("Scripts/python.exe" if validator.os.name == "nt" else "bin/python")
    commands: list[list[str]] = []

    def fake_run(command: list[str], cwd: Path, env: dict[str, str], timeout: int = 300) -> tuple[int, str, float]:
        commands.append(command)
        if command[2:4] == ["-m", "venv"]:
            resolver_python.parent.mkdir(parents=True)
            resolver_python.touch()
            return 0, "", 0.0
        if command[2:4] == ["-m", "pip"]:
            require(command[0] == str(resolver_python), "pip did not run from the temporary resolver environment")
            return 0, "", 0.0
        if command[2] == "-c":
            return 0, "26.2.1\n", 0.0
        raise AssertionError(f"unexpected command: {command}")

    monkeypatch.setattr(validator, "run", fake_run)
    actual = validator.pinned_lock_resolver(
        source_python,
        "test resolver",
        lock,
        environment,
        validator.trusted_env(tmp_path / "home"),
    )

    require(actual == resolver_python, "the pinned resolver did not return its virtual-environment Python")
    bootstrap = next(command for command in commands if command[2:4] == ["-m", "pip"])
    require("--require-hashes" in bootstrap, "resolver pip installation did not enforce hashes")
    require("--force-reinstall" in bootstrap, "resolver pip installation trusted the bundled pip")
    require("--no-deps" in bootstrap, "resolver pip installation could resolve unpinned dependencies")
    bootstrap_input = Path(bootstrap[bootstrap.index("-r") + 1])
    bootstrap_text = bootstrap_input.read_text(encoding="utf-8")
    require("pip==26.2.1" in bootstrap_text, "resolver pip installation used the wrong pip version")
    require(f"--hash=sha256:{first_hash}" in bootstrap_text, "first governed pip hash was omitted")
    require(f"--hash=sha256:{second_hash}" in bootstrap_text, "second governed pip hash was omitted")


def test_pinned_lock_resolver_classifies_venv_timeout_as_blocked(tmp_path: Path, monkeypatch) -> None:
    """A timed-out resolver environment bootstrap is an unavailable prerequisite."""
    lock = tmp_path / "requirements-ci.lock"
    lock.write_text(
        "pip==26.2.1 \\\n"
        f"    --hash=sha256:{'4' * 64}\n",
        encoding="utf-8",
    )
    source_python = tmp_path / "source-python"
    source_python.touch()
    environment = tmp_path / "resolver"

    def fake_run(command: list[str], cwd: Path, env: dict[str, str], timeout: int = 300) -> tuple[int, str, float]:
        require(command[2:4] == ["-m", "venv"], "unexpected command before resolver venv timeout")
        return 124, "command timed out after 120 seconds", 120.0

    monkeypatch.setattr(validator, "run", fake_run)
    try:
        validator.pinned_lock_resolver(
            source_python,
            "test resolver",
            lock,
            environment,
            validator.trusted_env(tmp_path / "home"),
        )
    except validator.LockResolutionBlockedError as exc:
        require("could not create the test resolver resolver environment" in str(exc), "venv timeout diagnostic was lost")
    else:
        raise AssertionError("resolver venv timeout was not classified as blocked")

def test_pinned_lock_resolver_rejects_an_unhashed_pip_pin(tmp_path: Path) -> None:
    """The lock cannot delegate resolver integrity to an unhashed pip pin."""
    lock = tmp_path / "requirements-ci.lock"
    lock.write_text("pip==26.2.1\n", encoding="utf-8")

    try:
        validator.locked_requirement_hashes(lock, "pip", "26.2.1")
    except ValueError as exc:
        require("hash-pin" in str(exc), "an unhashed resolver pip failed without a clear diagnostic")
    else:
        raise AssertionError("an unhashed resolver pip was accepted")


def test_pinned_lock_resolver_rejects_a_wrong_installed_pip_version(tmp_path: Path, monkeypatch) -> None:
    """A successful bootstrap is insufficient unless the selected pip version is exact."""
    lock = tmp_path / "requirements-ci.lock"
    lock.write_text(
        "pip==26.2.1 \\\n"
        f"    --hash=sha256:{'3' * 64}\n",
        encoding="utf-8",
    )
    source_python = tmp_path / "source-python"
    source_python.touch()
    environment = tmp_path / "resolver"
    resolver_python = environment / ("Scripts/python.exe" if validator.os.name == "nt" else "bin/python")

    def fake_run(command: list[str], cwd: Path, env: dict[str, str], timeout: int = 300) -> tuple[int, str, float]:
        if command[2:4] == ["-m", "venv"]:
            resolver_python.parent.mkdir(parents=True)
            resolver_python.touch()
            return 0, "", 0.0
        if command[2:4] == ["-m", "pip"]:
            return 0, "", 0.0
        if command[2] == "-c":
            return 0, "26.2.0\n", 0.0
        raise AssertionError(f"unexpected command: {command}")

    monkeypatch.setattr(validator, "run", fake_run)
    try:
        validator.pinned_lock_resolver(
            source_python,
            "test resolver",
            lock,
            environment,
            validator.trusted_env(tmp_path / "home"),
        )
    except ValueError as exc:
        require("pip==26.2.1" in str(exc), "the unexpected resolver pip version was not identified")
    else:
        raise AssertionError("an unexpected resolver pip version was accepted")


def test_requirements_lock_closure_resolves_marker_gated_transitive_chain(
    tmp_path: Path, monkeypatch
) -> None:
    """Marker-only dependencies are recursively resolved for their active target."""
    requirements_input = tmp_path / "requirements-ci.in"
    requirements_input.write_text("build==1.6.1\n", encoding="utf-8")
    lock = tmp_path / "requirements-ci.lock"
    lock.write_text(
        "build==1.6.1 \\\n"
        "    --hash=sha256:" + "0" * 64 + "\n"
        "    # via -r requirements-ci.in\n"
        "marker-parent==1.0.0 \\\n"
        "    --hash=sha256:" + "1" * 64 + "\n"
        "    # via build\n"
        "marker-child==2.0.0 \\\n"
        "    --hash=sha256:" + "2" * 64 + "\n"
        "    # via marker-parent\n",
        encoding="utf-8",
    )
    resolver_python = tmp_path / "resolver-python"
    runtime_python = tmp_path / "runtime-python"
    resolver_python.touch()
    runtime_python.touch()
    requested_roots: list[tuple[str, list[str]]] = []

    def fake_run(command: list[str], cwd: Path, env: dict[str, str], timeout: int = 300) -> tuple[int, str, float]:
        if command[2] == "-c":
            expected = "cpython 3.13.2" if command[0] == str(resolver_python) else "cpython 3.12.11"
            return 0, expected + "\n", 0.0
        report = Path(command[command.index("--report") + 1])
        requested = Path(command[command.index("-r") + 1]).read_text(encoding="utf-8").strip()
        requested_roots.append((requested, command))
        if requested == "build==1.6.1":
            installs = [
                {
                    "metadata": {
                        "name": "build",
                        "version": "1.6.1",
                        "requires_dist": [
                            "marker-parent[feature-one]==1.0.0; sys_platform == 'win32'",
                            "marker-parent[feature-two]==1.0.0; sys_platform == 'win32'",
                        ],
                    }
                }
            ]
        elif requested == "marker-parent[feature-one,feature-two]==1.0.0":
            installs = [
                {
                    "metadata": {
                        "name": "marker-parent",
                        "version": "1.0.0",
                        "requires_dist": [
                            "marker-child==2.0.0; "
                            "extra == 'feature-one' and sys_platform == 'win32'"
                        ],
                    }
                }
            ]
        elif requested == "marker-child==2.0.0":
            installs = [{"metadata": {"name": "marker-child", "version": "2.0.0"}}]
        else:
            raise AssertionError(f"unexpected marker resolution request: {requested}")
        report.write_text(json.dumps({"install": installs}), encoding="utf-8")
        return 0, "", 0.0

    monkeypatch.setattr(validator, "run", fake_run)
    monkeypatch.setattr(
        validator,
        "pinned_lock_resolver",
        lambda python, _label, _lock, _environment, _env: python,
    )
    validator.validate_requirements_lock_closure(
        requirements_input,
        lock,
        resolver_python,
        runtime_python,
        tmp_path / "work",
    )

    marker_requests = [requested for requested, _command in requested_roots if requested != "build==1.6.1"]
    require(
        marker_requests
        == ["marker-parent[feature-one,feature-two]==1.0.0", "marker-child==2.0.0"],
        "marker closure did not preserve extras while resolving recursively",
    )
    for requested, command in requested_roots:
        if requested != "build==1.6.1":
            require("--platform" in command and "win_amd64" in command, "marker closure used the wrong target")


def test_requirements_lock_closure_filters_runner_only_dependencies_from_marker_reports(
    tmp_path: Path, monkeypatch
) -> None:
    """A supplemental report must retain only dependencies active for its synthetic target."""
    requirements_input = tmp_path / "requirements-ci.in"
    requirements_input.write_text("build==1.6.1\n", encoding="utf-8")
    lock = tmp_path / "requirements-ci.lock"
    lock.write_text(
        "build==1.6.1 \\\n"
        "    --hash=sha256:" + "0" * 64 + "\n"
        "    # via -r requirements-ci.in\n"
        "marker-parent==1.0.0 \\\n"
        "    --hash=sha256:" + "1" * 64 + "\n"
        "    # via build\n",
        encoding="utf-8",
    )
    resolver_python = tmp_path / "resolver-python"
    runtime_python = tmp_path / "runtime-python"
    resolver_python.touch()
    runtime_python.touch()

    def fake_run(command: list[str], cwd: Path, env: dict[str, str], timeout: int = 300) -> tuple[int, str, float]:
        if command[2] == "-c":
            expected = "cpython 3.13.2" if command[0] == str(resolver_python) else "cpython 3.12.11"
            return 0, expected + "\n", 0.0
        report = Path(command[command.index("--report") + 1])
        requested = Path(command[command.index("-r") + 1]).read_text(encoding="utf-8").strip()
        if requested == "build==1.6.1":
            installs = [
                {
                    "metadata": {
                        "name": "build",
                        "version": "1.6.1",
                        "requires_dist": ["marker-parent==1.0.0; sys_platform == 'win32'"],
                    }
                }
            ]
        elif requested == "marker-parent==1.0.0":
            # The resolver host is Linux even while the request targets Windows.
            installs = [
                {
                    "metadata": {
                        "name": "marker-parent",
                        "version": "1.0.0",
                        "requires_dist": ["runner-child==2.0.0; sys_platform == 'linux'"],
                    }
                },
                {"metadata": {"name": "runner-child", "version": "2.0.0"}},
            ]
        else:
            raise AssertionError(f"unexpected marker resolution request: {requested}")
        report.write_text(json.dumps({"install": installs}), encoding="utf-8")
        return 0, "", 0.0

    monkeypatch.setattr(validator, "run", fake_run)
    monkeypatch.setattr(
        validator,
        "pinned_lock_resolver",
        lambda python, _label, _lock, _environment, _env: python,
    )
    validator.validate_requirements_lock_closure(
        requirements_input,
        lock,
        resolver_python,
        runtime_python,
        tmp_path / "work",
    )


def test_requirements_lock_closure_skips_target_inactive_sources_in_base_reports(
    tmp_path: Path, monkeypatch
) -> None:
    """A source package inactive for a target must not activate its own target-only children."""
    requirements_input = tmp_path / "requirements-ci.in"
    requirements_input.write_text("build==1.6.1\n", encoding="utf-8")
    lock = tmp_path / "requirements-ci.lock"
    lock.write_text(
        "build==1.6.1 \\\n"
        "    --hash=sha256:" + "0" * 64 + "\n"
        "    # via -r requirements-ci.in\n"
        "linux-parent==1.0.0 \\\n"
        "    --hash=sha256:" + "1" * 64 + "\n"
        "    # via build\n",
        encoding="utf-8",
    )
    resolver_python = tmp_path / "resolver-python"
    runtime_python = tmp_path / "runtime-python"
    resolver_python.touch()
    runtime_python.touch()
    marker_requests: list[str] = []

    def fake_run(command: list[str], cwd: Path, env: dict[str, str], timeout: int = 300) -> tuple[int, str, float]:
        if command[2] == "-c":
            expected = "cpython 3.13.2" if command[0] == str(resolver_python) else "cpython 3.12.11"
            return 0, expected + "\n", 0.0
        report = Path(command[command.index("--report") + 1])
        requested = Path(command[command.index("-r") + 1]).read_text(encoding="utf-8").strip()
        if requested != "build==1.6.1":
            marker_requests.append(requested)
            raise AssertionError(f"target-inactive source triggered marker resolution: {requested}")
        # The Linux resolver host includes linux-parent even for a Windows target.
        report.write_text(
            json.dumps(
                {
                    "install": [
                        {
                            "metadata": {
                                "name": "build",
                                "version": "1.6.1",
                                "requires_dist": [
                                    "linux-parent==1.0.0; sys_platform == 'linux'"
                                ],
                            }
                        },
                        {
                            "metadata": {
                                "name": "linux-parent",
                                "version": "1.0.0",
                                "requires_dist": [
                                    "windows-child==2.0.0; sys_platform == 'win32'"
                                ],
                            }
                        },
                    ]
                }
            ),
            encoding="utf-8",
        )
        return 0, "", 0.0

    monkeypatch.setattr(validator, "run", fake_run)
    monkeypatch.setattr(
        validator,
        "pinned_lock_resolver",
        lambda python, _label, _lock, _environment, _env: python,
    )
    validator.validate_requirements_lock_closure(
        requirements_input,
        lock,
        resolver_python,
        runtime_python,
        tmp_path / "work",
    )
    require(marker_requests == [], "a target-inactive base source triggered supplemental resolution")


def test_requirements_lock_closure_replaces_reports_when_activated_extras_expand(
    tmp_path: Path, monkeypatch
) -> None:
    """An obsolete no-extra report must not retain dependencies excluded by a later active extra."""
    requirements_input = tmp_path / "requirements-ci.in"
    requirements_input.write_text("build==1.6.1\n", encoding="utf-8")
    lock = tmp_path / "requirements-ci.lock"
    lock.write_text(
        "build==1.6.1 \\\n"
        "    --hash=sha256:" + "0" * 64 + "\n"
        "    # via -r requirements-ci.in\n"
        "marker-parent==1.0.0 \\\n"
        "    --hash=sha256:" + "1" * 64 + "\n"
        "    # via build\n"
        "zz-activator==1.0.0 \\\n"
        "    --hash=sha256:" + "2" * 64 + "\n"
        "    # via build\n",
        encoding="utf-8",
    )
    resolver_python = tmp_path / "resolver-python"
    runtime_python = tmp_path / "runtime-python"
    resolver_python.touch()
    runtime_python.touch()
    marker_requests: list[str] = []

    def fake_run(command: list[str], cwd: Path, env: dict[str, str], timeout: int = 300) -> tuple[int, str, float]:
        if command[2] == "-c":
            expected = "cpython 3.13.2" if command[0] == str(resolver_python) else "cpython 3.12.11"
            return 0, expected + "\n", 0.0
        report = Path(command[command.index("--report") + 1])
        requested = Path(command[command.index("-r") + 1]).read_text(encoding="utf-8").strip()
        if requested == "build==1.6.1":
            installs = [
                {
                    "metadata": {
                        "name": "build",
                        "version": "1.6.1",
                        "requires_dist": [
                            "marker-parent==1.0.0; sys_platform == 'win32'",
                            "zz-activator==1.0.0; sys_platform == 'win32'",
                        ],
                    }
                }
            ]
        elif requested == "marker-parent==1.0.0":
            marker_requests.append(requested)
            installs = [
                {
                    "metadata": {
                        "name": "marker-parent",
                        "version": "1.0.0",
                        "requires_dist": ["excluded-child==2.0.0; extra != 'feature'"],
                    }
                },
                {"metadata": {"name": "excluded-child", "version": "2.0.0"}},
            ]
        elif requested == "zz-activator==1.0.0":
            marker_requests.append(requested)
            installs = [
                {
                    "metadata": {
                        "name": "zz-activator",
                        "version": "1.0.0",
                        "requires_dist": [
                            "marker-parent[feature]==1.0.0; sys_platform == 'win32'"
                        ],
                    }
                }
            ]
        elif requested == "marker-parent[feature]==1.0.0":
            marker_requests.append(requested)
            installs = [
                {
                    "metadata": {
                        "name": "marker-parent",
                        "version": "1.0.0",
                        "requires_dist": ["excluded-child==2.0.0; extra != 'feature'"],
                    }
                }
            ]
        else:
            raise AssertionError(f"unexpected marker resolution request: {requested}")
        report.write_text(json.dumps({"install": installs}), encoding="utf-8")
        return 0, "", 0.0

    monkeypatch.setattr(validator, "run", fake_run)
    monkeypatch.setattr(
        validator,
        "pinned_lock_resolver",
        lambda python, _label, _lock, _environment, _env: python,
    )
    validator.validate_requirements_lock_closure(
        requirements_input,
        lock,
        resolver_python,
        runtime_python,
        tmp_path / "work",
    )
    require(
        marker_requests
        == ["marker-parent==1.0.0", "zz-activator==1.0.0", "marker-parent[feature]==1.0.0"],
        "supplemental reports were not rebuilt when activated extras expanded",
    )


def test_requirements_lock_closure_rejects_supplemental_report_cycles(
    tmp_path: Path, monkeypatch
) -> None:
    """A supplemental root that toggles its introducing marker must fail closed."""
    requirements_input = tmp_path / "requirements-ci.in"
    requirements_input.write_text("root==1.0.0\n", encoding="utf-8")
    lock = tmp_path / "requirements-ci.lock"
    lock.write_text(
        "root==1.0.0 \\\n"
        "    --hash=sha256:" + "0" * 64 + "\n"
        "    # via -r requirements-ci.in\n"
        "a==1.0.0 \\\n"
        "    --hash=sha256:" + "1" * 64 + "\n"
        "    # via root\n",
        encoding="utf-8",
    )
    resolver_python = tmp_path / "resolver-python"
    runtime_python = tmp_path / "runtime-python"
    resolver_python.touch()
    runtime_python.touch()

    def fake_run(
        command: list[str],
        cwd: Path,
        env: dict[str, str],
        timeout: int = 300,
    ) -> tuple[int, str, float]:
        if command[2] == "-c":
            expected = "cpython 3.13.2" if command[0] == str(resolver_python) else "cpython 3.12.11"
            return 0, expected + "\n", 0.0
        report = Path(command[command.index("--report") + 1])
        requested = Path(command[command.index("-r") + 1]).read_text(encoding="utf-8").strip()
        if requested == "root==1.0.0":
            installs = [
                {
                    "metadata": {
                        "name": "root",
                        "version": "1.0.0",
                        "requires_dist": ["a==1.0.0; extra != 'feature'"],
                    }
                }
            ]
        elif requested == "a==1.0.0":
            installs = [
                {
                    "metadata": {
                        "name": "a",
                        "version": "1.0.0",
                        "requires_dist": ["root[feature]==1.0.0"],
                    }
                },
                {
                    "metadata": {
                        "name": "root",
                        "version": "1.0.0",
                        "requires_dist": ["a==1.0.0; extra != 'feature'"],
                    }
                },
            ]
        else:
            raise AssertionError(f"unexpected marker resolution request: {requested}")
        report.write_text(json.dumps({"install": installs}), encoding="utf-8")
        return 0, "", 0.0

    monkeypatch.setattr(validator, "run", fake_run)
    monkeypatch.setattr(
        validator,
        "pinned_lock_resolver",
        lambda python, _label, _lock, _environment, _env: python,
    )
    try:
        validator.validate_requirements_lock_closure(
            requirements_input,
            lock,
            resolver_python,
            runtime_python,
            tmp_path / "work",
        )
    except ValueError as exc:
        require(
            "supplemental marker report state did not converge" in str(exc),
            f"unexpected supplemental-cycle error: {exc}",
        )
    else:
        raise AssertionError("supplemental report cycle was not rejected")


def test_requirements_lock_closure_rebuilds_reports_when_unmarked_dependencies_expand_extras(
    tmp_path: Path, monkeypatch
) -> None:
    """An unconditional dependency extra must replace an obsolete supplemental report."""
    requirements_input = tmp_path / "requirements-ci.in"
    requirements_input.write_text("build==1.6.1\n", encoding="utf-8")
    lock = tmp_path / "requirements-ci.lock"
    lock.write_text(
        "build==1.6.1 \\\n"
        "    --hash=sha256:" + "0" * 64 + "\n"
        "    # via -r requirements-ci.in\n"
        "aa-parent==1.0.0 \\\n"
        "    --hash=sha256:" + "1" * 64 + "\n"
        "    # via build\n"
        "zz-activator==1.0.0 \\\n"
        "    --hash=sha256:" + "2" * 64 + "\n"
        "    # via build\n",
        encoding="utf-8",
    )
    resolver_python = tmp_path / "resolver-python"
    runtime_python = tmp_path / "runtime-python"
    resolver_python.touch()
    runtime_python.touch()
    marker_requests: list[str] = []

    def fake_run(command: list[str], cwd: Path, env: dict[str, str], timeout: int = 300) -> tuple[int, str, float]:
        if command[2] == "-c":
            expected = "cpython 3.13.2" if command[0] == str(resolver_python) else "cpython 3.12.11"
            return 0, expected + "\n", 0.0
        report = Path(command[command.index("--report") + 1])
        requested = Path(command[command.index("-r") + 1]).read_text(encoding="utf-8").strip()
        if requested == "build==1.6.1":
            installs = [
                {
                    "metadata": {
                        "name": "build",
                        "version": "1.6.1",
                        "requires_dist": [
                            "aa-parent==1.0.0; sys_platform == 'win32'",
                            "zz-activator==1.0.0; sys_platform == 'win32'",
                        ],
                    }
                }
            ]
        elif requested == "aa-parent==1.0.0":
            marker_requests.append(requested)
            installs = [
                {
                    "metadata": {
                        "name": "aa-parent",
                        "version": "1.0.0",
                        "requires_dist": ["excluded-child==2.0.0; extra != 'feature'"],
                    }
                },
                {"metadata": {"name": "excluded-child", "version": "2.0.0"}},
            ]
        elif requested == "zz-activator==1.0.0":
            marker_requests.append(requested)
            installs = [
                {
                    "metadata": {
                        "name": "zz-activator",
                        "version": "1.0.0",
                        "requires_dist": ["aa-parent[feature]==1.0.0"],
                    }
                },
                {
                    "metadata": {
                        "name": "aa-parent",
                        "version": "1.0.0",
                        "requires_dist": ["excluded-child==2.0.0; extra != 'feature'"],
                    }
                },
            ]
        elif requested == "aa-parent[feature]==1.0.0":
            marker_requests.append(requested)
            installs = [
                {
                    "metadata": {
                        "name": "aa-parent",
                        "version": "1.0.0",
                        "requires_dist": ["excluded-child==2.0.0; extra != 'feature'"],
                    }
                }
            ]
        else:
            raise AssertionError(f"unexpected marker resolution request: {requested}")
        report.write_text(json.dumps({"install": installs}), encoding="utf-8")
        return 0, "", 0.0

    monkeypatch.setattr(validator, "run", fake_run)
    monkeypatch.setattr(
        validator,
        "pinned_lock_resolver",
        lambda python, _label, _lock, _environment, _env: python,
    )
    validator.validate_requirements_lock_closure(
        requirements_input,
        lock,
        resolver_python,
        runtime_python,
        tmp_path / "work",
    )
    require(
        marker_requests
        == ["aa-parent==1.0.0", "zz-activator==1.0.0", "aa-parent[feature]==1.0.0"],
        "an unconditional dependency extra did not replace the obsolete supplemental report",
    )


def test_requirements_lock_closure_refilters_earlier_reports_after_transitive_extras_expand(
    tmp_path: Path, monkeypatch
) -> None:
    """A later root's extra must remove an earlier root's now-inactive child."""
    requirements_input = tmp_path / "requirements-ci.in"
    requirements_input.write_text("build==1.6.1\n", encoding="utf-8")
    lock = tmp_path / "requirements-ci.lock"
    lock.write_text(
        "build==1.6.1 \\\n"
        "    --hash=sha256:" + "0" * 64 + "\n"
        "    # via -r requirements-ci.in\n"
        "aa-root==1.0.0 \\\n"
        "    --hash=sha256:" + "1" * 64 + "\n"
        "    # via build\n"
        "shared-parent==1.0.0 \\\n"
        "    --hash=sha256:" + "2" * 64 + "\n"
        "    # via aa-root, zz-root\n"
        "zz-root==1.0.0 \\\n"
        "    --hash=sha256:" + "3" * 64 + "\n"
        "    # via build\n",
        encoding="utf-8",
    )
    resolver_python = tmp_path / "resolver-python"
    runtime_python = tmp_path / "runtime-python"
    resolver_python.touch()
    runtime_python.touch()
    marker_requests: list[str] = []

    def fake_run(command: list[str], cwd: Path, env: dict[str, str], timeout: int = 300) -> tuple[int, str, float]:
        if command[2] == "-c":
            expected = "cpython 3.13.2" if command[0] == str(resolver_python) else "cpython 3.12.11"
            return 0, expected + "\n", 0.0
        report = Path(command[command.index("--report") + 1])
        requested = Path(command[command.index("-r") + 1]).read_text(encoding="utf-8").strip()
        if requested == "build==1.6.1":
            installs = [
                {
                    "metadata": {
                        "name": "build",
                        "version": "1.6.1",
                        "requires_dist": [
                            "aa-root==1.0.0; sys_platform == 'win32'",
                            "zz-root==1.0.0; sys_platform == 'win32'",
                        ],
                    }
                }
            ]
        elif requested == "aa-root==1.0.0":
            marker_requests.append(requested)
            installs = [
                {
                    "metadata": {
                        "name": "aa-root",
                        "version": "1.0.0",
                        "requires_dist": ["shared-parent==1.0.0"],
                    }
                },
                {
                    "metadata": {
                        "name": "shared-parent",
                        "version": "1.0.0",
                        "requires_dist": ["excluded-child==2.0.0; extra != 'feature'"],
                    }
                },
                {"metadata": {"name": "excluded-child", "version": "2.0.0"}},
            ]
        elif requested == "zz-root==1.0.0":
            marker_requests.append(requested)
            installs = [
                {
                    "metadata": {
                        "name": "zz-root",
                        "version": "1.0.0",
                        "requires_dist": ["shared-parent[feature]==1.0.0"],
                    }
                },
                {
                    "metadata": {
                        "name": "shared-parent",
                        "version": "1.0.0",
                        "requires_dist": ["excluded-child==2.0.0; extra != 'feature'"],
                    }
                },
            ]
        else:
            raise AssertionError(f"unexpected marker resolution request: {requested}")
        report.write_text(json.dumps({"install": installs}), encoding="utf-8")
        return 0, "", 0.0

    monkeypatch.setattr(validator, "run", fake_run)
    monkeypatch.setattr(
        validator,
        "pinned_lock_resolver",
        lambda python, _label, _lock, _environment, _env: python,
    )
    validator.validate_requirements_lock_closure(
        requirements_input,
        lock,
        resolver_python,
        runtime_python,
        tmp_path / "work",
    )
    require(
        marker_requests == ["aa-root==1.0.0", "zz-root==1.0.0"],
        "the transitive extra should refilter existing reports without another root resolution",
    )


def test_requirements_lock_closure_propagates_extras_from_unmarked_dependencies(
    tmp_path: Path, monkeypatch
) -> None:
    """An unconditional extra request must activate its target's marker-gated dependencies."""
    requirements_input = tmp_path / "requirements-ci.in"
    requirements_input.write_text("build==1.6.1\n", encoding="utf-8")
    lock = tmp_path / "requirements-ci.lock"
    lock.write_text(
        "build==1.6.1 \\\n"
        "    --hash=sha256:" + "0" * 64 + "\n"
        "    # via -r requirements-ci.in\n"
        "marker-parent==1.0.0 \\\n"
        "    --hash=sha256:" + "1" * 64 + "\n"
        "    # via build\n"
        "marker-child==2.0.0 \\\n"
        "    --hash=sha256:" + "2" * 64 + "\n"
        "    # via marker-parent\n",
        encoding="utf-8",
    )
    resolver_python = tmp_path / "resolver-python"
    runtime_python = tmp_path / "runtime-python"
    resolver_python.touch()
    runtime_python.touch()
    requested_roots: list[tuple[str, list[str]]] = []

    def fake_run(command: list[str], cwd: Path, env: dict[str, str], timeout: int = 300) -> tuple[int, str, float]:
        if command[2] == "-c":
            expected = "cpython 3.13.2" if command[0] == str(resolver_python) else "cpython 3.12.11"
            return 0, expected + "\n", 0.0
        report = Path(command[command.index("--report") + 1])
        requested = Path(command[command.index("-r") + 1]).read_text(encoding="utf-8").strip()
        requested_roots.append((requested, command))
        if requested == "build==1.6.1":
            installs = [
                {
                    "metadata": {
                        "name": "build",
                        "version": "1.6.1",
                        "requires_dist": ["marker-parent[feature]==1.0.0"],
                    }
                },
                {
                    "metadata": {
                        "name": "marker-parent",
                        "version": "1.0.0",
                        "requires_dist": [
                            "marker-child==2.0.0; "
                            "extra == 'feature' and sys_platform == 'win32'"
                        ],
                    }
                },
            ]
        elif requested == "marker-child==2.0.0":
            installs = [{"metadata": {"name": "marker-child", "version": "2.0.0"}}]
        else:
            raise AssertionError(f"unexpected marker resolution request: {requested}")
        report.write_text(json.dumps({"install": installs}), encoding="utf-8")
        return 0, "", 0.0

    monkeypatch.setattr(validator, "run", fake_run)
    monkeypatch.setattr(
        validator,
        "pinned_lock_resolver",
        lambda python, _label, _lock, _environment, _env: python,
    )
    validator.validate_requirements_lock_closure(
        requirements_input,
        lock,
        resolver_python,
        runtime_python,
        tmp_path / "work",
    )

    marker_requests = [requested for requested, _command in requested_roots if requested != "build==1.6.1"]
    require(
        marker_requests == ["marker-child==2.0.0"],
        "unconditional dependency extras did not activate the marker-gated transitive child",
    )


def test_requirements_lock_closure_rejects_missing_marker_gated_transitive_pin(
    tmp_path: Path, monkeypatch
) -> None:
    """A marker-only child absent from the lock must not be silently accepted."""
    requirements_input = tmp_path / "requirements-ci.in"
    requirements_input.write_text("build==1.6.1\n", encoding="utf-8")
    lock = tmp_path / "requirements-ci.lock"
    lock.write_text(
        "build==1.6.1 \\\n"
        "    --hash=sha256:" + "0" * 64 + "\n"
        "    # via -r requirements-ci.in\n"
        "marker-parent==1.0.0 \\\n"
        "    --hash=sha256:" + "1" * 64 + "\n"
        "    # via build\n",
        encoding="utf-8",
    )
    resolver_python = tmp_path / "resolver-python"
    runtime_python = tmp_path / "runtime-python"
    resolver_python.touch()
    runtime_python.touch()

    def fake_run(command: list[str], cwd: Path, env: dict[str, str], timeout: int = 300) -> tuple[int, str, float]:
        if command[2] == "-c":
            expected = "cpython 3.13.2" if command[0] == str(resolver_python) else "cpython 3.12.11"
            return 0, expected + "\n", 0.0
        report = Path(command[command.index("--report") + 1])
        requested = Path(command[command.index("-r") + 1]).read_text(encoding="utf-8").strip()
        if requested == "build==1.6.1":
            installs = [
                {
                    "metadata": {
                        "name": "build",
                        "version": "1.6.1",
                        "requires_dist": ["marker-parent==1.0.0; sys_platform == 'win32'"],
                    }
                }
            ]
        elif requested == "marker-parent==1.0.0":
            installs = [
                {
                    "metadata": {
                        "name": "marker-parent",
                        "version": "1.0.0",
                        "requires_dist": ["marker-child==2.0.0; sys_platform == 'win32'"],
                    }
                }
            ]
        else:
            raise AssertionError(f"unexpected marker resolution request: {requested}")
        report.write_text(json.dumps({"install": installs}), encoding="utf-8")
        return 0, "", 0.0

    monkeypatch.setattr(validator, "run", fake_run)
    monkeypatch.setattr(
        validator,
        "pinned_lock_resolver",
        lambda python, _label, _lock, _environment, _env: python,
    )
    try:
        validator.validate_requirements_lock_closure(
            requirements_input,
            lock,
            resolver_python,
            runtime_python,
            tmp_path / "work",
        )
    except ValueError as exc:
        message = str(exc)
        require("missing marker-gated package" in message, "missing marker child did not fail clearly")
        require("marker-child" in message, "missing marker child was omitted from the diagnostic")
    else:
        raise AssertionError("missing marker-gated transitive package was accepted")


def test_requirements_lock_closure_resolves_every_target_and_functional_runtime(
    tmp_path: Path, monkeypatch
) -> None:
    """Closure verification invokes pip for every supported target plus CPython 3.12.11."""
    requirements_input = tmp_path / "requirements-ci.in"
    requirements_input.write_text("build==1.6.1\n", encoding="utf-8")
    lock = tmp_path / "requirements-ci.lock"
    lock.write_text(
        "build==1.6.1 \\\n"
        "    --hash=sha256:" + "0" * 64 + "\n"
        "    # via -r requirements-ci.in\n",
        encoding="utf-8",
    )
    resolver_python = tmp_path / "resolver-python"
    runtime_python = tmp_path / "runtime-python"
    resolver_python.touch()
    runtime_python.touch()
    pip_commands: list[list[str]] = []
    marker_environments: list[dict[str, str]] = []
    marker_wrapper_sources: list[str] = []
    validated_reports: list[tuple[Path, ...]] = []
    pinned_resolver_calls: list[tuple[Path, str]] = []

    def fake_run(command: list[str], cwd: Path, env: dict[str, str], timeout: int = 300) -> tuple[int, str, float]:
        if command[2] == "-c":
            expected = "cpython 3.13.2" if command[0] == str(resolver_python) else "cpython 3.12.11"
            return 0, expected + "\n", 0.0
        report = Path(command[command.index("--report") + 1])
        wrapper = Path(command[2])
        require(
            wrapper.name == "target-marker-pip.py",
            "pip invocation did not use the synthetic target-marker wrapper",
        )
        marker_environments.append(json.loads(command[3]))
        marker_wrapper_sources.append(wrapper.read_text(encoding="utf-8"))
        report.write_text(
            json.dumps({"install": [{"metadata": {"name": "build", "version": "1.6.1"}}]}),
            encoding="utf-8",
        )
        pip_commands.append(command)
        return 0, "", 0.0

    monkeypatch.setattr(validator, "run", fake_run)
    monkeypatch.setattr(
        validator,
        "pinned_lock_resolver",
        lambda python, label, _lock, _environment, _env: (
            pinned_resolver_calls.append((python, label)) or python
        ),
    )
    monkeypatch.setattr(
        validator,
        "validate_resolved_requirements_lock",
        lambda _input, _lock, reports: validated_reports.append(tuple(reports)),
    )

    validator.validate_requirements_lock_closure(
        requirements_input,
        lock,
        resolver_python,
        runtime_python,
        tmp_path / "work",
    )

    require(len(pip_commands) == 4, "closure did not resolve every declared target and runtime")
    require(
        all("--platform" in command for command in pip_commands[:3]),
        "declared CPython 3.13.2 targets were not resolved with pip target selection",
    )
    require(
        any(command[0] == str(runtime_python) for command in pip_commands),
        "the functional CPython 3.12.11 runtime was not resolved",
    )
    require(
        all("--require-hashes" in command for command in pip_commands),
        "every target resolution must verify the selected artifact against lock hashes",
    )
    require(
        marker_environments
        == [
            *validator.LOCK_RESOLUTION_TARGET_MARKER_ENVIRONMENTS,
            validator.FUNCTIONAL_RUNTIME_MARKER_ENVIRONMENT,
        ],
        "each resolver invocation must receive its full synthetic target marker environment",
    )
    require(
        all(
            "markers.default_environment = target_marker_environment" in source
            and "default_environment()" not in source
            for source in marker_wrapper_sources
        ),
        "the target-marker wrapper must replace, not inherit, the host marker environment",
    )
    require(
        pinned_resolver_calls
        == [(resolver_python, "CPython 3.13.2"), (runtime_python, "CPython 3.12.11")],
        "closure resolution did not bootstrap both pinned resolver environments",
    )
    require(len(validated_reports) == 1 and len(validated_reports[0]) == 4, "all target reports were not validated")


def test_target_marker_pip_wrapper_evaluates_markers_for_the_declared_target(
    tmp_path: Path, monkeypatch
) -> None:
    """The resolver wrapper must replace host PEP 508 markers before Pip evaluates dependencies."""
    from pip._internal.cli import main as pip_cli_main
    from pip._vendor.packaging import markers

    wrapper = tmp_path / "target-marker-pip.py"
    wrapper.write_text(validator.TARGET_MARKER_PIP_WRAPPER, encoding="utf-8")
    target_environment = validator.LOCK_RESOLUTION_TARGET_MARKER_ENVIRONMENTS[1]
    pip_arguments: list[list[str]] = []

    def fake_main(arguments: list[str]) -> int:
        pip_arguments.append(arguments)
        return 0

    original_default_environment = markers.default_environment
    monkeypatch.setattr(pip_cli_main, "main", fake_main)
    monkeypatch.setattr(
        sys,
        "argv",
        [str(wrapper), json.dumps(target_environment), "--isolated", "install"],
    )
    try:
        try:
            runpy.run_path(str(wrapper), run_name="__main__")
        except SystemExit as exc:
            require(exc.code == 0, "target-marker wrapper did not return Pip's exit status")
        else:
            raise AssertionError("target-marker wrapper did not invoke Pip")
        require(
            pip_arguments == [["--isolated", "install"]],
            "target-marker wrapper did not forward the Pip command line",
        )
        require(
            markers.Marker("sys_platform == 'win32'").evaluate(),
            "the Windows target marker environment was not applied",
        )
        require(
            not markers.Marker("sys_platform != 'win32'").evaluate(),
            "a Linux-only marker remained active for the Windows target",
        )
    finally:
        markers.default_environment = original_default_environment


def test_requirements_lock_closure_marks_resolver_outage_blocked(tmp_path: Path, monkeypatch) -> None:
    """Transient resolver outages must be reported separately from stale locks."""
    requirements_input = tmp_path / "requirements-ci.in"
    requirements_input.write_text("build==1.6.1\n", encoding="utf-8")
    lock = tmp_path / "requirements-ci.lock"
    lock.write_text(
        "build==1.6.1 \\\n"
        "    --hash=sha256:" + "0" * 64 + "\n"
        "    # via -r requirements-ci.in\n",
        encoding="utf-8",
    )
    resolver_python = tmp_path / "resolver-python"
    runtime_python = tmp_path / "runtime-python"
    resolver_python.touch()
    runtime_python.touch()

    def fake_run(command: list[str], cwd: Path, env: dict[str, str], timeout: int = 300) -> tuple[int, str, float]:
        if command[2] == "-c":
            expected = "cpython 3.13.2" if command[0] == str(resolver_python) else "cpython 3.12.11"
            return 0, expected + "\n", 0.0
        return 124, "ERROR: Could not fetch URL: Read timed out", 300.0

    monkeypatch.setattr(validator, "run", fake_run)
    monkeypatch.setattr(
        validator,
        "pinned_lock_resolver",
        lambda python, _label, _lock, _environment, _env: python,
    )
    try:
        validator.validate_requirements_lock_closure(
            requirements_input,
            lock,
            resolver_python,
            runtime_python,
            tmp_path / "work",
        )
    except validator.LockResolutionBlockedError as exc:
        require("could not resolve the requirements lock closure" in str(exc), "blocked resolver output was lost")
    else:
        raise AssertionError("resolver outage was not classified as blocked")


def test_requirements_lock_closure_marks_http_429_as_blocked() -> None:
    """Package-index throttling is an outage, not proof that a valid lock is stale."""
    require(
        validator.is_transient_lock_resolution_failure(
            1,
            "ERROR: Could not install because of HTTP error 429: Too Many Requests",
        ),
        "HTTP 429 was not classified as a transient resolver failure",
    )


def test_requirements_lock_closure_keeps_invalid_resolution_as_failure(tmp_path: Path, monkeypatch) -> None:
    """Invalid resolver output remains a failed closure, not a blocked closure."""
    requirements_input = tmp_path / "requirements-ci.in"
    requirements_input.write_text("build==1.6.1\n", encoding="utf-8")
    lock = tmp_path / "requirements-ci.lock"
    lock.write_text(
        "build==1.6.1 \\\n"
        "    --hash=sha256:" + "0" * 64 + "\n"
        "    # via -r requirements-ci.in\n",
        encoding="utf-8",
    )
    resolver_python = tmp_path / "resolver-python"
    runtime_python = tmp_path / "runtime-python"
    resolver_python.touch()
    runtime_python.touch()

    def fake_run(command: list[str], cwd: Path, env: dict[str, str], timeout: int = 300) -> tuple[int, str, float]:
        if command[2] == "-c":
            expected = "cpython 3.13.2" if command[0] == str(resolver_python) else "cpython 3.12.11"
            return 0, expected + "\n", 0.0
        return 1, "ERROR: Cannot install build==1.6.1 because these package versions have conflicting dependencies.", 0.0

    monkeypatch.setattr(validator, "run", fake_run)
    monkeypatch.setattr(
        validator,
        "pinned_lock_resolver",
        lambda python, _label, _lock, _environment, _env: python,
    )
    try:
        validator.validate_requirements_lock_closure(
            requirements_input,
            lock,
            resolver_python,
            runtime_python,
            tmp_path / "work",
        )
    except validator.LockResolutionBlockedError:
        raise AssertionError("invalid resolution was incorrectly classified as blocked") from None
    except ValueError:
        pass
    else:
        raise AssertionError("invalid resolution was not rejected")


def test_requirements_lock_rejects_impossible_marker_transitive_pin(tmp_path: Path) -> None:
    """Inactive markers must be satisfiable by a declared lock-resolution target."""
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
        json.dumps(
            {
                "install": [
                    {
                        "metadata": {
                            "name": "build",
                            "version": "1.6.1",
                            "requires_dist": [
                                "colorama==0.4.6; os_name == 'not-a-real-os'"
                            ],
                        }
                    },
                ]
            }
        ),
        encoding="utf-8",
    )

    try:
        validator.validate_resolved_requirements_lock(requirements_input, lock, report)
    except ValueError as exc:
        require("unexpected locked packages" in str(exc), "impossible marker pin was not rejected")
        require("colorama==0.4.6" in str(exc), "impossible marker pin was omitted from diagnostics")
    else:
        raise AssertionError("impossible marker transitive pin was accepted")


def test_requirements_lock_rejects_unrequested_extra_transitive_pin(tmp_path: Path) -> None:
    """An inactive optional extra cannot be used to smuggle a lock package in."""
    requirements_input = tmp_path / "requirements-ci.in"
    requirements_input.write_text("build==1.6.1\n", encoding="utf-8")
    lock = tmp_path / "requirements-ci.lock"
    lock.write_text(
        "build==1.6.1 \\\n"
        "    --hash=sha256:" + "0" * 64 + "\n"
        "    # via -r requirements-ci.in\n"
        "keyring==1.0 \\\n"
        "    --hash=sha256:" + "1" * 64 + "\n"
        "    # via build\n",
        encoding="utf-8",
    )
    report = tmp_path / "resolution.json"
    report.write_text(
        json.dumps(
            {
                "install": [
                    {
                        "metadata": {
                            "name": "build",
                            "version": "1.6.1",
                            "requires_dist": ["keyring==1.0; extra == 'keyring'"],
                        }
                    },
                ]
            }
        ),
        encoding="utf-8",
    )

    try:
        validator.validate_resolved_requirements_lock(requirements_input, lock, report)
    except ValueError as exc:
        require("unexpected locked packages" in str(exc), "extra-only lock package was not identified")
        require("keyring==1.0" in str(exc), "extra-only package was omitted from the diagnostic")
    else:
        raise AssertionError("unrequested extra dependency was accepted into the lock")


def test_python_evidence_normalizer_explains_notrun_status() -> None:
    """Local evidence must retain an honest, actionable reason for NotRun."""
    root = Path(__file__).resolve().parents[2]
    normalizer = runpy.run_path(root / "scripts" / "Normalize-PythonFunctionalEvidence.py")
    record = {
        "schemaVersion": "1.1.0",
        "name": "GitHub-hosted workflow execution",
        "category": "workflow",
        "status": "NotRun",
        "exitCode": 0,
        "failureReason": None,
        "blockedReason": "stale reason",
        "notApplicableRationale": "stale rationale",
        "details": {"sanitizedOutput": "Hosted execution was not performed locally."},
    }
    normalized = normalizer["normalize_record"](record)
    require(normalized["exitCode"] is None, "NotRun evidence must not claim a process exit")
    require(
        normalized["failureReason"] == "Hosted execution was not performed locally.",
        "NotRun evidence omitted its truthful reason",
    )
    require(normalized["blockedReason"] is None, "NotRun evidence retained a blocked reason")
    require(normalized["notApplicableRationale"] is None, "NotRun evidence retained an inapplicable rationale")


def test_project_sbom_contains_runtime_dependencies_only() -> None:
    """The project inventory must not mislabel validation tools as runtime dependencies."""
    root = Path(__file__).resolve().parents[2]
    runtime_lock = (root / "examples" / "python-project" / "requirements-runtime.lock").read_text(encoding="utf-8")
    sbom = json.loads(
        (root / "examples" / "python-project" / "evidence" / "python-project-sbom.cdx.json").read_text(
            encoding="utf-8"
        )
    )
    expected_runtime_packages = {
        validator.normalized_requirement_name(package)
        for package in re.findall(r"(?m)^([A-Za-z0-9_.-]+)==", runtime_lock)
    }
    component_names = {
        validator.normalized_requirement_name(component["name"])
        for component in sbom.get("components", [])
        if component.get("name")
    }

    require(
        component_names == expected_runtime_packages,
        "project SBOM must contain only the dependencies declared by requirements-runtime.lock",
    )


def test_toolchain_sbom_matches_governed_lock_requirements() -> None:
    """A stale inventory must not report prior build-backend versions or hashes."""
    root = Path(__file__).resolve().parents[2]
    lock_text = (root / "examples" / "python-project" / "requirements-ci.lock").read_text(encoding="utf-8")
    sbom = json.loads(
        (root / "examples" / "python-project" / "evidence" / "python-toolchain-sbom.cdx.json").read_text(
            encoding="utf-8"
        )
    )
    root_component = sbom.get("metadata", {}).get("component", {})
    require(
        root_component.get("name") == "engineering-standards-python-toolchain",
        "toolchain SBOM must use the standards-owned toolchain root identity",
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


def test_evidence_sanitizes_nested_detail_paths(tmp_path: Path) -> None:
    """Generated evidence must never serialize workstation paths in nested details."""
    private_path = tmp_path / "trusted-tools" / "requirements-ci.lock"
    record = validator.make_evidence(
        "Evidence path sanitization",
        "security",
        ["python", "-c", f"assert {str(private_path)!r} not in value"],
        0,
        str(private_path),
        0,
        "test-tool",
        "1.0",
        [tmp_path],
        {
            "sourceLock": str(private_path),
            "nested": {"paths": [str(private_path)]},
            "pathsByLocation": {str(private_path): "trusted"},
        },
    )

    serialized = json.dumps(record)
    require(str(tmp_path) not in serialized, "nested evidence details leaked an absolute path")
    require(record["details"]["sourceLock"].startswith("."), "source lock detail was not sanitized")
    require(
        str(private_path).replace("\\", "\\\\") not in record["command"],
        "escaped command literal leaked an absolute path",
    )
    require(
        all(str(tmp_path) not in key for key in record["details"]["pathsByLocation"]),
        "nested evidence detail key leaked an absolute path",
    )


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


def test_both_sboms_are_generated_before_any_caller_code_runs() -> None:
    """Neither SBOM may be produced after caller code could alter its inputs or the tool environment."""
    source = inspect.getsource(validator.validate)
    toolchain = source.index('name="Python toolchain SBOM"')
    project = source.index('name="Python project SBOM"')
    require(toolchain < project, "the project SBOM must follow the toolchain SBOM")
    for caller_code_step in ("checks = [", "build_command = ", "pytest_command = ", "smoke_command = "):
        require(project < source.index(caller_code_step), f"an SBOM is generated after {caller_code_step!r}")


def test_toolchain_sbom_metadata_is_read_only_and_replaceable(tmp_path: Path) -> None:
    first = validator.write_toolchain_sbom_pyproject(tmp_path)
    second = validator.write_toolchain_sbom_pyproject(tmp_path)
    require(first == second and second.is_file(), "metadata was not rewritten in place")
    require(not second.stat().st_mode & stat.S_IWUSR, "standards-owned SBOM metadata must be read-only")


def _sbom_record(digest: str | None) -> dict[str, object]:
    details: dict[str, object] = {"sourceLock": "requirements-ci.lock"}
    if digest is not None:
        details["sha256"] = digest
    return {"name": "Python toolchain SBOM", "status": "Passed", "exitCode": 0, "details": details}


def test_sbom_integrity_accepts_the_unmodified_file(tmp_path: Path) -> None:
    sbom = tmp_path / "python-toolchain-sbom.cdx.json"
    sbom.write_text('{"bomFormat": "CycloneDX"}', encoding="utf-8")
    record = _sbom_record(validator.sha256(sbom))
    require(validator.verify_sbom_integrity(record, sbom), "unmodified SBOM was rejected")
    require(record["status"] == "Passed" and record["details"]["sha256Verified"] is True, "verified SBOM record changed")


def test_sbom_integrity_rejects_a_modified_removed_or_undigested_file(tmp_path: Path) -> None:
    sbom = tmp_path / "python-toolchain-sbom.cdx.json"
    sbom.write_text('{"bomFormat": "CycloneDX"}', encoding="utf-8")
    digest = validator.sha256(sbom)
    sbom.write_text('{"bomFormat": "tampered"}', encoding="utf-8")
    modified = _sbom_record(digest)
    require(not validator.verify_sbom_integrity(modified, sbom), "modified SBOM was accepted")
    require(modified["status"] == "Failed" and modified["exitCode"] == 1, "modified SBOM did not fail its record")
    sbom.unlink()
    removed = _sbom_record(digest)
    require(not validator.verify_sbom_integrity(removed, sbom), "removed SBOM was accepted")
    sbom.write_text("{}", encoding="utf-8")
    require(not validator.verify_sbom_integrity(_sbom_record(None), sbom), "SBOM without a recorded digest was accepted")
    already_failed = {"name": "x", "status": "Failed", "details": {}}
    require(validator.verify_sbom_integrity(already_failed, sbom), "a record that already failed must be left as is")


def test_sbom_integrity_is_verified_after_all_caller_code_has_run() -> None:
    source = inspect.getsource(validator.validate)
    verification = source.index("verify_sbom_integrity(sbom_record")
    for caller_code_step in ("build_command = ", "pytest_command = ", "smoke_command = "):
        require(
            source.index(caller_code_step) < verification,
            f"SBOM integrity is verified before {caller_code_step!r}",
        )
    for record in ("toolchain_sbom_record", "project_sbom_record"):
        require(record in source[verification - 300 : verification], f"{record} is not verified")


def test_descendants_are_stopped_before_sbom_verification() -> None:
    source = inspect.getsource(validator.validate)
    termination = source.index("terminate_descendants()")
    require(termination < source.index("verify_sbom_integrity(sbom_record"), "stragglers are stopped after SBOM verification")
    for caller_code_step in ("build_command = ", "pytest_command = ", "smoke_command = "):
        require(source.index(caller_code_step) < termination, f"stragglers are stopped before {caller_code_step!r}")
    require(source.index("become_subreaper()") < source.index("build_command = "), "adoption starts after caller code")


def test_detached_descendant_with_a_scrubbed_environment_is_still_terminated(tmp_path: Path) -> None:
    if not Path("/proc").is_dir():
        require(validator.terminate_descendants() == 0, "a platform without /proc must report nothing remaining")
        return
    require(validator.become_subreaper(), "this process could not become a subreaper")
    detach = (
        "import subprocess, sys;"
        "subprocess.Popen([sys.executable, '-c', 'import time; time.sleep(120)'],"
        " env={}, start_new_session=True, stdin=subprocess.DEVNULL, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)"
    )
    code = validator.run([sys.executable, "-c", detach], tmp_path, dict(validator.trusted_env(tmp_path / "home")))[0]
    require(code == 0, "the caller stand-in failed")
    require(validator.terminate_descendants() == 0, "a detached descendant survived the cleanup")
    survivors = [
        entry.name
        for entry in Path("/proc").iterdir()
        if entry.name.isdigit() and b"time.sleep(120)" in _cmdline(entry)
    ]
    require(not survivors, f"detached processes are still running: {survivors}")


def test_cleanup_leaves_unrelated_processes_alone(tmp_path: Path) -> None:
    require(validator.terminate_descendants(proc_root=tmp_path / "missing") == 0, "a missing /proc must report nothing remaining")
    if not Path("/proc").is_dir():
        return
    require(1 not in validator.live_descendants(Path("/proc"), validator.os.getpid()), "the init process is not a descendant")


def _cmdline(entry: Path) -> bytes:
    try:
        return (entry / "cmdline").read_bytes()
    except OSError:
        return b""


def test_tree_digest_detects_modified_added_removed_and_relinked_files(tmp_path: Path) -> None:
    root = tmp_path / "tools"
    (root / "bin").mkdir(parents=True)
    (root / ".git").mkdir()
    tool = root / "bin" / "tool.py"
    tool.write_text("print('ok')\n", encoding="utf-8")
    baseline = validator.tree_digest(root)
    (root / ".git" / "index").write_text("ignored\n", encoding="utf-8")
    require(validator.tree_digest(root) == baseline, "a top-level .git change must not alter the digest")
    tool.write_text("print('forged')\n", encoding="utf-8")
    require(validator.tree_digest(root) != baseline, "a modified file was not detected")
    tool.write_text("print('ok')\n", encoding="utf-8")
    require(validator.tree_digest(root) == baseline, "restoring the file must restore the digest")
    (root / "bin" / "extra.py").write_text("", encoding="utf-8")
    require(validator.tree_digest(root) != baseline, "an added file was not detected")
    (root / "bin" / "extra.py").unlink()
    tool.unlink()
    require(validator.tree_digest(root) != baseline, "a removed file was not detected")


def test_changed_trusted_tools_names_the_modified_roots(tmp_path: Path, monkeypatch) -> None:
    first = tmp_path / "first"
    second = tmp_path / "second"
    for root in (first, second):
        root.mkdir()
        (root / "tool.py").write_text("original\n", encoding="utf-8")
    monkeypatch.setattr(validator, "trusted_tool_roots", lambda: [first, second])
    before = validator.trusted_tool_digests()
    require(validator.changed_trusted_tools(before) == [], "unchanged tools were reported as changed")
    (second / "tool.py").write_text("forged\n", encoding="utf-8")
    require(validator.changed_trusted_tools(before) == [str(second)], "only the modified root should be reported")


def test_trusted_tool_roots_cover_standards_and_the_standard_library() -> None:
    roots = validator.trusted_tool_roots()
    require(VALIDATOR.resolve().parents[1] in roots, "the standards checkout is not covered")
    require(Path(__import__("sysconfig").get_path("stdlib")).resolve() in roots, "the standard library is not covered")


def test_caller_commands_cannot_write_bytecode_and_trusted_tools_are_verified_after_them() -> None:
    require(validator.trusted_env(Path("home"))["PYTHONDONTWRITEBYTECODE"] == "1", "bytecode writes are not disabled")
    source = inspect.getsource(validator.validate)
    baseline = source.index("trusted_tools_before = trusted_tool_digests()")
    pre_audit = source.index("tooling_changed = bool(changed_trusted_tools(trusted_tools_before))")
    final = source.index("if tooling_changed or changed_trusted_tools(trusted_tools_before)")
    require(baseline < source.index("become_subreaper()") < source.index("build_command = "), "baseline is taken too late")
    for caller_code_step in ("build_command = ", "pytest_command = ", "smoke_command = "):
        require(source.index(caller_code_step) < pre_audit, f"tooling is verified before {caller_code_step!r}")
    require(pre_audit < source.index("audit_command = "), "tooling must be verified immediately before the audit runs")
    require(source.index("terminate_descendants()") < final, "the final verification must follow the process cleanup")
    require("failed = True" in source[pre_audit : pre_audit + 700], "a changed toolchain must fail the run")
    require('"Python trusted tooling integrity"' in source[final:] and 'status="Failed"' in source[final : final + 900], "an integrity failure needs an explicit Failed record")
    require('"Python caller process cleanup"' in source, "a cleanup failure needs an explicit Failed record")
    require("terminate_descendants()" in inspect.getsource(validator.run), "run() must stop stragglers after every command")


def test_library_bytecode_is_compiled_before_the_trusted_baseline_is_taken() -> None:
    source = inspect.getsource(validator.validate)
    compile_step = source.index("compile_trusted_bytecode()")
    require(compile_step < source.index("trusted_tools_before = trusted_tool_digests()"), "bytecode is compiled after the baseline")
    require(compile_step < source.index("build_command = "), "bytecode is compiled after caller code")
    body = inspect.getsource(validator.compile_trusted_bytecode)
    require("compileall.compile_dir" in body and "!= standards" in body, "the standards checkout must not be compiled in place")
