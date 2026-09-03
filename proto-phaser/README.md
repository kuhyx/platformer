# proto-phaser

Phaser + TypeScript + Vite. Browser-native; desktop via a wrapper later.
Status: boot stub only.

## Requirements
Node 22+. First install, then **pin** every `"latest"` in package.json to
the resolved version (`npm ls --depth=0`) and commit `package-lock.json`.
Check that the installed Phaser is the 4.x line; if 4.x is not stable,
pin the newest 3.x and note it in the scorecard.

## Run / build / lint
```
npm install            # npm ci once the lockfile is committed
npm run dev            # http://localhost:5173 with HMR
npm run build          # tsc --noEmit && vite build → dist/
npm run lint
python3 ../tools/size_budget.py dist 1500000
```

## `__gameReady`
`src/main.ts`, once on `Phaser.Core.Events.POST_RENDER` in the Boot scene.

## Live tweak / hot reload
- Registry: Vite HMR re-imports `params.json` on change; add an
  `import.meta.hot` handler in `params.ts` during the slice.
- Code: Vite HMR, sub-second.

## Agent play (M9)
Playwright MCP against `npm run dev`: keyboard injection + screenshots,
no custom tooling. `node ../tools/measure_load.mjs http://localhost:4173`
after `npm run preview` for M3/M4.

## Desktop (Linux + Windows, tech-reqs)
Not scaffolded. Decision pending in the scorecard: Electron (consistent
WebGL on Linux) vs Tauri (smaller, but WebKitGTK WebGL is unreliable).
