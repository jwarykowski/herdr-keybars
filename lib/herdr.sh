# shellcheck shell=bash
# herdr-keybars' shared shell, sourced by each script in bin/: herdr's and
# keybars Pro's commands, the plugin's folders and settings, starting and
# stopping a background process, and herdr's sidebar tokens.

# plugin commands inherit herdr's environment; add where keybars Pro's install
# button, Homebrew and gh put commands
PATH="$PATH:$HOME/.local/bin:/usr/local/bin:/opt/homebrew/bin"

herdr="${HERDR_BIN_PATH:-herdr}"
kp="${HERDR_KEYBARS_COMMAND:-keybars-pro}"
state_dir="${HERDR_PLUGIN_STATE_DIR:-${XDG_STATE_HOME:-$HOME/.local/state}/herdr-keybars}"
config_dir="${HERDR_PLUGIN_CONFIG_DIR:-${XDG_CONFIG_HOME:-$HOME/.config}/herdr-keybars}"

# load_config reads config.env over the defaults the script has set
load_config() {
  # shellcheck source=/dev/null
  [[ -f "$config_dir/config.env" ]] && source "$config_dir/config.env"
  return 0
}

notify() {
  "$herdr" notification show "$1" >/dev/null 2>&1 || true
}

have_keybars() {
  command -v "$kp" >/dev/null 2>&1
}

# A background process, by name, keeps its pid file and log in the state
# folder; it's "$0 run", and exits when herdr has gone.

running() {
  [[ -f "$state_dir/$1.pid" ]] && kill -0 "$(cat "$state_dir/$1.pid")" 2>/dev/null
}

# spawn starts name in the background, once. herdr runs actions
# asynchronously, so two starts can overlap: mkdir is an atomic lock, and the
# pid file is written here rather than by the child later.
spawn() {
  mkdir -p "$state_dir"
  mkdir "$state_dir/$1.lock" 2>/dev/null || return 0
  if ! running "$1"; then
    nohup "$0" run >"$state_dir/$1.log" 2>&1 &
    echo $! >"$state_dir/$1.pid"
    disown
  fi
  rmdir "$state_dir/$1.lock"
}

# claim records this process as name when it was run directly, not spawned
claim() {
  mkdir -p "$state_dir"
  running "$1" || echo $$ >"$state_dir/$1.pid"
}

# halt stops name and waits for it to clear its pid file, so a start
# straight after can run
halt() {
  running "$1" || return 0
  kill "$(cat "$state_dir/$1.pid")"
  local _
  for _ in 1 2 3 4 5 6 7 8 9 10; do
    running "$1" || break
    sleep 0.2
  done
}

# token reports a sidebar token on one workspace for ttl milliseconds, so it
# goes on its own if the reporter stops; an empty value clears it
token() {
  local id=$1 name=$2 value=$3 ttl=$4
  if [[ -n $value ]]; then
    "$herdr" workspace report-metadata "$id" --source herdr-keybars --ttl-ms "$ttl" \
      --token "$name=$value" >/dev/null 2>&1
  else
    "$herdr" workspace report-metadata "$id" --source herdr-keybars --clear-token "$name" >/dev/null 2>&1
  fi
}

# token_all reports a token on every workspace
token_all() {
  local id
  for id in $("$herdr" workspace list 2>/dev/null | jq -r '.result.workspaces[].workspace_id // empty'); do
    token "$id" "$@"
  done
}
