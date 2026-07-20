"""Tests for safe path normalization."""

import pytest

from governed_paths import InvalidPath, normalize_relative_path


@pytest.mark.parametrize(
    ("value", "expected"), [("src/app.py", "src/app.py"), ("a\\b", "a/b")]
)
def test_normalizes_safe_paths(value: str, expected: str) -> None:
    assert normalize_relative_path(value) == expected


@pytest.mark.parametrize(
    "value", ["", ".", "../secret", "a/../../secret", "/etc/passwd", "C:\\secret"]
)
def test_rejects_unsafe_paths(value: str) -> None:
    with pytest.raises(InvalidPath):
        normalize_relative_path(value)
