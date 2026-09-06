# Research (2026-09-02, pre-decision)

Output of the engine bake-off research that preceded `spec/DOCS-decisions.md`.
Reference only; where this disagrees with `spec/`, the spec wins.

| File | Contents |
|---|---|
| `DOCS-01-engine-scores.md` | 11-engine scoring table, version facts, shortlist reasoning |
| `DOCS-02-web-load-and-tooling.md` | web bundle sizes, SharedArrayBuffer, MCP/agent tooling, test/lint, analytics |
| `DOCS-03-spec-critique.md` | contradictions in the original brief and how each was resolved |

## Sources consulted
- godotengine.org — "Web Export in 4.3" (wasm ~40 MB raw / ~5 MB Brotli)
- popcar.bearblog.dev — "How to Minify Godot's Build Size"
- bugnet.io — Godot HTML5 SharedArrayBuffer failure on itch.io
- dev.to/ziva — Godot 4 web export sizes (conflicting 25–35 MB claim)
- bevy-cheatbook.github.io — wasm sizes (30 MB, ~15 MB after wasm-opt)
- github.com/bevyengine/bevy — README on API churn (~3-month breaking cycle)
- github.com/Randroids-Dojo/PlayGodot — headless Godot test automation
- mcpservers.org — erodenn/godot-mcp-runtime, natepiano/bevy_brp_mcp
- github.com/abagames/headless-godot-skill-kit
- docs.rs/bevy_debugger_mcp
- godotengine.org/asset-library/asset/4390 — GdUnit4
- github.com/taiki-e/cargo-llvm-cov
- webgazer.cs.brown.edu — WebGazer status (unmaintained since 2026-02-24)
- Papoutsaki et al. 2016 — WebGazer accuracy (~4.17° error)
- chromium.org/audio-video/autoplay — autoplay policy (gesture required)
- en.wikipedia.org/wiki/Defold — sub-2 MB builds
- alt-kreation.itch.io devlog — Unity WebGL 45 s first load
- Unity blog 2026-05-11 — official Unity MCP Server (beta)

Version numbers were as reported by those sources in early September
2026 and were not independently verified. Re-check before pinning.
