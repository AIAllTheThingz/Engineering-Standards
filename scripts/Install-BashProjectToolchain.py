"""Install the standards-owned functional Bash toolchain from verified artifacts.

The installer parses the lock as inert JSON, validates every cached or downloaded
artifact before extraction, and never inspects or executes caller project files.
"""

from __future__ import annotations

import argparse
import hashlib
import json
import os
import re
import shutil
import subprocess
import sys
import tarfile
import time
import urllib.error
import urllib.parse
import urllib.request
from datetime import UTC, datetime
from pathlib import Path, PurePosixPath
from typing import Any

MAX_ARCHIVE_MEMBERS = 4096
MAX_ARCHIVE_BYTES = 256 * 1024 * 1024
MAX_MEMBER_BYTES = 64 * 1024 * 1024
MAX_DOWNLOAD_BYTES = 128 * 1024 * 1024
ALLOWED_KINDS = {"tar-xz", "tar-gzip", "raw-executable"}
EXPECTED_TOOLS = {"ShellCheck", "shfmt", "Bats"}
TOKEN_PATTERN = re.compile(
    r"(?i)(?:gh[pousr]_[A-Za-z0-9_]{20,}|github_pat_[A-Za-z0-9_]{20,}|"
    r"authorization\s*[:=]\s*(?:bearer|basic)\s+\S+)"
)


class BlockedError(RuntimeError):
    """A required immutable source is unavailable."""


def validate_https_url(value: str) -> None:
    """Reject non-HTTPS URLs, user information, and nonstandard ports."""
    parsed = urllib.parse.urlsplit(value)
    try:
        port = parsed.port
    except ValueError as exc:
        raise ValueError("tool source URL contains an invalid port") from exc
    if (
        parsed.scheme != "https"
        or not parsed.hostname
        or parsed.username is not None
        or parsed.password is not None
        or port not in (None, 443)
    ):
        raise ValueError("tool source URL must use credential-free HTTPS on port 443")


class HttpsOnlyRedirectHandler(urllib.request.HTTPRedirectHandler):
    """Keep every redirect inside the same credential-free HTTPS policy."""

    def redirect_request(self, request, file_pointer, code, message, headers, new_url):
        validate_https_url(new_url)
        return super().redirect_request(request, file_pointer, code, message, headers, new_url)


def utc_now() -> str:
    return datetime.now(UTC).isoformat().replace("+00:00", "Z")


