# Analytics (debug build only, D09)

## Session
One directory per run: `analytics/<utc-timestamp>/` in the user-data dir.
- `meta.json` — build id, engine, params hash, seed, device info.
- `inputs.jsonl` — one line per input change: `{"t":<tick>,"a":"jump","v":1}`.
- `state.jsonl` — one line per `state_log_every` ticks: full snapshot
  (`DOCS-dev-principles.md` §3).
- `events.jsonl` — death, checkpoint, room enter, pause.
- `video.*` — only when recording was explicitly enabled this session.
- `gaze.jsonl` — only when gaze was explicitly enabled; browser + WebGazer.

## Determinism
Replay = seed + params hash + `inputs.jsonl`. Fixed 60 Hz tick (D12). Any
drift between a replay and `state.jsonl` is a bug; the replay tool fails
on it.

## Recording indicator
A red dot in a corner whenever video or gaze is active. Absent from
public builds because the code is absent from public builds.

## Not yet decided
- Gaze pipeline. WebGazer accuracy ≈ 4°; try once, drop if calibration
  eats playtest time.
- Video: engine capture vs OS capture. Prefer re-rendering from replay
  offline; it costs the i3 nothing during play.
