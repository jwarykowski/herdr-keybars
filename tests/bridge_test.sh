#!/usr/bin/env bash
# Runs bin/bridge and bin/setup against fake herdr and keybars-pro commands.
set -euo pipefail

root=$(cd "$(dirname "$0")/.." && pwd)
tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT

cat >"$tmp/herdr" <<'SH'
#!/bin/sh
case "$1 $2" in
  "plugin list") printf 'jwarykowski.herdr-gh\njwarykowski.herdr-pomodoro\njwarykowski.herdr-keybars\n' ;;
  "plugin config-dir") echo "$FAKE/cfg/$3" ;;
  *) echo "$*" >>"$FAKE/herdr.log" ;;
esac
SH
cat >"$tmp/keybars-pro" <<'SH'
#!/bin/sh
echo "$*" >>"$FAKE/kp.log"
SH
chmod +x "$tmp/herdr" "$tmp/keybars-pro"

fail=0
expect() {
  grep -qxF -- "$1" "$tmp/kp.log" || {
    echo "FAIL: never sent: $1" >&2
    fail=1
  }
}
check() {
  "$@" || {
    echo "FAIL: $*" >&2
    fail=1
  }
}

export FAKE=$tmp HERDR_BIN_PATH=$tmp/herdr HERDR_KEYBARS_COMMAND=$tmp/keybars-pro
export HERDR_KEYBARS_STATE_DIR=$tmp/state HERDR_KEYBARS_CONFIG_DIR=$tmp/config
touch "$tmp/kp.log"
bridge() { env "$@" "$root/bin/bridge"; }

# herdr-gh: events go to Notify with the repo and branch; failing CI marks
# the workspace until it passes or the PR goes
gh=(HERDR_GH_REPO=me/app HERDR_GH_BRANCH=feat/x HERDR_GH_WORKSPACE_ID=w3)
bridge HERDR_GH_EVENT=ci.failed "${gh[@]}"
expect "notify -q -source github -repo me/app -branch feat/x ci.failed"
check test "$(cat "$tmp/state/ci/w3")" = me/app
bridge HERDR_GH_EVENT=ci.passed "${gh[@]}"
check test ! -e "$tmp/state/ci/w3"
bridge HERDR_GH_EVENT=ci.failed "${gh[@]}"
bridge HERDR_GH_EVENT=pull_request.merged "${gh[@]}"
expect "notify -q -source github -repo me/app -branch feat/x pull_request.merged"
check test ! -e "$tmp/state/ci/w3"
bridge HERDR_GH_EVENT=review.changes_requested "${gh[@]}"
expect "notify -q -source github -repo me/app -branch feat/x review.changes_requested"
bridge HERDR_GH_EVENT=ci.failed HERDR_GH_WORKSPACE_ID=../evil
check test ! -e "$tmp/state/evil"

# herdr-pomodoro: the round's length starts keybars Pro's Focus
bridge HERDR_POMODORO_EVENT=focus.started HERDR_POMODORO_ENDS_AT=$(($(date +%s) + 1500))
expect "focus start 25m"
bridge HERDR_POMODORO_EVENT=focus.break
bridge HERDR_POMODORO_EVENT=focus.stopped
expect "focus stop"
bridge HERDR_POMODORO_EVENT=focus.break HERDR_KEYBARS_POMODORO=events
expect "notify -q focus.break"
: >"$tmp/kp.log"
bridge HERDR_POMODORO_EVENT=focus.started HERDR_KEYBARS_POMODORO=off
check test ! -s "$tmp/kp.log"

# setup: the pack, and hooks in both plugins, leaving your own hook alone
mkdir -p "$tmp/cfg/jwarykowski.herdr-gh/hooks"
printf '#!/bin/sh\necho mine\n' >"$tmp/cfg/jwarykowski.herdr-gh/hooks/pull_request.merged"
HERDR_PLUGIN_STATE_DIR=$tmp/kstate HERDR_PLUGIN_CONFIG_DIR=$tmp/kconfig "$root/bin/setup" >"$tmp/setup.out"
for p in github-ci-pack review-nudges merge-confetti; do expect "market install $p"; done
check grep -q "rule packs installed" "$tmp/setup.out"
check grep -q "kept your own hooks: pull_request.merged" "$tmp/setup.out"
check grep -q "echo mine" "$tmp/cfg/jwarykowski.herdr-gh/hooks/pull_request.merged"
for h in ci.running ci.failed review.approved pull_request.closed; do
  check test -x "$tmp/cfg/jwarykowski.herdr-gh/hooks/$h"
done
check test -x "$tmp/cfg/jwarykowski.herdr-pomodoro/hooks/focus.started"

# a hook runs the bridge with herdr-keybars' state, not the calling plugin's
HERDR_KEYBARS_STATE_DIR="" HERDR_KEYBARS_CONFIG_DIR="" HERDR_PLUGIN_STATE_DIR=$tmp/gh-state \
  HERDR_GH_EVENT=ci.failed HERDR_GH_WORKSPACE_ID=w5 HERDR_GH_REPO=me/app \
  "$tmp/cfg/jwarykowski.herdr-gh/hooks/ci.failed"
check test -e "$tmp/kstate/ci/w5"

# setup again is harmless; remove takes out only its own hooks
HERDR_PLUGIN_STATE_DIR=$tmp/kstate HERDR_PLUGIN_CONFIG_DIR=$tmp/kconfig "$root/bin/setup" >/dev/null
HERDR_PLUGIN_STATE_DIR=$tmp/kstate HERDR_PLUGIN_CONFIG_DIR=$tmp/kconfig "$root/bin/setup" remove >/dev/null
check test ! -e "$tmp/cfg/jwarykowski.herdr-gh/hooks/ci.failed"
check test ! -e "$tmp/cfg/jwarykowski.herdr-pomodoro/hooks/focus.started"
check test -e "$tmp/cfg/jwarykowski.herdr-gh/hooks/pull_request.merged"

if ((fail)); then
  echo "bridge_test: failed" >&2
  exit 1
fi
echo "bridge_test: ok"
