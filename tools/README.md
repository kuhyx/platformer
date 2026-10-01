# tools

| Tool | Purpose | Gate |
|---|---|---|
| `validate_params.py` | registry entries well-formed (spec/DOCS-parameters.md) | CI hygiene |
| `gen_params.py` | regenerate per-prototype param copies | CI checks `git diff` |
| `size_budget.py <dir> <bytes>` | gzip size of a web build vs budget | CI per prototype |
| `measure_load.mjs <url> [runs]` | cached/uncached time to `__gameReady`; throws if it never fires | manual M3/M4; boot gate in `deploy-itch.yml` (runs=1) |

`measure_load.mjs` needs Playwright, exact-pinned in `tools/package.json`:
`cd tools && npm ci && npx playwright install chromium`.
All Python tools are stdlib-only, Python 3.10+.

The 250-line cap (D08) is not a tool here: it is the shared gate
`scripts/check_file_length.sh` (a shim over `~/src/utils`), run by pre-commit
and by `.github/workflows/file-length.yml`.