def sha256(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as stream:
        for chunk in iter(lambda: stream.read(1024 * 1024), b""):
            digest.update(chunk)
    return digest.hexdigest()


def sanitize(value: str, roots: list[Path]) -> str:
    result = value
    for root in sorted(roots, key=lambda item: len(str(item)), reverse=True):
        for representation in {str(root), str(root).replace("\\", "/")}:
            result = result.replace(representation, "<isolated>")
    return TOKEN_PATTERN.sub("<redacted>", result)[-12000:]


def write_json(path: Path, value: Any) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(json.dumps(value, indent=2) + "\n", encoding="utf-8")


def load_lock(path: Path) -> dict[str, Any]:
    data = json.loads(path.read_text(encoding="utf-8"))
    if data.get("schemaVersion") != "1.0.0":
        raise ValueError("unsupported Bash toolchain lock schema")
    runner = data.get("supportedRunner")
    if runner != {"os": "ubuntu-24.04", "architecture": "x86_64"}:
        raise ValueError("Bash toolchain lock must target ubuntu-24.04 x86_64")
    runtime = data.get("bashRuntime")
    if not isinstance(runtime, dict) or runtime.get("executable") != "/usr/bin/bash":
        raise ValueError("Bash runtime lock must require /usr/bin/bash")
    tools = data.get("tools")
    if not isinstance(tools, list) or {item.get("name") for item in tools if isinstance(item, dict)} != EXPECTED_TOOLS:
        raise ValueError("Bash toolchain lock must contain exactly ShellCheck, shfmt, and Bats")
    seen_files: set[str] = set()
    for tool in tools:
        required = {
            "name",
            "version",
            "sourceUrl",
            "artifactFile",
            "sha256",
            "installationKind",
            "expectedExecutablePath",
            "licenseSpdx",
            "purl",
            "runnerArchitecture",
        }
        if required.difference(tool):
            raise ValueError(f"tool lock record is incomplete: {tool.get('name', '<unknown>')}")
        if tool["installationKind"] not in ALLOWED_KINDS:
            raise ValueError(f"unsupported installation kind for {tool['name']}")
        if tool["runnerArchitecture"] != "linux-x86_64":
            raise ValueError(f"unsupported runner architecture for {tool['name']}")
        if not re.fullmatch(r"[0-9a-f]{64}", str(tool["sha256"])):
            raise ValueError(f"invalid SHA-256 for {tool['name']}")
        source = str(tool["sourceUrl"])
        validate_https_url(source)
        if "/latest/" in source or source.endswith("/latest"):
            raise ValueError(f"tool source is not an exact HTTPS URL for {tool['name']}")
        artifact = str(tool["artifactFile"])
        if artifact != Path(artifact).name or artifact.casefold() in seen_files:
            raise ValueError(f"unsafe or duplicate artifact filename for {tool['name']}")
        seen_files.add(artifact.casefold())
        executable = PurePosixPath(str(tool["expectedExecutablePath"]))
        if executable.is_absolute() or ".." in executable.parts or "\\" in str(executable):
            raise ValueError(f"unsafe executable path for {tool['name']}")
    return data


def normalized_member(name: str) -> str:
    candidate = PurePosixPath(name)
    if (
        not name
        or name.startswith("/")
        or candidate.is_absolute()
        or ".." in candidate.parts
        or "\\" in name
        or "\x00" in name
    ):
        raise ValueError(f"unsafe archive member: {name!r}")
    normalized = candidate.as_posix().rstrip("/")
    if not normalized:
        raise ValueError("archive contains an empty member name")
    return normalized


def inspect_archive(path: Path, expected_root: str) -> list[tarfile.TarInfo]:
    members: list[tarfile.TarInfo] = []
    seen: set[str] = set()
    total_size = 0
    with tarfile.open(path, "r:*") as archive:
        for member in archive.getmembers():
            name = normalized_member(member.name)
            key = name.casefold()
            if key in seen:
                raise ValueError(f"archive contains a duplicate or case-colliding member: {name}")
            seen.add(key)
            if PurePosixPath(name).parts[0] != expected_root:
                raise ValueError(f"archive member is outside the expected root: {name}")
            if not (member.isfile() or member.isdir()):
                raise ValueError(f"archive contains a link, device, or special member: {name}")
            if member.size < 0 or member.size > MAX_MEMBER_BYTES:
                raise ValueError(f"archive member exceeds the size limit: {name}")
            total_size += member.size
            if total_size > MAX_ARCHIVE_BYTES:
                raise ValueError("archive exceeds the expanded-size limit")
            members.append(member)
            if len(members) > MAX_ARCHIVE_MEMBERS:
                raise ValueError("archive exceeds the member-count limit")
    return members


def extract_archive(path: Path, destination: Path, expected_root: str) -> None:
    members = inspect_archive(path, expected_root)
    destination_resolved = destination.resolve()
    with tarfile.open(path, "r:*") as archive:
        for member in members:
            relative = Path(*PurePosixPath(normalized_member(member.name)).parts)
            target = destination / relative
            resolved_target = target.resolve(strict=False)
            try:
                resolved_target.relative_to(destination_resolved)
            except ValueError as exc:
                raise ValueError(f"archive member escapes extraction root: {member.name}") from exc
            if member.isdir():
                target.mkdir(parents=True, exist_ok=True, mode=0o755)
                continue
            target.parent.mkdir(parents=True, exist_ok=True, mode=0o755)
            source = archive.extractfile(member)
            if source is None:
                raise ValueError(f"archive member could not be read: {member.name}")
            with source, target.open("xb") as output:
                shutil.copyfileobj(source, output, length=1024 * 1024)
            target.chmod(0o755 if member.mode & 0o111 else 0o644)


def download(source_url: str, destination: Path) -> None:
    validate_https_url(source_url)
    request = urllib.request.Request(source_url, headers={"User-Agent": "engineering-standards-bash-bootstrap/1.0"})
    opener = urllib.request.build_opener(urllib.request.HTTPSHandler(), HttpsOnlyRedirectHandler())
    temporary = destination.with_name(destination.name + ".partial")
    try:
        with opener.open(request, timeout=60) as response, temporary.open("xb") as output:
            declared_length = response.headers.get("Content-Length")
            if declared_length and int(declared_length) > MAX_DOWNLOAD_BYTES:
                raise ValueError("tool artifact exceeds the download-size limit")
            downloaded = 0
            while chunk := response.read(1024 * 1024):
                downloaded += len(chunk)
                if downloaded > MAX_DOWNLOAD_BYTES:
                    raise ValueError("tool artifact exceeds the download-size limit")
                output.write(chunk)
        temporary.replace(destination)
    except (OSError, urllib.error.URLError, urllib.error.HTTPError) as exc:
        temporary.unlink(missing_ok=True)
        raise BlockedError(f"required tool source is unavailable: {type(exc).__name__}") from exc
    except Exception:
        temporary.unlink(missing_ok=True)
        raise


def version_output(executable: Path, tool_name: str) -> str:
    result = subprocess.run(
        [str(executable), "--version"],
        cwd=executable.parent,
        env={"HOME": os.devnull, "PATH": "/usr/bin:/bin", "LANG": "C.UTF-8", "LC_ALL": "C.UTF-8"},
        stdin=subprocess.DEVNULL,
        stdout=subprocess.PIPE,
        stderr=subprocess.STDOUT,
        text=True,
        timeout=30,
        check=False,
    )
    if result.returncode != 0:
        raise ValueError(f"{tool_name} version command failed with exit code {result.returncode}")
    return result.stdout.strip()[-2000:]


def verify_version(tool_name: str, version: str, output: str) -> None:
    patterns = {
        "ShellCheck": rf"(?m)^version:\s+{re.escape(version)}$",
        "shfmt": rf"(?m)^v?{re.escape(version)}$",
        "Bats": rf"(?mi)^Bats\s+{re.escape(version)}$",
    }
    if not re.search(patterns[tool_name], output):
        raise ValueError(f"installed {tool_name} version does not match {version}")


def evidence_record(
    status: str,
    started: str,
    output: str,
    roots: list[Path],
    details: dict[str, Any] | None = None,
) -> dict[str, Any]:
    sanitized = sanitize(output, roots)
    reason = sanitized[-1000:] or "Required toolchain installation did not complete."
    return {
        "schemaVersion": "1.1.0",
        "name": "Bash functional toolchain bootstrap",
        "category": "dependency",
        "status": status,
        "requiredValidation": True,
        "evidenceSource": "Automated",
        "command": "python3 -I scripts/Install-BashProjectToolchain.py --lock <lock> --cache <isolated-cache> --tool-root <isolated-tools>",
        "workingDirectory": ".",
        "startedAtUtc": started,
        "completedAtUtc": utc_now(),
        "durationSeconds": 0,
        "runtime": f"CPython {sys.version_info.major}.{sys.version_info.minor}.{sys.version_info.micro}",
        "toolName": "bash-toolchain-bootstrap",
        "toolVersion": "1.0.0",
        "exitCode": 0 if status == "Passed" else (None if status == "Blocked" else 1),
        "summary": f"Bash functional toolchain bootstrap {status.lower()}.",
        "warnings": [],
        "failureReason": reason if status == "Failed" else None,
        "blockedReason": reason if status == "Blocked" else None,
        "details": {"sanitizedOutput": sanitized or "No command output.", **(details or {})},
    }


def install(args: argparse.Namespace) -> dict[str, Any]:
    lock_path = args.lock.resolve(strict=True)
    cache = args.cache.resolve(strict=True)
    tool_root = args.tool_root.absolute()
    if not tool_root.is_absolute() or tool_root.exists():
        raise ValueError("tool root must be a new absolute path")
    cache.mkdir(parents=True, exist_ok=True, mode=0o700)
    tool_root.mkdir(parents=True, mode=0o700)
    lock = load_lock(lock_path)
    installed: list[dict[str, Any]] = []
    paths: dict[str, str] = {}
    for tool in lock["tools"]:
        artifact = cache / tool["artifactFile"]
        if not artifact.exists():
            if args.offline:
                raise BlockedError(f"offline cache is missing {tool['artifactFile']}")
            download(tool["sourceUrl"], artifact)
        if not artifact.is_file() or artifact.is_symlink():
            raise ValueError(f"cached artifact is missing or unsafe: {tool['artifactFile']}")
        actual_hash = sha256(artifact)
        if actual_hash != tool["sha256"]:
            raise ValueError(f"SHA-256 mismatch for {tool['artifactFile']}")
        if tool["installationKind"] == "raw-executable":
            executable = tool_root / tool["expectedExecutablePath"]
            shutil.copyfile(artifact, executable)
            executable.chmod(0o755)
        else:
            expected_root = tool.get("archiveRoot")
            if not isinstance(expected_root, str) or not expected_root:
                raise ValueError(f"archive root is missing for {tool['name']}")
            extract_archive(artifact, tool_root, expected_root)
            executable = tool_root / Path(*PurePosixPath(tool["expectedExecutablePath"]).parts)
            if not executable.is_file() or executable.is_symlink():
                raise ValueError(f"expected executable is missing for {tool['name']}")
            executable.chmod(0o755)
        output = version_output(executable, tool["name"])
        verify_version(tool["name"], tool["version"], output)
        key = tool["name"].lower().replace("shellcheck", "shellcheck")
        paths[key] = str(executable.resolve())
        installed.append(
            {
                "name": tool["name"],
                "version": tool["version"],
                "artifactFile": tool["artifactFile"],
                "artifactSha256": actual_hash,
                "executableSha256": sha256(executable),
                "sourceUrl": tool["sourceUrl"],
                "installationKind": tool["installationKind"],
                "licenseSpdx": tool["licenseSpdx"],
                "purl": tool["purl"],
                "runnerArchitecture": tool["runnerArchitecture"],
                "versionOutput": output,
            }
        )
    write_json(args.paths_output, paths)
    return {"paths": paths, "installed": installed, "lockSha256": sha256(lock_path)}


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--lock", type=Path, required=True)
    parser.add_argument("--cache", type=Path, required=True)
    parser.add_argument("--tool-root", type=Path, required=True)
    parser.add_argument("--evidence", type=Path, required=True)
    parser.add_argument("--paths-output", type=Path, required=True)
    parser.add_argument("--offline", action="store_true")
    args = parser.parse_args()
    started = utc_now()
    start_time = time.monotonic()
    roots = [args.cache.absolute(), args.tool_root.absolute(), args.lock.absolute(), args.evidence.absolute()]
    try:
        result = install(args)
        provenance = {"installed": result["installed"], "lockSha256": result["lockSha256"]}
        record = evidence_record("Passed", started, "Exact artifacts were verified and installed.", roots, provenance)
        record["durationSeconds"] = round(time.monotonic() - start_time, 3)
        write_json(args.evidence, record)
        print(json.dumps(result["paths"], sort_keys=True))
        return 0
    except BlockedError as exc:
        record = evidence_record("Blocked", started, str(exc), roots)
        record["durationSeconds"] = round(time.monotonic() - start_time, 3)
        write_json(args.evidence, record)
        print(str(exc), file=sys.stderr)
        return 2
    except Exception as exc:
        record = evidence_record("Failed", started, str(exc), roots)
        record["durationSeconds"] = round(time.monotonic() - start_time, 3)
        write_json(args.evidence, record)
        print(str(exc), file=sys.stderr)
        return 1


if __name__ == "__main__":
    raise SystemExit(main())
