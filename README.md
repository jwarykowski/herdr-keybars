# herdr-keybars

A [herdr](https://herdr.dev) plugin that puts your agents on the keyboard
through [keybars Pro](https://keybars.app/pro/), so you see which one needs
you without looking at the screen.

- **Number key N** is workspace N, the same N as herdr's `ctrl+alt+N`: it
  breathes amber while that workspace's agent is blocked on you, and holds
  green when it's done.
- **The top-right key** breathes while any agent is blocked; bind it to the
  `next-agent` action and one press takes you there.
- **Your own rules** get `agent.waiting` and `agent.done` too, with the
  workspace as the repository, so keybars Pro's Notify page can do more.
- **With [herdr-gh](https://github.com/jwarykowski/herdr-gh)**, failing CI
  holds the workspace's number key red (when no agent state is showing), and
  its events reach keybars Pro as GitHub's, so the marketplace's GitHub packs
  play them: the top row chases while CI runs, Escape holds red until it
  passes, reviews light the top-right key, and a merge sparkles.
- **With herdr-pomodoro**, a round starts and stops keybars Pro's Focus timer,
  so there's one timer. `$focus` shows it in herdr's sidebar either way.

It drives the keyboard with keybars Pro's
[command line](https://keybars.app/pro/cli/), so it works on any keyboard
keybars Pro does (ZSA boards over USB, others through OpenRGB), lights play
over the music rather than blanking the board, and only changes are sent.
It replaces herdr-zsa-lights, which needed Keymapp and kontroll.

## Requirements

- herdr 0.9.3+
- keybars Pro running, with its command installed: App settings, Command
  line, **Install the command-line tool** (`keybars-pro` on your PATH). The
  bridges need a build with `keybars-pro notify -source`.
- `jq`, `bash`

## Install

```sh
herdr plugin install jwarykowski/herdr-keybars
```

The watcher starts with each herdr session and exits when herdr stops,
clearing its lights. Then run the **setup** action once (and again after
updating). It installs the marketplace's `github-ci-pack`, `review-nudges`
and `merge-confetti` in keybars Pro and bridges herdr-gh and herdr-pomodoro if they're installed. The bridge is a
hook in each of their `hooks/` folders, and any hook you already have there
is left alone.

Add `$focus` to herdr's sidebar to see the Focus timer (`🎯12m`, `☕3m`):

```toml
[ui.sidebar.spaces]
rows = [["state_icon", "workspace", "$focus"], ["branch", "git_status"]]
```

## Actions

| action | does |
|---|---|
| `jwarykowski.herdr-keybars.next-agent` | focus the next blocked agent, else the next done one; repeat to cycle |
| `jwarykowski.herdr-keybars.setup` | install the GitHub rule packs, and bridge herdr-gh and herdr-pomodoro |
| `jwarykowski.herdr-keybars.mcp` | give Claude Code keybars Pro's tools (`keybars-pro mcp`), so an agent can light keys itself; other agents take the same command in their MCP settings |
| `jwarykowski.herdr-keybars.focus` | keybars Pro's Focus timer start / stop |
| `jwarykowski.herdr-keybars.toggle` | agent lights off / on |
| `jwarykowski.herdr-keybars.keyboard` | keybars Pro's lights off / on (its On switch) |
| `jwarykowski.herdr-keybars.remove-bridges` | take the bridge hooks out of herdr-gh and herdr-pomodoro |
| `jwarykowski.herdr-keybars.restart` | restart the watcher, e.g. after a config change |

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

## The bridges

| from | event | becomes |
|---|---|---|
| herdr-gh | `ci.running`, `ci.passed`, `ci.failed`, `review.approved`, `review.changes_requested`, `pull_request.merged`, `pull_request.closed` | the same event, as GitHub's: `keybars-pro notify -source github -repo owner/name -branch b ci.failed`; failing CI also marks the workspace for its number key |
| herdr-pomodoro | `focus.started`, `focus.stopped` | `keybars-pro focus start 25m` (the round's length), `focus stop` |

Both plugins name their events as keybars Pro does, so nothing is renamed on
the way. Rules decide the keys, so change them on keybars Pro's Notify page as
with any rule; any GitHub rule plays herdr-gh's events, whether they came from
herdr-gh or GitHub's webhook. `HERDR_KEYBARS_POMODORO=events` sends herdr-pomodoro's
`focus.*` events to Notify instead, for rules of your own.

Hooks from other plugins can still light the board themselves with
[`keybars-pro light`](https://keybars.app/pro/cli/#light), with any effect: a
merged PR in [herdr-gh](https://github.com/jwarykowski/herdr-gh)'s
`hooks/pull_request.merged`, or a finished round in herdr-pomodoro's
`hooks/focus.break`:

```sh
#!/bin/sh
keybars-pro light all purple -effect ripple
```

## Neovim

[herdr.nvim](https://code.warykowski.io/jwarykowski/herdr.nvim) with
`keybars = true` is the editor's half: `:KeybarsRun make test` shows a build on
the keyboard and opens failures in the quickfix list, errors can hold a key,
and a statusline component shows Focus and typing speed.

## Configuration

Optional. Put overrides in `config.env` inside the plugin config directory
(`herdr plugin config-dir jwarykowski.herdr-keybars`), then run the restart
action. See [`config.env.example`](config.env.example): colours, effects, the
jump key, which keys are workspaces 1–9 (by position, as `keybars-pro light`
names them; `keybars-pro map` shows your board), and whether to send events.

On a Moonlander, workspaces 1–9 are the number row's 1–5 and 6–9
(`r1c2`–`r1c6`, `r1c9`–`r1c12`); on a Voyager and most 12-column boards,
`r1c2`–`r1c10`.

## Development

`make check` runs shellcheck, `tests/watch_test.sh`, `tests/bridge_test.sh`
and `tests/mcp_test.sh`, which drive the scripts with fake `herdr` and
`keybars-pro` commands.

## Licence

MIT
