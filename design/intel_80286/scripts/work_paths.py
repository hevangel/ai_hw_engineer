"""Shared output-root resolution for reproducible 80286 runs."""

import os
from pathlib import Path


WORK_ROOT_ENV = "INTEL_80286_WORK_DIR"


def get_work_root(design_dir):
    """Return the configured evidence root, or the design's legacy work/ root."""
    configured = os.environ.get(WORK_ROOT_ENV)
    root = Path(configured).expanduser() if configured else Path(design_dir) / "work"
    return root.resolve()
