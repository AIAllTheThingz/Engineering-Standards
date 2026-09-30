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
from datetime import UTC, datetime, timedelta
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
        result = sanitize_path_variants(result, text)
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
        result = subprocess.run(  # noqa: S603 - commands use standards-validated executables and paths.
            command,
            cwd=cwd,
            env=env,
            text=True,
            stdout=subprocess.PIPE,
            stderr=subprocess.STDOUT,
            timeout=timeout,
            check=False,
            shell=False,
        )
        return result.returncode, result.stdout[-12000:], time.monotonic() - started
    except subprocess.TimeoutExpired as exc:
        return 124, f"Command exceeded {timeout} seconds: {exc}", time.monotonic() - started


def sanitize_path_variants(value: str, path: str) -> str:
    for candidate in (path, path.replace("\\", "/"), path.replace("\\", "\\\\")):
        value = value.replace(candidate, ".")
    return value


def sanitize_evidence_value(value: Any, roots: list[Path]) -> Any:
    if isinstance(value, str):
        return sanitize(value, roots)
    if isinstance(value, Path):
        return sanitize(str(value), roots)
    if isinstance(value, list):
        return [sanitize_evidence_value(item, roots) for item in value]
    if isinstance(value, dict):
        return {
            sanitize(key, roots) if isinstance(key, str) else str(key): sanitize_evidence_value(item, roots)
            for key, item in value.items()
        }
    return value


LOCK_RESOLUTION_TARGETS: tuple[tuple[str, tuple[str, ...]], ...] = (
    (
        "linux-cpython-3.13.2-x86_64",
        (
            "--platform",
            "manylinux_2_17_x86_64",
            "--implementation",
            "cp",
            "--python-version",
            "3.13.2",
            "--abi",
            "cp313",
        ),
    ),
    (
        "windows-cpython-3.13.2-x86_64",
        (
            "--platform",
            "win_amd64",
            "--implementation",
            "cp",
            "--python-version",
            "3.13.2",
            "--abi",
            "cp313",
        ),
    ),
    (
        "macos-cpython-3.13.2-x86_64",
        (
            "--platform",
            "macosx_13_0_x86_64",
            "--implementation",
            "cp",
            "--python-version",
            "3.13.2",
            "--abi",
            "cp313",
        ),
    ),
)
LOCK_RESOLUTION_PIP_NAME = "pip"
LOCK_RESOLUTION_PIP_VERSION = "26.2.1"
# The declared win_amd64 target uses the supported Windows 10 22H2 AMD64
# marker baseline. PEP 508 exposes platform.version() separately from
# platform.release(), so both must be concrete rather than treating
# version-gated dependencies as inactive.
WINDOWS_10_PLATFORM_RELEASE = "10"
WINDOWS_10_PLATFORM_VERSION = "10.0.19045"
# The declared macosx_13_0_x86_64 target is the released Intel macOS 13.0
# baseline.  PEP 508 exposes these values verbatim through platform.release()
# and platform.version(), so keep the marker environment aligned with that
# target instead of silently treating release-gated requirements as inactive.
MACOS_13_0_PLATFORM_RELEASE = "22.1.0"
MACOS_13_0_PLATFORM_VERSION = (
    "Darwin Kernel Version 22.1.0: Sun Oct 9 20:14:54 PDT 2022; "
    "root:xnu-8792.41.9~2/RELEASE_X86_64"
)
# Pip's cross-platform options select compatible wheels but do not apply PEP 508
# platform markers. These environments mirror the targets resolved above and are
# injected into Pip before each base or supplemental target resolution.
LOCK_RESOLUTION_TARGET_MARKER_ENVIRONMENTS: tuple[dict[str, str], ...] = (
    {
        "implementation_name": "cpython",
        "implementation_version": "3.13.2",
        "os_name": "posix",
        "platform_machine": "x86_64",
        "platform_python_implementation": "CPython",
        "platform_release": "",
        "platform_system": "Linux",
        "platform_version": "",
        "python_full_version": "3.13.2",
        "python_version": "3.13",
        "sys_platform": "linux",
        "extra": "",
    },
    {
        "implementation_name": "cpython",
        "implementation_version": "3.13.2",
        "os_name": "nt",
        "platform_machine": "AMD64",
        "platform_python_implementation": "CPython",
        "platform_release": WINDOWS_10_PLATFORM_RELEASE,
        "platform_system": "Windows",
        "platform_version": WINDOWS_10_PLATFORM_VERSION,
        "python_full_version": "3.13.2",
        "python_version": "3.13",
        "sys_platform": "win32",
        "extra": "",
    },
    {
        "implementation_name": "cpython",
        "implementation_version": "3.13.2",
        "os_name": "posix",
        "platform_machine": "x86_64",
        "platform_python_implementation": "CPython",
        "platform_release": MACOS_13_0_PLATFORM_RELEASE,
        "platform_system": "Darwin",
        "platform_version": MACOS_13_0_PLATFORM_VERSION,
        "python_full_version": "3.13.2",
        "python_version": "3.13",
        "sys_platform": "darwin",
        "extra": "",
    },
)
FUNCTIONAL_RUNTIME_MARKER_ENVIRONMENT: dict[str, str] = {
    "implementation_name": "cpython",
    "implementation_version": "3.12.11",
    "os_name": "posix",
    "platform_machine": "x86_64",
    "platform_python_implementation": "CPython",
    "platform_release": "",
    "platform_system": "Linux",
    "platform_version": "",
    "python_full_version": "3.12.11",
    "python_version": "3.12",
    "sys_platform": "linux",
    "extra": "",
}
TARGET_MARKER_PIP_WRAPPER = """\
import json
import sys

from pip._vendor.packaging import markers

target_environment = json.loads(sys.argv[1])


def target_marker_environment():
    return dict(target_environment)


markers.default_environment = target_marker_environment

from pip._internal.cli.main import main

raise SystemExit(main(sys.argv[2:]))
"""
TOOLCHAIN_SBOM_PROJECT_NAME = "engineering-standards-python-toolchain"
TOOLCHAIN_SBOM_PROJECT_VERSION = "1.0.0"


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


