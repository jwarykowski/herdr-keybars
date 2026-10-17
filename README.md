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

It drives the keyboard with keybars Pro's
[command line](https://keybars.app/pro/cli/), so it works on any keyboard
keybars Pro does (ZSA boards over USB, others through OpenRGB), lights play
over the music rather than blanking the board, and only changes are sent.
It replaces herdr-zsa-lights, which needed Keymapp and kontroll.

## Requirements

- herdr 0.9.3+
- keybars Pro running, with its command installed: App settings, Command
  line, **Install the command-line tool** (`keybars-pro` on your PATH)
- `jq`, `bash`

## Install

```sh
herdr plugin install jwarykowski/herdr-keybars
```

The watcher starts with each herdr session and exits when herdr stops,
clearing its lights.

## Actions

| action | does |
|---|---|
| `jwarykowski.herdr-keybars.next-agent` | focus the next blocked agent, else the next done one; repeat to cycle |
| `jwarykowski.herdr-keybars.toggle` | agent lights off / on |
| `jwarykowski.herdr-keybars.keyboard` | keybars Pro's lights off / on (its On switch) |
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

Hooks from other plugins can light the board themselves with
[`keybars-pro light`](https://keybars.app/pro/cli/#light), with any effect: a
merged PR in [herdr-gh](https://github.com/jwarykowski/herdr-gh)'s
`hooks/pr.merged`, or a finished round in herdr-pomodoro's
`hooks/pomodoro.work_done`:

```sh
#!/bin/sh
keybars-pro light all purple -effect ripple
```

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

`make check` runs shellcheck and `tests/watch_test.sh`, which drives
`bin/watch` with fake `herdr` and `keybars-pro` commands.

## Licence

MIT
