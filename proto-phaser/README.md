# proto-phaser

Phaser + TypeScript + Vite. Browser-native; desktop via a wrapper later.
Status: the full slice (spec/DOCS-slice.md) runs in the browser; sim test,
replay fixture and headless M9 run pass. Not done: audio, analytics (D09),
desktop wrapper.

## Requirements
Node 24. Every dependency is exact-pinned in `package.json` and
`package-lock.json` is committed; Phaser is on the 4.x line (4.2.1).
TypeScript is held at 6.0.3 fleet-wide until typescript-eslint supports
7 (see `~/src/utils/dependency-freshness.allowlist.yaml`). `@types/node`
is dev-only, for the tests.

## Run / build / test / lint
```
npm ci
npm run dev            # http://localhost:5173 with HMR, debug overlay on
npm run build          # tsc --noEmit && vite build → dist/
npm test               # node --test on tests/*.test.ts (type stripping)
npm run lint
python3 ../tools/size_budget.py dist 1500000
```

## Files
| File | Role |
|---|---|
| `src/sim.ts`, `simTypes.ts`, `simState.ts` | pure 60 Hz sim, shared types, F6 snapshot (no Phaser) |
| `src/rooms.ts` | parses `rooms.json` (generated), winnability assert |
| `src/params.ts` | registry accessor over `params.json` (generated), F5 reload |
| `src/fx.ts`, `rng.ts` | hitstop-aware juice from the seeded RNG |
| `src/save.ts` | IndexedDB autosave, corrupt/missing → room 0 |
| `src/input.ts` | keyboard + gamepad per DOCS-input-map.md |
| `src/gate.ts`, `overlay.ts` | start gate pulse; F1 slider overlay (DOM) |
| `src/game.ts`, `main.ts` | thin Phaser scene; boot, WebGL check (D19) |
| `tests/` | sim checks, replay fixture, module checks |
| `e2e/m9.mjs` | headless Playwright run (M9) |

## Web build
```
npm run build
python3 ../tools/size_budget.py dist 1500000
python3 -m http.server 8771 --directory dist     # then open http://127.0.0.1:8771/
node ../tools/measure_load.mjs http://127.0.0.1:8771/ 5
```
`dist/` is static and relative (`base: "./"`); `params.json` is emitted
next to `index.html` so F5 can re-fetch it. Debug build = `npm run dev` or
`?debug` on the built page (F1 overlay, F5 reload, F6 snapshot to the
console and IndexedDB; `?restore` loads it; `?seed=N` fixes the RNG).
Without `?debug` the overlay is never created.

## Tests
`npm test` replays `../shared/replay/slice_trace.json` and requires the same
events, rooms and order (each tick within ±1; observed: exact), plus
coyote/buffer at 0 vs default, same-seed determinism, fx, gate, save parse.
Sim storage rounds to float32 like Godot's Vector2: without it the
fixture's goal contact (x reaches 808.0 against a goal at 820) lands on the
wrong side in 64-bit doubles.

## `__gameReady`
`src/game.ts`, once on `Phaser.Core.Events.POST_RENDER` in the Slice
scene; the start gate only draws after it.

## Live tweak / hot reload
- Registry: F1 sliders (live), F5 re-fetches `params.json` from the server.
- Code: Vite HMR, sub-second.

## Agent play (M9)
Headless Playwright from `../tools/node_modules`, real keyboard path:
```
python3 -m http.server 8771 --directory dist &
node e2e/m9.mjs http://127.0.0.1:8771/ /tmp/phaser-shots
```
Runs: gate click, hold D into the pit, jump route to room 2, relaunch
resumes room id 1, blade death, pause, F1/F5, goal flash, corrupt save →
room id 0. Screenshots land in the second argument. Software GL
(`--use-angle=swiftshader`), muted; ~30 s.

## Desktop (Linux + Windows, tech-reqs)
Not scaffolded. Decision pending in the scorecard: Electron (consistent
WebGL on Linux) vs Tauri (smaller, but WebKitGTK WebGL is unreliable).