def write_toolchain_sbom_pyproject(work_root: Path) -> Path:
    """Write standards-owned metadata for the validation-toolchain SBOM root."""
    metadata_dir = work_root.resolve(strict=True) / "toolchain-sbom-metadata"
    metadata_dir.mkdir(mode=0o700, exist_ok=True)
    metadata_path = metadata_dir / "pyproject.toml"
    metadata_path.write_text(
        "[project]\n"
        f'name = "{TOOLCHAIN_SBOM_PROJECT_NAME}"\n'
        f'version = "{TOOLCHAIN_SBOM_PROJECT_VERSION}"\n'
        'description = "Standards-owned Python validation toolchain"\n'
        'requires-python = ">=3.13,<3.14"\n',
        encoding="utf-8",
    )
    return metadata_path


def attach_sbom_root_dependencies(sbom_path: Path) -> None:
    """Connect an SBOM root to every governed component in its closure."""
    try:
        document = json.loads(sbom_path.read_text(encoding="utf-8"))
    except (OSError, json.JSONDecodeError) as exc:
        raise ValueError(f"could not read generated SBOM: {exc}") from exc
    if not isinstance(document, dict):
        raise ValueError("generated SBOM must be a JSON object")
    metadata = document.get("metadata")
    root_component = metadata.get("component") if isinstance(metadata, dict) else None
    root_ref = root_component.get("bom-ref") if isinstance(root_component, dict) else None
    if not isinstance(root_ref, str) or not root_ref:
        raise ValueError("generated SBOM is missing its root component reference")
    components = document.get("components", [])
    if not isinstance(components, list):
        raise ValueError("generated SBOM components must be a list")
    component_refs: list[str] = []
    for component in components:
        ref = component.get("bom-ref") if isinstance(component, dict) else None
        if not isinstance(ref, str) or not ref:
            raise ValueError("generated SBOM contains a component without a reference")
        if ref in component_refs:
            raise ValueError(f"generated SBOM contains duplicate component reference '{ref}'")
        component_refs.append(ref)
    dependencies = document.get("dependencies")
    if not isinstance(dependencies, list) or any(not isinstance(item, dict) for item in dependencies):
        raise ValueError("generated SBOM contains invalid dependency records")
    root_records = [item for item in dependencies if item.get("ref") == root_ref]
    if len(root_records) != 1:
        raise ValueError("generated SBOM must contain exactly one root dependency record")
    root_records[0]["dependsOn"] = component_refs
    try:
        sbom_path.write_text(json.dumps(document, indent=2) + "\n", encoding="utf-8")
    except OSError as exc:
        raise ValueError(f"could not write generated SBOM: {exc}") from exc


GOVERNED_HATCHLING_VERSION = "1.32.4"


def parse_project_metadata(project: Path) -> dict[str, Any]:
    pyproject = project / "pyproject.toml"
    data = tomllib.loads(pyproject.read_text(encoding="utf-8"))
    build_system = data.get("build-system", {})
    if build_system.get("build-backend") != "hatchling.build":
        raise ValueError("only the reviewed hatchling.build backend is supported")
    expected_hatchling = f"hatchling=={GOVERNED_HATCHLING_VERSION}"
    if build_system.get("requires") != [expected_hatchling]:
        raise ValueError(f"build-system requirements must be exactly {expected_hatchling}")
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


def normalized_requirement_name(name: str) -> str:
    return re.sub(r"[-_.]+", "-", name).lower()


def pinned_requirements(path: Path) -> dict[str, str]:
    requirements: dict[str, str] = {}
    for line_number, raw_line in enumerate(path.read_text(encoding="utf-8").splitlines(), start=1):
        line = raw_line.split("#", 1)[0].strip()
        if not line:
            continue
        match = re.fullmatch(r"([A-Za-z0-9][A-Za-z0-9_.-]*)==([^\s]+)", line)
        if not match:
            raise ValueError(f"{path.name} line {line_number} must contain an exact name==version pin")
        name = normalized_requirement_name(match.group(1))
        if name in requirements:
            raise ValueError(f"{path.name} contains duplicate requirement '{match.group(1)}'")
        requirements[name] = match.group(2)
    if not requirements:
        raise ValueError(f"{path.name} does not contain any requirements")
    return requirements


def locked_requirements(path: Path) -> dict[str, str]:
    requirements: dict[str, str] = {}
    for name, version in package_lines(path):
        normalized_name = normalized_requirement_name(name)
        if normalized_name in requirements:
            raise ValueError(f"{path.name} contains duplicate locked requirement '{name}'")
        requirements[normalized_name] = version
    if not requirements:
        raise ValueError(f"{path.name} does not contain any locked requirements")
    return requirements


def locked_requirement_hashes(path: Path, name: str, version: str) -> tuple[str, ...]:
    """Return the hash options for one exact package pin in a pip-compile lock."""
    target_name = normalized_requirement_name(name)
    pinned_version: str | None = None
    hashes: list[str] = []
    collecting_hashes = False
    hash_pattern = re.compile(r"^\s*--hash=sha256:([0-9a-fA-F]{64})(?:\s+\\)?\s*$")
    for raw_line in path.read_text(encoding="utf-8").splitlines():
        package_match = re.match(r"^([A-Za-z0-9_.-]+)==([^\s\\]+)", raw_line.strip())
        if package_match:
            package_name = normalized_requirement_name(package_match.group(1))
            package_version = package_match.group(2)
            collecting_hashes = package_name == target_name
            if collecting_hashes:
                if pinned_version is not None:
                    raise ValueError(f"{path.name} contains duplicate locked requirement '{name}'")
                pinned_version = package_version
            continue
        if not collecting_hashes:
            continue
        hash_match = hash_pattern.fullmatch(raw_line)
        if hash_match:
            hashes.append(f"--hash=sha256:{hash_match.group(1).lower()}")
    if pinned_version is None:
        raise ValueError(f"{path.name} must lock {name}=={version} for resolver verification")
    if pinned_version != version:
        raise ValueError(
            f"{path.name} must lock {name}=={version} for resolver verification "
            f"(found {name}=={pinned_version})"
        )
    if not hashes:
        raise ValueError(f"{path.name} must hash-pin {name}=={version} for resolver verification")
    return tuple(hashes)


