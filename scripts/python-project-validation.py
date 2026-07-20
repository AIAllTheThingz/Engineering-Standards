"""Trusted entry point for the governed Python example's functional checks."""

from __future__ import annotations

import argparse
import hashlib
import json
import os
import subprocess
import sys
import tarfile
import time
import venv
import zipfile
from datetime import UTC, datetime
from pathlib import Path, PurePosixPath
from typing import Any


def utc() -> str:
    return datetime.now(UTC).isoformat().replace("+00:00", "Z")


def sanitize(value: str) -> str:
    """Remove local workspace and interpreter paths from portable evidence."""
    workspace = str(Path.cwd())
    return (
        value.replace(workspace, ".")
        .replace(workspace.replace("\\", "/"), ".")
        .replace(sys.executable, "python")
        .replace(sys.executable.replace("\\", "/"), "python")
    )


def run(command: list[str], cwd: Path, timeout: int = 300) -> tuple[int, str, float]:
    started = time.monotonic()
    env = {
        key: value for key, value in os.environ.items() if not key.startswith("PYTHON")
    }
    env.update(
        {
            "PYTEST_DISABLE_PLUGIN_AUTOLOAD": "1",
            "PYTHONNOUSERSITE": "1",
            "PYTHONSAFEPATH": "1",
            "PYTHONPATH": str(cwd / "src"),
        }
    )
    try:
        result = subprocess.run(
            command,
            cwd=cwd,
            env=env,
            text=True,
            stdout=subprocess.PIPE,
            stderr=subprocess.STDOUT,
            timeout=timeout,
            check=False,
        )
        return result.returncode, result.stdout[-12000:], time.monotonic() - started
    except subprocess.TimeoutExpired as exc:
        return (
            124,
            f"Command exceeded {timeout} seconds: {exc}",
            time.monotonic() - started,
        )


def safe_archive(path: Path, expected_root: str | None = None) -> list[str]:
    if path.suffix == ".whl":
        with zipfile.ZipFile(path) as archive:
            names = archive.namelist()
    else:
        with tarfile.open(path, "r:gz") as archive:
            members = archive.getmembers()
            if any(member.issym() or member.islnk() for member in members):
                raise ValueError("source distribution contains a link")
            names = [member.name for member in members]
    for name in names:
        candidate = PurePosixPath(name)
        if candidate.is_absolute() or ".." in candidate.parts or "\\" in name:
            raise ValueError(f"unsafe archive member: {name}")
        if expected_root and candidate.parts and candidate.parts[0] != expected_root:
            raise ValueError(f"unexpected source distribution root: {name}")
    return names


