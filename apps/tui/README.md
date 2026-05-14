# Symphony TUI

Symphony TUI is a modern terminal UI library for OCaml. It follows the same core shape as OpenTUI: a renderer-owned root tree, composable components, a buffered cell surface, flexbox-style layout, structured keyboard events, and practical widgets.

The library is intentionally framework-free. The layout engine uses `toffee`, an OCaml port of Taffy, so panels, rows, columns, padding, borders, growth, and fixed sizes behave like a terminal-focused subset of CSS flexbox.

## Current Features

- Buffered cell surface with plain snapshots, ANSI rendering, and diff rendering.
- Semantic styling primitives: colors, attributes, themes, borders, padding, margins, and flex properties.
- Components: `text`, `box`, `input`, `select`, `scroll_box`, `progress_bar`, `sparkline`, `panel`, `badge`, `tab_bar`, `key_value`, `table`, `split`, `row`, and `column`.
- Themed component design contexts with `Components.make_design` and `?design` arguments for reusable widgets and patterns.
- Application patterns: `Patterns.app_shell`, `header`, `rule_panel`, `metric_card`, `log_feed`, `message`, `timeline`, `composer`, `command_bar`, `footer`, and `modal`.
- Example presets: `Presets.Open_code.wordmark`, `model_status`, `command_block`, `hint_bar`, and `tip`.
- Keyboard parsing for common terminal sequences plus focus routing and basic widget key handling.
- Keymap engine with single-key and multi-stroke bindings.
- Terminal helpers for alternate screen, raw mode, viewport detection, color capability, and a small render loop.

## Example

```ocaml
open Tui

let root =
  box
    ~style:Style.(make ~border:Rounded ~title:"Demo" ~padding:(spacing_all 1) ())
    [
      text "Hello from OCaml";
      progress_bar ~label:"build" 0.72;
      input ~placeholder:"type here" ();
    ]

let () =
  let renderer = Renderer.create ~width:60 ~height:12 root in
  print_endline (Renderer.render_to_string renderer)
```

Run the included demo:

```bash
dune exec examples/demo.exe
```

## Responsive Layouts

Consumers can read the terminal viewport and branch their layout without reaching into renderer internals:

```ocaml
open Tui

let root viewport =
  match Viewport.breakpoint viewport with
  | Tiny | Compact -> box [ text "Compact view" ]
  | Regular | Wide -> box [ text "Full view" ]

let () =
  let viewport = Terminal.viewport () in
  let renderer =
    Renderer.create ~width:viewport.width ~height:viewport.height (root viewport)
  in
  print_string (Renderer.render_to_string ~ansi:true renderer)
```

Useful public helpers:

- `Terminal.viewport ()`, `Terminal.size ()`, `Terminal.columns ()`, and `Terminal.rows ()`
- `Viewport.breakpoint`, `Viewport.fits`, `Viewport.choose`, and `Viewport.orientation`
- `Renderer.viewport`, `Renderer.size`, `Renderer.resize`, `Renderer.resize_to_viewport`, and `Renderer.resize_to_terminal`

Run the screenshot-style operations console example:

```bash
dune exec examples/operations_dashboard.exe
```

Run the OpenCode-inspired examples from the reference images:

```bash
opam exec -- dune exec examples/opencode_splash.exe
opam exec -- dune exec examples/opencode_session.exe
```

The OpenCode examples open a full-screen preview and exit on any key. They size
themselves from `COLUMNS`/`LINES` when exported, otherwise they query the active
TTY. If your shell exports `NO_COLOR`, unset it for the preview:

```bash
env -u NO_COLOR opam exec -- dune exec examples/opencode_splash.exe
```

Run tests:

```bash
dune runtest
```

## Package Release

The publishable OCaml package is `tui`. Package metadata lives in `dune-project`, and `tui.opam`
is generated from it:

```bash
dune build @opam
```

Before publishing a tagged release, run the package checks from `apps/tui`:

```bash
opam lint tui.opam
opam install . --deps-only --with-test
dune build
dune runtest
```

When the repository tag is pushed and a GitHub source archive is available, publish through the
standard opam-repository PR flow:

```bash
opam publish
```