def direct_locked_requirements(path: Path, requirements_input: Path) -> dict[str, str]:
    requirements: dict[str, str] = {}
    current: tuple[str, str] | None = None
    inline_direct_marker = re.compile(rf"^\s*# via -r .*{re.escape(requirements_input.name)}\s*$")
    multiline_provenance_marker = re.compile(r"^\s*# via\s*$")
    multiline_direct_marker = re.compile(rf"^\s*#\s+-r\s+.*{re.escape(requirements_input.name)}\s*$")
    in_multiline_provenance = False
    for raw_line in path.read_text(encoding="utf-8").splitlines():
        match = re.match(r"^([A-Za-z0-9_.-]+)==([^\s\\]+)", raw_line.strip())
        if match:
            current = (normalized_requirement_name(match.group(1)), match.group(2))
            in_multiline_provenance = False
            continue
        if current is None:
            continue
        if inline_direct_marker.fullmatch(raw_line) or (
            in_multiline_provenance and multiline_direct_marker.fullmatch(raw_line)
        ):
            name, version = current
            if name in requirements:
                raise ValueError(f"{path.name} contains duplicate direct requirement '{name}'")
            requirements[name] = version
        if multiline_provenance_marker.fullmatch(raw_line):
            in_multiline_provenance = True
    return requirements


def validate_requirements_lock(requirements_input: Path, lock: Path) -> None:
    requested = pinned_requirements(requirements_input)
    locked = locked_requirements(lock)
    direct_locked = direct_locked_requirements(lock, requirements_input)
    missing = sorted(name for name in requested if name not in locked or name not in direct_locked)
    extra = sorted(name for name in direct_locked if name not in requested)
    mismatched = sorted(
        f"{name}=={requested[name]} (lock has {direct_locked[name]})"
        for name in requested
        if name in direct_locked and requested[name] != direct_locked[name]
    )
    if missing or extra or mismatched:
        details: list[str] = []
        if missing:
            details.append(f"missing from lock: {', '.join(missing)}")
        if extra:
            details.append(f"extra direct pins in lock: {', '.join(extra)}")
        if mismatched:
            details.append(f"version mismatch: {', '.join(mismatched)}")
        raise ValueError(
            f"requirements input and lock are out of sync ({'; '.join(details)}). "
            "Regenerate the lock with the documented pip-compile command."
        )


def resolution_install_records(report: Path) -> list[dict[str, Any]]:
    try:
        document = json.loads(report.read_text(encoding="utf-8"))
    except (OSError, json.JSONDecodeError) as exc:
        raise ValueError(f"could not read the pip resolution report: {exc}") from exc
    installs = document.get("install")
    if not isinstance(installs, list) or not installs:
        raise ValueError("pip resolution report does not contain a non-empty install closure")
    if any(not isinstance(item, dict) for item in installs):
        raise ValueError("pip resolution report contains an invalid install record")
    return installs


def resolved_requirements(install_records: list[dict[str, Any]]) -> dict[str, str]:
    requirements: dict[str, str] = {}
    for item in install_records:
        if not isinstance(item.get("metadata"), dict):
            raise ValueError("pip resolution report contains an invalid install record")
        name = item["metadata"].get("name")
        version = item["metadata"].get("version")
        if not isinstance(name, str) or not isinstance(version, str) or not name or not version:
            raise ValueError("pip resolution report contains a package without a name and version")
        normalized_name = normalized_requirement_name(name)
        if normalized_name in requirements:
            raise ValueError(f"pip resolution report contains duplicate package '{name}'")
        requirements[normalized_name] = version
    return requirements


def package_dependency_requirements(install_records: list[dict[str, Any]]) -> list[tuple[str, Any]]:
    """Parse the complete package dependency graph from a pip resolution report."""
    try:
        from pip._vendor.packaging.requirements import InvalidRequirement, Requirement
    except ImportError as exc:
        raise ValueError("pip's bundled PEP 508 requirement parser is unavailable") from exc

    dependencies: list[tuple[str, Any]] = []
    for item in install_records:
        metadata = item.get("metadata")
        if not isinstance(metadata, dict):
            raise ValueError("pip resolution report contains an invalid install record")
        source_name = metadata.get("name")
        if not isinstance(source_name, str) or not source_name:
            raise ValueError("pip resolution report contains a package without a name")
        source_package = normalized_requirement_name(source_name)
        requires_dist = metadata.get("requires_dist")
        if requires_dist is None:
            continue
        if not isinstance(requires_dist, list) or any(not isinstance(raw, str) for raw in requires_dist):
            raise ValueError("pip resolution report contains invalid package dependency metadata")
        for raw_requirement in requires_dist:
            try:
                requirement = Requirement(raw_requirement)
            except InvalidRequirement as exc:
                raise ValueError(
                    f"pip resolution report contains an invalid dependency declaration: {raw_requirement!r}"
                ) from exc
            if requirement.url is not None:
                raise ValueError(
                    "pip resolution report contains an unsupported direct URL dependency declaration: "
                    f"{raw_requirement!r}"
                )
            dependencies.append((source_package, requirement))
    return dependencies


def marker_variable_names(marker: Any) -> set[str]:
    """Return PEP 508 marker variables from pip's governed parser representation."""
    try:
        from pip._vendor.packaging.markers import Variable
    except ImportError as exc:
        raise ValueError("pip's bundled PEP 508 marker parser is unavailable") from exc

    variables: set[str] = set()

    def visit(value: Any) -> None:
        if isinstance(value, Variable):
            variables.add(value.value)
        elif isinstance(value, (list, tuple)):
            for item in value:
                visit(item)

    visit(marker._markers)
    return variables


def marker_may_apply_to_target(
    marker: Any,
    target_environment: dict[str, str],
    activated_extras: tuple[str, ...],
    unmodeled_fields: set[str],
) -> bool:
    """Return whether a marker can apply without assuming values for unmodeled fields."""
    try:
        from pip._vendor.packaging.markers import Variable, _eval_op, _normalize
    except ImportError as exc:
        raise ValueError("pip's bundled PEP 508 marker parser is unavailable") from exc

    def evaluate_condition(condition: tuple[Any, Any, Any], environment: dict[str, Any]) -> bool | None:
        lhs, operator, rhs = condition
        if isinstance(lhs, Variable):
            environment_key = lhs.value
            if environment_key in unmodeled_fields:
                return None
            lhs_value = environment[environment_key]
            rhs_value = rhs.value
        else:
            environment_key = rhs.value
            if environment_key in unmodeled_fields:
                return None
            lhs_value = lhs.value
            rhs_value = environment[environment_key]
        normalized_lhs, normalized_rhs = _normalize(lhs_value, rhs_value, key=environment_key)
        return _eval_op(normalized_lhs, operator, normalized_rhs, key=environment_key)

    def evaluate_expression(expression: list[Any], environment: dict[str, Any]) -> bool | None:
        groups: list[list[bool | None]] = [[]]
        for item in expression:
            if isinstance(item, list):
                groups[-1].append(evaluate_expression(item, environment))
            elif isinstance(item, tuple):
                groups[-1].append(evaluate_condition(item, environment))
            elif item == "or":
                groups.append([])
            elif item != "and":
                raise ValueError("pip resolution report contains an unsupported marker expression")
        group_results: list[bool | None] = []
        for group in groups:
            if any(result is False for result in group):
                group_results.append(False)
            elif all(result is True for result in group):
                group_results.append(True)
            else:
                group_results.append(None)
        if any(result is True for result in group_results):
            return True
        if all(result is False for result in group_results):
            return False
        return None

    for extra in activated_extras or ("",):
        environment = {**target_environment, "extra": extra}
        if evaluate_expression(marker._markers, environment) is not False:
            return True
    return False


