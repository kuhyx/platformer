#!/usr/bin/env python3
"""Generate per-prototype copies of the parameter registry (spec/parameters.md)."""

from __future__ import annotations

import json
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
REGISTRY = ROOT / "shared" / "params" / "params.json"
MARKER = "GENERATED FILE - edit shared/params/params.json and run `make gen-params`"
JSON_TARGETS = ["proto-godot", "proto-phaser", "proto-bevy"]
FIELDS = ("value", "min", "max", "step")


def load() -> dict[str, dict]:
    raw = json.loads(REGISTRY.read_text(encoding="utf-8"))
    return {k: v for k, v in raw.items() if not k.startswith("_")}


def write(path: Path, text: str) -> None:
    path.write_text(text, encoding="utf-8")
    print(f"gen-params: wrote {path.relative_to(ROOT)}")


def gen_json(params: dict[str, dict]) -> str:
    return json.dumps({"_generated": MARKER, **params}, indent=2) + "\n"


def gen_lua(params: dict[str, dict]) -> str:
    lines = [f"-- {MARKER}", "return {"]
    for key, entry in params.items():
        fields = ", ".join(f"{f} = {entry[f]}" for f in FIELDS)
        lines.append(f"    {key} = {{ {fields} }},")
    lines.append("}")
    return "\n".join(lines) + "\n"


def gen_c_header(params: dict[str, dict]) -> str:
    lines = [f"// {MARKER}", "#ifndef PARAMS_H", "#define PARAMS_H", "",
             "typedef struct { const char *key; float value, min, max, step; } Param;", "",
             "enum {"]
    lines += [f"    P_{key.upper()}," for key in params]
    lines += ["    P_COUNT", "};", "", "static Param PARAMS[] = {"]
    for key, entry in params.items():
        values = ", ".join(f"{float(entry[f])}f" for f in FIELDS)
        lines.append(f'    {{"{key}", {values}}},')
    lines += ["};", "", "#define PARAM(k) (PARAMS[(k)].value)", "", "#endif"]
    return "\n".join(lines) + "\n"


def main() -> None:
    params = load()
    for proto in JSON_TARGETS:
        write(ROOT / proto / "params.json", gen_json(params))
    write(ROOT / "proto-love" / "params.lua", gen_lua(params))
    write(ROOT / "proto-raylib" / "params.h", gen_c_header(params))


if __name__ == "__main__":
    main()
