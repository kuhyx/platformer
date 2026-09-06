# HANDOFF — start here in Claude Code

Read in this order: this file → `CLAUDE.md` → `spec/decisions.md` →
`spec/slice.md`. Everything else is reference.

## What this is
Skeleton for a 2D single-player platformer engine bake-off: five
prototype stubs of one slice, a binding spec, a parameter registry,
hygiene tooling and CI. Two commits of history are in `.git`. The
reasoning behind every decision is in `docs/session-log.md` and
`docs/research/`.

## Verified in the authoring sandbox (2026-09-03)
- `make hygiene` passes: 250-line cap, params validate, generated copies
  in sync.
- `proto-godot`: gdlint + gdformat clean.
- `proto-raylib/main.c`: compiles with `-Wconversion -Werror` against a
  stub raylib header (not the real one).
- `tools/*.py` and `tools/measure_load.mjs` parse.

## NOT verified — do these first on the PC
1. `proto-phaser`: `npm install`, then pin every `"latest"` and commit
   the lockfile; confirm Phaser major (4.x expected); `npm run lint &&
   npm run build`.
2. `proto-bevy`: `cargo search bevy` for the 0.19.x patch; `cargo clippy`.
   `src/main.rs` uses 0.16-era names (`Camera2d`, `Sprite::from_color`,
   `WindowPlugin`); fix against the 0.19 migration guide.
3. `proto-love`: install LÖVE, set `conf.lua` `t.version` to match;
   `luacheck .`.
4. `proto-raylib`: real raylib 6.0 via pkg-config; `make native`.
5. `proto-godot`: open once in Godot 4.6 to generate `.godot/`, create
   the Web export preset with threads off, commit `export_presets.cfg`.
6. Push to GitHub and watch `.github/workflows/ci.yml`; expect the
   phaser/love/raylib/bevy jobs to need package tweaks.

## Then
Answer the five open questions at the bottom of `spec/decisions.md`
(room model first), and build the slice in `proto-godot` per D11's
order. Record measurements with the `slice-status` skill.

## Owner working rules (from the chat, apply throughout)
- Brief answers. Assertive pushback. Ask rather than assume.
- Flag unspecified behaviour and stop; do not fill gaps.
- Never claim done without running the gates and quoting their output.
- Record corrections under "Lessons" in `CLAUDE.md`.
