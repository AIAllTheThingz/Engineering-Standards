"""Trusted functional validation for governed Bash projects.

Caller content is validated as an untrusted tree, copied into a new isolated
workspace, and executed only through the bounded Bats phase after all mandatory
non-executing gates pass. Trusted tools are always supplied by absolute path.
"""

from __future__ import annotations

import argparse
import ctypes
import hashlib
import json
import os
import re
import resource
import shutil
import signal
import stat
import subprocess
import sys
import tempfile
import time
from datetime import UTC, datetime
from pathlib import Path, PurePosixPath
from typing import Any

SYS_LANDLOCK_CREATE_RULESET = 444
SYS_LANDLOCK_ADD_RULE = 445
SYS_LANDLOCK_RESTRICT_SELF = 446
LANDLOCK_CREATE_RULESET_VERSION = 1
LANDLOCK_RULE_PATH_BENEATH = 1
LANDLOCK_ACCESS_FS_EXECUTE = 1 << 0
LANDLOCK_ACCESS_FS_WRITE_FILE = 1 << 1
LANDLOCK_ACCESS_FS_READ_FILE = 1 << 2
LANDLOCK_ACCESS_FS_READ_DIR = 1 << 3
LANDLOCK_ACCESS_FS_REMOVE_DIR = 1 << 4
LANDLOCK_ACCESS_FS_REMOVE_FILE = 1 << 5
LANDLOCK_ACCESS_FS_MAKE_CHAR = 1 << 6
LANDLOCK_ACCESS_FS_MAKE_DIR = 1 << 7
LANDLOCK_ACCESS_FS_MAKE_REG = 1 << 8
LANDLOCK_ACCESS_FS_MAKE_SOCK = 1 << 9
LANDLOCK_ACCESS_FS_MAKE_FIFO = 1 << 10
LANDLOCK_ACCESS_FS_MAKE_BLOCK = 1 << 11
LANDLOCK_ACCESS_FS_MAKE_SYM = 1 << 12
LANDLOCK_ACCESS_FS_REFER = 1 << 13
LANDLOCK_ACCESS_FS_TRUNCATE = 1 << 14
LANDLOCK_ACCESS_FS_IOCTL_DEV = 1 << 15
LANDLOCK_ACCESS_NET_BIND_TCP = 1 << 0
LANDLOCK_ACCESS_NET_CONNECT_TCP = 1 << 1
PR_SET_NO_NEW_PRIVS = 38
PR_SET_CHILD_SUBREAPER = 36


class LandlockRulesetAttr(ctypes.Structure):
    _fields_ = [("handled_access_fs", ctypes.c_uint64), ("handled_access_net", ctypes.c_uint64)]


class LandlockPathBeneathAttr(ctypes.Structure):
    _fields_ = [("allowed_access", ctypes.c_uint64), ("parent_fd", ctypes.c_int)]

IGNORED_COPY_NAMES = {
    ".bats-cache",
    ".batsrc",
    ".cache",
    ".git",
    ".pytest_cache",
    ".shellcheckrc",
    "evidence",
    "generated",
    "output",
}
UNSAFE_ENVIRONMENT_VARIABLES = {
    "BASH_ENV",
    "ENV",
    "SHELLOPTS",
    "BASHOPTS",
    "CDPATH",
    "GLOBIGNORE",
    "BATS_LIB_PATH",
    "SHELLCHECK_OPTS",
    "SHFMT_OPTS",
}
REQUIRED_PROJECT_FILES = {
    "README.md",
    "AGENTS.md",
    "project-manifest.json",
    "governance.config.json",
}
PHASE_FILES = {
    "syntax": "bash-syntax.json",
    "shellcheck": "bash-shellcheck.json",
    "formatting": "bash-formatting.json",
    "tests": "bash-tests.json",
    "toolchain": "bash-toolchain.json",
    "sbom": "bash-project-sbom.cdx.json",
}
MAX_PROJECT_FILES = 512
MAX_PROJECT_BYTES = 16 * 1024 * 1024
MAX_BASH_FILES = 100
MAX_BASH_FILE_BYTES = 1024 * 1024
MAX_OUTPUT_BYTES = 1024 * 1024
EVIDENCE_OUTPUT_CHARS = 12000
TOKEN_PATTERN = re.compile(
    r"(?i)(?:gh[pousr]_[A-Za-z0-9_]{20,}|github_pat_[A-Za-z0-9_]{20,}|"
    r"authorization\s*[:=]\s*(?:bearer|basic)\s+\S+|"
    r"(?:password|passwd|client[_-]?secret|api[_-]?key|access[_-]?token)\s*[:=]\s*\S{8,})"
)
SHELLCHECK_DIRECTIVE_PATTERN = re.compile(r"(?i)#\s*shellcheck(?:\s|$)")


def utc_now() -> str:
    return datetime.now(UTC).isoformat().replace("+00:00", "Z")


