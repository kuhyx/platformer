#!/bin/bash
# Native end-to-end check on a private Xvfb (never the live display).
# Usage: ./e2e_native.sh [outdir]   (needs bin/proto-raylib, xvfb-run, xdotool, import)
set -euo pipefail

HERE="$(cd "$(dirname "$0")" && pwd)"
readonly HERE
readonly TRACE="$HERE/../shared/replay/slice_trace.json"
readonly BIN="$HERE/bin/proto-raylib"
readonly OUT="${1:-/tmp/proto-raylib-e2e}"
readonly WINDOW_NAME="proto-raylib"

if [[ "${E2E_INNER:-}" != 1 ]]; then
    # Drop any inherited DISPLAY so xvfb-run can never reuse the live session.
    exec env -u DISPLAY -u WAYLAND_DISPLAY E2E_INNER=1 SDL_AUDIODRIVER=dummy \
        xvfb-run -a -s "-screen 0 1280x720x24" "$0" "$@"
fi

mkdir -p "$OUT/data"
rm -f "$OUT"/*.png "$OUT"/*.log
export XDG_DATA_HOME="$OUT/data"
rm -rf "$XDG_DATA_HOME/proto-raylib"
FAILS=0

check() {
    local what="$1"
    shift
    if "$@"; then echo "ok   $what"; else echo "FAIL $what"; FAILS=$((FAILS + 1)); fi
}

launch() {
    local log="$1"
    shift
    (cd "$OUT" && exec "$BIN" --seed=7 --log-events "$@" >"$log" 2>&1) &
    GAME_PID=$!
}

first_room_entered() { grep -m1 'room_enter' "$1" | sed 's/.*room=//'; }

launch "$OUT/held.log"
until xdotool search --name "$WINDOW_NAME" >/dev/null 2>&1; do sleep 0.2; done
xdotool mousemove 400 300 # no window manager: key focus follows the pointer
sleep 0.5
xdotool keydown d
sleep 1.0
import -window root "$OUT/held_walking.png"
sleep 2.5
xdotool keyup d
import -window root "$OUT/held_after.png"
xdotool keydown F1
sleep 0.2
xdotool keyup F1
sleep 0.5
import -window root "$OUT/overlay.png"
kill "$GAME_PID" 2>/dev/null || true
wait "$GAME_PID" 2>/dev/null || true
check "held D walks the avatar into the pit (death in room 0)" grep -q 'death room=0' "$OUT/held.log"

launch "$OUT/replay.log" --replay="$TRACE" --shot=3 --shot=160 --shot=500 --quit-at=500
wait "$GAME_PID"
check "replay reaches room 2 (room id 1)" grep -q 'room_enter room=1' "$OUT/replay.log"

launch "$OUT/resume.log" --quit-at=2
wait "$GAME_PID"
check "relaunch resumes in room id 1" test "$(first_room_entered "$OUT/resume.log")" = 1

printf '\001garbage{{{' >"$XDG_DATA_HOME/proto-raylib/save.json"
launch "$OUT/corrupt.log" --quit-at=2
wait "$GAME_PID"
check "corrupt save starts in room id 0" test "$(first_room_entered "$OUT/corrupt.log")" = 0

launch "$OUT/goal.log" --replay="$TRACE" --shot=949 --quit-at=960
wait "$GAME_PID"
check "replay reaches the goal and loops to room id 0" grep -q 'goal room=1' "$OUT/goal.log"

echo "e2e_native: $FAILS failure(s), screenshots in $OUT"
exit $((FAILS > 0))
