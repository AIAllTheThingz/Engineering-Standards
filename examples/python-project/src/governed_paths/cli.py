"""Command-line interface for governed path validation."""

import argparse

from governed_paths.paths import InvalidPath, normalize_relative_path


def main() -> int:
    """Validate one path and print its normalized form."""
    parser = argparse.ArgumentParser()
    parser.add_argument("path")
    args = parser.parse_args()
    try:
        print(normalize_relative_path(args.path))
    except InvalidPath as exc:
        parser.error(str(exc))
    return 0
