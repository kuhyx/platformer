# proto-love

LÖVE (Lua). Status: boot stub only.

## Requirements
- LÖVE 11.5 (newest stable as of 2026-09-06; `conf.lua` matches).
- `luacheck` (`luarocks install luacheck`).
- Web: love.js (`npm i -g love.js`); verify it supports the LÖVE version
  you installed.

## Run / lint
```
love .
luacheck .
```

## Web build
```
zip -9 -r proto-love.love . -x '*.git*' 'dist/*'
love.js -c -t proto-love proto-love.love dist    # -c = compatibility (no threads, D10)
python3 ../tools/size_budget.py dist 4000000
```

## `__gameReady`
**Not settable from Lua.** love.js has no JS bridge. Patch `dist/index.html`
after the build: on `Module.onRuntimeInitialized`, hook the first
`requestAnimationFrame` and set `window.__gameReady = performance.now()`.
Script that patch into a `make web` target during the slice. Note this as
a tooling cost in the scorecard.

## Live tweak / hot reload
- Registry: `package.loaded.params = nil; registry = require("params")`
  on F5 rewrites the table; wire it during the slice.
- Code: no built-in reload. `lurker`/`lick` style libraries exist; test
  one and score M8 honestly.

## Agent play (M9)
No MCP server exists. Options: `love --fused` + xdotool key injection +
screenshots, or a UDP command listener inside the game. Both are custom.

## Known gaps
No JSON parser in LÖVE, which is why the registry is generated as
`params.lua` rather than read from JSON.
