"""Trusted functional validation for governed Python projects.

Trusted tools run from a standards-controlled virtual environment. Caller code is
copied into a separate work root and is executed only during the isolated build,
test, and installed-package smoke phases.
"""

from __future__ import annotations

import argparse
import email.parser
import hashlib
import json
import os
import re
import shutil
import stat
import subprocess
import sys
import tarfile
import time
import tomllib
import venv
import zipfile
from datetime import UTC, datetime
from pathlib import Path, PurePosixPath
from typing import Any

FORBIDDEN_TOOL_MODULES = {
    "build",
    "cyclonedx_py",
    "mypy",
    "pip_audit",
    "pytest",
    "ruff",
}
IGNORED_COPY_NAMES = {
    ".git",
    ".mypy_cache",
    ".pytest_cache",
    ".ruff_cache",
    ".smoke-venv",
    ".venv",
    "__pycache__",
    "build",
    "dist",
    "evidence",
}
TOOL_DISTRIBUTIONS = {
    "ruff": "ruff",
    "mypy": "mypy",
    "pytest": "pytest",
    "pip_audit": "pip-audit",
    "build": "build",
    "cyclonedx_py": "cyclonedx-bom",
    "hatchling": "hatchling",
    "pip": "pip",
}


def utc() -> str:
    return datetime.now(UTC).isoformat().replace("+00:00", "Z")