def evidence(
    name: str,
    category: str,
    command: list[str],
    code: int,
    output: str,
    duration: float,
    details: dict[str, Any] | None = None,
    blocked: bool = False,
) -> dict[str, Any]:
    status = "Blocked" if blocked else ("Passed" if code == 0 else "Failed")
    output = sanitize(output)
    reason = (
        None
        if status == "Passed"
        else output[-1000:] or "Required command did not complete."
    )
    return {
        "schemaVersion": "1.1.0",
        "name": name,
        "category": category,
        "status": status,
        "requiredValidation": True,
        "evidenceSource": "Automated",
        "command": sanitize(" ".join(command)),
        "workingDirectory": "examples/python-project",
        "startedAtUtc": utc(),
        "completedAtUtc": utc(),
        "durationSeconds": round(duration, 3),
        "runtime": f"CPython {sys.version_info.major}.{sys.version_info.minor}.{sys.version_info.micro}",
        "toolVersion": "governed-python-validator/1.0.0",
        "exitCode": None if blocked else code,
        "summary": f"{name} {'completed successfully' if code == 0 else 'did not complete successfully'}.",
        "warnings": [],
        "failureReason": reason if status == "Failed" else None,
        "blockedReason": reason if status == "Blocked" else None,
        "details": {"sanitizedOutput": output or "No command output.", **(details or {})},
    }


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--project", type=Path, required=True)
    args = parser.parse_args()
    root = args.project.resolve()
    if root.is_symlink() or not (root / "project-manifest.json").is_file():
        parser.error("project must be a non-linked governed Python project root")
    evidence_dir, dist = root / "evidence", root / "dist"
    evidence_dir.mkdir(exist_ok=True)
    dist.mkdir(exist_ok=True)
    records: list[dict[str, Any]] = []
    commands = [
        (
            "Python Ruff",
            "lint",
            [
                sys.executable,
                "-m",
                "ruff",
                "check",
                "--no-cache",
                "--isolated",
                "--extend-per-file-ignores",
                "tests/*:S101",
                "src",
                "tests",
            ],
        ),
        (
            "Python formatting",
            "lint",
            [
                sys.executable,
                "-m",
                "ruff",
                "format",
                "--check",
                "--no-cache",
                "--isolated",
                "src",
                "tests",
            ],
        ),
        (
            "Python type check",
            "lint",
            [
                sys.executable,
                "-m",
                "mypy",
                "--config-file",
                str(Path(__file__).with_name("python-mypy.ini")),
                "src",
            ],
        ),
        (
            "Python tests",
            "unit",
            [
                sys.executable,
                "-m",
                "pytest",
                "-c",
                os.devnull,
                "--rootdir",
                ".",
                "-p",
                "no:cacheprovider",
                "--strict-config",
                "--strict-markers",
                "tests",
            ],
        ),
        (
            "Python dependency audit",
            "security",
            [
                sys.executable,
                "-m",
                "pip_audit",
                "--disable-pip",
                "--progress-spinner",
                "off",
                "--format",
                "json",
                "--requirement",
                "requirements-ci.lock",
            ],
        ),
        (
            "Python package build",
            "build",
            [
                sys.executable,
                "-m",
                "build",
                "--no-isolation",
                "--wheel",
                "--sdist",
                ".",
            ],
        ),
    ]
    failed = False
    for name, category, command in commands:
        code, output, duration = run(command, root)
        blocked = name == "Python dependency audit" and code not in (0, 1)
        record = evidence(
            name, category, command, code, output, duration, blocked=blocked
        )
        records.append(record)
        (
            evidence_dir
            / (
                {
                    "Python tests": "python-tests.json",
                    "Python type check": "python-type-check.json",
                    "Python dependency audit": "python-dependency-audit.json",
                    "Python package build": "python-build.json",
                }.get(name, name.lower().replace(" ", "-") + ".json")
            )
        ).write_text(json.dumps(record, indent=2) + "\n", encoding="utf-8")
        failed |= code != 0
    if list(dist.glob("*.whl")) and list(dist.glob("*.tar.gz")):
        wheel = next(dist.glob("*.whl"))
        sdist = next(dist.glob("*.tar.gz"))
        wheel_names = safe_archive(wheel)
        sdist_names = safe_archive(sdist, "governed_paths_example-1.0.0")
        hashes = {
            item.name: hashlib.sha256(item.read_bytes()).hexdigest()
            for item in (wheel, sdist)
        }
        build_record = evidence(
            "Python archive inspection",
            "build",
            ["trusted-archive-inspection"],
            0,
            "Archive members are safe.",
            0,
            {
                "hashes": hashes,
                "wheelMembers": len(wheel_names),
                "sdistMembers": len(sdist_names),
            },
        )
        records.append(build_record)
        smoke_dir = root / ".smoke-venv"
        venv.EnvBuilder(with_pip=True, clear=True).create(smoke_dir)
        py = smoke_dir / ("Scripts/python.exe" if os.name == "nt" else "bin/python")
        code, output, duration = run(
            [str(py), "-m", "pip", "install", "--no-deps", str(wheel)], root
        )
        if code == 0:
            code, output, duration2 = run(
                [
                    str(py),
                    "-I",
                    "-c",
                    "import governed_paths; print(governed_paths.normalize_relative_path('src/app.py'))",
                ],
                root,
            )
            duration += duration2
        smoke = evidence(
            "Installed wheel smoke test",
            "integration",
            [str(py), "-I", "-c", "import governed_paths"],
            code,
            output,
            duration,
        )
        records.append(smoke)
        failed |= code != 0
        (evidence_dir / "python-build.json").write_text(
            json.dumps([records[-2], records[-1]], indent=2) + "\n", encoding="utf-8"
        )
        code, output, duration = run(
            [
                sys.executable,
                "-m",
                "cyclonedx_py",
                "requirements",
                "requirements-ci.lock",
                "--output-file",
                "evidence/python-project-sbom.cdx.json",
                "--output-format",
                "JSON",
            ],
            root,
        )
        records.append(
            evidence(
                "Python project SBOM",
                "security",
                [sys.executable, "-m", "cyclonedx_py", "requirements"],
                code,
                output,
                duration,
            )
        )
        failed |= code != 0
    hosted = os.environ.get("GITHUB_ACTIONS") == "true"
    records.append(
        {
            **evidence(
                "GitHub-hosted workflow execution",
                "workflow",
                ["GitHub Actions governed Python job"],
                0,
                "Hosted execution is active." if hosted else "Hosted execution requires GitHub Actions.",
                0,
            ),
            "status": "Passed" if hosted else "NotRun",
            "exitCode": 0 if hosted else None,
            "failureReason": None if hosted else "GitHub-hosted execution was not performed during local validation.",
            "summary": "GitHub-hosted Python workflow is running." if hosted else "GitHub-hosted Python workflow was not run locally.",
        }
    )
    (evidence_dir / "local-test-results.json").write_text(
        json.dumps(records, indent=2) + "\n", encoding="utf-8"
    )
    return 1 if failed else 0


if __name__ == "__main__":
    raise SystemExit(main())
