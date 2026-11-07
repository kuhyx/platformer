# proto-love

LÖVE (Lua). Status: **slice built** (spec/DOCS-slice.md): two rooms,
hazards, checkpoints, goal loop, juice, web start gate, debug overlay.
Analytics (D09) and audio skipped: known gaps.

## Requirements
- LÖVE 11.5 native (newest stable, github.com/love2d/love; outside the
  freshness gate, re-check by hand).
- `luacheck` and `busted` (`luarocks install luacheck busted`).
- Web: `love.js` 11.4.1, exact-pinned in `package.json` (newest on npm,
  `npm view love.js version`, 2026-11-06); `make web` runs `npm ci`.

## Files
| File | Role |
|---|---|
| `sim.lua` / `sim_state.lua` | pure fixed-step sim (D12) + snapshot; no `love.*` |
| `f32.lua` / `rng.lua` | float32 rounding and the seeded RNG Godot uses |
| `layout.lua` / `rooms.lua` | rooms loader + winnability assert; generated layout (D24) |
| `registry.lua` / `params.lua` | registry accessor; generated values (F5 re-requires) |
| `fx.lua` | hitstop, shake, seeded particle burst, goal flash |
| `input.lua` | keyboard + gamepads per spec/DOCS-input-map.md |
| `save.lua` | `save.txt` (room id + registry hash); temp + rename native, IDBFS web |
| `view.lua` | drawing, letterbox (D13), pause dim, pulsing start gate |
| `overlay.lua` | F1 debug overlay generated from the registry |
| `devtools.lua` | flags, F5 reload, F6 snapshot, `--shots` |
| `autodrive.lua` | `--autodrive` bot (replay.gd's policy) through `input.poll` |
| `main.lua` / `conf.lua` | glue: tick loop, events, pause, gate, web markers |
| `web/index.html` | text-free shell; stdout markers → `__gameReady`, `__game` |
| `e2e_web.mjs` | Playwright: gate, hold D to room 2, IDBFS resume, corrupt save |
| `spec/` | busted: sim, save, cross-engine replay (+ tiny JSON reader) |

## Run
```
love .                                   # Pause: Esc / P / Start
love . --autodrive --shots --quit-after=1500   # bot plays, screenshots to save dir
love . --seed=7                          # fixed RNG seed
```
Debug keys (unfused `love .` only): F1 overlay, F5 reload registry +
`sim.lua` + `fx.lua` in place, F6 dump `snapshot.lua` to the save dir.

## Test / lint
```
busted        # last line: 15 successes / 0 failures / 0 errors / 0 pending
luacheck .    # last line: Total: 0 warnings / 0 errors in 21 files
```
`spec/replay_spec.lua` replays `shared/replay/slice_trace.json` and
prints `replay: ok (14 events, exact ticks)`.

## Web build
```
make web      # last line: size-budget: 1,727,911 / 4,000,000 bytes gzip  ok
timeout 50 python3 -m http.server 8772 --bind 127.0.0.1 --directory dist & sleep 1
node e2e_web.mjs http://127.0.0.1:8772/   # last line: e2e_web: 0 failure(s), ...
```
`make web`: zip the top-level `*.lua` into `build/proto-love.love`,
`love.js -c` (compatibility, no threads, D10) into `dist/`, replace
`dist/index.html` with `web/index.html`, run `tools/size_budget.py`.

### love.js and LÖVE 11.5
love.js 11.4.1 is the newest release and embeds a **LÖVE 11.4.0** runtime
(`love.getVersion()` in Chromium, 2026-11-06); there is no 11.5 build. The
slice uses no 11.5-only API, so it runs. A game declaring `11.5` still
runs but logs a compatibility warning, so `conf.lua` declares `11.4` on web.

### `__gameReady` and the gate
love.js has no JS bridge. Lua's `print` reaches `Module.print`, so
`main.lua` prints `__gameReady` on its first drawn frame (before the gate)
and `web/index.html` sets `window.__gameReady = performance.now()`.
`__room=N` and `__gate=0` feed `window.__game` the same way for e2e. The
pulsing gate is drawn in Lua (`gate_*` params).

### Saves on web
love.js mounts IDBFS at `/home/web_user/love` but writes it back only on
`beforeunload`. A reload persists (e2e verified); a tab crash or kill
loses the last save. No fix without a JS bridge.

## Agent play (M9)
Native: `--autodrive` feeds the bot through the real `input.poll` path,
`--shots` captures room 1 start, death burst, room 2, goal flash; or
`xdotool keydown d` on the Xvfb window. Web: `e2e_web.mjs`.
