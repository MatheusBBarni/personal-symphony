# OpenCode Splash Example

Source: [../opencode_splash.ml](../opencode_splash.ml)

Run from `apps/tui`:

```bash
opam exec -- dune exec examples/opencode_splash.exe
```

For a deterministic size:

```bash
COLUMNS=120 LINES=36 opam exec -- dune exec examples/opencode_splash.exe
```

## Purpose

`opencode_splash` recreates a responsive full-screen splash screen inspired by OpenCode. It demonstrates how to combine viewport detection, centered layout, preset helpers, and alternate-screen preview behavior.

## What It Demonstrates

- `Terminal.viewport` for runtime terminal sizing.
- `Viewport` dimensions passed into a `root` function.
- `Presets.Open_code.wordmark`, `model_status`, `hint_bar`, and `tip`.
- `Patterns.rule_panel` for the prompt surface.
- Conditional rendering based on width and height.
- Alternate-screen rendering when stdin and stdout are interactive.
- ANSI snapshot output when the process is not interactive.

## Terminal Behavior

In an interactive terminal, the example opens a full-screen preview and exits on any key. It restores the previous screen on exit.

If your shell exports `NO_COLOR`, unset it to see colors:

```bash
env -u NO_COLOR opam exec -- dune exec examples/opencode_splash.exe
```

## When To Use It

Use this example when building splash screens, prompt-first entry views, or responsive terminal landing states.
