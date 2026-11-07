# proto-raylib

raylib 6.2 (newest stable tag; the earlier plan said 6.0), C99. Status:
slice implemented, native + web.

## Requirements
- raylib with pkg-config (`pkg-config --modversion raylib`), clang-format.
- Web: emscripten 6.x on PATH and a raylib checkout built for web. One-shot,
  idempotent: `./install_web_toolchain.sh` (clones tag 6.2 to `~/raylib`,
  runs `make -C ~/raylib/src PLATFORM=PLATFORM_WEB`, about 40 s). Point
  `RAYLIB_WEB` elsewhere to relocate it.
- E2E only: xvfb-run, xdotool, ImageMagick `import`, node + `tools/node_modules`.

## Build / run / test / lint
```
make native && ./bin/proto-raylib       # run from proto-raylib/ (F5 path)
make test                               # headless sim, replay, save checks
make lint
RAYLIB_WEB=~/raylib make web            # dist/, runs the size budget
```
Flags (native): `--seed=N`, `--replay=FILE` (feed a trace through the loop),
`--shot=TICK` (PNG at that tick), `--log-events`, `--quit-at=TICK`.

## Layout
- `sim.c/h` pure sim (no raylib), `fx.c/h` juice, `prm.c/h` live registry,
  `save.c/h`, `trace.c/h` fixture reader, `util.c/h`.
- `main.c` loop + gate, `render.c` 854x480 target letterboxed (D13),
  `input.c`, `overlay.c` (F1), `debug.c` (flags, F5, F6), `shell.html`.
- `test_sim.c`, `test_replay.c`: `make test`. `e2e_native.sh`, `e2e_web.mjs`.

## `__gameReady`
`main.c::frame`, after the first `render_present` (the web page also gets
read-only `window.__game` for the e2e driver).

## Live tweak / hot reload
- F1 sliders write `PARAMS[i].value` in place through `prm_table()`.
- F5 (native) re-reads `shared/params/params.json` (`prm_reload`). On web
  `params.h` is compiled in, so F5 is the browser's own page reload.
- Code: none. Recompile is ~1 s; score M8 as "no".

## Agent play (M9)
`--replay`, `--shot`, `--log-events`, `--quit-at` and `window.__game` give
scripted runs and screenshots; there is no live command socket.

## Notes
- `-Wconversion -Werror` is deliberate. Web build uses
  `emscripten_set_main_loop`, no ASYNCIFY (wasm 48 KB, 88 KB gzip total).
- `params.h` keeps a `static` table per translation unit; `prm.h` redirects
  `PARAM()` to the single table in `prm.c`.
- Saves: native `$XDG_DATA_HOME/proto-raylib/save.json` (atomic temp+rename);
  web IndexedDB (IDBFS mounted at `/save`, flushed after every write).
- Known gaps: no audio, no analytics (D09), no F6 restore.