def marker_applies_to_target(
    marker: Any,
    target_environment: dict[str, str],
    target_name: str,
    activated_extras: tuple[str, ...],
) -> bool:
    """Evaluate markers fail-closed only when unmodeled fields can affect the target."""
    unmodeled_fields = sorted(
        field
        for field in ("platform_release", "platform_version")
        if field in marker_variable_names(marker) and not target_environment.get(field)
    )
    if unmodeled_fields and marker_may_apply_to_target(
        marker,
        target_environment,
        activated_extras,
        set(unmodeled_fields),
    ):
        raise ValueError(
            "requirements lock closure cannot safely evaluate unmodeled "
            f"{', '.join(unmodeled_fields)} marker(s) for {target_name}"
        )
    if unmodeled_fields:
        return False
    extra_contexts = activated_extras or ("",)
    return any(
        marker.evaluate({**target_environment, "extra": extra})
        for extra in extra_contexts
    )


def target_reachable_packages_and_extras_for_target(
    dependencies: list[tuple[str, Any]],
    target_environment: dict[str, str],
    target_name: str,
    root_packages: set[str] | None = None,
    initially_activated_extras: dict[str, tuple[str, ...]] | None = None,
) -> tuple[set[str], dict[str, tuple[str, ...]]]:
    """Traverse only target-reachable dependency edges and propagate their requested extras."""
    initially_activated_extras = initially_activated_extras or {}
    initial_extras: dict[str, set[str]] = {
        normalized_requirement_name(package): set(extras)
        for package, extras in initially_activated_extras.items()
        if extras
    }
    activated = {package: set(extras) for package, extras in initial_extras.items()}
    seen_activated_states = {
        tuple(sorted((package, tuple(sorted(extras))) for package, extras in activated.items()))
    }
    while True:
        reachable = (
            {normalized_requirement_name(package) for package in root_packages}
            if root_packages is not None
            else {source_package for source_package, _ in dependencies}
        )
        reachable.update(
            normalized_requirement_name(package)
            for package in initially_activated_extras
        )
        next_activated = {package: set(extras) for package, extras in initial_extras.items()}
        changed = True
        while changed:
            changed = False
            for source_package, requirement in dependencies:
                if source_package not in reachable:
                    continue
                source_extras = activated.get(source_package, ())
                if requirement.marker is not None and not marker_applies_to_target(
                    requirement.marker,
                    target_environment,
                    target_name,
                    source_extras,
                ):
                    continue
                target_package = normalized_requirement_name(requirement.name)
                if target_package not in reachable:
                    reachable.add(target_package)
                    changed = True
                if requirement.extras:
                    target_extras = next_activated.setdefault(target_package, set())
                    previous_count = len(target_extras)
                    target_extras.update(requirement.extras)
                    changed = changed or len(target_extras) != previous_count
        if next_activated == activated:
            return reachable, {package: tuple(sorted(extras)) for package, extras in activated.items()}
        next_activated_state = tuple(
            sorted((package, tuple(sorted(extras))) for package, extras in next_activated.items())
        )
        if next_activated_state in seen_activated_states:
            raise ValueError(
                "requirements lock closure extra activation state did not converge for "
                f"{target_name}"
            )
        seen_activated_states.add(next_activated_state)
        activated = next_activated


def marker_gated_requirements_for_target(
    install_records: list[dict[str, Any]],
    locked: dict[str, str],
    target_environment: dict[str, str],
    target_name: str,
    activated_extras_by_package: dict[str, tuple[str, ...]] | None = None,
    root_packages: set[str] | None = None,
) -> dict[str, tuple[str, tuple[str, ...]]]:
    """Return lock pins reached by target-active dependency edges and activated extras."""
    dependencies = package_dependency_requirements(install_records)
    reachable_packages, activated_extras_by_package = target_reachable_packages_and_extras_for_target(
        dependencies,
        target_environment,
        target_name,
        root_packages,
        activated_extras_by_package,
    )
    marker_gated: dict[str, tuple[str, tuple[str, ...]]] = {}
    for source_package, requirement in dependencies:
        if source_package not in reachable_packages:
            continue
        activated_extras = activated_extras_by_package.get(source_package, ())
        if requirement.marker is None:
            continue
        if not marker_applies_to_target(
            requirement.marker,
            target_environment,
            target_name,
            activated_extras,
        ):
            continue
        name = normalized_requirement_name(requirement.name)
        version = locked.get(name)
        if version is None:
            raise ValueError(
                f"requirements lock is missing marker-gated package '{name}' required for {target_name}"
            )
        if not requirement.specifier.contains(version, prereleases=True):
            raise ValueError(
                f"requirements lock pin {name}=={version} does not satisfy the marker-gated "
                f"dependency declared for {target_name}"
            )
        extras = tuple(sorted(requirement.extras))
        prior = marker_gated.get(name)
        if prior is not None:
            prior_version, prior_extras = prior
            if prior_version != version:
                raise ValueError(
                    f"marker-gated package {name} has incompatible locked versions "
                    f"for {target_name}"
                )
            extras = tuple(sorted(set(prior_extras).union(extras)))
        marker_gated[name] = (version, extras)
    return marker_gated


def marker_resolution_requirement(name: str, version: str, extras: tuple[str, ...]) -> str:
    """Format a constrained supplemental request without discarding extras."""
    suffix = f"[{','.join(extras)}]" if extras else ""
    return f"{name}{suffix}=={version}"