def sha256(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as stream:
        for chunk in iter(lambda: stream.read(1024 * 1024), b""):
            digest.update(chunk)
    return digest.hexdigest()


def is_within(path: Path, root: Path) -> bool:
    try:
        path.relative_to(root)
        return True
    except ValueError:
        return False


def sanitize(value: str, roots: list[Path]) -> str:
    result = value
    for root in sorted(roots, key=lambda item: len(str(item)), reverse=True):
        text = str(root)
        result = result.replace(text, ".").replace(text.replace("\\", "/"), ".")
    return result.replace(str(sys.executable), "python")


def trusted_env(home: Path) -> dict[str, str]:
    blocked_prefixes = ("PYTHON", "PYTEST", "MYPY", "RUFF")
    blocked_names = {
        "PIP_CONFIG_FILE",
        "PIP_INDEX_URL",
        "PIP_EXTRA_INDEX_URL",
        "PIP_FIND_LINKS",
        "PIP_REQUIRE_VIRTUALENV",
    }
    env = {
        key: value
        for key, value in os.environ.items()
        if not key.startswith(blocked_prefixes) and key not in blocked_names
    }
    home.mkdir(parents=True, exist_ok=True)
    env.update(
        {
            "HOME": str(home),
            "PIP_CONFIG_FILE": os.devnull,
            "PIP_DISABLE_PIP_VERSION_CHECK": "1",
            "PYTHONHASHSEED": "0",
            "PYTHONNOUSERSITE": "1",
            "PYTHONSAFEPATH": "1",
            "PYTEST_DISABLE_PLUGIN_AUTOLOAD": "1",
        }
    )
    return env


def run(
    command: list[str],
    cwd: Path,
    env: dict[str, str],
    timeout: int = 300,
) -> tuple[int, str, float]:
    started = time.monotonic()
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
        return 124, f"Command exceeded {timeout} seconds: {exc}", time.monotonic() - started


def module_command(python: Path, module: str, *args: str) -> list[str]:
    return [str(python), "-I", "-m", module, *args]


def inspect_project_tree(root: Path) -> None:
    if root.is_symlink():
        raise ValueError("project root must not be a symbolic link")
    root_resolved = root.resolve(strict=True)
    for current, directories, files in os.walk(root, followlinks=False):
        current_path = Path(current)
        for name in [*directories, *files]:
            path = current_path / name
            info = path.lstat()
            mode = info.st_mode
            if stat.S_ISLNK(mode):
                raise ValueError(f"project contains a symbolic link: {path.relative_to(root)}")
            if not (stat.S_ISDIR(mode) or stat.S_ISREG(mode)):
                raise ValueError(f"project contains a special filesystem entry: {path.relative_to(root)}")
            if stat.S_ISREG(mode) and info.st_nlink > 1:
                raise ValueError(f"project contains a hard-linked file: {path.relative_to(root)}")
            if not is_within(path.resolve(strict=True), root_resolved):
                raise ValueError(f"project path escapes its root: {path.relative_to(root)}")


def prepare_work_root(project: Path, work_root: Path) -> tuple[Path, Path, Path]:
    project_resolved = project.resolve(strict=True)
    candidate = work_root.absolute()
    if candidate.is_symlink():
        raise ValueError("work root must not be a symbolic link")
    resolved = candidate.resolve(strict=False)
    if is_within(resolved, project_resolved) or is_within(project_resolved, resolved):
        raise ValueError("project and work roots must not overlap")
    if resolved.exists():
        inspect_project_tree(resolved)
        shutil.rmtree(resolved)
    resolved.mkdir(parents=True, mode=0o700)
    caller = resolved / "caller"
    evidence_dir = resolved / "evidence"
    dist_dir = resolved / "dist"
    shutil.copytree(
        project_resolved,
        caller,
        symlinks=False,
        ignore=shutil.ignore_patterns(*IGNORED_COPY_NAMES),
    )
    evidence_dir.mkdir(mode=0o700)
    dist_dir.mkdir(mode=0o700)
    inspect_project_tree(caller)
    return caller, evidence_dir, dist_dir


def parse_project_metadata(project: Path) -> dict[str, Any]:
    pyproject = project / "pyproject.toml"
    data = tomllib.loads(pyproject.read_text(encoding="utf-8"))
    build_system = data.get("build-system", {})
    if build_system.get("build-backend") != "hatchling.build":
        raise ValueError("only the reviewed hatchling.build backend is supported")
    if build_system.get("requires") != ["hatchling==1.31.0"]:
        raise ValueError("build-system requirements must be exactly hatchling==1.31.0")
    if "backend-path" in build_system:
        raise ValueError("build-system backend-path is not permitted")
    project_table = data.get("project", {})
    name = project_table.get("name")
    version = project_table.get("version")
    if not isinstance(name, str) or not re.fullmatch(r"[A-Za-z0-9][A-Za-z0-9._-]*", name):
        raise ValueError("project.name must be a static valid distribution name")
    if not isinstance(version, str) or not re.fullmatch(r"[0-9]+(?:\.[0-9]+){1,3}(?:[A-Za-z0-9.-]*)?", version):
        raise ValueError("project.version must be a supported static version")
    dynamic = project_table.get("dynamic", [])
    if "version" in dynamic:
        raise ValueError("dynamic project versions are not supported")
    packages = [
        item.name
        for item in (project / "src").iterdir()
        if item.is_dir() and not item.is_symlink() and (item / "__init__.py").is_file()
    ]
    if len(packages) != 1 or not all(part.isidentifier() for part in packages[0].split(".")):
        raise ValueError("src must contain exactly one importable package")
    scripts = project_table.get("scripts", {})
    if not isinstance(scripts, dict):
        raise ValueError("project.scripts must be a table")
    for script_name, target in scripts.items():
        if not re.fullmatch(r"[A-Za-z0-9][A-Za-z0-9._-]*", script_name):
            raise ValueError("console-script names must be safe tokens")
        if not isinstance(target, str) or not target.startswith(packages[0] + "."):
            raise ValueError("console-script targets must belong to the declared package")
    return {
        "distribution": name,
        "version": version,
        "importName": packages[0],
        "scripts": scripts,
        "normalizedDistribution": re.sub(r"[-_.]+", "_", name),
    }


def normalized_member(name: str) -> str:
    candidate = PurePosixPath(name)
    if not name or name.startswith("/") or candidate.is_absolute() or ".." in candidate.parts or "\\" in name:
        raise ValueError(f"unsafe archive member: {name}")
    normalized = candidate.as_posix().rstrip("/")
    if not normalized:
        raise ValueError("archive contains an empty member name")
    return normalized


def inspect_wheel(path: Path, metadata: dict[str, Any]) -> list[str]:
    names: list[str] = []
    seen: set[str] = set()
    with zipfile.ZipFile(path) as archive:
        for item in archive.infolist():
            name = normalized_member(item.filename)
            key = name.casefold()
            if key in seen:
                raise ValueError(f"wheel contains duplicate or case-colliding member: {name}")
            seen.add(key)
            mode = (item.external_attr >> 16) & 0xFFFF
            kind = stat.S_IFMT(mode)
            if kind not in (0, stat.S_IFREG, stat.S_IFDIR):
                raise ValueError(f"wheel contains a link or special member: {name}")
            names.append(name)
        top_levels = {PurePosixPath(name).parts[0].split(".")[0] for name in names}
        collision = sorted(FORBIDDEN_TOOL_MODULES.intersection(top_levels))
        if collision:
            raise ValueError(f"wheel attempts to replace trusted tool modules: {', '.join(collision)}")
        dist_info = f"{metadata['normalizedDistribution']}-{metadata['version']}.dist-info"
        metadata_name = f"{dist_info}/METADATA"
        if metadata_name not in names:
            raise ValueError("wheel is missing expected METADATA")
        parsed = email.parser.Parser().parsestr(archive.read(metadata_name).decode("utf-8"))
        if parsed.get("Name") != metadata["distribution"] or parsed.get("Version") != metadata["version"]:
            raise ValueError("wheel metadata does not match declared project metadata")
    return names


def inspect_sdist(path: Path, metadata: dict[str, Any]) -> list[str]:
    expected_root = f"{metadata['normalizedDistribution']}-{metadata['version']}"
    names: list[str] = []
    seen: set[str] = set()
    with tarfile.open(path, "r:gz") as archive:
        for item in archive.getmembers():
            name = normalized_member(item.name)
            key = name.casefold()
            if key in seen:
                raise ValueError(f"source distribution contains duplicate member: {name}")
            seen.add(key)
            if not (item.isfile() or item.isdir()):
                raise ValueError(f"source distribution contains a link or special member: {name}")
            if PurePosixPath(name).parts[0] != expected_root:
                raise ValueError(f"unexpected source-distribution root: {name}")
            names.append(name)
    return names


def package_lines(lock: Path) -> list[tuple[str, str]]:
    packages: list[tuple[str, str]] = []
    for line in lock.read_text(encoding="utf-8").splitlines():
        match = re.match(r"^([A-Za-z0-9_.-]+)==([^\s\\]+)", line.strip())
        if match:
            packages.append((match.group(1), match.group(2)))
    return packages


def tool_versions(tool_python: Path, env: dict[str, str], cwd: Path) -> dict[str, str]:
    code = "import importlib.metadata,json; print(json.dumps({" + ",".join(
        f"{module!r}:importlib.metadata.version({distribution!r})"
        for module, distribution in TOOL_DISTRIBUTIONS.items()
    ) + "}))"
    result, output, _ = run([str(tool_python), "-I", "-c", code], cwd, env, 60)
    if result != 0:
        raise RuntimeError(f"could not identify trusted tools: {output}")
    return json.loads(output.strip().splitlines()[-1])


def make_evidence(
    name: str,
    category: str,
    command: list[str],
    code: int | None,
    output: str,
    duration: float,
    tool_name: str,
    tool_version: str,
    roots: list[Path],
    details: dict[str, Any] | None = None,
    status: str | None = None,
) -> dict[str, Any]:
    effective = status or ("Passed" if code == 0 else "Failed")
    sanitized = sanitize(output, roots)
    reason = sanitized[-1000:] or "Required validation did not complete."
    return {
        "schemaVersion": "1.1.0",
        "name": name,
        "category": category,
        "status": effective,
        "requiredValidation": True,
        "evidenceSource": "Automated",
        "command": sanitize(" ".join(command), roots),
        "workingDirectory": "trusted-isolated-workspace",
        "startedAtUtc": utc(),
        "completedAtUtc": utc(),
        "durationSeconds": round(duration, 3),
        "runtime": f"CPython {sys.version_info.major}.{sys.version_info.minor}.{sys.version_info.micro}",
        "toolName": tool_name,
        "toolVersion": tool_version,
        "exitCode": code,
        "summary": f"{name} {'completed successfully' if effective == 'Passed' else effective.lower()}.",
        "warnings": [],
        "failureReason": reason if effective == "Failed" else None,
        "blockedReason": reason if effective == "Blocked" else None,
        "details": {"sanitizedOutput": sanitized or "No command output.", **(details or {})},
    }


def write_record(evidence_dir: Path, filename: str, record: Any) -> None:
    (evidence_dir / filename).write_text(json.dumps(record, indent=2) + "\n", encoding="utf-8")


def build_sbom(
    metadata: dict[str, Any], wheel: Path, sdist: Path, runtime_lock: Path, generator_version: str
) -> dict[str, Any]:
    root_ref = f"pkg:pypi/{metadata['distribution']}@{metadata['version']}"
    components = []
    dependencies = []
    for name, version in package_lines(runtime_lock):
        ref = f"pkg:pypi/{name.lower().replace('_', '-')}@{version}"
        components.append({"type": "library", "name": name, "version": version, "purl": ref, "bom-ref": ref})
        dependencies.append(ref)
    return {
        "bomFormat": "CycloneDX",
        "specVersion": "1.5",
        "serialNumber": f"urn:uuid:{hashlib.sha256((root_ref + sha256(wheel)).encode()).hexdigest()[:32]}",
        "version": 1,
        "metadata": {
            "timestamp": utc(),
            "tools": {"components": [{"type": "application", "name": "cyclonedx-bom", "version": generator_version}]},
            "component": {
                "type": "application",
                "name": metadata["distribution"],
                "version": metadata["version"],
                "purl": root_ref,
                "bom-ref": root_ref,
                "hashes": [
                    {"alg": "SHA-256", "content": sha256(wheel)},
                    {"alg": "SHA-256", "content": sha256(sdist)},
                ],
            },
        },
        "components": components,
        "dependencies": [{"ref": root_ref, "dependsOn": dependencies}],
    }


def validate(args: argparse.Namespace) -> int:
    original_project = args.project.absolute()
    if not original_project.exists() or not (original_project / "project-manifest.json").is_file():
        raise ValueError("project must be a governed Python project root")
    inspect_project_tree(original_project)
    project, evidence_dir, dist_dir = prepare_work_root(original_project, args.work_root)
    roots = [original_project.resolve(), args.work_root.resolve(), args.tool_python.resolve()]
    tool_python = args.tool_python.resolve(strict=True)
    tool_lock = args.tool_lock.resolve(strict=True)
    if is_within(tool_python, original_project.resolve()) or is_within(tool_lock, original_project.resolve()):
        raise ValueError("trusted tools and locks must be outside the caller project")
    runtime_lock = project / args.runtime_lock
    if runtime_lock.is_symlink() or not runtime_lock.is_file():
        raise ValueError("runtime dependency lock is missing or unsafe")
    metadata = parse_project_metadata(project)
    env = trusted_env(args.work_root / "home")
    versions = tool_versions(tool_python, env, args.work_root)
    records: list[dict[str, Any]] = []

    checks = [
        (
            "Python Ruff",
            "lint",
            "python-ruff.json",
            "ruff",
            module_command(tool_python, "ruff", "check", "--no-cache", "--isolated", "--extend-per-file-ignores", "tests/*:S101", str(project / "src"), str(project / "tests")),
        ),
        (
            "Python formatting",
            "lint",
            "python-formatting.json",
            "ruff",
            module_command(tool_python, "ruff", "format", "--check", "--no-cache", "--isolated", str(project / "src"), str(project / "tests")),
        ),
        (
            "Python type check",
            "lint",
            "python-type-check.json",
            "mypy",
            module_command(tool_python, "mypy", "--config-file", str(args.mypy_config.resolve(strict=True)), str(project / "src")),
        ),
    ]
    failed = False
    for name, category, filename, tool, command in checks:
        code, output, duration = run(command, args.work_root, env)
        record = make_evidence(name, category, command, code, output, duration, tool, versions[tool], roots)
        records.append(record)
        write_record(evidence_dir, filename, record)
        failed |= code != 0

    build_command = module_command(tool_python, "build", "--no-isolation", "--wheel", "--sdist", "--outdir", str(dist_dir), str(project))
    code, output, duration = run(build_command, args.work_root, env)
    build_records: list[dict[str, Any]] = [
        make_evidence("Python package build", "build", build_command, code, output, duration, "build", versions["build"], roots)
    ]
    failed |= code != 0
    wheels = list(dist_dir.glob("*.whl"))
    sdists = list(dist_dir.glob("*.tar.gz"))
    if code == 0:
        if len(wheels) != 1 or len(sdists) != 1 or len(list(dist_dir.iterdir())) != 2:
            raise ValueError("build must produce exactly one wheel and one source distribution")
        wheel, sdist = wheels[0], sdists[0]
        wheel_names = inspect_wheel(wheel, metadata)
        sdist_names = inspect_sdist(sdist, metadata)
        inspection = make_evidence(
            "Python archive inspection",
            "build",
            ["trusted-archive-inspection"],
            0,
            "Archive members and package metadata are safe.",
            0,
            "python-standard-library",
            f"{sys.version_info.major}.{sys.version_info.minor}.{sys.version_info.micro}",
            roots,
            {
                "artifacts": {
                    wheel.name: sha256(wheel),
                    sdist.name: sha256(sdist),
                },
                "wheelMembers": len(wheel_names),
                "sdistMembers": len(sdist_names),
            },
        )
        build_records.append(inspection)

        test_venv = args.work_root / "test-venv"
        venv.EnvBuilder(with_pip=True, clear=True).create(test_venv)
        test_python = test_venv / ("Scripts/python.exe" if os.name == "nt" else "bin/python")
        test_env = trusted_env(args.work_root / "test-home")
        install_tools = module_command(test_python, "pip", "install", "--no-input", "--only-binary=:all:", "--require-hashes", "--no-deps", "-r", str(tool_lock))
        install_code, install_output, install_duration = run(install_tools, args.work_root, test_env, 600)
        if install_code == 0 and package_lines(runtime_lock):
            runtime_install = module_command(test_python, "pip", "install", "--no-input", "--only-binary=:all:", "--require-hashes", "--no-deps", "-r", str(runtime_lock))
            install_code, install_output, extra = run(runtime_install, args.work_root, test_env, 600)
            install_duration += extra
        if install_code == 0:
            wheel_install = module_command(test_python, "pip", "install", "--no-input", "--no-deps", str(wheel))
            install_code, install_output, extra = run(wheel_install, args.work_root, test_env, 300)
            install_duration += extra
        build_records.append(
            make_evidence("Installed wheel environment", "integration", install_tools, install_code, install_output, install_duration, "pip", versions["pip"], roots)
        )
        failed |= install_code != 0

        if install_code == 0:
            pytest_command = module_command(test_python, "pytest", "-c", os.devnull, "--rootdir", str(project), "-p", "no:cacheprovider", "--strict-config", "--strict-markers", str(project / "tests"))
            test_code, test_output, test_duration = run(pytest_command, args.work_root, test_env)
            test_record = make_evidence("Python tests", "unit", pytest_command, test_code, test_output, test_duration, "pytest", versions["pytest"], roots)
            records.append(test_record)
            write_record(evidence_dir, "python-tests.json", test_record)
            failed |= test_code != 0

            smoke_code_text = (
                "import importlib, pathlib; "
                f"m=importlib.import_module({metadata['importName']!r}); "
                "p=pathlib.Path(m.__file__).resolve(); "
                "print(p); "
                f"assert {str(project / 'src')!r} not in str(p)"
            )
            smoke_command = [str(test_python), "-I", "-c", smoke_code_text]
            smoke_code, smoke_output, smoke_duration = run(smoke_command, args.work_root, test_env)
            smoke_record = make_evidence("Installed wheel smoke test", "integration", smoke_command, smoke_code, smoke_output, smoke_duration, metadata["distribution"], metadata["version"], roots, {"importName": metadata["importName"]})
            build_records.append(smoke_record)
            failed |= smoke_code != 0

        sbom = build_sbom(metadata, wheel, sdist, runtime_lock, versions["cyclonedx_py"])
        write_record(evidence_dir, "python-project-sbom.cdx.json", sbom)
        sbom_record = make_evidence("Python project SBOM", "security", ["trusted-cyclonedx-generation"], 0, "CycloneDX application SBOM generated.", 0, "cyclonedx-bom", versions["cyclonedx_py"], roots, {"rootComponent": sbom["metadata"]["component"]["purl"]})
        records.append(sbom_record)

    write_record(evidence_dir, "python-build.json", build_records)
    records.extend(build_records)

    runtime_packages = package_lines(runtime_lock)
    if runtime_packages:
        audit_command = module_command(tool_python, "pip_audit", "--disable-pip", "--progress-spinner", "off", "--format", "json", "--requirement", str(runtime_lock))
        audit_code, audit_output, audit_duration = run(audit_command, args.work_root, env)
        if audit_code == 0:
            audit_status = "Passed"
        elif audit_code == 1:
            audit_status = "Failed"
        elif re.search(r"(network|connection|timeout|service unavailable|name resolution)", audit_output, re.I):
            audit_status = "Blocked"
        else:
            audit_status = "Failed"
        audit_record = make_evidence("Python dependency audit", "security", audit_command, None if audit_status == "Blocked" else audit_code, audit_output, audit_duration, "pip-audit", versions["pip_audit"], roots, {"dependencyCount": len(runtime_packages), "advisorySource": "PyPI advisory service", "queryTimestampUtc": utc()}, audit_status)
        failed |= audit_status in {"Failed", "Blocked"}
    else:
        audit_record = make_evidence("Python dependency audit", "security", ["pip-audit", "requirements-runtime.lock"], None, "No third-party runtime dependencies are declared.", 0, "pip-audit", versions["pip_audit"], roots, {"dependencyCount": 0}, "NotApplicable")
    records.append(audit_record)
    write_record(evidence_dir, "python-dependency-audit.json", audit_record)

    hosted = os.environ.get("GITHUB_ACTIONS") == "true"
    hosted_record = make_evidence("GitHub-hosted workflow execution", "workflow", ["GitHub Actions governed Python job"], 0 if hosted else None, "Hosted execution is active." if hosted else "Hosted execution was not performed locally.", 0, "GitHub Actions", os.environ.get("RUNNER_OS", "local"), roots, status="Passed" if hosted else "NotRun")
    records.append(hosted_record)
    write_record(evidence_dir, "local-test-results.json", records)
    return 1 if failed else 0


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--project", type=Path, required=True)
    parser.add_argument("--work-root", type=Path, required=True)
    parser.add_argument("--tool-python", type=Path, required=True)
    parser.add_argument("--tool-lock", type=Path, required=True)
    parser.add_argument("--runtime-lock", default="requirements-runtime.lock")
    parser.add_argument("--mypy-config", type=Path, required=True)
    args = parser.parse_args()
    try:
        return validate(args)
    except Exception as exc:
        work_root = args.work_root.absolute()
        evidence_dir = work_root / "evidence"
        evidence_dir.mkdir(parents=True, exist_ok=True)
        record = make_evidence("Governed Python validation", "workflow", ["python-project-validation.py"], 1, str(exc), 0, "governed-python-validator", "1.1.0", [args.project.absolute(), work_root])
        write_record(evidence_dir, "local-test-results.json", [record])
        write_record(evidence_dir, "python-validation.json", record)
        print(str(exc), file=sys.stderr)
        return 1


if __name__ == "__main__":
    raise SystemExit(main())
