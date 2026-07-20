"""Local launcher for the central trusted Python validation implementation."""

import runpy
from pathlib import Path

runpy.run_path(
    str(Path(__file__).resolve().parents[3] / "scripts/python-project-validation.py"),
    run_name="__main__",
)