def validate_resolved_requirements_lock(
    requirements_input: Path,
    lock: Path,
    reports: Path | tuple[Path, ...],
) -> None:
    """Require the lock to match the resolver closure on every applicable platform."""
    validate_requirements_lock(requirements_input, lock)
    locked = locked_requirements(lock)
    report_paths = (reports,) if isinstance(reports, Path) else reports
    if not report_paths:
        raise ValueError("requirements lock closure must include at least one resolution report")
    resolved: dict[str, str] = {}
    for report in report_paths:
        report_records = resolution_install_records(report)
        for name, version in resolved_requirements(report_records).items():
            prior_version = resolved.get(name)
            if prior_version is not None and prior_version != version:
                raise ValueError(
                    f"requirements lock resolution differs across supported targets for {name}: "
                    f"{prior_version} and {version}"
                )
            resolved[name] = version
    unexpected = sorted(
        f"{name}=={locked[name]}"
        for name in locked
        if name not in resolved
    )
    missing = sorted(
        f"{name}=={resolved[name]}" for name in resolved if name not in locked
    )
    mismatched = sorted(
        f"{name}=={resolved[name]} (lock has {locked[name]})"
        for name in resolved
        if name in locked and resolved[name] != locked[name]
    )
    if unexpected or missing or mismatched:
        details: list[str] = []
        if unexpected:
            details.append(f"unexpected locked packages: {', '.join(unexpected)}")
        if missing:
            details.append(f"missing resolved packages: {', '.join(missing)}")
        if mismatched:
            details.append(f"resolution version mismatch: {', '.join(mismatched)}")
        raise ValueError(
            f"requirements lock does not match the complete constrained resolver closure ({'; '.join(details)}). "
            "Regenerate the lock with the documented pip-compile command."
        )


class LockResolutionBlockedError(ValueError):
    """The package resolver could not reach the required external service."""


def require_pinned_lock_metadata_parser() -> None:
    """Reject PEP 508 parsing unless this process uses the governed pip build."""
    try:
        import pip
    except ImportError as exc:
        raise ValueError(
            f"requirements lock metadata parsing requires {LOCK_RESOLUTION_PIP_NAME}=={LOCK_RESOLUTION_PIP_VERSION}"
        ) from exc
    if getattr(pip, "__version__", None) != LOCK_RESOLUTION_PIP_VERSION:
        raise ValueError(
            "requirements lock metadata parsing must run under "
            f"{LOCK_RESOLUTION_PIP_NAME}=={LOCK_RESOLUTION_PIP_VERSION}"
        )


def is_transient_lock_resolution_failure(exit_code: int, output: str) -> bool:
    """Classify resolver outages without hiding invalid or stale lock failures."""
    if exit_code == 124:
        return True
    return bool(
        re.search(
            r"(?:could not fetch url|read timed? out|timed out|connection (?:reset|refused|aborted|error)|"
            r"failed to establish a new connection|network is unreachable|temporary failure in name resolution|"
            r"name or service not known|service unavailable|http error (?:429|5\d{2})|"
            r"(?:429|5\d{2}) (?:client|server) error|too many requests|503 server error)",
            output,
            flags=re.IGNORECASE,
        )
    )


def pinned_lock_resolver(
    source_python: Path,
    label: str,
    lock: Path,
    environment: Path,
    env: dict[str, str],
) -> Path:
    """Create a temporary resolver environment with the lock-pinned pip version."""
    hashes = locked_requirement_hashes(lock, LOCK_RESOLUTION_PIP_NAME, LOCK_RESOLUTION_PIP_VERSION)
    create_command = module_command(source_python, "venv", str(environment))
    create_code, create_output, _ = run(create_command, environment.parent, env, 120)
    if create_code != 0:
        message = (
            f"could not create the {label} resolver environment: "
            f"{sanitize(create_output, [lock.parent, environment.parent, source_python.parent])}"
        )
        if create_code == 124:
            raise LockResolutionBlockedError(message)
        raise ValueError(message)
    resolver_python = environment / ("Scripts/python.exe" if os.name == "nt" else "bin/python")
    if not resolver_python.is_file():
        raise ValueError(f"the {label} resolver environment did not produce a Python executable")
    bootstrap_requirements = environment / "bootstrap-pip.requirements"
    bootstrap_lines = [f"{LOCK_RESOLUTION_PIP_NAME}=={LOCK_RESOLUTION_PIP_VERSION} \\"]
    for index, hash_option in enumerate(hashes):
        continuation = " \\" if index < len(hashes) - 1 else ""
        bootstrap_lines.append(f"    {hash_option}{continuation}")
    bootstrap_requirements.write_text("\n".join(bootstrap_lines) + "\n", encoding="utf-8")
    bootstrap_command = module_command(
        resolver_python,
        "pip",
        "--isolated",
        "install",
        "--disable-pip-version-check",
        "--no-input",
        "--no-deps",
        "--upgrade",
        "--force-reinstall",
        "--only-binary=:all:",
        "--no-cache-dir",
        "--require-hashes",
        "--index-url",
        "https://pypi.org/simple",
        "-r",
        str(bootstrap_requirements),
    )
    bootstrap_code, bootstrap_output, _ = run(bootstrap_command, environment.parent, env, 300)
    if bootstrap_code != 0:
        message = (
            f"could not install the locked resolver pip for {label}: "
            f"{sanitize(bootstrap_output, [lock.parent, environment.parent, source_python.parent])}"
        )
        if is_transient_lock_resolution_failure(bootstrap_code, bootstrap_output):
            raise LockResolutionBlockedError(message)
        raise ValueError(message)
    version_command = [
        str(resolver_python),
        "-I",
        "-c",
        "import pip; print(pip.__version__)",
    ]
    version_code, version_output, _ = run(version_command, environment.parent, env, 60)
    if version_code != 0 or version_output.strip() != LOCK_RESOLUTION_PIP_VERSION:
        raise ValueError(
            f"the {label} resolver must use {LOCK_RESOLUTION_PIP_NAME}=={LOCK_RESOLUTION_PIP_VERSION}"
        )
    print(f"Lock-closure resolver for {label}: {LOCK_RESOLUTION_PIP_NAME}=={LOCK_RESOLUTION_PIP_VERSION}")
    return resolver_python


