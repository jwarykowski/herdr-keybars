# shellcheck shell=bash
# The tests' shared parts: a scratch folder with fake commands in it, and
# checks that report every failure, then fail the test at the end.
#
#   source tests/lib.sh
#   fake herdr <<'SH' ... SH      a fake command, logging to $tmp/<name>.log
#   expect "light esc red"        it was sent to keybars-pro
#   check test -e "$tmp/file"     any command that should succeed
#   finish name                   prints ok, or fails

# the repo, for the tests that source this
# shellcheck disable=SC2034
root=$(cd "$(dirname "$0")/.." && pwd)
tmp=$(mktemp -d)
# pid is a background process a test started, stopped at the end
# shellcheck disable=SC2154
trap 'kill "${pid:-}" 2>/dev/null || true; rm -rf "$tmp"' EXIT
fail=0

export FAKE=$tmp HERDR_BIN_PATH=$tmp/herdr HERDR_KEYBARS_COMMAND=$tmp/keybars-pro
export HERDR_PLUGIN_STATE_DIR=$tmp/state HERDR_PLUGIN_CONFIG_DIR=$tmp/config
touch "$tmp/kp.log" "$tmp/herdr.log"

# fake writes a command from standard input into the scratch folder
fake() {
  {
    echo '#!/bin/sh'
    cat
  } >"$tmp/$1"
  chmod +x "$tmp/$1"
}

# expect and reject check what reached keybars-pro, line by line
expect() {
  grep -qxF -- "$1" "$tmp/kp.log" || {
    echo "FAIL: never sent: $1" >&2
    fail=1
  }
}
reject() {
  if grep -qxF -- "$1" "$tmp/kp.log"; then
    echo "FAIL: sent: $1" >&2
    fail=1
  fi
}

check() {
  "$@" || {
    echo "FAIL: $*" >&2
    fail=1
  }
}

finish() {
  if ((fail)); then
    echo "$1: failed" >&2
    exit 1
  fi
  echo "$1: ok"
}
