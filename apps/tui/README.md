# Symphony TUI

Symphony TUI is an OCaml terminal UI toolkit. It provides a renderer-owned component tree, buffered cell surfaces, ANSI and plain-text rendering, Toffee-backed flexbox layout, keyboard parsing, keymaps, viewport helpers, and reusable terminal UI widgets.

The package is intentionally framework-free. You build a tree of `Tui.Node.t` values, render it with `Tui.Renderer`, and decide whether your program prints a static snapshot or runs an interactive terminal loop.

Unless noted otherwise, commands in this README run from `apps/tui`.

## Quick Start

Add the `tui` library to a Dune executable:

```lisp
(executable
 (name my_console)
 (libraries tui))
```

Create a root node and render it:

```ocaml
open Tui

let root =
  box
    ~style:Style.(make ~border:Rounded ~title:"Build" ~padding:(spacing_all 1) ())
    [
      text "Hello from OCaml";
      progress_bar ~label:"compile" 0.72;
      input ~placeholder:"type here" ();
    ]

let () =
  let renderer = Renderer.create ~width:60 ~height:12 root in
  print_endline (Renderer.render_to_string renderer)
```

Run one of the bundled examples:

```bash
opam exec -- dune exec examples/demo.exe
```

## Public API Layers

Use the lower layers when you need control, and the higher layers when you want common application shapes.

- Core: `Geometry`, `Color`, `Theme`, `Style`, `Surface`, `Node`, `Layout`, `Renderer`, `Terminal`, `Viewport`, `Key`, and `Keymap`.
- Components: `text`, `rich_text`, `box`, `input`, `select`, `scroll_box`, `progress_bar`, `sparkline`, `panel`, `badge`, `tab_bar`, `key_value`, `table`, `split`, `row`, and `column`.
- Patterns: `Patterns.app_shell`, `header`, `rule_panel`, `metric_card`, `log_feed`, `message`, `timeline`, `composer`, `command_bar`, `footer`, and `modal`.
- Presets: `Presets.Open_code.wordmark`, `model_status`, `command_block`, `hint_bar`, and `tip`.

`Components` are the stable building blocks. `Patterns` are opinionated application layouts. `Presets` are example-shaped helpers and should not be treated as neutral primitives.
Existing callers can still reach moved pattern and preset helpers through `Components`; prefer the canonical `Patterns` and `Presets` modules for new code.

## Layout Usage

Most layout is configured through `Style.make`. The toolkit supports terminal-focused flexbox concepts:

- `width`, `height`, `min_width`, and `min_height`
- `flex_direction`, `flex_grow`, and `flex_shrink`
- `justify_content` and `align_items`
- `padding`, `margin`, `gap`, and borders
- absolute positioning for overlays such as modals

Example:

```ocaml
open Tui

let root =
  Components.row
    ~style:Style.(make ~width:(Percent 1.) ~height:(Percent 1.) ~gap:1 ())
    [
      Components.panel
        ~style:Style.(make ~width:(Cells 28) ())
        "Navigator"
        [ text "Queue"; text "Runs"; text "Logs" ];
      Components.panel
        ~style:Style.(make ~flex_grow:1. ())
        "Detail"
        [ text "Selected item" ];
    ]
```

## Rendering Modes

For a fixed snapshot, construct a renderer with an explicit size:

```ocaml
let renderer = Renderer.create ~width:96 ~height:24 root
let plain = Renderer.render_to_string renderer
let ansi = Renderer.render_to_string ~ansi:true renderer
```

For a terminal-sized view, read the current viewport:

```ocaml
let viewport = Terminal.viewport () in
let renderer =
  Renderer.create ~width:viewport.width ~height:viewport.height (root viewport)
```

For full-screen previews, enter the alternate screen, render, and restore the terminal when the program exits. The OpenCode-inspired examples show this pattern.

## Theming

Components and patterns accept an optional `?design` value. A design combines a theme with tone mapping:

```ocaml
open Tui

let design = Components.make_design ~theme:Theme.light ()

let root =
  Components.panel ~design ~tone:Components.Success "Status"
    [
      Components.badge ~design ~tone:Components.Success "ready";
      Patterns.log_feed ~design [ ("12:00", "OK", "started") ];
    ]
```

`Theme.dark` is the default. Use `Theme.light` or a custom `Theme.t` when an application needs its own palette.

## Keyboard Usage

Inputs, selects, and scroll boxes handle common keys through `Renderer.dispatch_key`. For application-level shortcuts, use `Keymap`:

```ocaml
let keymap = Keymap.create ()
let quit = ref false

let () =
  Keymap.register keymap ~key:"q" ~name:"quit" ~run:(fun () -> quit := true)
```

The renderer also supports focus routing for focusable nodes such as `input`, `select`, and `scroll_box`.

## Examples

Example documentation lives in [examples/README.md](examples/README.md).

| Example | Purpose | Run |
| --- | --- | --- |
| `demo` | Minimal component composition and fixed snapshot rendering. | `opam exec -- dune exec examples/demo.exe` |
| `operations_dashboard` | Wide dashboard using panels, metrics, tables, logs, and app shell patterns. | `opam exec -- dune exec examples/operations_dashboard.exe` |
| `agent_workspace` | Message-first agent workspace with navigator, transcript, composer, and run state. | `opam exec -- dune exec examples/agent_workspace.exe` |
| `opencode_splash` | Responsive full-screen splash using OpenCode-inspired presets. | `opam exec -- dune exec examples/opencode_splash.exe` |
| `opencode_session` | Responsive session view with conversation, composer, footer, and optional right rail. | `opam exec -- dune exec examples/opencode_session.exe` |

The OpenCode-inspired examples open a full-screen preview and exit on any key when run in an interactive terminal. They size themselves from `COLUMNS` and `LINES` when those variables are exported, otherwise they query the active TTY. If your shell exports `NO_COLOR`, unset it for the preview:

```bash
env -u NO_COLOR opam exec -- dune exec examples/opencode_splash.exe
```

## Development

Run tests:

```bash
opam exec -- dune runtest
```

Build everything in the package:

```bash
opam exec -- dune build @all
```

Build the opam metadata:

```bash
opam exec -- dune build @opam
```

## Package Release

The publishable OCaml package is `tui`. Package metadata lives in `dune-project`, and `tui.opam` is generated from it.

Before publishing a tagged release, run the package checks from `apps/tui`:

```bash
opam lint tui.opam
opam install . --deps-only --with-test
opam exec -- dune build @all
opam exec -- dune runtest
```

When the repository tag is pushed and a GitHub source archive is available, publish through the standard opam-repository PR flow:

```bash
opam publish
```
