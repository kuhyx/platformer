# Finish the remaining prototypes' toolchains and their slices

Read in this order: this file → `CLAUDE.md` → `spec/DOCS-decisions.md` →
`spec/DOCS-slice.md`. Everything else is reference; the reasoning behind
every decision is in `docs/DOCS-session-log.md` and `docs/research/`.

## what
The Godot slice is built and verified native + web as of 2026-09-11 (session
log §9). Every lint and build that can run without a web toolchain passes,
and every dependency is exact-pinned at newest stable. What is left is the
web side of the other four prototypes, their slices, and the scorecard.

## outstanding
1. `proto-love`: install LÖVE 11.5 (`love` is not on this PC) and run
   `love .`; luacheck already passes.
2. `proto-raylib`: install emsdk and a raylib checkout built with
   `PLATFORM=PLATFORM_WEB`, then `make web`. Native build passes.
3. `proto-godot`: fill the scorecard row (`slice-status` skill). M5 is
   already known: 10.1 MB gzip against a 6 MB budget — owner decides
   between raising the Godot budget and a custom web template build.
4. `proto-bevy`: `rustup target add wasm32-unknown-unknown` plus
   `wasm-bindgen-cli` and `wasm-opt`; run the web build from the README.
5. Build the slice in Phaser → LÖVE → raylib → Bevy (D11 order), each
   mirroring `proto-godot/sim.gd` + `rooms.json` so the five stay
   comparable. Promote `rooms.json` to `shared/` when the second one lands.

## done
- `make hygiene && pre-commit run --all-files` exits 0 (already true).
- Each `proto-*/README.md` web-build block runs to completion and
  `tools/size_budget.py` passes for that `dist/`.
- Every scorecard row in `spec/DOCS-comparison-protocol.md` is filled.

## verify
Desktop. Run the exact commands from each prototype README and quote the
last line each printed; CI on `main` green.

## read first
- `docs/DOCS-session-log.md` §8 — what was verified on the PC and how.
- `spec/DOCS-dev-principles.md` §4 — the full gate list.

REMOVE ME AFTER FINISH
