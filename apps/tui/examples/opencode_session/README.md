# OpenCode Session Example

Source: [../opencode_session.ml](../opencode_session.ml)

Run from `apps/tui`:

```bash
opam exec -- dune exec examples/opencode_session.exe
```

For a deterministic size:

```bash
COLUMNS=132 LINES=38 opam exec -- dune exec examples/opencode_session.exe
```

## Purpose

`opencode_session` recreates a compact agent-session view inspired by OpenCode. It shows a conversation area, command block, thinking state, model status, composer, footer hints, and an optional right rail.

## What It Demonstrates

- `Terminal.viewport` for responsive sizing.
- Width-based compact behavior for conversation copy and model labels.
- Optional right rail rendering when the viewport is wide enough.
- `Presets.Open_code.command_block`, `model_status`, and `hint_bar`.
- `Patterns.rule_panel` for the composer surface.
- Manual right-rail composition with core `box`, `text`, `rich_text`, and `spacer`.
- Alternate-screen rendering when stdin and stdout are interactive.
- ANSI snapshot output when the process is not interactive.

## Terminal Behavior

In an interactive terminal, the example opens a full-screen preview and exits on any key. It restores the previous screen on exit.

If your shell exports `NO_COLOR`, unset it to see colors:

```bash
env -u NO_COLOR opam exec -- dune exec examples/opencode_session.exe
```

## When To Use It

Use this example when building a full agent session, chat workspace, or tool execution view that needs responsive layout decisions.
