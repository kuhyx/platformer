# proto-godot

Godot 4.7, GDScript, GL Compatibility renderer. Status: boot stub only.

## Requirements
- Godot 4.7.2 editor + export templates (newest stable; the
  dependency-freshness gate does not track Godot, so re-check
  github.com/godotengine/godot/releases when bumping).
- `pip install "gdtoolkit==4.5.0"` for gdlint/gdformat.

First open on a fresh clone: `godot --headless --path . --import` builds
`.godot/` (gitignored), which registers the `Params` class; without it
`main.gd` fails to parse.

## Run
```
godot --path .                 # editor-less run of main.tscn
godot --path . --headless      # headless (agent/CI)
```

## Lint
```
gdlint . && gdformat --check .
```

## Web build
Export preset "Web", **Thread Support: off** (single-threaded, D10). Then:
```
godot --path . --headless --export-release Web dist/index.html
python3 ../tools/size_budget.py dist 6000000
```
Host on itch.io with SharedArrayBuffer support left **off**.

## `__gameReady`
`main.gd::_signal_web_ready`, deferred from `_ready`. Move it to the first
rendered frame once the slice exists.

## Live tweak / hot reload
- Registry: `Params.load_registry` re-reads `params.json`; bind to F5.
- Code: GDScript reloads on save when the editor is attached.

## Agent play (M9)
Candidates: `erodenn/godot-mcp-runtime` (input injection + screenshots, no
addon), `Randroids-Dojo/PlayGodot` (needs a Godot fork),
`Coding-Solo/godot-mcp` (editor control). Pick one during the slice;
record what worked in the scorecard.

## Known gaps
- No export_presets.cfg committed yet; create via editor, then commit.
- `.import` files will appear once assets exist; commit them.
