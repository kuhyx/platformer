# Session log — 2026-09-02 → 2026-09-06 (Claude mobile chat)

Chronological record so the Claude Code session inherits the reasoning,
not just the artefacts.

## 1. Brief (09-02)
Owner posted design principles (constant gameplay, minimalism, no text,
no cheap mechanics, gameplay-first, satisfying, never lose progress),
technical requirements (60 fps@480p on i3 iGPU, Linux+Windows, browser
on itch.io, maximal analytics) and development principles (everything
live-tunable, hot reload, jump anywhere, 100% coverage, hardest lint,
250-line cap, LLM-friendly harness). No task stated.

## 2. First pushback
- "No loading" is impossible in browser → owner accepted "< 2 s cached".
- Video/gaze recording + no text = no consent screen = GDPR problem →
  owner: analytics only on their own build.
- Owner: wants all three of engine recommendation, critique, plan;
  platformer, 2D or 3D open, "let's try all of them"; greenfield.

## 3. Research (09-02)
Deep research produced the report now in `docs/research/`. Headline:
Godot 4.6 GDScript first, a small-bundle control engine, Bevy optional;
Unreal/Unity/C#-Godot-web/GameMaker/Construct deprioritised. Report ended
with 10 decisions for the owner.

## 4. Ten decisions (09-03)
2D · start gate yes · progress = checkpoints · no-text runtime-only ·
zero settings · "everything: juice, mastery, rewards" · literal 100%
coverage · 250 lines everywhere · video/gaze debug-only · single-threaded
web yes.

## 5. Second pushback
- Checkpoint granularity undefined → owner: per room.
- Zero settings costs accessibility → owner: aware, accepted.
- "Rewards" contradicts minimalism without a defined reward → owner:
  drop rewards.
- Literal 100% + 2D + web-first tilts toward Phaser/TS over GDScript →
  owner: drop the coverage requirement for the bake-off, prototype all
  options.
- Owner: write the monorepo skeleton plus decisions.

## 6. Skeleton (09-03)
Delivered: spec (9 files), registry + generator, 4 tools, 5 prototype
stubs, CI, deploy workflow, 3 skills, CLAUDE.md/AGENTS.md. Verified in
the sandbox: `make hygiene`, gdlint/gdformat, C syntax with `-Werror`,
Node/Python parse. Not verified: npm/cargo installs, luacheck,
clang-format, any version pin, Bevy 0.19 API names.

## 7. Handoff (09-06)
Owner asked for one zip with everything from the session for a Claude
Code session. This repo, including `.git`, is that zip.

## 8. On the PC (09-06, Claude Code)
Unpacked to `~/platformer`, brought under the fleet's shared gates, pushed
to `kuhyx/platformer`. Verified here, not in a sandbox:
- Pins at newest stable, lockfiles committed: Phaser 4.2.1, Vite 8.2.2,
  ESLint 10.10.0, typescript-eslint 8.69.0 (TypeScript 6.0.3, held
  fleet-wide); Bevy 0.19.1, serde 1.0.229, serde_json 1.0.151,
  js-sys 0.3.105. CI toolchains: Node 24.20.0, Python `3.x`,
  gdtoolkit 4.5.0. Godot 4.7.2, LÖVE 11.5 and raylib 6.0 are the current
  stable releases per their GitHub release pages.
- `proto-phaser`: `npm run lint && npm run build`, 356 kB gzip of a
  1.5 MB budget. Phaser 4 no longer declares `Scene.create`, so `override`
  came off.
- `proto-bevy`: `cargo fmt --check && cargo clippy --all-targets -- -D
  warnings` on Rust 1.98.1. `WindowResolution` takes `(u32, u32)` in 0.19;
  the registry moved to `src/lib.rs` so its overlay API is not dead code.
- `proto-raylib`: `make lint && make native` against raylib 6.0.
- `proto-love`: `luacheck .` clean. LÖVE itself is not installed here.
- `proto-godot`: gdlint + gdformat clean; `godot --headless --import` then
  a headless run on 4.7.2 boots `main.tscn`.
- `tools/check_line_cap.py` deleted in favour of the shared 250-line gate;
  markdown renamed into the fleet namespaces; `HANDOFF.md` became
  `TODO-handoff.md` holding only what is still outstanding.
