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
| phaser | — | — | 107 | 211 | 0.36 MB | ~0.3 h (agent) | yes | n/m | yes | yes | 4 | open |
| love | — | — | 123 | 296 | 1.73 MB | ~0.5 h (agent) | yes | partial | yes | yes | 3 | open |
| raylib | — | — | 79 | 144 | 0.09 MB | ~0.3 h (agent) | yes | no | yes | yes | 3 | open |
| bevy | — | — | 529 | 772 | 6.90 MB | n/m | yes | no | yes | yes | 5 | open |

## Notes
- godot (2026-09-11): M1/M2 not measured — no i3 iGPU device on hand;
  the dev PC (RTX 3090) is not the reference. M3/M4 from
  `tools/measure_load.mjs` against `python3 -m http.server` on localhost,
  so M4 is a floor, not a network number. M5 exceeds the 6 MB budget
  (D21). M8 partial: GDScript reloads only with the editor attached.
  M9 via xdotool (native) and Playwright `keyboard.down` (web). M10 via
  `tests/test_sim.gd`, no coverage tool. M11: gdlint + gdformat, 3/5.
- phaser, love, raylib (2026-11-06): M1/M2 `—` as for godot. M3/M4
  `tools/measure_load.mjs` on localhost (floors). M6 is agent wall-clock
  porting an existing sim, not comparable with godot's human-led hours,
  so the M6 kill criterion is not applied. All three replay
  `shared/replay/slice_trace.json` exactly (D12).
  - phaser: M8 n/m (Vite HMR exists, not timed). M9 Playwright
    `e2e/m9.mjs`, 13 checks. M10 node:test, no coverage. M11
    typescript-eslint `strictTypeChecked`, 4/5.
  - love: M8 partial: F5 reloads `sim.lua`/`fx.lua` live, not
    `main.lua`/`view.lua`. M9 `--autodrive` native, Playwright web. M10
    busted, no coverage. M11 luacheck (complexity 10), 3/5. love.js 11.4.1
    runs LÖVE 11.4, not 11.5.
  - raylib: M8 no (recompile ~1 s, relaunch). M9 `--replay`/`--shot`
    and xdotool native, Playwright web; no live command socket. M10 C
    test binary, no coverage. M11 `-Wconversion -Werror` +
    clang-format, 3/5. Web F5 is a page reload (params compiled in).
- bevy (2026-11-06, Bevy 0.20.1): M1/M2 `—` as above; M3/M4 floors as
  above. M6 n/m: the porting agent's wall-clock was not logged. M7 via
  the F1 sliders on the `Params` resource (read every tick). M8 no
  (Rust recompile and relaunch). M9 `--autodrive` under Xvfb native,
  Playwright web; replays `slice_trace.json` exactly (D12). M10
  `cargo test`, no coverage. M11 clippy `pedantic` `-D warnings`,
  `unwrap_used` deny, `unsafe_code` forbid + rustfmt, 5/5.

## Exit
Pick one engine and record it as D15 in `DOCS-decisions.md`. Archive the other
prototype directories; do not delete them — they are reference
implementations of the slice.
