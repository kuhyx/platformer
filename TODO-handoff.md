# Finish the five prototype stubs' toolchains and start the slice

Read in this order: this file → `CLAUDE.md` → `spec/DOCS-decisions.md` →
`spec/DOCS-slice.md`. Everything else is reference; the reasoning behind
every decision is in `docs/DOCS-session-log.md` and `docs/research/`.

## what
The skeleton is verified on the PC as of 2026-09-06 (see the session log,
§8): every lint and build that can run without a web toolchain passes, and
every dependency is exact-pinned at newest stable. What is left is the web
side of each prototype, then the slice itself.

## outstanding
1. `proto-love`: install LÖVE 11.5 (`love` is not on this PC) and run
   `love .`; luacheck already passes.
2. `proto-raylib`: install emsdk and a raylib checkout built with
   `PLATFORM=PLATFORM_WEB`, then `make web`. Native build passes.
3. `proto-godot`: create the Web export preset with threads off and commit
   `export_presets.cfg`; then wire `barichello/godot-ci` into `ci.yml`.
4. `proto-bevy`: `rustup target add wasm32-unknown-unknown` plus
   `wasm-bindgen-cli` and `wasm-opt`; run the web build from the README.
5. Answer the five open questions at the bottom of
   `spec/DOCS-decisions.md` (room model first), then build the slice in
   `proto-godot` per D11's order. Record measurements with the
   `slice-status` skill.

## done
- `make hygiene && pre-commit run --all-files` exits 0 (already true).
- Each `proto-*/README.md` web-build block runs to completion and
  `tools/size_budget.py` passes for that `dist/`.
- `export_presets.cfg` is committed and the `godot` CI job exports.

## verify
Desktop. Run the exact commands from each prototype README and quote the
last line each printed; CI on `main` green.

## read first
- `docs/DOCS-session-log.md` §8 — what was verified on the PC and how.
- `spec/DOCS-dev-principles.md` §4 — the full gate list.

REMOVE ME AFTER FINISH
