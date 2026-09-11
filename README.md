# platformer — engine bake-off monorepo

Greenfield 2D single-player platformer. Five prototypes of the same 60-second
slice, one per engine, measured against `spec/DOCS-comparison-protocol.md`.
Nothing here is the game yet; it is the harness for choosing how to build it.

## Layout

```
TODO-handoff.md  start here when picking this repo up (deleted when done)
spec/            binding design + tech spec (start with DOCS-decisions.md)
docs/            session log and the pre-decision research report
shared/params/   the parameter registry — single source for every tunable
tools/           params validation/generation, size budget, load timer
scripts/         shims over the shared gates in ~/utils + install_hooks.sh
proto-godot/     Godot 4.7, GDScript
proto-phaser/    Phaser + TypeScript + Vite
proto-love/      LÖVE (Lua)
proto-raylib/    raylib 6, C
proto-bevy/      Bevy 0.19.1, Rust
.github/         CI: per-prototype lint/build, the shared gates, itch.io deploy
.claude/skills/  repeatable agent workflows
CLAUDE.md        agent entry point (AGENTS.md points here)
```

## Quick start

1. Read `spec/DOCS-decisions.md` (binding), then `spec/DOCS-slice.md` (what to build).
2. `scripts/install_hooks.sh` once; then `make hygiene` and
   `pre-commit run --all-files` must pass before any commit.
3. `./run.sh <proto>` installs that prototype's dependencies (pacman +
   project-level) and runs it natively; or follow the prototype's README.

## Hard rules

- 250 lines max per file, code and prose. Pre-commit and CI enforced.
- Every dependency exact-pinned at newest stable, lockfiles committed.
- Markdown lives in four namespaces: README / CLAUDE* / DOCS-* / TODO-*.
- No in-game text. No HUD. No settings. One hit = death.
- Every tunable comes from `shared/params/params.json`. No magic numbers in code.
- Every web build sets `window.__gameReady = performance.now()` on its first
  playable frame so `tools/measure_load.mjs` can time it.

## Status

Skeleton only. No prototype has the slice yet. Every manifest is pinned at
newest stable and every native lint/build passes on the PC (2026-09-06);
the web builds are the next step — see `TODO-handoff.md`.