def bootstrap_pinned_lock_metadata_parser(
    source_python: Path,
    lock: Path,
    work_root: Path,
    output_path: Path,
) -> None:
    """Create a verified pip-pinned interpreter for lock metadata parsing."""
    source_python = source_python.resolve(strict=True)
    lock = lock.resolve(strict=True)
    work_root = work_root.absolute()
    output_path = output_path.absolute()
    parser_python = pinned_lock_resolver(
        source_python,
        "lock metadata parser",
        lock,
        work_root / "lock-metadata-parser",
        trusted_env(work_root / "lock-metadata-parser-home"),
    )
    if not parser_python.is_file():
        raise ValueError("the verified lock metadata parser did not produce a Python executable")
    output_path.parent.mkdir(parents=True, exist_ok=True)
    output_path.write_text(str(parser_python.resolve()) + "\n", encoding="utf-8")


def validate_requirements_lock_closure(
    requirements_input: Path,
    lock: Path,
    resolver_python: Path,
    runtime_python: Path,
    work_root: Path,
) -> None:
    """Resolve the lock for every supported target before installation."""
    import tempfile

    require_pinned_lock_metadata_parser()
    requirements_input = requirements_input.resolve(strict=True)
    lock = lock.resolve(strict=True)
    resolver_python = resolver_python.resolve(strict=True)
    runtime_python = runtime_python.resolve(strict=True)
    resolver_root = work_root.absolute() / "lock-resolution"
    resolver_root.mkdir(parents=True, exist_ok=True)
    env = trusted_env(resolver_root / "home")

    def verify_python_version(python: Path, expected: str, label: str) -> None:
        version_command = [
            str(python),
            "-I",
            "-c",
            "import sys; print(f'{sys.implementation.name} {sys.version_info.major}.{sys.version_info.minor}.{sys.version_info.micro}')",
        ]
        version_code, version_output, _ = run(version_command, resolver_root, env, 60)
        if version_code != 0 or version_output.strip() != expected:
            raise ValueError(f"requirements lock closure must use {label}")

    verify_python_version(resolver_python, "cpython 3.13.2", "CPython 3.13.2")
    verify_python_version(runtime_python, "cpython 3.12.11", "the functional CPython 3.12.11 runtime")
    with tempfile.TemporaryDirectory(prefix="lock-resolution-", dir=resolver_root) as directory:
        reports: list[Path] = []
        locked = locked_requirements(lock)
        direct_requirement_names = set(pinned_requirements(requirements_input))
        resolver_pip = pinned_lock_resolver(
            resolver_python,
            "CPython 3.13.2",
            lock,
            Path(directory) / "resolver-cpython-3.13.2",
            env,
        )
        runtime_pip = pinned_lock_resolver(
            runtime_python,
            "CPython 3.12.11",
            lock,
            Path(directory) / "runtime-cpython-3.12.11",
            env,
        )
        target_marker_wrapper = Path(directory) / "target-marker-pip.py"
        target_marker_wrapper.write_text(TARGET_MARKER_PIP_WRAPPER, encoding="utf-8")

        def resolve_target(
            python: Path,
            target_name: str,
            target_args: tuple[str, ...],
            target_environment: dict[str, str],
            resolution_input: Path,
            report_name: str,
        ) -> Path:
            report = Path(directory) / f"{report_name}.json"
            command = [
                str(python),
                "-I",
                str(target_marker_wrapper),
                json.dumps(target_environment, sort_keys=True, separators=(",", ":")),
                "--isolated",
                "install",
                "--disable-pip-version-check",
                "--no-input",
                "--only-binary=:all:",
                "--no-cache-dir",
                "--require-hashes",
                "--dry-run",
                "--ignore-installed",
                "--report",
                str(report),
                "--index-url",
                "https://pypi.org/simple",
                *target_args,
                "-r",
                str(resolution_input),
                "-c",
                str(lock),
            ]
            code, output, _ = run(command, resolver_root, env, 300)
            if code != 0:
                sanitized = sanitize(
                    output,
                    [
                        requirements_input.parent,
                        lock.parent,
                        resolver_root,
                        resolver_python.parent,
                        runtime_python.parent,
                    ],
                )
                message = f"could not resolve the requirements lock closure for {target_name}: {sanitized}"
                if is_transient_lock_resolution_failure(code, output):
                    raise LockResolutionBlockedError(message)
                raise ValueError(message)
            if not report.is_file():
                raise ValueError(f"pip did not produce the required {target_name} resolution report")
            return report

        def collect_target_resolution(target_reports: list[Path], target_name: str) -> tuple[list[dict[str, Any]], dict[str, str]]:
            install_records: list[dict[str, Any]] = []
            resolved: dict[str, str] = {}
            for report in target_reports:
                report_records = resolution_install_records(report)
                install_records.extend(report_records)
                for name, version in resolved_requirements(report_records).items():
                    prior_version = resolved.get(name)
                    if prior_version is not None and prior_version != version:
                        raise ValueError(
                            f"requirements lock resolution differs within {target_name} for {name}: "
                            f"{prior_version} and {version}"
                        )
                    resolved[name] = version
            return install_records, resolved

        def filter_supplemental_report_for_target(
            report: Path,
            root_name: str,
            root_extras: tuple[str, ...],
            target_environment: dict[str, str],
            target_name: str,
            activated_extras_by_package: dict[str, tuple[str, ...]] | None = None,
        ) -> Path:
            """Keep only the requested root and dependencies active for the synthetic target."""
            try:
                document = json.loads(report.read_text(encoding="utf-8"))
            except (OSError, json.JSONDecodeError) as exc:
                raise ValueError(f"could not read the pip resolution report: {exc}") from exc
            if not isinstance(document, dict):
                raise ValueError("pip resolution report must be a JSON object")
            install_records = resolution_install_records(report)
            resolved_requirements(install_records)
            dependencies = package_dependency_requirements(install_records)
            records_by_package = {
                normalized_requirement_name(record["metadata"]["name"]): record
                for record in install_records
            }
            root_package = normalized_requirement_name(root_name)
            if root_package not in records_by_package:
                raise ValueError(
                    f"marker-gated package {root_name} was not resolved for {target_name}"
                )
            active_extra_context = {
                normalized_requirement_name(package): tuple(sorted(set(extras)))
                for package, extras in (activated_extras_by_package or {}).items()
                if extras
            }
            active_extra_context[root_package] = tuple(
                sorted(set(active_extra_context.get(root_package, ())).union(root_extras))
            )
            active_packages, _ = target_reachable_packages_and_extras_for_target(
                dependencies,
                target_environment,
                target_name,
                {root_package},
                active_extra_context,
            )
            document["install"] = [
                record
                for record in install_records
                if normalized_requirement_name(record["metadata"]["name"]) in active_packages
            ]
            filtered_report = report.with_name(f"{report.stem}-target-filtered.json")
            filtered_report.write_text(json.dumps(document), encoding="utf-8")
            return filtered_report

        if len(LOCK_RESOLUTION_TARGETS) != len(LOCK_RESOLUTION_TARGET_MARKER_ENVIRONMENTS):
            raise RuntimeError("lock-resolution targets and marker environments are not aligned")
        target_specs = [
            (resolver_pip, target_name, target_args, target_environment)
            for (target_name, target_args), target_environment in zip(
                LOCK_RESOLUTION_TARGETS,
                LOCK_RESOLUTION_TARGET_MARKER_ENVIRONMENTS,
                strict=True,
            )
        ]
        target_specs.append(
            (runtime_pip, "runtime-cpython-3.12.11", (), FUNCTIONAL_RUNTIME_MARKER_ENVIRONMENT)
        )

        for python, target_name, target_args, target_environment in target_specs:
            target_root_packages = set(direct_requirement_names)
            base_report = resolve_target(
                python,
                target_name,
                target_args,
                target_environment,
                requirements_input,
                f"{target_name}-base",
            )
            supplemental_reports: dict[str, Path] = {}
            supplemental_raw_reports: dict[str, Path] = {}
            supplemental_report_contexts: dict[str, dict[str, tuple[str, ...]]] = {}
            marker_request_number = 0
            requested_marker_extras: dict[str, tuple[str, ...]] = {}
            seen_supplemental_states: set[tuple[object, ...]] = set()
            while True:
                target_reports = [base_report, *supplemental_reports.values()]
                install_records, resolved = collect_target_resolution(target_reports, target_name)
                dependencies = package_dependency_requirements(install_records)
                _, active_extras_by_package = target_reachable_packages_and_extras_for_target(
                    dependencies,
                    target_environment,
                    target_name,
                    target_root_packages,
                    requested_marker_extras,
                )
                active_extra_context = {
                    name: extras for name, extras in active_extras_by_package.items() if extras
                }
                supplemental_state: tuple[object, ...] = (
                    tuple(sorted(resolved.items())),
                    tuple(sorted((name, tuple(extras)) for name, extras in requested_marker_extras.items())),
                    tuple(sorted((name, tuple(extras)) for name, extras in active_extra_context.items())),
                    tuple(
                        sorted(
                            (
                                name,
                                tuple(
                                    sorted(
                                        (package, tuple(extras))
                                        for package, extras in context.items()
                                    )
                                ),
                            )
                            for name, context in supplemental_report_contexts.items()
                        )
                    ),
                )
                if supplemental_state in seen_supplemental_states:
                    raise ValueError(
                        f"supplemental marker report state did not converge for {target_name}"
                    )
                seen_supplemental_states.add(supplemental_state)
                reports_to_refilter = [
                    name
                    for name in supplemental_reports
                    if supplemental_report_contexts.get(name) != active_extra_context
                ]
                if reports_to_refilter:
                    for name in reports_to_refilter:
                        supplemental_reports[name] = filter_supplemental_report_for_target(
                            supplemental_raw_reports[name],
                            name,
                            requested_marker_extras[name],
                            target_environment,
                            target_name,
                            active_extra_context,
                        )
                        supplemental_report_contexts[name] = dict(active_extra_context)
                    continue
                marker_requirements = marker_gated_requirements_for_target(
                    install_records,
                    locked,
                    target_environment,
                    target_name,
                    requested_marker_extras,
                    target_root_packages,
                )
                desired_marker_requirements = {
                    name: (
                        version,
                        tuple(sorted(set(extras).union(active_extras_by_package.get(name, ())))),
                    )
                    for name, (version, extras) in marker_requirements.items()
                }
                obsolete_marker_reports = sorted(
                    set(supplemental_reports).difference(desired_marker_requirements)
                )
                if obsolete_marker_reports:
                    for name in obsolete_marker_reports:
                        del supplemental_reports[name]
                        del supplemental_raw_reports[name]
                        del supplemental_report_contexts[name]
                        del requested_marker_extras[name]
                    continue
                pending: list[tuple[str, str, tuple[str, ...]]] = []
                for name, (version, extras) in sorted(desired_marker_requirements.items()):
                    requested_extras = requested_marker_extras.get(name, ())
                    if name not in resolved or extras != requested_extras:
                        pending.append((name, version, extras))
                if not pending:
                    break
                for name, version, extras in pending:
                    marker_request_number += 1
                    marker_input = Path(directory) / f"{target_name}-marker-{marker_request_number}.in"
                    marker_input.write_text(
                        marker_resolution_requirement(name, version, extras) + "\n",
                        encoding="utf-8",
                    )
                    marker_report = resolve_target(
                        python,
                        target_name,
                        target_args,
                        target_environment,
                        marker_input,
                        f"{target_name}-marker-{marker_request_number}",
                    )
                    marker_resolved = resolved_requirements(resolution_install_records(marker_report))
                    if marker_resolved.get(name) != version:
                        raise ValueError(
                            f"marker-gated package {name}=={version} was not resolved for {target_name}"
                        )
                    requested_marker_extras[name] = extras
                    supplemental_raw_reports[name] = marker_report
                    supplemental_reports[name] = filter_supplemental_report_for_target(
                        marker_report,
                        name,
                        extras,
                        target_environment,
                        target_name,
                    )
                    supplemental_report_contexts[name] = {}
            reports.extend([base_report, *supplemental_reports.values()])
        validate_resolved_requirements_lock(requirements_input, lock, tuple(reports))


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
    # Callers record this immediately after the command returns, so the measured
    # duration places the start; stamping both ends here would report a multi-second
    # run with near-identical timestamps.
    completed_at = datetime.now(UTC)
    started_at = completed_at - timedelta(seconds=duration)
    return {
        "schemaVersion": "1.1.0",
        "name": name,
        "category": category,
        "status": effective,
        "requiredValidation": True,
        "evidenceSource": "Automated",
        "command": sanitize(" ".join(command), roots),
        "workingDirectory": "trusted-isolated-workspace",
        "startedAtUtc": started_at.isoformat().replace("+00:00", "Z"),
        "completedAtUtc": completed_at.isoformat().replace("+00:00", "Z"),
        "durationSeconds": round(duration, 3),
        "runtime": f"CPython {sys.version_info.major}.{sys.version_info.minor}.{sys.version_info.micro}",
        "toolName": tool_name,
        "toolVersion": tool_version,
        "exitCode": code,
        "summary": f"{name} {'completed successfully' if effective == 'Passed' else effective.lower()}.",
        "warnings": [],
        "failureReason": reason if effective == "Failed" else None,
        "blockedReason": reason if effective == "Blocked" else None,
        "details": {
            "sanitizedOutput": sanitized or "No command output.",
            **sanitize_evidence_value(details or {}, roots),
        },
    }


