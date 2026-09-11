# tools

| Tool | Purpose | Gate |
|---|---|---|
| `validate_params.py` | registry entries well-formed (spec/DOCS-parameters.md) | CI hygiene |
| `gen_params.py` | regenerate per-prototype param copies | CI checks `git diff` |
| `size_budget.py <dir> <bytes>` | gzip size of a web build vs budget | CI per prototype |
| `measure_load.mjs <url> [runs]` | cached/uncached time to `__gameReady` | manual, M3/M4 |

`measure_load.mjs` needs Playwright: `npm i -D playwright && npx playwright
install chromium` in the repo root (not committed; install locally).
All Python tools are stdlib-only, Python 3.10+.

The 250-line cap (D08) is not a tool here: it is the shared gate
`scripts/check_file_length.sh` (a shim over `~/src/utils`), run by pre-commit
and by `.github/workflows/file-length.yml`.
