# Engine scoring (1–5, 5 best) against the original spec

| Engine (version) | 60fps@480p i3 iGPU | Linux+Win | Web & <2s | Hot reload | Live params | Test/cov | Lint | LLM/MCP | Analytics | 2D / 3D |
|---|---|---|---|---|---|---|---|---|---|---|
| Godot 4.5/4.6 GDScript | 5 | 5 | 3 | 4 | 5 | 4 | 4 | 5 | 4 | 5 / 4 |
| Godot C#/.NET | 5 | 5 | 1 (web unofficial) | 3 | 4 | 5 | 5 | 4 | 4 | 5 / 4 |
| Bevy 0.19 (Rust) | 4 | 5 | 2 (big wasm) | 2 | 3 | 5 | 5 | 5 (BRP+MCP) | 3 | 4 / 4 |
| LÖVE 11.x (love.js) | 5 | 5 | 4 | 4 | 3 | 3 | 3 | 3 | 3 | 5 / 1 |
| raylib 6.0 (C/Zig/Odin) | 5 | 5 | 4 | 2 | 2 | 3 | 4 | 2 | 3 | 4 / 3 |
| Phaser/TS | 4 | 4 (wrapper) | 5 | 5 | 4 | 5 | 5 | 4 | 5 | 4 / 1 |
| Defold 1.12 | 5 | 5 | 5 (tiny) | 3 | 3 | 3 | 3 | 2 | 3 | 5 / 2 |
| Unity 6 | 4 | 5 | 2 (heavy) | 3 | 4 | 4 | 4 | 4 (official MCP) | 4 | 4 / 5 |
| GameMaker | 4 | 4 | 3 | 3 | 3 | 2 | 2 | 2 | 3 | 5 / 1 |
| Construct 3 | 4 | 3 | 4 | 4 | 4 | 2 | 2 | 2 | 3 | 4 / 1 |
| Unreal 5 | 1 | 5 | 1 | 2 | 3 | 3 | 4 | 3 | 3 | 2 / 5 |

Scored before D01 (2D) was decided; the 3D column is now moot.

## Version facts as reported (early Sept 2026, unverified)
- Godot stable 4.6.3 (2026-05-20). 4.5 line added stencil buffers, shader
  baker, accessibility descriptions. MIT.
- Bevy 0.19.1 (2026-08-13). README: early stage, breaking releases ~every
  3 months.
- Defold 1.12.4 (May 2026). Exports under 2 MB.
- raylib 6.0 (April 2026): software-renderer backend, dependency-free
  Emscripten backend, headless memory-framebuffer mode.
- Construct r368 (2026-05-11), proprietary.
- Unity 6 with an official MCP Server (open beta, 2026-05-11).
- Phaser: version not captured by the research; check `npm view phaser`.

## Shortlist reasoning
1. **Godot 4.5/4.6 GDScript — first choice.** Fastest iteration, live
   inspector + remote debugger, most mature MCP/headless automation,
   native Linux/Windows, strong 2D. Weak point: ~5 MB Brotli engine wasm.
2. **LÖVE or raylib — the "web <2 s trivially" control.** Tiny bundles,
   trivial 60 fps on an iGPU; weak editor/agent tooling is the trade.
3. **Bevy — optional.** Best live inspect/mutate via BRP+MCP, strictest
   tooling, slowest iteration, heaviest wasm.
4. **Phaser/TS — added after D01 (2D) and the coverage discussion.**
   First-class coverage (c8), Vite HMR, strict ESLint, Playwright MCP
   drives it in a real browser with no custom tooling. Desktop needs a
   wrapper; Electron over Tauri on Linux because WebKitGTK WebGL is
   unreliable.

Deprioritised: Unreal (i3 iGPU can't drive it; no web), Unity (web too
heavy for <2 s; licensing), C# Godot on web (unofficial), GameMaker and
Construct (weak testing/lint/agent automation, proprietary).

Owner decision D11: prototype all five of Godot, Phaser, LÖVE, raylib,
Bevy. Protocol and kill criteria: `spec/DOCS-comparison-protocol.md`.
