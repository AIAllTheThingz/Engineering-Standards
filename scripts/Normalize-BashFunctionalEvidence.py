"""Normalize and fail closed on governed Bash functional evidence."""

from __future__ import annotations

import argparse
import json
import re
from pathlib import Path
from typing import Any

CANONICAL_STATUSES = {"Passed", "Failed", "Blocked", "NotRun", "NotApplicable"}
REQUIRED_FILES = {
    "bash-syntax.json",
    "bash-shellcheck.json",
    "bash-formatting.json",
    "bash-tests.json",
    "bash-toolchain.json",
    "bash-project-sbom.cdx.json",
    "local-test-results.json",
}
ABSOLUTE_PATTERN = re.compile(
    r"(?:[A-Za-z]:\\|/(?:home|tmp|mnt|root|var|etc|opt|usr|workspace|github|run)(?:/|\\))"
)
TOKEN_PATTERN = re.compile(
    r"(?i)(?:gh[pousr]_[A-Za-z0-9_]{20,}|github_pat_[A-Za-z0-9_]{20,}|"
    r"authorization\s*[:=]\s*(?:bearer|basic)\s+\S+|"
    r"(?:password|passwd|client[_-]?secret|api[_-]?key|access[_-]?token)\s*[:=]\s*\S{8,})"
)


def normalize_record(record: dict[str, Any]) -> dict[str, Any]:
    required = {
        "schemaVersion",
        "name",
        "category",
        "status",
        "requiredValidation",
        "evidenceSource",
        "command",
        "workingDirectory",
        "startedAtUtc",
        "completedAtUtc",
        "durationSeconds",
        "runtime",
        "toolVersion",
        "exitCode",
        "summary",
        "warnings",
    }
    missing = required.difference(record)
    if missing:
        raise ValueError(f"evidence record {record.get('name', '<unknown>')} is missing: {', '.join(sorted(missing))}")
    if record["status"] not in CANONICAL_STATUSES:
        raise ValueError(f"evidence record uses a noncanonical status: {record['status']}")
    tool_name = record.pop("toolName", None)
    details = record.setdefault("details", {})
    if tool_name:
        details["toolName"] = tool_name
        details["toolVersion"] = record.get("toolVersion")
        record["toolVersion"] = f"{tool_name}/{record.get('toolVersion', 'unknown')}"[:120]
    status = record["status"]
    if status == "NotApplicable":
        record["notApplicableRationale"] = str(
            details.get("sanitizedOutput") or "This validation does not apply to the governed Bash project."
        )[:2000]
        record["exitCode"] = None
    elif status == "NotRun" and not record.get("notRunReason"):
        record["notRunReason"] = str(details.get("sanitizedOutput") or "Required validation did not run.")[:2000]
    elif status == "Blocked" and not record.get("blockedReason"):
        record["blockedReason"] = str(details.get("sanitizedOutput") or "Required validation was blocked.")[:2000]
    elif status == "Failed" and not record.get("failureReason"):
        record["failureReason"] = str(details.get("sanitizedOutput") or "Required validation failed.")[:2000]
    return record


def normalize_document(value: Any) -> Any:
    if isinstance(value, list):
        return [normalize_document(item) for item in value]
    if isinstance(value, dict):
        if {"schemaVersion", "name", "category", "status"}.issubset(value):
            return normalize_record(value)
        return {key: normalize_document(item) for key, item in value.items()}
    return value


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--evidence", type=Path, required=True)
    args = parser.parse_args()
    root = args.evidence.resolve(strict=True)
    missing = sorted(name for name in REQUIRED_FILES if not (root / name).is_file())
    if missing:
        raise ValueError(f"required Bash evidence is missing: {', '.join(missing)}")
    for path in sorted(root.glob("*.json")):
        document = json.loads(path.read_text(encoding="utf-8"))
        if path.name.endswith("sbom.cdx.json") or path.name == "completion-result.json":
            normalized = document
        else:
            normalized = normalize_document(document)
        rendered = json.dumps(normalized, indent=2) + "\n"
        if ABSOLUTE_PATTERN.search(rendered):
            raise ValueError(f"absolute workstation path found in {path.name}")
        if TOKEN_PATTERN.search(rendered):
            raise ValueError(f"credential-like value found in {path.name}")
        path.write_text(rendered, encoding="utf-8")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
