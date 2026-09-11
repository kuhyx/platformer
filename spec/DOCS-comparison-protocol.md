# Comparison protocol

Build `DOCS-slice.md` in each engine, then fill one scorecard row per prototype.

## Measurements
| # | Metric | How |
|---|---|---|
| M1 | fps, native, i3 iGPU, 854×480 | engine fps counter, 60 s in room 2 (blade moving) |
| M2 | fps, browser, same device | same, Chromium and Firefox |
| M3 | Cached web load (ms) | `node tools/measure_load.mjs <url> 5` → `cached_median_ms` |
| M4 | Uncached web load (ms) | same run → `uncached_ms` |
| M5 | Compressed bundle bytes | `python3 tools/size_budget.py <dir> <budget>` |
| M6 | Hours to build the slice | honest log |
| M7 | Live tweak | change `jump_velocity` in the overlay with no restart: yes/no |
| M8 | Hot reload | edit movement code → visible in < 5 s without relaunch: yes/partial/no |
| M9 | Agent plays it | an LLM launches the build headless, injects inputs to reach room 2, screenshots: yes/no + tooling |
| M10 | Test story | pure movement logic unit-testable without the engine running: yes/no; coverage tool |
| M11 | Lint strictness | tool + config; 1–5 |

## Kill criteria (stop working on the prototype)
- M1 or M2 below 60 fps after one day of optimisation.
- M3 above 2000 ms or M4 above 4000 ms after minification and compression.
- M9 impossible within one day.
- M6 exceeds 3× the fastest completed prototype.

## Scorecard
| Proto | M1 | M2 | M3 | M4 | M5 | M6 | M7 | M8 | M9 | M10 | M11 | Verdict |
|---|---|---|---|---|---|---|---|---|---|---|---|---|
| godot | — | — | 505 | 651 | 10.1 MB | ~2.5 h | yes | partial | yes | yes | 3 | open |
| phaser | | | | | | | | | | | | |
| love | | | | | | | | | | | | |
| raylib | | | | | | | | | | | | |
| bevy | | | | | | | | | | | | |

## Notes
- godot (2026-09-11): M1/M2 not measured — no i3 iGPU device on hand;
  the dev PC (RTX 3090) is not the reference. M3/M4 from
  `tools/measure_load.mjs` against `python3 -m http.server` on localhost,
  so M4 is a floor, not a network number. M5 exceeds the 6 MB budget
  (D21). M8 partial: GDScript reloads only with the editor attached.
  M9 via xdotool (native) and Playwright `keyboard.down` (web). M10 via
  `tests/test_sim.gd`, no coverage tool. M11: gdlint + gdformat, 3/5.

## Exit
Pick one engine and record it as D15 in `DOCS-decisions.md`. Archive the other
prototype directories; do not delete them — they are reference
implementations of the slice.
