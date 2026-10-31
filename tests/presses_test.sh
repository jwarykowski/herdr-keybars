#!/usr/bin/env bash
# Runs bin/presses against fake herdr and keybars-pro: a Go to the agent
# press focuses the agent of the workspace it names, else the one waiting.
set -euo pipefail
# shellcheck source=tests/lib.sh
source "$(dirname "$0")/lib.sh"

# herdr answers three workspace lists, then is gone, so run returns
fake herdr <<'SH'
case "$1 $2" in
  "workspace list")
    n=$(($(cat "$FAKE/lists" 2>/dev/null || echo 0) + 1))
    echo "$n" >"$FAKE/lists"
    [ "$n" -le 3 ] || exit 1
    echo '{"result":{"workspaces":[{"workspace_id":"w1","number":1,"label":"web app"},{"workspace_id":"w2","number":2,"label":"api"}]}}'
    ;;
  "agent list")
    echo '{"result":{"agents":[{"pane_id":"w2:p1","workspace_id":"w2","agent_status":"working","focused":false},{"pane_id":"w1:p3","workspace_id":"w1","agent_status":"blocked","focused":false}]}}'
    ;;
  *) echo "$*" >>"$FAKE/herdr.log" ;;
esac
SH
fake keybars-pro <<'SH'
case "$1" in
  watch)
    echo '{"event":"pressed","data":{"do":"open","event":{"repo":"api"}}}'
    echo '{"event":"pressed","data":{"do":"agent","event":{"source":"cli","name":"agent.waiting","repo":"api"}}}'
    echo '{"event":"pressed","data":{"do":"agent","event":{"source":"cli","name":"agent.waiting","repo":"gone"}}}'
    ;;
  *) echo "$*" >>"$FAKE/kp.log" ;;
esac
SH

"$root/bin/presses" run
check grep -qxF "agent focus w2:p1" "$tmp/herdr.log"
# no such workspace: the agent waiting on you
check grep -qxF "agent focus w1:p3" "$tmp/herdr.log"
lines=$(wc -l <"$tmp/herdr.log")
check test "$lines" -eq 2
check test ! -e "$tmp/state/presses.pid"

finish presses_test
