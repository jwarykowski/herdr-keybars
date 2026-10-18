#!/usr/bin/env bash
# Runs bin/mcp against a fake claude.
set -euo pipefail
# shellcheck source=tests/lib.sh
source "$(dirname "$0")/lib.sh"

fake claude <<'SH'
echo "$*" >>"$FAKE/claude.log"
case "$1 $2" in
  "mcp get") [ -f "$FAKE/added" ] ;;
  "mcp add") touch "$FAKE/added" ;;
esac
SH
fake keybars-pro </dev/null
fake herdr </dev/null
export HERDR_KEYBARS_CLAUDE=$tmp/claude

out=$("$root/bin/mcp")
check grep -qxF "mcp add --scope user keybars -- $tmp/keybars-pro mcp" "$tmp/claude.log"
check grep -q "new sessions can light keys" <<<"$out"
out=$("$root/bin/mcp")
check grep -q "already has" <<<"$out"
check test "$(grep -c "mcp add" "$tmp/claude.log")" = 1
out=$(HERDR_KEYBARS_CLAUDE=$tmp/none "$root/bin/mcp")
check grep -q "No Claude Code" <<<"$out"

finish mcp_test
