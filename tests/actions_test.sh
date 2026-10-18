#!/usr/bin/env bash
# Runs the setup and focus actions against fake herdr and keybars-pro.
set -euo pipefail
# shellcheck source=tests/lib.sh
source "$(dirname "$0")/lib.sh"

fake herdr <<'SH'
echo "$*" >>"$FAKE/herdr.log"
SH
fake keybars-pro <<'SH'
case "$1 $2" in
  "focus status") cat "$FAKE/focus.json" ;;
  *) echo "$*" >>"$FAKE/kp.log" ;;
esac
SH

out=$("$root/bin/setup")
for p in github-ci-pack review-nudges merge-confetti; do expect "market install $p"; done
check grep -q "GitHub rule packs installed" <<<"$out"

echo '{"phase":""}' >"$tmp/focus.json"
"$root/bin/focus"
expect "focus start"
echo '{"phase":"work","remaining":600}' >"$tmp/focus.json"
"$root/bin/focus"
expect "focus stop"
"$root/bin/focus" start 50m
expect "focus start 50m"
check grep -qF "notification show Focus started" "$tmp/herdr.log"

finish actions_test
