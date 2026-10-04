# CLAUDE.md — agent entry point

Read `TODO-handoff.md`, then `spec/DOCS-decisions.md` (binding), then
`spec/DOCS-slice.md`.

## What this repo is
Bake-off for a 2D single-player platformer: five prototypes of one slice.
Layout in `README.md`.

## Before any change
1. Find the decision that covers it. If none exists, add one to
   `spec/DOCS-decisions.md` with `Status: Proposed` and stop for owner review.
2. Tunables go in `shared/params/params.json`, then `make gen-params`.
   Never a literal in code.
3. If the request leaves behaviour unspecified, list the gaps as questions
   and stop. Do not fill them silently.

## After any change
```
make hygiene                # line cap, params validate, generated copies in sync
pre-commit run --all-files  # the shared gates: line cap, md naming, deps, binaries
see proto-<name>/README     # that prototype's lint + build commands
```
On a fresh clone run `scripts/install_hooks.sh` once so the gates run on
every commit. Never `--no-verify`.
Never report a task as done unless these ran. Say which commands ran and
what their last line printed.

## Hard rules
- No text rendered in-game. No HUD. No settings. No new game elements
  without a spec change.
- 250 lines per file, code and prose. Split rather than squeeze.
- Markdown is one of four namespaces: `README.md`, `CLAUDE*.md`, `DOCS-*.md`
  (records), `TODO-*.md` (tasks, carry the removal marker the md-naming gate
  demands, deleted when the work lands). `spec/` and `docs/` are records.
- Every dependency exact-pinned at newest stable; lockfiles committed.
  A blocked upgrade is an allowlist entry with a reason, never a range.
- Web builds set `window.__gameReady = performance.now()` on the first
  playable frame.
- Verify versions against the real registry (`npm view`, `cargo search`,
  release pages) before pinning. Do not trust memory. Godot, LÖVE and
  raylib are outside the freshness gate; check their release pages by hand.
- Deterministic sim: all randomness via the seeded RNG (D12).

## Skills
- `.claude/skills/hygiene` — run every gate.
- `.claude/skills/add-param` — add a tunable end to end.
- `.claude/skills/slice-status` — fill a scorecard row.

## Lessons (owner corrections — append, never delete)
- 2026-09-03: Unspecified edge cases are surfaced as questions, not assumed.
- 2026-09-06: A private reimplementation of a shared gate (the old
  `tools/check_line_cap.py`) is a drift risk, not a convenience; use the
  shim over `~/src/utils`.

## Commands

- run: `./run.sh godot` | n/a: one prototype per engine; `./run.sh <godot|phaser|love|raylib|bevy>`
- test: `scripts/test_changed.sh --all`
- test-changed: `scripts/test_changed.sh`
- lint: `make hygiene && gdlint proto-godot && gdformat --check proto-godot && (cd proto-love && luacheck .)`
- coverage: n/a: no coverage tooling for Godot/GDScript
- coverage-gaps: n/a: no coverage tooling for Godot/GDScript
