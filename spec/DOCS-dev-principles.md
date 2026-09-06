# Development principles

## 1. Everything tunable, live (D14)
- One registry: `shared/params/params.json`. Contract: `DOCS-parameters.md`.
- Debug build reads the registry at boot and on file change; the debug
  overlay auto-generates one slider per entry.
- A number in code that is not 0, 1 or a unit conversion is a bug.

## 2. Hot reload
Target per engine; noted in each prototype README; scored as M8.

## 3. Jump anywhere (debug)
Snapshot = `{ room_id, checkpoint_id, player_state, rng_seed,
params_hash }`. The debug build can dump and restore a snapshot from a
file and warp to any room. The same structure feeds saves and replays.

## 4. Hygiene gates (D07, D08)
- 250 lines per file, everything: `scripts/check_file_length.sh --all`
  (shared gate, also in pre-commit and CI)
- Strictest lint per language (configs live in each prototype).
- Params validate: `python3 tools/validate_params.py`
- Generated copies in sync: `make gen-params && git diff --exit-code`
- Markdown namespaces (README / CLAUDE* / DOCS* / TODO*):
  `scripts/check_md_naming.sh --all`
- Every dependency exact-pinned at newest stable, lockfiles committed:
  `scripts/check_dependency_freshness.sh --all --strict`
- No binaries in the tree: `scripts/check_no_binaries.sh`
- Coverage: suspended during the bake-off (D07).

## 5. LLM-friendly
- `CLAUDE.md` is the entry point; `AGENTS.md` points to it.
- Skills in `.claude/skills/`. One skill = one repeatable workflow.
- Each prototype README lists: run, build web, lint, where `__gameReady`
  is set, and the agent-play route (MCP server or headless input
  injection).
- Agents record owner corrections under "Lessons" in `CLAUDE.md`.
