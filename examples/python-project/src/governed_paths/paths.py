"""Small deterministic path validation library."""

from pathlib import PurePath, PurePosixPath


class InvalidPath(ValueError):
    """Raised when input is not a safe repository-relative path."""


def normalize_relative_path(value: str) -> str:
    """Return a normalized POSIX path after rejecting unsafe input."""
    if not value or "\x00" in value:
        raise InvalidPath("path must be non-empty and contain no NUL bytes")
    candidate = value.replace("\\", "/")
    path = PurePosixPath(candidate)
    if (
        path.is_absolute()
        or PurePath(value).drive
        or any(part == ".." for part in path.parts)
    ):
        raise InvalidPath("path must remain repository-relative")
    parts = [part for part in path.parts if part not in ("", ".")]
    if not parts:
        raise InvalidPath("path must identify a child entry")
    return "/".join(parts)
