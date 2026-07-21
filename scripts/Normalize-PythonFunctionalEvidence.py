"""Normalize governed Python functional evidence to the repository schema."""

from __future__ import annotations

import argparse
import json
from pathlib import Path
from typing import Any


def normalize_record(record: dict[str, Any]) -> dict[str, Any]:
    tool_name = record.pop("toolName", None)
    details = record.setdefault("details", {})
    if tool_name:
        details["toolName"] = tool_name
        details["toolVersion"] = record.get("toolVersion")
        record["toolVersion"] = f"{tool_name}/{record.get('toolVersion', 'unknown')}"[:120]
    if record.get("status") == "NotApplicable":
        rationale = details.get("sanitizedOutput") or "This validation does not apply to the governed project."
        record["notApplicableRationale"] = str(rationale)[:2000]
        record["exitCode"] = None
        record["failureReason"] = None
        record["blockedReason"] = None
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
    for path in sorted(root.glob("*.json")):
        if path.name.endswith("sbom.cdx.json") or path.name == "completion-result.json":
            continue
        document = json.loads(path.read_text(encoding="utf-8"))
        normalized = normalize_document(document)
        path.write_text(json.dumps(normalized, indent=2) + "\n", encoding="utf-8")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
