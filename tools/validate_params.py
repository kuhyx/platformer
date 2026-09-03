#!/usr/bin/env python3
"""Validate shared/params/params.json against spec/parameters.md."""

from __future__ import annotations

import json
import sys
from pathlib import Path

REGISTRY = Path(__file__).resolve().parent.parent / "shared" / "params" / "params.json"
REQUIRED = {"value", "min", "max", "step", "unit", "desc"}
NUMERIC = {"value", "min", "max", "step"}


def check_entry(key: str, entry: object) -> list[str]:
    if not isinstance(entry, dict):
        return [f"{key}: entry is not an object"]
    missing = REQUIRED - entry.keys()
    errors = [f"{key}: missing {sorted(missing)}"] if missing else []
    for field in NUMERIC & entry.keys():
        if isinstance(entry[field], bool) or not isinstance(entry[field], (int, float)):
            errors.append(f"{key}.{field}: not a number")
    if errors:
        return errors
    if not entry["min"] <= entry["value"] <= entry["max"]:
        errors.append(f"{key}: value {entry['value']} outside [{entry['min']}, {entry['max']}]")
    if entry["step"] <= 0:
        errors.append(f"{key}: step must be > 0")
    if not key.islower() or not key.replace("_", "").isalnum():
        errors.append(f"{key}: key must be snake_case")
    return errors


def main() -> int:
    registry = json.loads(REGISTRY.read_text(encoding="utf-8"))
    errors: list[str] = []
    for key, entry in registry.items():
        if not key.startswith("_"):
            errors.extend(check_entry(key, entry))
    for line in errors:
        print(line)
    print(f"validate-params: {len(registry)} entries, {len(errors)} error(s)")
    return 1 if errors else 0


if __name__ == "__main__":
    sys.exit(main())
