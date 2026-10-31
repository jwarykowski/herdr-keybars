# herdr-keybars

A [herdr](https://herdr.dev) plugin that puts your workspaces on the keyboard
through [keybars Pro](https://keybars.app/pro/): which agent needs you, how
each branch's pull request is doing, and the Focus timer, without looking at
the screen. It brings together what were herdr-zsa-lights, herdr-gh and
herdr-pomodoro.

- **Number key N** is workspace N, the same N as herdr's `ctrl+alt+N`: it
  breathes amber while that workspace's agent is blocked on you, and holds
  green when it's done.
- **The top-right key** breathes while any agent is blocked; bind it to the
  `next-agent` action and one press takes you there.
- **Your own rules** get `agent.waiting` and `agent.done` too, with the
  workspace as the repository, so keybars Pro's Alerts page can do more.
- **Pull requests**: `$gh` in the sidebar shows each workspace's PR in a few
  characters (`#412│×│!`), from your own `gh` login. Its changes reach keybars
  Pro as GitHub's events, so the marketplace's GitHub packs play them: the top
  row chases while CI runs, Escape holds red until it passes, reviews light
  the top-right key, and a merge sparkles. Failing CI also holds the
  workspace's number key red when no agent state is showing.
- **Focus**: keybars Pro's Focus timer is herdr's pomodoro. Start and stop it
  with actions, see it as `$focus` in the sidebar (`🎯12m`, `☕3m`), and get a
  notification when a break starts and ends.

It drives the keyboard with keybars Pro's
[command line](https://keybars.app/pro/cli/), so it works on any keyboard
keybars Pro does (ZSA boards over USB, others through OpenRGB), lights play
over the music rather than blanking the board, and only changes are sent.
It replaces herdr-zsa-lights, which needed Keymapp and kontroll.

## Requirements

- herdr 0.9.3+
- keybars Pro running, with its command installed: App settings, Command
  line, **Install the command-line tool** (`keybars-pro` on your PATH), in a
  build with `keybars-pro alert -source`.
- `jq`, `bash`
- for pull requests: [`gh`](https://cli.github.com), logged in (`gh auth login`), and `git`

## Install

```sh
herdr plugin install jwarykowski/herdr-keybars
```

The watcher and the pull request reporter start with each herdr session and
exit when herdr stops, clearing what they showed. Then run the **setup**
action once (and again after updating): it installs the marketplace's
`github-ci-pack`, `review-nudges` and `merge-confetti` in keybars Pro.

Add `$gh` and `$focus` to herdr's sidebar:

```toml
[ui.sidebar.spaces]
rows = [["state_icon", "workspace", "$focus"], ["branch", "$gh", "git_status"]]
```

Coming from herdr-gh or herdr-pomodoro: uninstall them, as this does both.

## Actions

| action | does |
|---|---|
| `jwarykowski.herdr-keybars.next-agent` | focus the next blocked agent, else the next done one; repeat to cycle |
| `jwarykowski.herdr-keybars.setup` | install the GitHub rule packs in keybars Pro |
| `jwarykowski.herdr-keybars.mcp` | give Claude Code keybars Pro's tools (`keybars-pro mcp`), so an agent can light keys itself; other agents take the same command in their MCP settings |
| `jwarykowski.herdr-keybars.focus` | keybars Pro's Focus timer start / stop |
| `jwarykowski.herdr-keybars.focus-start`, `.focus-stop` | start a Focus session, or stop it |
| `jwarykowski.herdr-keybars.github-refresh` | check pull requests now, rather than within the minute |
| `jwarykowski.herdr-keybars.toggle` | agent lights off / on |
| `jwarykowski.herdr-keybars.keyboard` | keybars Pro's lights off / on (its On switch) |
| `jwarykowski.herdr-keybars.restart` | restart the watcher and the reporter, e.g. after a config change |

Bind them in herdr's `config.toml`, then point keyboard keys at those chords
in Oryx (e.g. the top-right key sends `ctrl+alt+a`):

```toml
[[keys.command]]
key = "ctrl+alt+a"
type = "plugin_action"
command = "jwarykowski.herdr-keybars.next-agent"
description = "focus the agent that needs you"
```

## Effects

The blocked and done keys can use any of keybars Pro's effects; set them in
`config.env` (`HERDR_KEYBARS_BLOCKED_EFFECT`, `HERDR_KEYBARS_DONE_EFFECT`):

| effect | plays | |
|---|---|---|
| `flash` | 0.9 s | on and off three times |
| `pulse` | 3 s | fades up and down three times |
| `wave` | 1.5 s | sweeps left to right |
| `fade` | 3 s | lights up, then fades away |
| `sparkle` | 3 s | twinkles at random |
| `ripple` | 1.5 s | rings spread over the board from the key |
| `hold` | until it changes | stays lit |
| `breathe` | until it changes | glows up and down slowly, never dark |
| `chase` | until it changes | a light runs along the keys |

The ones that play once suit a moment, such as `ripple` when an agent
finishes; the rest suit a state that lasts, such as `breathe` while one waits.

## Pressing the key

An alert rule in a keybars Pro with action keys can do Go to the agent when
it's pressed: on a keyboard with keybars firmware the lit key does it, and
on any keyboard the rule's key in keybars Pro's window, its tray or
`keybars-pro press` does. The plugin listens for those presses and focuses
the agent in the workspace the event names (bin/watch sends
`agent.waiting` and `agent.done` with the workspace's label as `-repo`),
else the agent that needs you, as `next-agent` picks.

## Pull requests

`$gh` shows each workspace's PR, found from the branch checked out in its
first pane:

| part | meaning |
|---|---|
| `#412` / `d412` | PR number (`d` = draft) |
| `√` `×` `•` | CI passed, failed, running |
| `+` `!` | review approved, changes requested (blank while waiting) |
| `↗` | merged: time to remove the worktree |
| `†` | closed without merging |

Each change goes to keybars Pro as GitHub's own event, about the PR's
repository and branch: `ci.running`, `ci.passed`, `ci.failed`,
`review.approved`, `review.changes_requested`, `pull_request.merged` and
`pull_request.closed`, as `keybars-pro alert -source github`. So any GitHub
rule plays it, the same as if it came through GitHub's webhook; change the
keys on keybars Pro's Alerts page as with any rule. The reporter checks once a
minute, so a change shows up to a minute later, and a PR it hasn't seen before
is only recorded, so a restart sends nothing.

## Neovim

[keybars.nvim](https://code.warykowski.io/jwarykowski/keybars.nvim) is the
editor's half: `:KeybarsRun make test` shows a build on the keyboard and opens
failures in the quickfix list, errors can hold a key, and a statusline
component shows Focus and typing speed.

## Configuration

Optional. Put overrides in `config.env` inside the plugin config directory
(`herdr plugin config-dir jwarykowski.herdr-keybars`), then run the restart
action. See [`config.env.example`](config.env.example): colours, effects, the
jump key, which keys are workspaces 1–9 (by position, as `keybars-pro light`
names them; `keybars-pro map` shows your board), whether to send events, and
the pull request reporter's interval and symbols.

On a Moonlander, workspaces 1–9 are the number row's 1–5 and 6–9
(`r1c2`–`r1c6`, `r1c9`–`r1c12`); on a Voyager and most 12-column boards,
`r1c2`–`r1c10`.

## Development

The scripts in `bin/` share `lib/herdr.sh`: the commands and folders, a
background process's start and stop, and sidebar tokens. `make check` runs
shellcheck and the tests in `tests/`, which share `tests/lib.sh` and drive the
scripts with fake `herdr`, `gh` and `keybars-pro` commands.

## Licence

MIT
