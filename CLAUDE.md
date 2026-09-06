# CLAUDE.md — agent entry point

Read `HANDOFF.md`, then `spec/decisions.md` (binding), then `spec/slice.md`.

## What this repo is
Bake-off for a 2D single-player platformer: five prototypes of one slice.
Layout in `README.md`.

## Before any change
1. Find the decision that covers it. If none exists, add one to
   `spec/decisions.md` with `Status: Proposed` and stop for owner review.
2. Tunables go in `shared/params/params.json`, then `make gen-params`.
   Never a literal in code.
3. If the request leaves behaviour unspecified, list the gaps as questions
   and stop. Do not fill them silently.

## After any change
```
make hygiene              # line cap, params validate, generated copies in sync
see proto-<name>/README   # that prototype's lint + build commands
```
Never report a task as done unless these ran. Say which commands ran and
what their last line printed.

## Hard rules
- No text rendered in-game. No HUD. No settings. No new game elements
  without a spec change.
- 250 lines per file, code and prose. Split rather than squeeze.
- Web builds set `window.__gameReady = performance.now()` on the first
  playable frame.
- Verify versions against the real registry (`npm view`, `cargo search`,
  release pages) before pinning. Do not trust memory.
- Deterministic sim: all randomness via the seeded RNG (D12).

## Skills
- `.claude/skills/hygiene` — run every gate.
- `.claude/skills/add-param` — add a tunable end to end.
- `.claude/skills/slice-status` — fill a scorecard row.

## Lessons (owner corrections — append, never delete)
- 2026-09-03: Unspecified edge cases are surfaced as questions, not assumed.
