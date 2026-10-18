#!/usr/bin/env bash
# Runs bin/watch against fake herdr and keybars-pro commands and checks what
# it sends as workspaces change.
set -euo pipefail

root=$(cd "$(dirname "$0")/.." && pwd)
tmp=$(mktemp -d)
trap 'kill "${pid:-}" 2>/dev/null || true; rm -rf "$tmp"' EXIT

cat >"$tmp/herdr" <<'SH'
#!/bin/sh
case "$1 $2" in
  "workspace list") cat "$FAKE/workspaces.json" ;;
  *) echo "$*" >>"$FAKE/herdr.log" ;;
esac
SH
cat >"$tmp/keybars-pro" <<'SH'
#!/bin/sh
case "$1 $2" in
  "status -json") echo '{"keyboard":"Moonlander Mark I"}' ;;
  "focus status") cat "$FAKE/focus.json" 2>/dev/null || echo '{"phase":""}' ;;
  *) echo "$*" >>"$FAKE/kp.log" ;;
esac
SH
chmod +x "$tmp/herdr" "$tmp/keybars-pro"

workspaces() {
  # number:status pairs
  local out='{"result":{"workspaces":[' sep=""
  for p in "$@"; do
    out+="$sep{\"number\":${p%%:*},\"workspace_id\":\"w${p%%:*}\",\"label\":\"ws ${p%%:*}\",\"agent_status\":\"${p#*:}\"}"
    sep=,
  done
  echo "$out]}}" >"$tmp/workspaces.json"
}

fail=0
expect() {
  local want=$1
  if ! grep -qxF -- "$want" "$tmp/kp.log"; then
    echo "FAIL: never sent: $want" >&2
    fail=1
  fi
}
reject() {
  if grep -qxF -- "$1" "$tmp/kp.log"; then
    echo "FAIL: sent: $1" >&2
    fail=1
  fi
}
settle() { sleep 0.5; }

export FAKE=$tmp HERDR_BIN_PATH=$tmp/herdr HERDR_KEYBARS_COMMAND=$tmp/keybars-pro
export HERDR_PLUGIN_STATE_DIR=$tmp/state HERDR_PLUGIN_CONFIG_DIR=$tmp/config HERDR_KEYBARS_INTERVAL=0.1
touch "$tmp/kp.log"

workspaces 1:working 2:working
"$root/bin/watch" run &
pid=$!
settle
[[ ! -s $tmp/kp.log ]] || { echo "FAIL: sent something with nothing to show" >&2; fail=1; }

workspaces 1:blocked 2:working
settle
expect "light r1c2 amber -effect breathe"
expect "light top-right amber -effect breathe"
expect "notify -q -repo ws-1 agent waiting"

: >"$tmp/kp.log"
settle
[[ ! -s $tmp/kp.log ]] || { echo "FAIL: resent an unchanged frame" >&2; fail=1; }

workspaces 1:done 2:working 7:blocked
settle
expect "light r1c2 green -effect hold"
expect "light r1c10 amber -effect breathe"
expect "notify -q -repo ws-1 agent done"
reject "light top-right amber -effect breathe" # still blocked: unchanged

: >"$tmp/kp.log"
workspaces 1:working 2:working
settle
expect "clear r1c2"
expect "clear r1c10"
expect "clear top-right"

# failing CI holds the workspace's key red, unless its agent is showing
: >"$tmp/kp.log"
mkdir -p "$tmp/state/ci"
echo me/repo >"$tmp/state/ci/w2"
settle
expect "light r1c3 red -effect hold"
workspaces 1:working 2:blocked
settle
expect "light r1c3 amber -effect breathe"
: >"$tmp/kp.log"
workspaces 1:working 2:working
settle
expect "light r1c3 red -effect hold"
rm "$tmp/state/ci/w2"
settle
expect "clear r1c3"

# the Focus timer reaches the sidebar as $focus, and goes when it stops
echo '{"phase":"work","remaining":700}' >"$tmp/focus.json"
settle
grep -qF -- "workspace report-metadata w1 --source herdr-keybars --ttl-ms 90000 --token focus=🎯12m" "$tmp/herdr.log" ||
  { echo "FAIL: no focus token" >&2; fail=1; }
echo '{"phase":""}' >"$tmp/focus.json"
settle
grep -qF -- "workspace report-metadata w1 --source herdr-keybars --clear-token focus" "$tmp/herdr.log" ||
  { echo "FAIL: focus token not cleared" >&2; fail=1; }

kill "$pid"
wait "$pid" 2>/dev/null || true
if ((fail)); then
  echo "watch_test: failed" >&2
  exit 1
fi
echo "watch_test: ok"
