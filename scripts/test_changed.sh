#!/bin/bash

# ============================================================================
# Run only the tests related to files changed vs HEAD (staged, unstaged and
# untracked). Quiet: failures plus a one-line summary. The suites are cheap
# (params validation + headless Godot sim test, ~4 s), so any non-doc change
# runs both; doc-only changes run nothing. `--all` forces both.
# Only the Godot sim has unit tests; other prototypes are lint/build only
# (see their README and the Makefile / CI).
# ============================================================================

set -euo pipefail

cd "$(git rev-parse --show-toplevel)"
CHANGED=()
while IFS= read -r f; do
    [[ -n "$f" && -e "$f" ]] && CHANGED+=("$f")
done < <({ git diff --name-only HEAD 2>/dev/null || true; git ls-files --others --exclude-standard; } | sort -u)

relevant=0
[[ "${1:-}" == "--all" ]] && relevant=1
for f in "${CHANGED[@]}"; do
    case "$f" in
        *.md | docs/* | spec/* | .claude/*) ;;
        *) relevant=1 ;;
    esac
done
if [[ $relevant -eq 0 ]]; then echo "no code changes vs HEAD: nothing to test"; exit 0; fi

rc=0
run() {
    local name="$1" out
    shift
    out="$("$@" 2>&1)" || { rc=1; echo "FAIL $name"; tail -30 <<<"$out"; }
}
godot_sim() {
    local out
    out="$(godot --headless --path proto-godot -s tests/test_sim.gd 2>&1)"
    grep -q '^test_sim: 0 failure(s)' <<<"$out" && return 0
    grep -v '^ok ' <<<"$out" | tail -30
    return 1
}
run validate_params python3 tools/validate_params.py
# --import registers class_names (.godot/ is gitignored); sim test is headless.
run godot_import godot --headless --path proto-godot --import
godot_sim || { rc=1; echo "FAIL godot_sim"; }
echo "ran 2 suite(s): $([[ $rc -eq 0 ]] && echo pass || echo FAIL)"
exit "$rc"
