# herdr-keybars

A herdr plugin (bash) that puts workspaces on the keyboard through keybars
Pro: agent state on number keys, each workspace's pull request, and Focus as
herdr's pomodoro. README.md has the detail; this file is what to keep in
mind while working here.

## Commands

- `make check`: shellcheck over `bin/`, `lib/` and `tests/`, then the tests.
- Scripts run on Linux (Fedora) and macOS: no GNU-only flags, no bash 4+
  features (macOS has bash 3.2).
- Under `set -o pipefail`, `grep -q` on a pipe can fail with SIGPIPE: read
  the output into a variable first.

## How it fits together

- `herdr-plugin.toml`: startup commands (`bin/watch`, `bin/github`) and
  actions. Bump `version` there for a release.
- `lib/herdr.sh`: shared helpers (spawn, halt, claim, token, config). Put
  anything two scripts need there.
- Everything reaches the keyboard through the `keybars-pro` command (keybars
  Pro's CLI), never the keyboard directly; it works on any board keybars Pro
  drives.
- `bin/setup` installs the marketplace packs the plugin relies on.

## Related repos (in ~/development)

- `keybars-pro`: the app and the `keybars-pro` command this drives. A change
  to its CLI or alert events can break this plugin.
- `keybars.nvim`: the Neovim plugin, which drives keybars Pro the same way.
