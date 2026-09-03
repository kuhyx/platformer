#!/usr/bin/env python3
"""Fail if a web build's gzip-compressed size exceeds its budget (spec/tech-reqs.md).

Usage: size_budget.py <build-dir> <budget-bytes>
"""

from __future__ import annotations

import gzip
import sys
from pathlib import Path


def compressed_size(path: Path) -> int:
    return len(gzip.compress(path.read_bytes(), compresslevel=6))


def main() -> int:
    if len(sys.argv) != 3:
        print(__doc__)
        return 2
    build_dir, budget = Path(sys.argv[1]), int(sys.argv[2])
    files = sorted(p for p in build_dir.rglob("*") if p.is_file())
    if not files:
        print(f"size-budget: no files under {build_dir}")
        return 1
    total = 0
    for path in files:
        size = compressed_size(path)
        total += size
        print(f"{size:>10,d}  {path.relative_to(build_dir)}")
    verdict = "ok" if total <= budget else "OVER BUDGET"
    print(f"size-budget: {total:,d} / {budget:,d} bytes gzip  {verdict}")
    return 0 if total <= budget else 1


if __name__ == "__main__":
    sys.exit(main())
