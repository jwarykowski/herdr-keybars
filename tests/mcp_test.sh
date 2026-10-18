#!/usr/bin/env bash
# Runs bin/mcp against a fake claude.
set -euo pipefail

root=$(cd "$(dirname "$0")/.." && pwd)
tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT

cat >"$tmp/claude" <<'SH'
#!/bin/sh
echo "$*" >>"$FAKE/claude.log"
case "$1 $2" in
  "mcp get") [ -f "$FAKE/added" ] ;;
  "mcp add") touch "$FAKE/added" ;;
esac
SH
printf '#!/bin/sh\n' >"$tmp/keybars-pro"
printf '#!/bin/sh\n' >"$tmp/herdr"
chmod +x "$tmp/claude" "$tmp/keybars-pro" "$tmp/herdr"
export FAKE=$tmp HERDR_BIN_PATH=$tmp/herdr HERDR_KEYBARS_COMMAND=$tmp/keybars-pro HERDR_KEYBARS_CLAUDE=$tmp/claude

fail=0
out=$("$root/bin/mcp")
grep -qxF "mcp add --scope user keybars -- $tmp/keybars-pro mcp" "$tmp/claude.log" || { echo "FAIL: not added" >&2; fail=1; }
[[ $out == *"new sessions can light keys"* ]] || { echo "FAIL: said $out" >&2; fail=1; }
out=$("$root/bin/mcp")
[[ $out == *"already has"* ]] || { echo "FAIL: added twice: $out" >&2; fail=1; }
[[ $(grep -c "mcp add" "$tmp/claude.log") == 1 ]] || { echo "FAIL: mcp add ran again" >&2; fail=1; }
out=$(HERDR_KEYBARS_CLAUDE=$tmp/none "$root/bin/mcp")
[[ $out == *"No Claude Code"* ]] || { echo "FAIL: said $out" >&2; fail=1; }

if ((fail)); then
  echo "mcp_test: failed" >&2
  exit 1
fi
echo "mcp_test: ok"
