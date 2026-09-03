# platformer — engine bake-off monorepo

Greenfield 2D single-player platformer. Five prototypes of the same 60-second
slice, one per engine, measured against `spec/comparison-protocol.md`.
Nothing here is the game yet; it is the harness for choosing how to build it.

## Layout

```
spec/            binding design + tech spec (start with decisions.md)
shared/params/   the parameter registry — single source for every tunable
tools/           line-cap check, params validation/generation, size budget, load timer
proto-godot/     Godot 4.6, GDScript
proto-phaser/    Phaser + TypeScript + Vite
proto-love/      LÖVE (Lua)
proto-raylib/    raylib 6, C
proto-bevy/      Bevy 0.19, Rust
.github/         CI gates and itch.io deploy
.claude/skills/  repeatable agent workflows
CLAUDE.md        agent entry point (AGENTS.md points here)
```

## Quick start

1. Read `spec/decisions.md` (binding), then `spec/slice.md` (what to build).
2. `make hygiene` — must pass before any commit.
3. Pick a prototype directory and follow its README.

## Hard rules

- 250 lines max per file, code and prose. CI-enforced.
- No in-game text. No HUD. No settings. One hit = death.
- Every tunable comes from `shared/params/params.json`. No magic numbers in code.
- Every web build sets `window.__gameReady = performance.now()` on its first
  playable frame so `tools/measure_load.mjs` can time it.

## Status

Skeleton only. No prototype has the slice yet. Versions in manifests are
unverified — pin after the first install (see each prototype README).
