# tools

| Tool | Purpose | Gate |
|---|---|---|
| `check_line_cap.py` | 250-line cap on every file (D08) | CI hygiene |
| `validate_params.py` | registry entries well-formed (spec/parameters.md) | CI hygiene |
| `gen_params.py` | regenerate per-prototype param copies | CI checks `git diff` |
| `size_budget.py <dir> <bytes>` | gzip size of a web build vs budget | CI per prototype |
| `measure_load.mjs <url> [runs]` | cached/uncached time to `__gameReady` | manual, M3/M4 |

`measure_load.mjs` needs Playwright: `npm i -D playwright && npx playwright
install chromium` in the repo root (not committed; install locally).
All Python tools are stdlib-only, Python 3.10+.
