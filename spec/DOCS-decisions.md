# Decisions

Binding record. Superseding a decision = new entry; the old one is marked
Superseded. `Accepted` = owner confirmed. `Proposed` = recommendation
awaiting the owner. Deciders: repo owner. Format: ADR-lite.

## D01 — 2D single-player platformer
Status: Accepted · 2026-09-03
Decision: 2D. Single player. Platformer.
Consequences: 3D-capable engines score on 2D quality only. Room/camera
model must be defined (Open Q1).

## D02 — One start gate on web
Status: Accepted · 2026-09-03
Context: browsers block audio until a user gesture; wasm downloads on
first load.
Decision: exactly one non-gameplay interaction on web: press any key or
click. It unlocks audio and hides the uncached load. Absent on desktop.
Consequences: gate is icon-only. The <2 s target applies to cached loads.

## D03 — Progress = checkpoints, one per room
Status: Accepted · 2026-09-03
Decision: a checkpoint at every room entrance. Touching it autosaves.
Death respawns at the current room's checkpoint after `respawn_delay`
(registry parameter).
Consequences: "never lose progress" means never lose a room. Save payload
is tiny (room id + counters), so atomic writes are cheap. Room size must be
defined (Open Q1).

## D04 — "No text" scope
Status: Accepted · 2026-09-03
Decision: applies to the in-game runtime only. Store pages, EULA, OS
dialogs and crash reports may contain text.
Consequences: save corruption, missing WebGL, unsupported browser must be
signalled by icon + audio only. Each needs a designed signal (Open Q4).

## D05 — Zero settings
Status: Accepted · 2026-09-03
Decision: no settings of any kind. Fixed keyboard and gamepad maps, both
active at once (`spec/DOCS-input-map.md`). Volume, fullscreen and resolution
are left to the OS/browser.
Consequences: accessibility cost accepted by owner. No rebinding, ever.
Pause is the only overlay and offers resume only (quit: Open Q3).

## D06 — Engagement: juice + mastery only
Status: Accepted · 2026-09-03
Decision: feedback juice (hitstop, shake, particles, squash/stretch,
audio) and skill-mastery loops. No reward currencies, unlocks, streaks,
variable-ratio schedules or other engagement dark patterns. Supersedes
the original principle 6 wording ("all techniques used by mainstream
apps").
Consequences: nothing needs a HUD, which keeps principle 2 intact.

## D07 — Testing during the prototype phase
Status: Accepted · 2026-09-03
Decision: the 100% coverage requirement is suspended for the bake-off.
Gates while prototyping: strictest lint, 250-line cap, build succeeds,
params validate. Tests are welcome, not gated.
Consequences: coverage policy is re-decided at engine selection (D11
exit). Coverage tooling quality stays a scored criterion (M10).

## D08 — 250-line cap everywhere
Status: Accepted · 2026-09-03
Decision: no file exceeds 250 lines, code or prose. Enforced by
`tools/check_line_cap.py` in CI. Generated files (marked `GENERATED
FILE`), lockfiles and vendored dependencies are excluded.
Consequences: docs split into linked files. Levels are data, not code.

## D09 — Analytics
Status: Accepted · 2026-09-03
Decision: analytics exist only in the developer (debug) build. Core:
timestamped input log + periodic full-state log + RNG seed →
deterministic replay. Video and webcam gaze are debug-only, off by
default, with a visible recording indicator. Public builds contain no
capture code. Detail: `spec/DOCS-analytics.md`.
Consequences: deterministic sim is mandatory (D12). Sharing a debug build
with a friend still records them; owner accepts.

## D10 — Web hosting and load budget
Status: Accepted · 2026-09-03
Decision: itch.io. Godot web exports use the single-threaded template (no
SharedArrayBuffer). Cached load < 2 s to first playable frame, measured
by `tools/measure_load.mjs`.
Consequences: every web build sets `window.__gameReady` (see
`spec/DOCS-tech-reqs.md`).

## D11 — Engines: prototype all five
Status: Accepted · 2026-09-03
Decision: build `spec/DOCS-slice.md` in Godot 4.6 GDScript, Phaser/TypeScript,
LÖVE, raylib 6 and Bevy 0.19. Score per `spec/DOCS-comparison-protocol.md`,
then pick one (recorded as D15).
Recommended order: Godot → Phaser → LÖVE → raylib → Bevy. Apply kill
criteria early rather than finishing all five.
Consequences: roughly 1–2 days per slice solo; 2–3 weeks before the real
game starts.

## D12 — Deterministic fixed-step simulation
Status: Proposed · 2026-09-03
Decision: simulation at a fixed 60 Hz tick, rendering decoupled. All
randomness from one seeded RNG stored in saves and replays.
Why: replay (D09), cross-engine comparability, browser/native parity.

## D13 — Baseline resolution and renderer
Status: Proposed · 2026-09-03
Decision: internal resolution 854×480, scaled to the window with aspect
preserved. Godot: GL Compatibility renderer. Others: WebGL2 / OpenGL 3.3.
Why: 480p is the stated performance target; GL Compatibility is the only
Godot path that runs well on an i3 iGPU and on web.

## D14 — Parameter registry
Status: Proposed · 2026-09-03
Decision: every tunable lives in `shared/params/params.json` with
value/min/max/step/unit/desc. Prototypes read a generated copy
(`make gen-params`) and never hardcode a tunable. Debug overlays are
generated from the registry. Contract: `spec/DOCS-parameters.md`.
Why: makes "everything adjustable live" finite and enforceable.

## Open questions (answer before the slice is built)
1. Room = one fixed 854×480 screen with hard transitions, or a scrolling
   area with a defined boundary? Drives D03 and all camera code.
2. Player placeholder 12×16 px acceptable?
3. With zero settings, how does a player quit or start over? Close the
   window/tab only? Is "new game" ever possible?
4. Diegetic signals for: save missing/corrupt, WebGL unavailable, gamepad
   disconnected.
5. Respawn presentation: hard cut to checkpoint, or brief camera pan? The
   delay is a parameter; the presentation is a design choice.
