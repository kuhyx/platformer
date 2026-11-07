#!/usr/bin/env python3
"""Generate per-prototype copies of the slice layout (D24).

Source: shared/rooms/rooms.json. JSON engines get a marked copy; LÖVE has no
JSON parser and C has none in the standard library, so they get a Lua table
and a C header. Run `make gen-rooms`; CI diffs the outputs.
"""

from __future__ import annotations

import json
from pathlib import Path
from typing import Any

ROOT = Path(__file__).resolve().parent.parent
LAYOUT = ROOT / "shared" / "rooms" / "rooms.json"
MARKER = "GENERATED FILE - edit shared/rooms/rooms.json and run `make gen-rooms`"
JSON_TARGETS = ["proto-godot", "proto-phaser", "proto-bevy"]
RECT_LISTS = ("solids", "hazards")

Room = dict[str, Any]


def load() -> dict[str, Any]:
    """Read the layout and check its shape so a typo fails here, not in five engines."""
    raw = json.loads(LAYOUT.read_text(encoding="utf-8"))
    for key in ("width", "height", "rooms"):
        if key not in raw:
            raise SystemExit(f"gen-rooms: missing top-level key {key!r}")
    for i, room in enumerate(raw["rooms"]):
        _check_room(i, room)
    return raw


def _check_room(i: int, room: Room) -> None:
    def rect(name: str, value: Any) -> None:
        if not (isinstance(value, list) and len(value) == 4):
            raise SystemExit(f"gen-rooms: room {i} {name} is not [x, y, w, h]")

    rect("checkpoint", room["checkpoint"])
    for key in RECT_LISTS:
        for r in room[key]:
            rect(key, r)
    if room["blade"] is not None:
        rect("blade.rect", room["blade"]["rect"])
    if room["goal"] is not None:
        rect("goal", room["goal"])


def write(path: Path, text: str) -> None:
    path.write_text(text, encoding="utf-8")
    print(f"gen-rooms: wrote {path.relative_to(ROOT)}")


def gen_json(layout: dict[str, Any]) -> str:
    body = {k: v for k, v in layout.items() if not k.startswith("_")}
    return json.dumps({"_generated": MARKER, **body}, indent=2) + "\n"


def _lua_list(values: list[Any]) -> str:
    return (
        "{ "
        + ", ".join(_lua_list(v) if isinstance(v, list) else str(v) for v in values)
        + " }"
    )


def gen_lua(layout: dict[str, Any]) -> str:
    lines = [
        f"-- {MARKER}",
        "return {",
        f"    width = {layout['width']},",
        f"    height = {layout['height']},",
        "    rooms = {",
    ]
    for room in layout["rooms"]:
        lines.append("        {")
        for key in ("spawn", "checkpoint", *RECT_LISTS, "gaps"):
            lines.append(f"            {key} = {_lua_list(room[key])},")
        if room["blade"] is not None:
            blade = room["blade"]
            lines.append(
                f"            blade = {{ rect = {_lua_list(blade['rect'])}, "
                f"track = {_lua_list(blade['track'])} }},"
            )
        if room["goal"] is not None:
            lines.append(f"            goal = {_lua_list(room['goal'])},")
        lines.append("        },")
    lines += ["    },", "}"]
    return "\n".join(lines) + "\n"


def _c_rect(r: list[Any]) -> str:
    return "{" + ", ".join(f"{float(v)}f" for v in r) + "}"


def _c_rects(rects: list[list[Any]], cap: int) -> str:
    padded = [_c_rect(r) for r in rects] + [_c_rect([0, 0, 0, 0])] * (cap - len(rects))
    return "{" + ", ".join(padded) + "}"


def gen_c_header(layout: dict[str, Any]) -> str:
    rooms = layout["rooms"]
    caps = {key: max(1, *(len(r[key]) for r in rooms)) for key in (*RECT_LISTS, "gaps")}
    lines = [
        f"// {MARKER}",
        "#ifndef ROOMS_H",
        "#define ROOMS_H",
        "",
        f"#define ROOMS_WIDTH {float(layout['width'])}f",
        f"#define ROOMS_HEIGHT {float(layout['height'])}f",
        f"#define ROOM_COUNT {len(rooms)}",
        f"#define ROOM_MAX_SOLIDS {caps['solids']}",
        f"#define ROOM_MAX_HAZARDS {caps['hazards']}",
        f"#define ROOM_MAX_GAPS {caps['gaps']}",
        "",
        "typedef struct { float x, y, w, h; } RoomRect;",
        "",
        "typedef struct {",
        "    float spawn_x, spawn_y;",
        "    RoomRect checkpoint;",
        "    int solid_count, hazard_count, gap_count;",
        "    RoomRect solids[ROOM_MAX_SOLIDS];",
        "    RoomRect hazards[ROOM_MAX_HAZARDS];",
        "    float gaps[ROOM_MAX_GAPS][2];",
        "    int has_blade;",
        "    RoomRect blade;",
        "    float blade_track[2];",
        "    int has_goal;",
        "    RoomRect goal;",
        "} Room;",
        "",
        "static const Room ROOMS[ROOM_COUNT] = {",
    ]
    for room in rooms:
        gaps = [f"{{{float(a)}f, {float(b)}f}}" for a, b in room["gaps"]]
        gaps += ["{0.0f, 0.0f}"] * (caps["gaps"] - len(gaps))
        blade = room["blade"]
        zero = [0, 0, 0, 0]
        track = ", ".join(f"{float(v)}f" for v in (blade["track"] if blade else [0, 0]))
        lines += [
            "    {",
            f"        {float(room['spawn'][0])}f, {float(room['spawn'][1])}f,",
            f"        {_c_rect(room['checkpoint'])},",
            f"        {len(room['solids'])}, {len(room['hazards'])}, {len(room['gaps'])},",
            f"        {_c_rects(room['solids'], caps['solids'])},",
            f"        {_c_rects(room['hazards'], caps['hazards'])},",
            "        {" + ", ".join(gaps) + "},",
            f"        {int(blade is not None)},",
            f"        {_c_rect(blade['rect'] if blade else zero)},",
            f"        {{{track}}},",
            f"        {int(room['goal'] is not None)},",
            f"        {_c_rect(room['goal'] or zero)},",
            "    },",
        ]
    lines += ["};", "", "#endif"]
    return "\n".join(lines) + "\n"


def main() -> None:
    layout = load()
    for proto in JSON_TARGETS:
        write(ROOT / proto / "rooms.json", gen_json(layout))
    write(ROOT / "proto-love" / "rooms.lua", gen_lua(layout))
    write(ROOT / "proto-raylib" / "rooms.h", gen_c_header(layout))


if __name__ == "__main__":
    main()
