#!/usr/bin/env bash
# Runs bin/github once at a time against fake herdr, gh and keybars-pro, with
# a git repo as the workspace, and checks the sidebar token and what reaches
# keybars Pro as the pull request changes.
set -euo pipefail
# shellcheck source=tests/lib.sh
source "$(dirname "$0")/lib.sh"

repo=$tmp/app
git init -q "$repo"
fake herdr <<SH
case "\$1 \$2" in
  "api snapshot") echo '{"result":{"snapshot":{"workspaces":[{"workspace_id":"w1"}],"panes":[{"workspace_id":"w1","cwd":"$repo"}]}}}' ;;
  *) echo "\$*" >>"\$FAKE/herdr.log" ;;
esac
SH
fake gh <<'SH'
case "$1 $2" in
  "auth status") exit 0 ;;
  "pr view") cat "$FAKE/pr.json" ;;
esac
SH
fake keybars-pro <<'SH'
echo "$*" >>"$FAKE/kp.log"
SH
export PATH="$tmp:$PATH"

# pr state: OPEN or MERGED; check conclusion: SUCCESS, FAILURE or "" (running)
pr() {
  local check
  case $2 in
    running) check='{"status":"IN_PROGRESS"}' ;;
    *) check="{\"status\":\"COMPLETED\",\"conclusion\":\"$2\"}" ;;
  esac
  cat >"$tmp/pr.json" <<JSON
{"number":412,"url":"https://github.com/me/app/pull/412","title":"Fix it","headRefName":"fix/it",
 "state":"$1","isDraft":false,"reviewDecision":"${3:-}","statusCheckRollup":[$check]}
JSON
}
once() { "$root/bin/github" once; }

pr OPEN running
once
check test ! -s "$tmp/kp.log" # the first sight is only recorded
check grep -qF "workspace report-metadata w1 --source herdr-keybars --ttl-ms 180000 --token gh=#412│•" "$tmp/herdr.log"

pr OPEN FAILURE CHANGES_REQUESTED
once
expect "alert -q -source github -repo me/app -branch fix/it ci.failed"
expect "alert -q -source github -repo me/app -branch fix/it review.changes_requested"
check test "$(cat "$tmp/state/ci/w1")" = me/app
check grep -qF "token gh=#412│×│!" "$tmp/herdr.log"

: >"$tmp/kp.log"
once
check test ! -s "$tmp/kp.log" # nothing changed, nothing sent

pr OPEN running CHANGES_REQUESTED
once
expect "alert -q -source github -repo me/app -branch fix/it ci.running"
pr OPEN SUCCESS APPROVED
once
expect "alert -q -source github -repo me/app -branch fix/it ci.passed"
expect "alert -q -source github -repo me/app -branch fix/it review.approved"
check test ! -e "$tmp/state/ci/w1"

pr OPEN FAILURE APPROVED
once
check test -e "$tmp/state/ci/w1"
pr MERGED FAILURE APPROVED
once
expect "alert -q -source github -repo me/app -branch fix/it pull_request.merged"
check test ! -e "$tmp/state/ci/w1"
check grep -qF "token gh=#412│↗" "$tmp/herdr.log"

finish github_test
