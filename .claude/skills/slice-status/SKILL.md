---
name: slice-status
description: Fill or update one prototype's row in the scorecard (spec/comparison-protocol.md) from measured values, and apply the kill criteria. Use after any measurement session.
---

# slice-status

1. Collect M1–M11 for the prototype as defined in
   `spec/comparison-protocol.md`. Measured values only; leave a cell blank
   rather than estimating.
2. Update the scorecard row. Record the commands used for M3–M5 in the
   commit message.
3. Check every kill criterion. If one trips, say so plainly and propose
   archiving the prototype; do not soften it.
