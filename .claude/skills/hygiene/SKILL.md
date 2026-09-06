---
name: hygiene
description: Run every repo gate (line cap, params validation, generated copies in sync) plus the lint and build of any prototype that changed. Use before claiming any change is done.
---

# hygiene

1. From the repo root: `make hygiene`, then `pre-commit run --all-files`
   (the four shared gates: line cap, markdown naming, dependency
   freshness, no binaries).
2. For each `proto-*` directory touched, run the lint and build lines from
   its `README.md`.
3. Report the exact commands and the last line each printed. A failure
   means the task is not done; fix it or hand the failure to the owner.