def sha256(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as stream:
        for chunk in iter(lambda: stream.read(1024 * 1024), b""):
            digest.update(chunk)
    return digest.hexdigest()


def landlock_abi() -> int:
    libc = ctypes.CDLL(None, use_errno=True)
    result = libc.syscall(
        SYS_LANDLOCK_CREATE_RULESET,
        None,
        0,
        LANDLOCK_CREATE_RULESET_VERSION,
    )
    return int(result)


def landlock_handled_fs(abi: int) -> int:
    access = (
        LANDLOCK_ACCESS_FS_EXECUTE
        | LANDLOCK_ACCESS_FS_WRITE_FILE
        | LANDLOCK_ACCESS_FS_READ_FILE
        | LANDLOCK_ACCESS_FS_READ_DIR
        | LANDLOCK_ACCESS_FS_REMOVE_DIR
        | LANDLOCK_ACCESS_FS_REMOVE_FILE
        | LANDLOCK_ACCESS_FS_MAKE_CHAR
        | LANDLOCK_ACCESS_FS_MAKE_DIR
        | LANDLOCK_ACCESS_FS_MAKE_REG
        | LANDLOCK_ACCESS_FS_MAKE_SOCK
        | LANDLOCK_ACCESS_FS_MAKE_FIFO
        | LANDLOCK_ACCESS_FS_MAKE_BLOCK
        | LANDLOCK_ACCESS_FS_MAKE_SYM
    )
    if abi >= 2:
        access |= LANDLOCK_ACCESS_FS_REFER
    if abi >= 3:
        access |= LANDLOCK_ACCESS_FS_TRUNCATE
    if abi >= 5:
        access |= LANDLOCK_ACCESS_FS_IOCTL_DEV
    return access


def apply_landlock(
    abi: int,
    read_only_roots: list[Path],
    read_write_roots: list[Path],
    deny_tcp: bool,
) -> None:
    libc = ctypes.CDLL(None, use_errno=True)
    handled_fs = landlock_handled_fs(abi)
    handled_net = (
        LANDLOCK_ACCESS_NET_BIND_TCP | LANDLOCK_ACCESS_NET_CONNECT_TCP
        if deny_tcp
        else 0
    )
    ruleset = LandlockRulesetAttr(handled_access_fs=handled_fs, handled_access_net=handled_net)
    ruleset_fd = libc.syscall(
        SYS_LANDLOCK_CREATE_RULESET,
        ctypes.byref(ruleset),
        ctypes.sizeof(ruleset),
        0,
    )
    if ruleset_fd < 0:
        raise OSError(ctypes.get_errno(), "could not create Landlock ruleset")
    read_access = LANDLOCK_ACCESS_FS_EXECUTE | LANDLOCK_ACCESS_FS_READ_FILE | LANDLOCK_ACCESS_FS_READ_DIR
    try:
        for root, access in [
            *((path, read_access) for path in read_only_roots),
            *((path, handled_fs) for path in read_write_roots),
        ]:
            if not root.exists():
                continue
            if not root.is_dir():
                access &= (
                    LANDLOCK_ACCESS_FS_EXECUTE
                    | LANDLOCK_ACCESS_FS_WRITE_FILE
                    | LANDLOCK_ACCESS_FS_READ_FILE
                    | LANDLOCK_ACCESS_FS_TRUNCATE
                    | LANDLOCK_ACCESS_FS_IOCTL_DEV
                )
            descriptor = os.open(root, os.O_PATH | os.O_CLOEXEC)
            try:
                path_rule = LandlockPathBeneathAttr(allowed_access=access, parent_fd=descriptor)
                result = libc.syscall(
                    SYS_LANDLOCK_ADD_RULE,
                    ruleset_fd,
                    LANDLOCK_RULE_PATH_BENEATH,
                    ctypes.byref(path_rule),
                    0,
                )
                if result < 0:
                    raise OSError(ctypes.get_errno(), f"could not add Landlock rule for {root}")
            finally:
                os.close(descriptor)
        if libc.prctl(PR_SET_NO_NEW_PRIVS, 1, 0, 0, 0) != 0:
            raise OSError(ctypes.get_errno(), "could not set no-new-privileges")
        if libc.syscall(SYS_LANDLOCK_RESTRICT_SELF, ruleset_fd, 0) != 0:
            raise OSError(ctypes.get_errno(), "could not enforce Landlock ruleset")
    finally:
        os.close(ruleset_fd)


def enable_child_subreaper() -> None:
    libc = ctypes.CDLL(None, use_errno=True)
    if libc.prctl(PR_SET_CHILD_SUBREAPER, 1, 0, 0, 0) != 0:
        raise OSError(ctypes.get_errno(), "could not enable child subreaper")


def kill_reparented_children() -> None:
    parent_pid = os.getpid()
    for _ in range(20):
        while True:
            try:
                reaped, _ = os.waitpid(-1, os.WNOHANG)
            except ChildProcessError:
                break
            if reaped == 0:
                break
        children: list[int] = []
        for stat_path in Path("/proc").glob("[0-9]*/stat"):
            try:
                text = stat_path.read_text(encoding="utf-8")
                fields = text[text.rfind(")") + 2 :].split()
                if int(fields[1]) == parent_pid:
                    children.append(int(stat_path.parent.name))
            except (OSError, ValueError, IndexError):
                continue
        if not children:
            return
        for child_pid in children:
            try:
                os.kill(child_pid, signal.SIGKILL)
            except ProcessLookupError:
                pass
        time.sleep(0.05)
    raise RuntimeError("sandbox descendants could not be terminated")


def is_within(path: Path, root: Path) -> bool:
    try:
        path.relative_to(root)
        return True
    except ValueError:
        return False


def validate_relative_project_path(value: str) -> str:
    if not value or "\x00" in value:
        raise ValueError("project-path must be a nonempty repository-relative path")
    if value.startswith(("/", "\\")) or re.match(r"^[A-Za-z]:[\\/]", value):
        raise ValueError("project-path must not be rooted")
    normalized = value.replace("\\", "/")
    candidate = PurePosixPath(normalized)
    if candidate.is_absolute() or ".." in candidate.parts:
        raise ValueError("project-path must not contain traversal")
    if any(part in {"", "."} for part in candidate.parts[1:]):
        raise ValueError("project-path contains an ambiguous path component")
    return candidate.as_posix()


def reject_symlink_components(path: Path) -> None:
    current = Path(path.anchor)
    for part in path.absolute().parts[1:]:
        current /= part
        if current.exists() and current.is_symlink():
            raise ValueError(f"path contains a symbolic-link component: {current.name}")


def ensure_distinct_roots(project: Path, work_root: Path, evidence_root: Path) -> tuple[Path, Path, Path]:
    if not project.is_absolute() or not work_root.is_absolute() or not evidence_root.is_absolute():
        raise ValueError("project, work root, and evidence root must be absolute paths")
    project_resolved = project.resolve(strict=True)
    work_resolved = work_root.resolve(strict=False)
    evidence_resolved = evidence_root.resolve(strict=False)
    roots = {project_resolved, work_resolved, evidence_resolved}
    if len(roots) != 3:
        raise ValueError("project, work root, and evidence root must be distinct")
    for left in roots:
        for right in roots:
            if left != right and (is_within(left, right) or is_within(right, left)):
                raise ValueError("project, work root, and evidence root must not overlap")
    return project_resolved, work_resolved, evidence_resolved


def resolve_caller_project(caller_root: Path, project: Path, project_path_input: str) -> tuple[Path, Path]:
    relative_input = validate_relative_project_path(project_path_input)
    lexical_caller = caller_root.absolute()
    lexical_project = project.absolute()
    expected = lexical_caller if relative_input == "." else lexical_caller / Path(*PurePosixPath(relative_input).parts)
    if os.path.normpath(lexical_project) != os.path.normpath(expected):
        raise ValueError("absolute project path does not match caller root and project-path input")
    reject_symlink_components(lexical_caller)
    reject_symlink_components(lexical_project)
    resolved_caller = lexical_caller.resolve(strict=True)
    resolved_project = lexical_project.resolve(strict=True)
    if not is_within(resolved_project, resolved_caller):
        raise ValueError("project-path resolves outside the caller checkout")
    return resolved_caller, resolved_project


def inspect_project_tree(root: Path) -> None:
    reject_symlink_components(root)
    root_info = root.lstat()
    if stat.S_ISLNK(root_info.st_mode):
        raise ValueError("project root must not be a symbolic link")
    if not stat.S_ISDIR(root_info.st_mode):
        raise ValueError("project root must be a directory")
    root_resolved = root.resolve(strict=True)
    count = 0
    total = 0
    for current, directories, files in os.walk(root, followlinks=False):
        if Path(current) == root:
            directories[:] = [name for name in directories if name != ".git"]
            files = [name for name in files if name != ".git"]
        for name in [*directories, *files]:
            path = Path(current) / name
            info = path.lstat()
            mode = info.st_mode
            relative = path.relative_to(root)
            if stat.S_ISLNK(mode):
                raise ValueError(f"project contains a symbolic link: {relative}")
            if not (stat.S_ISDIR(mode) or stat.S_ISREG(mode)):
                raise ValueError(f"project contains a special filesystem entry: {relative}")
            if stat.S_ISREG(mode):
                if info.st_nlink > 1:
                    raise ValueError(f"project contains a hard-linked file: {relative}")
                count += 1
                total += info.st_size
                if count > MAX_PROJECT_FILES or total > MAX_PROJECT_BYTES:
                    raise ValueError("project exceeds the bounded file-count or size limit")
            if not is_within(path.resolve(strict=True), root_resolved):
                raise ValueError(f"project path escapes its root: {relative}")


def copy_project(source: Path, destination: Path) -> None:
    if destination.exists():
        raise ValueError("work root must be new and empty")
    destination.parent.mkdir(parents=True, exist_ok=True, mode=0o700)
    shutil.copytree(
        source,
        destination,
        symlinks=False,
        ignore=shutil.ignore_patterns(*IGNORED_COPY_NAMES),
    )
    inspect_project_tree(destination)


def write_json(path: Path, value: Any) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(json.dumps(value, indent=2) + "\n", encoding="utf-8")


def load_json(path: Path) -> Any:
    return json.loads(path.read_text(encoding="utf-8"))


def load_tool_lock(path: Path) -> dict[str, Any]:
    lock = load_json(path)
    if lock.get("schemaVersion") != "1.0.0":
        raise ValueError("unsupported Bash toolchain lock schema")
    if lock.get("supportedRunner") != {"os": "ubuntu-24.04", "architecture": "x86_64"}:
        raise ValueError("functional Bash toolchain must target ubuntu-24.04 x86_64")
    tools = lock.get("tools")
    if not isinstance(tools, list) or {item.get("name") for item in tools} != {"ShellCheck", "shfmt", "Bats"}:
        raise ValueError("functional Bash toolchain lock is incomplete")
    return lock


def trusted_env(home: Path, temporary: Path) -> dict[str, str]:
    home.mkdir(parents=True, exist_ok=True, mode=0o700)
    temporary.mkdir(parents=True, exist_ok=True, mode=0o700)
    environment = {
        "HOME": str(home),
        "TMPDIR": str(temporary),
        "PATH": "/usr/bin:/bin",
        "SHELL": "/usr/bin/bash",
        "LANG": "C.UTF-8",
        "LC_ALL": "C.UTF-8",
        "TZ": "UTC",
        "NO_COLOR": "1",
        "GIT_CONFIG_NOSYSTEM": "1",
        "GIT_CONFIG_GLOBAL": os.devnull,
    }
    if UNSAFE_ENVIRONMENT_VARIABLES.intersection(environment):
        raise RuntimeError("trusted environment contains a prohibited shell or tool override")
    return environment


def _limit_child(
    landlock_version: int | None = None,
    read_only_roots: list[Path] | None = None,
    read_write_roots: list[Path] | None = None,
    deny_tcp: bool = False,
) -> None:
    os.setsid()
    resource.setrlimit(resource.RLIMIT_FSIZE, (MAX_OUTPUT_BYTES, MAX_OUTPUT_BYTES))
    resource.setrlimit(resource.RLIMIT_CORE, (0, 0))
    try:
        resource.setrlimit(resource.RLIMIT_NOFILE, (128, 128))
        resource.setrlimit(resource.RLIMIT_NPROC, (128, 128))
    except (ValueError, OSError):
        pass
    if landlock_version is not None:
        apply_landlock(landlock_version, read_only_roots or [], read_write_roots or [], deny_tcp)


def run_command(
    command: list[str],
    cwd: Path,
    env: dict[str, str],
    timeout_seconds: int,
    sandbox: dict[str, Any] | None = None,
) -> tuple[int, str, float, bool]:
    started = time.monotonic()
    with tempfile.TemporaryFile() as output:
        process = subprocess.Popen(
            command,
            cwd=cwd,
            env=env,
            stdin=subprocess.DEVNULL,
            stdout=output,
            stderr=subprocess.STDOUT,
            text=False,
            preexec_fn=lambda: _limit_child(**(sandbox or {})),
        )
        timed_out = False
        try:
            process.wait(timeout=timeout_seconds)
        except subprocess.TimeoutExpired:
            timed_out = True
            try:
                os.killpg(process.pid, signal.SIGKILL)
            except ProcessLookupError:
                pass
            process.wait(timeout=10)
        else:
            try:
                os.killpg(process.pid, signal.SIGKILL)
            except ProcessLookupError:
                pass
            process.wait(timeout=10)
        if sandbox is not None:
            kill_reparented_children()
        output.seek(0, os.SEEK_END)
        length = output.tell()
        output.seek(max(0, length - EVIDENCE_OUTPUT_CHARS))
        captured = output.read(EVIDENCE_OUTPUT_CHARS).decode("utf-8", errors="replace")
    if timed_out:
        captured = f"Command exceeded {timeout_seconds} seconds.\n{captured}"
        return 124, captured, time.monotonic() - started, True
    return process.returncode, captured, time.monotonic() - started, False


def sanitize(value: str, roots: list[Path], executables: dict[str, Path]) -> str:
    result = value
    replacements = {str(path): f"<{name}>" for name, path in executables.items()}
    for original, replacement in sorted(replacements.items(), key=lambda item: len(item[0]), reverse=True):
        result = result.replace(original, replacement).replace(original.replace("\\", "/"), replacement)
    for root in sorted(roots, key=lambda item: len(str(item)), reverse=True):
        for representation in {str(root), str(root).replace("\\", "/")}:
            result = result.replace(representation, ".")
    result = TOKEN_PATTERN.sub("<redacted>", result)
    return result[-EVIDENCE_OUTPUT_CHARS:]


def make_record(
    name: str,
    category: str,
    command: list[str],
    status: str,
    output: str,
    duration: float,
    tool_name: str,
    tool_version: str,
    roots: list[Path],
    executables: dict[str, Path],
    exit_code: int | None,
    artifact_paths: list[str],
    started_at: str | None = None,
    details: dict[str, Any] | None = None,
    required: bool = True,
) -> dict[str, Any]:
    sanitized = sanitize(output, roots, executables)
    reason = sanitized[-1000:] or "Required validation did not complete."
    return {
        "schemaVersion": "1.1.0",
        "name": name,
        "category": category,
        "status": status,
        "requiredValidation": required,
        "evidenceSource": "Automated",
        "command": sanitize(" ".join(command), roots, executables),
        "workingDirectory": ".",
        "startedAtUtc": started_at or utc_now(),
        "completedAtUtc": utc_now(),
        "durationSeconds": round(duration, 3),
        "runtime": f"CPython {sys.version_info.major}.{sys.version_info.minor}.{sys.version_info.micro}",
        "toolName": tool_name,
        "toolVersion": tool_version,
        "exitCode": exit_code,
        "summary": f"{name} {status.lower()}.",
        "warnings": [],
        "failureReason": reason if status in {"Failed", "NotRun"} else None,
        "blockedReason": reason if status == "Blocked" else None,
        "notRunReason": reason if status == "NotRun" else None,
        "artifactPaths": artifact_paths,
        "details": {"sanitizedOutput": sanitized or "No command output.", **(details or {})},
    }


def placeholder_record(
    phase: str,
    reason: str,
    roots: list[Path],
    executables: dict[str, Path],
    status: str = "NotRun",
) -> dict[str, Any]:
    names = {
        "syntax": ("Bash syntax", "syntax", "bash"),
        "shellcheck": ("Bash ShellCheck", "lint", "shellcheck"),
        "formatting": ("Bash formatting", "lint", "shfmt"),
        "tests": ("Bash tests", "unit", "bats"),
        "toolchain": ("Bash toolchain provenance", "dependency", "bash-toolchain"),
        "sbom": ("Bash project SBOM", "security", "cyclonedx"),
    }
    name, category, tool = names[phase]
    return make_record(
        name,
        category,
        [tool],
        status,
        reason,
        0,
        tool,
        "unknown",
        roots,
        executables,
        None,
        [PHASE_FILES[phase]],
    )


def validate_structure(project: Path) -> tuple[list[Path], list[Path]]:
    missing = sorted(path for path in REQUIRED_PROJECT_FILES if not (project / path).is_file())
    if missing:
        raise ValueError(f"governed Bash project is missing required files: {', '.join(missing)}")
    for directory in ("cmd", "lib", "spec"):
        if not (project / directory).is_dir():
            raise ValueError(f"governed Bash project is missing {directory}/")
    manifest = load_json(project / "project-manifest.json")
    if manifest.get("projectType") != "bash":
        raise ValueError("project manifest must use the supported bash project type")
    if "agents/AGENTS_Bash.md" not in manifest.get("applicableStandards", []):
        raise ValueError("project manifest must apply agents/AGENTS_Bash.md")
    if "bash" not in manifest.get("requiredWorkflows", []):
        raise ValueError("project manifest must require the bash workflow")
    if "Bash 5.2" not in (project / "README.md").read_text(encoding="utf-8"):
        raise ValueError("README must declare supported Bash 5.2")
    bash_files = sorted(
        [path for path in (project / "cmd").iterdir() if path.is_file()]
        + list((project / "lib").glob("*.sh"))
    )
    bats_files = sorted((project / "spec").glob("*.bats"))
    if not bash_files or not bats_files:
        raise ValueError("governed Bash project must contain Bash entry points, libraries, and Bats specs")
    if len(bash_files) + len(bats_files) > MAX_BASH_FILES:
        raise ValueError("governed Bash project exceeds the Bash file-count limit")
    for path in bash_files:
        if path.stat().st_size > MAX_BASH_FILE_BYTES:
            raise ValueError(f"Bash file exceeds the size limit: {path.relative_to(project)}")
        first_line = path.read_text(encoding="utf-8").splitlines()[0]
        if first_line not in {"#!/usr/bin/env bash", "#!/usr/bin/bash"}:
            raise ValueError(f"Bash file has an unsupported shebang: {path.relative_to(project)}")
    for path in bats_files:
        if path.stat().st_size > MAX_BASH_FILE_BYTES:
            raise ValueError(f"Bats file exceeds the size limit: {path.relative_to(project)}")
        first_line = path.read_text(encoding="utf-8").splitlines()[0]
        if first_line != "#!/usr/bin/env bats":
            raise ValueError(f"Bats file has an unsupported shebang: {path.relative_to(project)}")
    declared = {path.resolve() for path in [*bash_files, *bats_files]}
    for path in project.rglob("*"):
        if not path.is_file() or path.resolve() in declared:
            continue
        suffix_marks_bash = path.suffix.lower() in {".sh", ".bash", ".bats"}
        with path.open("rb") as stream:
            first_line = stream.readline(256)
        shebang_marks_bash = first_line.startswith((b"#!/usr/bin/env bash", b"#!/usr/bin/bash", b"#!/usr/bin/env bats"))
        if suffix_marks_bash or shebang_marks_bash:
            raise ValueError(f"Bash-executable content exists outside declared cmd, lib, or spec paths: {path.relative_to(project)}")
    return bash_files, bats_files


def make_read_only(root: Path, executable_files: set[Path]) -> None:
    for current, directories, files in os.walk(root, topdown=False):
        for name in files:
            path = Path(current) / name
            path.chmod(0o555 if path in executable_files else 0o444)
        for name in directories:
            (Path(current) / name).chmod(0o555)
    root.chmod(0o555)


def identify_tool(
    name: str,
    executable: Path,
    expected_version: str,
    cwd: Path,
    env: dict[str, str],
) -> tuple[str, str]:
    if not executable.is_absolute() or not executable.is_file() or executable.is_symlink():
        raise FileNotFoundError(f"trusted {name} executable is unavailable")
    code, output, _, _ = run_command([str(executable), "--version"], cwd, env, 30)
    if code != 0:
        raise ValueError(f"trusted {name} version command failed")
    patterns = {
        "ShellCheck": rf"(?m)^version:\s+{re.escape(expected_version)}$",
        "shfmt": rf"(?m)^v?{re.escape(expected_version)}$",
        "Bats": rf"(?mi)^Bats\s+{re.escape(expected_version)}$",
    }
    if not re.search(patterns[name], output):
        raise ValueError(f"trusted {name} version mismatch; expected {expected_version}")
    return output.strip(), sha256(executable)


def build_sbom(project_name: str, lock: dict[str, Any], lock_hash: str, bash_hash: str) -> dict[str, Any]:
    root_ref = f"pkg:generic/{project_name}@1.0.0"
    serial_hex = hashlib.sha256((root_ref + lock_hash).encode()).hexdigest()[:32]
    serial_uuid = f"{serial_hex[:8]}-{serial_hex[8:12]}-{serial_hex[12:16]}-{serial_hex[16:20]}-{serial_hex[20:]}"
    components = []
    dependencies = []
    for tool in lock["tools"]:
        component = {
            "type": "application",
            "name": tool["name"],
            "version": tool["version"],
            "purl": tool["purl"],
            "bom-ref": tool["purl"],
            "licenses": [{"license": {"id": tool["licenseSpdx"]}}],
            "hashes": [{"alg": "SHA-256", "content": tool["sha256"]}],
            "properties": [
                {"name": "engineering-standards:artifact", "value": tool["artifactFile"]},
                {"name": "engineering-standards:source", "value": tool["sourceUrl"]},
            ],
        }
        components.append(component)
        dependencies.append(tool["purl"])
    bash_ref = "pkg:generic/gnu-bash@5.2"
    components.append(
        {
            "type": "application",
            "name": "GNU Bash",
            "version": "5.2",
            "bom-ref": bash_ref,
            "hashes": [{"alg": "SHA-256", "content": bash_hash}],
        }
    )
    dependencies.append(bash_ref)
    return {
        "bomFormat": "CycloneDX",
        "specVersion": "1.5",
        "serialNumber": f"urn:uuid:{serial_uuid}",
        "version": 1,
        "metadata": {
            "timestamp": utc_now(),
            "tools": {"components": [{"type": "application", "name": "bash-project-validation", "version": "1.0.0"}]},
            "component": {"type": "application", "name": project_name, "version": "1.0.0", "bom-ref": root_ref},
        },
        "components": components,
        "dependencies": [{"ref": root_ref, "dependsOn": dependencies}],
    }


def execute(args: argparse.Namespace) -> int:
    _, original_project = resolve_caller_project(args.caller_root, args.project, args.project_path_input)
    project_root, work_root, evidence_root = ensure_distinct_roots(
        original_project, args.work_root.absolute(), args.evidence_root.absolute()
    )
    if work_root.exists() or evidence_root.exists():
        raise ValueError("work root and evidence root must be new paths")
    roots = [project_root, work_root, evidence_root, args.tool_lock.absolute()]
    executables = {
        "bash": args.bash.absolute(),
        "shellcheck": args.shellcheck.absolute(),
        "shfmt": args.shfmt.absolute(),
        "bats": args.bats.absolute(),
    }
    records: list[dict[str, Any]] = []
    phase_records: dict[str, Any] = {}
    inspect_project_tree(project_root)
    isolated_project = work_root / "caller"
    copy_project(project_root, isolated_project)
    env = trusted_env(work_root / "home", work_root / "tmp")
    sandbox_abi = landlock_abi()
    if sandbox_abi < 1:
        raise FileNotFoundError("Linux Landlock filesystem isolation is unavailable")
    if os.environ.get("GITHUB_ACTIONS") == "true" and sandbox_abi < 4:
        raise FileNotFoundError("hosted Bash execution requires Landlock ABI 4 TCP connect and bind restriction")
    enable_child_subreaper()

    structure_started = utc_now()
    bash_files, bats_files = validate_structure(isolated_project)
    structure_record = make_record(
        "Bash project structure and path safety",
        "security",
        ["trusted-project-tree-inspection"],
        "Passed",
        "Project structure and filesystem entries are safe.",
        0,
        "python-standard-library",
        f"{sys.version_info.major}.{sys.version_info.minor}.{sys.version_info.micro}",
        roots,
        executables,
        0,
        [],
        structure_started,
        {"bashFileCount": len(bash_files), "batsFileCount": len(bats_files)},
    )
    records.append(structure_record)

    lock = load_tool_lock(args.tool_lock.resolve(strict=True))
    runtime = lock["bashRuntime"]
    bash = args.bash.resolve(strict=True)
    if bash != Path(runtime["executable"]).resolve(strict=True):
        raise ValueError("trusted Bash interpreter must be /usr/bin/bash")
    bash_code, bash_output, bash_duration, _ = run_command([str(bash), "--version"], work_root, env, 30)
    bash_match = re.search(r"GNU bash, version (\d+)\.(\d+)\.([0-9]+)", bash_output)
    bash_status = "Passed"
    if (
        bash_code != 0
        or bash_match is None
        or int(bash_match.group(1)) != runtime["requiredMajor"]
        or int(bash_match.group(2)) != runtime["requiredMinor"]
    ):
        bash_status = "Failed"
    bash_record = make_record(
        "Bash interpreter identity",
        "runtime",
        [str(bash), "--version"],
        bash_status,
        bash_output,
        bash_duration,
        "GNU Bash",
        bash_match.group(0).removeprefix("GNU bash, version ") if bash_match else "unknown",
        roots,
        executables,
        bash_code,
        ["bash-toolchain.json"],
        details={"executableSha256": sha256(bash)},
    )
    records.append(bash_record)

    tool_details = []
    tool_failure: tuple[str, str] | None = None
    for item in lock["tools"]:
        name = item["name"]
        path = {"ShellCheck": args.shellcheck, "shfmt": args.shfmt, "Bats": args.bats}[name].absolute()
        try:
            output, executable_hash = identify_tool(name, path, item["version"], work_root, env)
            tool_details.append(
                {
                    "name": name,
                    "version": item["version"],
                    "artifactFile": item["artifactFile"],
                    "artifactSha256": item["sha256"],
                    "executableSha256": executable_hash,
                    "licenseSpdx": item["licenseSpdx"],
                    "purl": item["purl"],
                    "versionOutput": output,
                }
            )
        except FileNotFoundError as exc:
            tool_failure = ("Blocked", str(exc))
            break
        except Exception as exc:
            tool_failure = ("Failed", str(exc))
            break
    tool_status, tool_output = tool_failure or ("Passed", "Exact trusted tool versions matched the functional lock.")
    tool_record = make_record(
        "Bash toolchain provenance",
        "dependency",
        ["trusted-tool-version-and-hash-verification"],
        tool_status,
        tool_output,
        0,
        "bash-toolchain",
        "1.0.0",
        roots,
        executables,
        0 if tool_status == "Passed" else (None if tool_status == "Blocked" else 1),
        ["bash-toolchain.json"],
        details={
            "lockSha256": sha256(args.tool_lock),
            "bash": {"version": bash_record["toolVersion"], "executableSha256": sha256(bash)},
            "tools": tool_details,
        },
    )
    phase_records["toolchain"] = tool_record
    records.append(tool_record)

    source_files = [*bash_files, *bats_files]
    syntax_outputs: list[str] = []
    syntax_duration = 0.0
    syntax_code = 0
    for path in source_files:
        command = [str(bash), "--noprofile", "--norc", "-n", str(path)]
        code, output, duration, _ = run_command(command, isolated_project, env, args.command_timeout_seconds)
        syntax_duration += duration
        syntax_outputs.append(f"{path.relative_to(isolated_project)}: {output or 'syntax passed'}")
        if code != 0:
            syntax_code = code
    syntax_record = make_record(
        "Bash syntax",
        "syntax",
        [str(bash), "--noprofile", "--norc", "-n", "<declared-bash-files>"],
        "Passed" if syntax_code == 0 else "Failed",
        "\n".join(syntax_outputs),
        syntax_duration,
        "GNU Bash",
        bash_record["toolVersion"],
        roots,
        executables,
        syntax_code,
        [PHASE_FILES["syntax"]],
        details={"files": [path.relative_to(isolated_project).as_posix() for path in source_files]},
    )
    phase_records["syntax"] = syntax_record
    records.append(syntax_record)

    if tool_status == "Passed":
        directives = [
            path.relative_to(isolated_project).as_posix()
            for path in source_files
            if SHELLCHECK_DIRECTIVE_PATTERN.search(path.read_text(encoding="utf-8"))
        ]
        shellcheck_command = [
            str(args.shellcheck.resolve(strict=True)),
            "--format=json1",
            "--severity=warning",
            "--shell=bash",
            "--source-path=SCRIPTDIR",
            "--rcfile=/dev/null",
            "--enable=all",
            *[str(path) for path in source_files],
        ]
        if directives:
            shellcheck_code, shellcheck_output, shellcheck_duration = (
                1,
                f"Caller ShellCheck directives are prohibited: {', '.join(directives)}",
                0.0,
            )
        else:
            shellcheck_code, shellcheck_output, shellcheck_duration, _ = run_command(
                shellcheck_command, isolated_project, env, args.command_timeout_seconds
            )
        shellcheck_record = make_record(
            "Bash ShellCheck",
            "lint",
            shellcheck_command,
            "Passed" if shellcheck_code == 0 else "Failed",
            shellcheck_output,
            shellcheck_duration,
            "ShellCheck",
            next(item["version"] for item in lock["tools"] if item["name"] == "ShellCheck"),
            roots,
            executables,
            shellcheck_code,
            [PHASE_FILES["shellcheck"]],
            details={
                "callerRcFileIgnored": True,
                "externalSources": False,
                "externalSourceLoadingFlagPresent": False,
                "callerDirectives": directives,
            },
        )

        shfmt_command = [
            str(args.shfmt.resolve(strict=True)),
            "-d",
            "-ln",
            "bash",
            "-i",
            "2",
            "-ci",
            "-bn",
            "-sr",
            *[str(path) for path in source_files],
        ]
        shfmt_code, shfmt_output, shfmt_duration, _ = run_command(
            shfmt_command, isolated_project, env, args.command_timeout_seconds
        )
        formatting_record = make_record(
            "Bash formatting",
            "lint",
            shfmt_command,
            "Passed" if shfmt_code == 0 else "Failed",
            shfmt_output,
            shfmt_duration,
            "shfmt",
            next(item["version"] for item in lock["tools"] if item["name"] == "shfmt"),
            roots,
            executables,
            shfmt_code,
            [PHASE_FILES["formatting"]],
            details={"language": "bash", "indent": 2, "callerEditorConfigIgnoredByExplicitOptions": True},
        )
    else:
        shellcheck_record = placeholder_record("shellcheck", tool_output, roots, executables, tool_status)
        formatting_record = placeholder_record("formatting", tool_output, roots, executables, tool_status)
    phase_records["shellcheck"] = shellcheck_record
    phase_records["formatting"] = formatting_record
    records.extend([shellcheck_record, formatting_record])

    execution_gate = all(
        record["status"] == "Passed"
        for record in (bash_record, tool_record, syntax_record, shellcheck_record, formatting_record)
    )
    make_read_only(isolated_project, set(source_files))
    if execution_gate:
        bats_command = [
            str(args.bats.resolve(strict=True)),
            "--tap",
            "--timing",
            *[str(path) for path in bats_files],
        ]
        bats_code, bats_output, bats_duration, bats_timed_out = run_command(
            bats_command,
            isolated_project,
            env,
            args.test_timeout_seconds,
            sandbox={
                "landlock_version": sandbox_abi,
                "read_only_roots": [
                    isolated_project,
                    args.bats.resolve(strict=True).parents[1],
                    *[Path(path) for path in ("/usr", "/bin", "/lib", "/lib64", "/etc", "/dev/urandom")],
                ],
                "read_write_roots": [work_root / "home", work_root / "tmp", Path("/dev/null")],
                "deny_tcp": sandbox_abi >= 4,
            },
        )
        tests_record = make_record(
            "Bash tests",
            "unit",
            bats_command,
            "Passed" if bats_code == 0 else "Failed",
            bats_output,
            bats_duration,
            "Bats",
            next(item["version"] for item in lock["tools"] if item["name"] == "Bats"),
            roots,
            executables,
            bats_code,
            [PHASE_FILES["tests"]],
            details={
                "specFiles": [path.relative_to(isolated_project).as_posix() for path in bats_files],
                "timedOut": bats_timed_out,
                "projectReadOnly": True,
                "landlockAbi": sandbox_abi,
                "filesystemSandboxed": True,
                "tcpConnectAndBindRestricted": sandbox_abi >= 4,
            },
        )
    else:
        tests_record = placeholder_record(
            "tests",
            "Bats execution was not run because a mandatory non-executing gate did not pass.",
            roots,
            executables,
        )
    phase_records["tests"] = tests_record
    records.append(tests_record)

    sbom = build_sbom(
        load_json(isolated_project / "project-manifest.json")["projectName"],
        lock,
        sha256(args.tool_lock),
        sha256(bash),
    )
    sbom_record = make_record(
        "Bash project SBOM",
        "security",
        ["trusted-cyclonedx-1.5-generation"],
        "Passed",
        "CycloneDX 1.5 SBOM generated from the verified functional lock.",
        0,
        "python-standard-library",
        f"{sys.version_info.major}.{sys.version_info.minor}.{sys.version_info.micro}",
        roots,
        executables,
        0,
        [PHASE_FILES["sbom"]],
        details={"componentCount": len(sbom["components"]), "specVersion": "1.5"},
    )
    phase_records["sbom"] = sbom_record
    records.append(sbom_record)

    hosted = os.environ.get("GITHUB_ACTIONS") == "true"
    hosted_record = make_record(
        "GitHub-hosted workflow execution",
        "workflow",
        ["GitHub Actions governed Bash job"],
        "Passed" if hosted else "NotRun",
        "Hosted execution is active." if hosted else "Hosted execution was not performed locally.",
        0,
        "GitHub Actions",
        os.environ.get("RUNNER_OS", "local"),
        roots,
        executables,
        0 if hosted else None,
        [],
        required=hosted,
    )
    records.append(hosted_record)
    if evidence_root.exists():
        raise ValueError("reserved evidence root was modified during caller execution")
    evidence_root.mkdir(parents=True, mode=0o700)
    for phase in ("syntax", "shellcheck", "formatting", "tests", "toolchain"):
        write_json(evidence_root / PHASE_FILES[phase], phase_records[phase])
    write_json(evidence_root / PHASE_FILES["sbom"], sbom)
    write_json(evidence_root / "local-test-results.json", records)
    mandatory = [record for record in records if record.get("requiredValidation")]
    return 0 if all(record["status"] in {"Passed", "NotApplicable"} for record in mandatory) else 1


def write_failure_evidence(args: argparse.Namespace, error: Exception) -> None:
    evidence_root = args.evidence_root.absolute()
    reject_symlink_components(evidence_root.parent)
    evidence_resolved = evidence_root.resolve(strict=False)
    protected_roots = [
        args.caller_root.resolve(strict=True),
        args.project.resolve(strict=True),
        args.work_root.absolute().resolve(strict=False),
        args.tool_lock.resolve(strict=True).parent,
    ]
    for protected in protected_roots:
        if is_within(evidence_resolved, protected) or is_within(protected, evidence_resolved):
            raise ValueError("refusing to create failure evidence in an overlapping protected root")
    if os.path.lexists(evidence_root):
        raise ValueError("refusing to replace a pre-existing failure-evidence path")
    evidence_root.mkdir(parents=True)
    roots = [args.project.absolute(), args.work_root.absolute(), evidence_root, args.tool_lock.absolute()]
    executables = {
        "bash": args.bash.absolute(),
        "shellcheck": args.shellcheck.absolute(),
        "shfmt": args.shfmt.absolute(),
        "bats": args.bats.absolute(),
    }
    status = "Blocked" if isinstance(error, FileNotFoundError) else "Failed"
    structure = make_record(
        "Bash project structure and path safety",
        "security",
        ["trusted-project-tree-inspection"],
        status,
        str(error),
        0,
        "bash-project-validation",
        "1.0.0",
        roots,
        executables,
        None if status == "Blocked" else 1,
        [],
    )
    records = [structure]
    for phase, filename in PHASE_FILES.items():
        record = placeholder_record(phase, f"Not run because project validation failed: {error}", roots, executables)
        write_json(evidence_root / filename, record if phase != "sbom" else {"status": "NotRun", "reason": record["notRunReason"]})
        records.append(record)
    hosted = make_record(
        "GitHub-hosted workflow execution",
        "workflow",
        ["GitHub Actions governed Bash job"],
        "Passed" if os.environ.get("GITHUB_ACTIONS") == "true" else "NotRun",
        "Hosted execution context recorded." if os.environ.get("GITHUB_ACTIONS") == "true" else "Hosted execution was not performed locally.",
        0,
        "GitHub Actions",
        os.environ.get("RUNNER_OS", "local"),
        roots,
        executables,
        0 if os.environ.get("GITHUB_ACTIONS") == "true" else None,
        [],
        required=os.environ.get("GITHUB_ACTIONS") == "true",
    )
    records.append(hosted)
    write_json(evidence_root / "bash-validation.json", structure)
    write_json(evidence_root / "local-test-results.json", records)


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--bash", type=Path, required=True)
    parser.add_argument("--shellcheck", type=Path, required=True)
    parser.add_argument("--shfmt", type=Path, required=True)
    parser.add_argument("--bats", type=Path, required=True)
    parser.add_argument("--caller-root", type=Path, required=True)
    parser.add_argument("--project", type=Path, required=True)
    parser.add_argument("--project-path-input", required=True)
    parser.add_argument("--work-root", type=Path, required=True)
    parser.add_argument("--evidence-root", type=Path, required=True)
    parser.add_argument("--tool-lock", type=Path, required=True)
    parser.add_argument("--command-timeout-seconds", type=int, default=30)
    parser.add_argument("--test-timeout-seconds", type=int, default=120)
    args = parser.parse_args()
    if not 5 <= args.command_timeout_seconds <= 120:
        parser.error("command timeout must be between 5 and 120 seconds")
    if not 5 <= args.test_timeout_seconds <= 300:
        parser.error("test timeout must be between 5 and 300 seconds")
    try:
        return execute(args)
    except Exception as exc:
        try:
            write_failure_evidence(args, exc)
        except Exception as evidence_error:
            print(f"could not write complete failure evidence: {evidence_error}", file=sys.stderr)
        print(str(exc), file=sys.stderr)
        return 1


if __name__ == "__main__":
    raise SystemExit(main())
