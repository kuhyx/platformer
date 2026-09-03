# proto-raylib

raylib 6.0, C99. Status: boot stub only.

## Requirements
- raylib 6.0 installed with pkg-config (`pkg-config --modversion raylib`).
- clang-format for lint.
- Web: emsdk + a raylib source checkout built for web
  (`make PLATFORM=PLATFORM_WEB` inside `raylib/src`); point `RAYLIB_WEB`
  at that checkout.

## Build / run / lint
```
make native && ./bin/proto-raylib
make lint
RAYLIB_WEB=~/raylib make web     # dist/, runs the size budget
```

## `__gameReady`
`main.c::signal_web_ready`, called after the first `EndDrawing`.

## Live tweak / hot reload
- Registry: `PARAMS[]` is a mutable table; a debug overlay can edit
  `.value` in place. Reload from disk needs a small file parser; decide
  during the slice whether to vendor cJSON or read `params.h` values
  from a text sidecar.
- Code: none. Recompile is ~1 s; score M8 as "no".

## Agent play (M9)
Nothing exists. raylib 6.0 has a headless memory-framebuffer mode; a UDP
command socket for input injection plus `ExportImage` for screenshots is
the realistic route. Custom work; budget it.

## Notes
- `-Wconversion -Werror` is deliberate; expect casts around raylib's int
  APIs.
- The web target uses `ASYNCIFY`, which costs size and speed. Try
  `emscripten_set_main_loop` without it before scoring M5.
