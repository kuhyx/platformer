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
Code session. This repo, including `.git`, is that zip. Start at
`HANDOFF.md`.
