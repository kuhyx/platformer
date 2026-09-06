# Web load, agent tooling, testing, analytics — findings

## Web export and the <2 s target
- Godot 4 engine wasm ≈ 40 MB uncompressed / ≈ 5 MB Brotli (Godot
  Foundation's own 4.3 figure). A minified custom template + Brotli can
  reach ≈ 2.7 MB zipped, but itch.io does not serve Brotli, so served
  size lands nearer gzip. A dev.to post claims 25–35 MB compressed; the
  sources conflict — measure your own export.
- Cached load: the wasm is local, so <2 s is realistic for Godot once
  cached. The first uncached ~5 MB is the risk on slow links. Hence D02
  (start gate hides it) and D10 (target is the cached load).
- Godot threaded web builds need SharedArrayBuffer → COOP/COEP headers.
  itch.io's experimental checkbox uses `COEP: credentialless`, which
  Safari and Firefox-Android have not supported; games fail to boot.
  Fix: single-threaded web template (Godot 4.3+). Adopted in D10.
- Bevy wasm: 30 MB+, ~15 MB after wasm-opt. Needs a lazy-load UX.
- Defold, LÖVE, raylib, Phaser produce small bundles; best bets for raw
  <2 s.
- Unity WebGL: empty builds are several MB; one devlog reports a 45 s
  first load before optimisation. Poor fit.
- Godot C# web export: still unofficial (community Docker builds only).
  Use GDScript for browser targets.
- Browser audio needs a user gesture (Chromium autoplay policy since
  M66/M70). A wasm canvas cannot start audio on load. Adopted in D02.

## Agent / LLM tooling
- **Godot:** Coding-Solo/godot-mcp (launch/run/debug), IvanMurzak/
  Godot-MCP (42 tools, screenshots), PlayGodot ("Playwright for Godot",
  headless input simulation, needs a Godot fork), erodenn/
  godot-mcp-runtime (input injection, screenshots, live GDScript over
  UDP, no addon), abagames/headless-godot-skill-kit (patch → test → web
  export). Native `--headless`.
- **Bevy:** Bevy Remote Protocol built in; natepiano/bevy_brp_mcp +
  bevy_brp_extras (screenshots, format discovery); bevy_debugger_mcp
  (record/replay). Strongest live inspect/mutate story.
- **Unity:** official MCP Server (beta) + CoplayDev/unity-mcp.
- **Phaser:** Playwright MCP, no game-specific server needed.
- **LÖVE / raylib:** nothing exists; custom input socket + screenshots.
- Language fit: GDScript, TypeScript and Rust are all well represented
  in training data. Rust gives the cleanest compile-or-fail loop but
  slowest iteration; GDScript iterates fastest.

## Testing, linting, coverage
- GDScript: GdUnit4 (v6.2.0, built on Godot 4.5) or GUT; CLI + JUnit
  export; jamie-pate/godot-code-coverage for %; gdlint. 100% on
  node-coupled code is impractical — test pure logic.
- Rust/Bevy: cargo-nextest, cargo-llvm-cov (line/region/branch),
  clippy + rustfmt. Best in class.
- Phaser/TS: Vitest/Jest + c8, ESLint + strict tsconfig. Excellent.
- Owner decision D07: coverage gate suspended for the bake-off.

## Analytics feasibility
- Input log + deterministic replay is cheap and works everywhere;
  full-state serialisation is easy in Godot (resources) and Bevy
  (reflection/BRP). Adopted as the core in D09.
- Video capture on an i3 iGPU costs frames; prefer re-rendering from
  replay offline, or low-res/low-fps capture in the debug build only.
- Gaze: WebGazer.js is the only free webcam option; browser-only,
  client-side. Accuracy ≈ 4° visual angle; unmaintained as of
  2026-02-24. Treat as a rough attention heatmap, debug-only.
