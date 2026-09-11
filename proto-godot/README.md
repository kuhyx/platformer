# proto-godot

Godot 4.7, GDScript, GL Compatibility renderer. Status: **slice built**
(spec/DOCS-slice.md) — two rooms, hazards, checkpoints, goal loop, juice,
web start gate, debug overlay, analytics log. Scorecard row still open.

## Requirements
- Godot 4.7.2 editor + export templates (newest stable; the
  dependency-freshness gate does not track Godot, so re-check
  github.com/godotengine/godot/releases when bumping). The Arch package
  `godot-export-templates-linux-bin` ships only the Linux templates; the
  web ones come from the official `.tpz` (`templates/web_*.zip`), unpacked
  into `~/.local/share/godot/export_templates/4.7.2.stable/`.
- `pip install "gdtoolkit==4.5.0"` for gdlint/gdformat.

First open on a fresh clone: `godot --headless --path . --import` builds
`.godot/` (gitignored), which registers the `class_name`s; without it
`main.gd` fails to parse.

## Files
| File | Role |
|---|---|
| `sim.gd` / `sim_state.gd` | pure fixed-step sim (D12) and its snapshot/restore. No nodes. |
| `rooms.gd` / `rooms.json` | layout loader; asserts every gap and step is beatable at the registry values |
| `fx.gd` | particles, shake, flash — ticked with the sim, fed its RNG |
| `main.gd` / `main.tscn` | input polling, drawing, web gate, pause, F1/F5/F6 |
| `params.gd` / `params.json` | registry accessor (generated copy) |
| `save_file.gd` | atomic `user://save.json` (room id + registry hash) |
| `analytics.gd` | debug-build session log (D09) |
| `overlay.gd` | debug overlay generated from the registry |
| `web/shell.html` | custom HTML shell: no text, icon on failure (D19) |
| `tests/test_sim.gd` | headless slice checks |

## Run
```
godot --path .                          # editor-less run of main.tscn
godot --path . --headless               # headless (agent/CI)
godot --path . -- --seed=7              # fixed RNG seed (replays)
godot --path . -- --restore             # boot from user://snapshot.json (F6 dump; edit room_id to warp)
```
Pause: Esc / P / Start. Quit: close the window (D18).

## Test
```
godot --headless --path . -s tests/test_sim.gd   # last line: "test_sim: 0 failure(s)"
```
Drives `Sim` directly: landing, both hazards, room transition + autosave,
goal loop, coyote time and jump buffer at 0 vs default, determinism.

## Lint
```
gdlint . && gdformat --check .
```

## Web build
Preset "Web" in `export_presets.cfg`: **Thread Support off** (D10), custom
shell `web/shell.html`, tests excluded.
```
mkdir -p dist && godot --path . --headless --export-release Web dist/index.html
python3 ../tools/size_budget.py dist 6000000
python3 -m http.server 8765 --directory dist   # then node ../tools/measure_load.mjs http://127.0.0.1:8765/ 5
```
Measured 2026-09-11: 10.1 MB gzip — the stock 4.7.2 web template is
39.5 MB of wasm. Over the 6 MB budget; see the scorecard notes.
Host on itch.io with SharedArrayBuffer support left **off**.

## `__gameReady`
`main.gd::_on_first_frame`, connected one-shot to
`RenderingServer.frame_post_draw`. The start gate is drawn only after it.

## Live tweak / hot reload
- F1: overlay, one slider per registry entry, room id, fps. Writes through
  `Params.set_value`, so the sim sees the change on the next tick (M7).
- F5: re-read `params.json` from disk (running from the project dir).
- F6: dump the snapshot (`user://snapshot.json`).
- Code: GDScript reloads on save when the editor is attached.

## Agent play (M9)
Two working routes on 2026-09-11:
- **Native**: `xdotool keydown --window <id> d` against the running window,
  `import -window <id> shot.png` for screenshots.
- **Web**: Playwright `keyboard.down("KeyD")` against `dist/` served
  locally (system Chromium with `--use-gl=angle --use-angle=swiftshader`).
Synthetic per-tap key presses are too short for `Input.is_action_pressed`
(press and release inside one tick); hold the key.

## Known gaps
- Audio (optional in the slice) not added.
- Analytics: `video.*` / `gaze.jsonl` not started (DOCS-analytics.md "not yet decided").