def write_record(evidence_dir: Path, filename: str, record: Any) -> None:
    (evidence_dir / filename).write_text(json.dumps(record, indent=2) + "\n", encoding="utf-8")


def validate(args: argparse.Namespace) -> int:
    original_project = args.project.absolute()
    if not original_project.exists() or not (original_project / "project-manifest.json").is_file():
        raise ValueError("project must be a governed Python project root")
    inspect_project_tree(original_project)
    tool_python = args.tool_python.resolve(strict=True)
    tool_lock = args.tool_lock.resolve(strict=True)
    tool_input = tool_lock.with_suffix(".in")
    validate_requirements_lock(tool_input, tool_lock)
    project, evidence_dir, dist_dir = prepare_work_root(original_project, args.work_root)
    mypy_config = args.mypy_config.resolve(strict=True)
    roots = [
        original_project.resolve(),
        args.work_root.resolve(),
        tool_python,
        tool_python.parent,
        tool_python.parent.parent,
        tool_lock,
        tool_lock.parent,
        mypy_config,
        mypy_config.parent,
    ]
    if is_within(tool_python, original_project.resolve()) or is_within(tool_lock, original_project.resolve()):
        raise ValueError("trusted tools and locks must be outside the caller project")
    runtime_lock = project / args.runtime_lock
    if runtime_lock.is_symlink() or not runtime_lock.is_file():
        raise ValueError("runtime dependency lock is missing or unsafe")
    metadata = parse_project_metadata(project)
    toolchain_sbom_pyproject = write_toolchain_sbom_pyproject(args.work_root)
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
            module_command(tool_python, "mypy", "--config-file", str(mypy_config), str(project / "src")),
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

        for name, filename, source_lock, source_lock_name, sbom_pyproject, root_component in (
            (
                "Python project SBOM",
                "python-project-sbom.cdx.json",
                runtime_lock,
                "requirements-runtime.lock",
                project / "pyproject.toml",
                metadata["distribution"],
            ),
            (
                "Python toolchain SBOM",
                "python-toolchain-sbom.cdx.json",
                tool_lock,
                "requirements-ci.lock",
                toolchain_sbom_pyproject,
                TOOLCHAIN_SBOM_PROJECT_NAME,
            ),
        ):
            sbom_path = evidence_dir / filename
            sbom_command = module_command(
                tool_python,
                "cyclonedx_py",
                "requirements",
                str(source_lock),
                "--pyproject",
                str(sbom_pyproject),
                "--sv",
                "1.5",
                "--output-reproducible",
                "--output-file",
                str(sbom_path),
            )
            sbom_code, sbom_output, sbom_duration = run(sbom_command, args.work_root, env)
            if sbom_code == 0:
                try:
                    attach_sbom_root_dependencies(sbom_path)
                except ValueError as exc:
                    sbom_code = 1
                    sbom_output = f"{sbom_output}\nSBOM dependency graph validation failed: {exc}".strip()
            sbom_record = make_evidence(
                name,
                "security",
                sbom_command,
                sbom_code,
                sbom_output,
                sbom_duration,
                "cyclonedx-bom",
                versions["cyclonedx_py"],
                roots,
                {
                    "sourceLock": source_lock_name,
                    "specVersion": "1.5",
                    "rootComponent": root_component,
                },
            )
            records.append(sbom_record)
            failed |= sbom_code != 0

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
    lock_mode = parser.add_mutually_exclusive_group()
    lock_mode.add_argument("--verify-tool-lock", action="store_true")
    lock_mode.add_argument("--bootstrap-lock-parser", action="store_true")
    parser.add_argument("--project", type=Path)
    parser.add_argument("--work-root", type=Path)
    parser.add_argument("--tool-python", type=Path)
    parser.add_argument("--tool-lock", type=Path, required=True)
    parser.add_argument("--runtime-lock", default="requirements-runtime.lock")
    parser.add_argument("--mypy-config", type=Path)
    parser.add_argument("--resolver-python", type=Path)
    parser.add_argument("--runtime-python", type=Path)
    parser.add_argument("--lock-parser-output", type=Path)
    args = parser.parse_args()
    if args.bootstrap_lock_parser:
        if args.work_root is None or args.resolver_python is None or args.lock_parser_output is None:
            parser.error("--bootstrap-lock-parser requires --work-root, --resolver-python, and --lock-parser-output")
        try:
            bootstrap_pinned_lock_metadata_parser(
                args.resolver_python,
                args.tool_lock,
                args.work_root,
                args.lock_parser_output,
            )
            return 0
        except LockResolutionBlockedError as exc:
            print(str(exc), file=sys.stderr)
            return 2
        except Exception as exc:
            print(str(exc), file=sys.stderr)
            return 1
    if args.verify_tool_lock:
        if args.work_root is None or args.resolver_python is None or args.runtime_python is None:
            parser.error("--verify-tool-lock requires --work-root, --resolver-python, and --runtime-python")
        try:
            validate_requirements_lock_closure(
                args.tool_lock.with_suffix(".in"),
                args.tool_lock,
                args.resolver_python,
                args.runtime_python,
                args.work_root,
            )
            return 0
        except LockResolutionBlockedError as exc:
            print(str(exc), file=sys.stderr)
            return 2
        except Exception as exc:
            print(str(exc), file=sys.stderr)
            return 1
    missing = [
        name
        for name, value in (("--project", args.project), ("--work-root", args.work_root), ("--tool-python", args.tool_python), ("--mypy-config", args.mypy_config))
        if value is None
    ]
    if missing:
        parser.error(f"{' '.join(missing)} required unless a lock-verification mode is supplied")
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
