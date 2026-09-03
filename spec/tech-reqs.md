# Technical requirements

## Targets
| Requirement | Value | Verified by |
|---|---|---|
| Frame rate | 60 fps sustained at 854×480 | manual run on the reference device (M1/M2) |
| Reference device | Intel i3, integrated GPU, 8 GB RAM, no dGPU | scorecard |
| Platforms | Linux + Windows native; browser on itch.io | prototype READMEs |
| Web load | < 2 s cached to first playable frame | `tools/measure_load.mjs` |
| Web hosting | itch.io, no SharedArrayBuffer | single-threaded builds (D10) |

## Web build contract
1. Set `window.__gameReady = performance.now()` on the first playable
   frame. `performance.now()` is relative to navigation start, so the value
   is the load time.
2. Show the start gate (D02) only after that; the gate is the first input.
3. Never require COOP/COEP headers.
4. Persist saves in IndexedDB, not localStorage. Save payload < 1 KB.

## Size budgets (gzip, whole web bundle)
Proxy for uncached load. CI fails when exceeded (`tools/size_budget.py`).
| Prototype | Budget |
|---|---|
| proto-phaser | 1.5 MB |
| proto-raylib | 2 MB |
| proto-love | 4 MB |
| proto-godot | 6 MB |
| proto-bevy | 12 MB |

Starting points. Tighten after the first measurement.

## Native build contract
- Window 854×480, resizable; content scaled with aspect preserved (D13).
- Saves: atomic write (temp file + rename) in the platform user-data dir.
- Keyboard and gamepad both active (`input-map.md`).

## Analytics
Debug build only. See `analytics.md`.
