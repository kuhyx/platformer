#!/usr/bin/env python3
"""Fail if any repo file exceeds the 250-line cap (spec D08)."""

from __future__ import annotations

import subprocess
import sys
from pathlib import Path

CAP = 250
SKIP_DIRS = {".git", "node_modules", "target", "dist", "build", ".godot", "vendor", "bin"}
SKIP_FILES = {"package-lock.json", "Cargo.lock"}
GENERATED_MARKER = "GENERATED FILE"


def repo_files(root: Path) -> list[Path]:
    """Use git's view of the tree when available, else walk the filesystem."""
    try:
        proc = subprocess.run(
            ["git", "ls-files", "--cached", "--others", "--exclude-standard"],
            cwd=root, check=True, capture_output=True, text=True,
        )
        return [root / line for line in proc.stdout.splitlines() if line]
    except (subprocess.CalledProcessError, FileNotFoundError):
        return [p for p in root.rglob("*") if p.is_file()]


def skipped(path: Path, root: Path) -> bool:
    rel = path.relative_to(root)
    if any(part in SKIP_DIRS for part in rel.parts):
        return True
    return path.name in SKIP_FILES


def line_count(path: Path) -> int | None:
    """Return the line count, or None for binary / generated files."""
    try:
        text = path.read_text(encoding="utf-8")
    except (UnicodeDecodeError, OSError):
        return None
    if GENERATED_MARKER in text[:300]:
        return None
    if not text:
        return 0
    return text.count("\n") + (0 if text.endswith("\n") else 1)


def main() -> int:
    root = Path(sys.argv[1] if len(sys.argv) > 1 else ".").resolve()
    offenders: list[tuple[int, Path]] = []
    for path in repo_files(root):
        if not path.is_file() or skipped(path, root):
            continue
        count = line_count(path)
        if count is not None and count > CAP:
            offenders.append((count, path.relative_to(root)))
    for count, rel in sorted(offenders, reverse=True):
        print(f"{count:5d} > {CAP}  {rel}")
    print(f"line-cap: {len(offenders)} file(s) over {CAP} lines")
    return 1 if offenders else 0


if __name__ == "__main__":
    sys.exit(main())
