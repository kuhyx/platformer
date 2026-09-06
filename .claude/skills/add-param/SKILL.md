---
name: add-param
description: Add or change a tunable end to end — registry entry, regenerate copies, replace the literal in code. Use whenever a number appears in game code that is not 0, 1 or a unit conversion.
---

# add-param

1. Add the entry to `shared/params/params.json` following
   `spec/DOCS-parameters.md` (value, min, max, step, unit, desc).
2. `make gen-params`.
3. Replace the literal in code with the engine's accessor
   (`Params.get_value`, `param()`, `PARAM(P_*)`, `params.get`).
4. `make hygiene`. Mention the new key in the commit message.
