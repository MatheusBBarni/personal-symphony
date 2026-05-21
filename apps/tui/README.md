# Symphony TUI

Symphony TUI is an OCaml terminal UI toolkit. It provides a renderer-owned component tree, buffered cell surfaces, ANSI and plain-text rendering, Toffee-backed flexbox layout, keyboard parsing, keymaps, viewport helpers, and reusable terminal UI widgets.

The package is intentionally framework-free. New screens should start with the `Tui.Jsx` authoring layer, which is a set of JSX-friendly wrapper modules over the same `Tui.Node.t` tree rendered by `Tui.Renderer`. Direct `Tui.Components` and `Tui.Patterns` calls remain stable lower-level APIs for callers that want the primitive functions.

Unless noted otherwise, commands in this README run from `apps/tui`.

## Quick start

Add the opam package:

```sh
opam install symphony-orchestrator-tui
```

Then add the library to a Dune executable:

```lisp
(executable
 (name my_console)
 (libraries symphony-orchestrator-tui))
```

Create a Reason source file with a `Tui.Jsx` tree and render it:

```reason
open Tui;
open Tui.Jsx;

let root =
  <AppShell title="Build" subtitle="standalone terminal tool">
    <Panel title="Status">
      <Text value="Hello from OCaml" />
      <ProgressBar label="compile" fraction=0.72 />
      <Input placeholder="type here" />
    </Panel>
  </AppShell>;

let () = {
  let renderer = Renderer.create(~width=60, ~height=12, root);
  print_endline(Renderer.render_to_string(renderer));
};
```

Run the smallest bundled example or the JSX parity example:

```bash
opam exec -- dune exec examples/demo.exe
opam exec -- dune exec examples/agent_workspace_jsx.exe
```

## Public API layers

Use `Tui.Jsx` for new screens. Use the lower layers when you need control or are maintaining existing direct-call code.

- Core: `Geometry`, `Color`, `Theme`, `Style`, `Surface`, `Node`, `Layout`, `Renderer`, `Terminal`, `Viewport`, `Key`, and `Keymap`.
- JSX: `Tui.Jsx` wrapper modules with `createElement` entrypoints for Reason JSX tags and `make` functions for programmatic composition. Both return `Tui.Node.t`.
- Components: `text`, `rich_text`, `box`, `input`, `select`, `scroll_box`, `progress_bar`, `sparkline`, `panel`, `badge`, `tab_bar`, `key_value`, `table`, `split`, `row`, `column`, `divider`, `callout`, `empty_state`, `toolbar`, and `meter`.
- Patterns: `Patterns.app_shell`, `header`, `rule_panel`, `metric_card`, `log_feed`, `message`, `timeline`, `composer`, `command_bar`, `footer`, and `modal`.
- Presets: `Presets.Open_code.wordmark`, `model_status`, `command_block`, `hint_bar`, and `tip`.

`Components` are the stable building blocks. `Patterns` are opinionated application layouts. `Presets` are example-shaped helpers and should not be treated as neutral primitives.
Existing callers can still reach moved pattern and preset helpers through `Components`; prefer the canonical `Patterns` and `Presets` modules for new code.

## Supported JSX Surface

`Tui.Jsx` V1 ships wrappers for the general-purpose components and patterns most standalone terminal tools need.

Component wrappers: `Text`, `RichText`, `VerticalRule`, `Box`, `Spacer`, `Input`, `Option`, `Select`, `ScrollBox`, `ProgressBar`, `Sparkline`, `Row`, `Column`, `Panel`, `Badge`, `TabBar`, `KeyValue`, `Table`, `Split`, `Divider`, `Callout`, `EmptyState`, `Toolbar`, and `Meter`.

Pattern wrappers: `RulePanel`, `Modal`, `Header`, `MetricCard`, `LogFeed`, `SectionTitle`, `NavItem`, `Message`, `Timeline`, `Composer`, `CommandBar`, `Footer`, and `AppShell`.

After `open Tui.Jsx`, wrapper modules can be written as Reason JSX elements:

```reason
let status =
  <Panel title="Status" tone=Components.Info>
    <Message
      tone=Components.Info
      author="User"
      time="14:12"
      body="Build the package payload"
    />
    <Text value="Plain text child" />
  </Panel>;
```

V1 intentionally keeps a few APIs direct-call only:

- `Components.repeat` and `Components.fit` are table-formatting helpers, not JSX authoring constructors.
- `Tui.Presets.Open_code.*` stays under `Tui.Presets` because those helpers are preset examples rather than neutral building blocks.
- Text content is explicit. Use `<Text value="..." />` or `Tui.Jsx.Text.make(~value="...", ())`; string children are not converted implicitly.
- `Tui.Jsx` is not a React runtime and does not provide React state, hooks, reconciliation, or DOM compatibility.

## Migrating Direct Calls

JSX wrappers delegate to the existing direct APIs. Migration is mostly a mechanical move from function calls to wrapper modules while keeping the same styles, tones, data, and renderer.

Direct component call:

```ocaml
open Tui

let root =
  Components.panel "Status"
    [
      text "Build ready";
      Components.meter ~label:"coverage" ~value:"82%" 0.82;
    ]
```

Equivalent `Tui.Jsx` wrapper call:

```reason
open Tui;
open Tui.Jsx;

let root =
  <Panel title="Status">
    <Text value="Build ready" />
    <Meter label="coverage" value="82%" fraction=0.82 />
  </Panel>;
```

Keep using direct `Components` and `Patterns` calls when you want lower-level helper functions, table string fitting, preset examples, or existing code that does not benefit from tree-shaped wrapper modules. Both paths produce `Tui.Node.t` and render through the same `Renderer`.

## Component guide

Most applications start with `box`, `row`, `column`, and `panel`, then add focused widgets inside those containers. Components return `Tui.Node.t`, so they compose by nesting lists.

### Text and layout

```ocaml
open Tui

let root =
  Components.column
    ~style:Style.(make ~width:(Percent 1.) ~height:(Percent 1.) ~gap:1 ())
    [
      Components.row
        ~style:Style.(make ~height:(Cells 1) ~gap:2 ())
        [
          text "Queue";
          Components.badge ~tone:Components.Success "ready";
        ];
      Components.divider ~width:48 ~title:"Runs" ();
      Components.panel "Current task"
        [
          text "Build package payload";
          Components.meter ~label:"progress" ~value:"72%" 0.72;
        ];
    ]
```

Use `row` when children should sit beside each other. Use `column` when they should stack. `Style.make` controls width, height, growth, padding, margin, gap, colors, and borders.

### Forms and selection

```ocaml
let queue_picker =
  Components.panel "Queue"
    [
      select
        ~style:Style.(make ~height:(Cells 5) ())
        [
          option ~description:"ready to start" "bootstrap";
          option ~description:"running tests" "backend";
          option ~description:"waiting on review" "frontend";
        ];
      input ~placeholder:"filter tasks" ();
    ]
```

`input`, `select`, and `scroll_box` are focusable. `Renderer.dispatch_key` routes keyboard events to the focused node first, then falls back to the renderer keymap.

### Status and data

```ocaml
let run_summary =
  Components.panel ~tone:Components.Info "Run summary"
    [
      Components.key_value
        ~label_width:12
        [
          ("branch", "task/tui-readme");
          ("status", "running");
          ("worker", "agent-2");
        ];
      Components.table
        [ ("STEP", 18); ("STATE", 10); ("TIME", 8) ]
        [
          [ "build"; "OK"; "11s" ];
          [ "test"; "RUNNING"; "04s" ];
        ];
    ]
```

Use `key_value` for dense metadata and `table` when rows need alignment. Fixed cell widths are deliberate: terminal tables read better when columns stay put.

### Messages, logs, and empty states

```ocaml
let activity =
  Components.panel "Activity"
    [
      Patterns.log_feed
        ~style:Style.(make ~height:(Cells 6) ())
        [
          ("12:00", "INFO", "created task branch");
          ("12:01", "OK", "backend tests passed");
          ("12:02", "WARN", "frontend build still running");
        ];
      Components.callout
        ~tone:Components.Warning
        ~title:"Next check"
        [ text "Review generated assets before publishing." ];
    ]

let no_results =
  Components.empty_state
    ~detail:"No tasks match the current filter."
    ~action:"Press / to change the filter."
    "Nothing to show"
```

`log_feed` is a pattern because it has opinions about timestamp and level formatting. `callout` and `empty_state` are plain components.

## Putting components together

This example builds a compact work queue view. It uses `Patterns.app_shell` for the frame, `Components.split` for the main layout, panels for sections, and smaller components inside each panel.

```ocaml
open Tui

let design =
  Components.make_design ~theme:Theme.high_contrast_dark ()

let sidebar =
  [
    Components.toolbar
      ~design
      [ ("n", "ew"); ("/", "filter"); ("?", "help") ];
    Components.panel ~design "Queues"
      [
        select
          ~style:Style.(make ~height:(Cells 6) ())
          [
            option ~description:"3 tasks" "Ready";
            option ~description:"1 task" "Running";
            option ~description:"2 tasks" "Review";
          ];
      ];
    Components.panel ~design "Runtime"
      [
        Components.key_value
          ~design
          ~label_width:10
          [
            ("workspace", "demo");
            ("branch", "task/tui");
            ("agent", "builder");
          ];
      ];
  ]

let main =
  [
    Components.row
      ~style:Style.(make ~height:(Cells 7) ~gap:1 ())
      [
        Components.panel
          ~design
          ~tone:Components.Success
          ~style:Style.(make ~width:(Cells 28) ())
          "Build"
          [ Components.meter ~design ~label:"package" ~value:"72%" 0.72 ];
        Components.panel
          ~design
          ~tone:Components.Info
          ~style:Style.(make ~width:(Cells 28) ())
          "Tests"
          [ Components.meter ~design ~label:"backend" ~value:"24/24" 1.0 ];
      ];
    Components.panel ~design "Tasks"
      [
        Components.table
          ~design
          [ ("TASK", 18); ("STATE", 10); ("OWNER", 10) ]
          [
            [ "bootstrap"; "OK"; "agent-1" ];
            [ "backend"; "RUNNING"; "agent-2" ];
            [ "frontend"; "REVIEW"; "agent-3" ];
          ];
      ];
    Components.panel
      ~design
      ~tone:Components.Warning
      "Recent events"
      [
        Patterns.log_feed
          ~design
          ~style:Style.(make ~height:(Cells 5) ())
          [
            ("13:41", "INFO", "created task worktree");
            ("13:42", "OK", "package build finished");
            ("13:43", "WARN", "review still pending");
          ];
      ];
  ]

let root =
  Patterns.app_shell
    ~title:"Task queue"
    ~subtitle:"workspace demo"
    ~design
    ~badges:[ (Components.Success, "live"); (Components.Info, "local") ]
    ~footer_items:[ ("q", "uit"); ("r", "efresh"); ("/", "filter"); ("Tab", "focus") ]
    [ Components.split ~left_width:30 sidebar main ]

let () =
  let renderer = Renderer.create ~width:120 ~height:32 root in
  print_endline (Renderer.render_to_string renderer)
```

The important bit is the shape: compose small nodes, put repeated chunks in `let` bindings, and keep stateful widgets inside panels that make their role obvious.

## Layout usage

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

## Rendering modes

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

`Theme.dark` is the default. Use `Theme.light`, `Theme.high_contrast_dark`, `Theme.named`, or a custom `Theme.t` when an application needs its own palette. For custom palettes, build a `Theme.palette` with `Theme.make`, convert it with `Theme.of_palette`, and override individual slots with `Theme.with_slot`.

For component styles that should follow the active design, use the `Components.style`, `tone_style`, and `surface_style` helpers:

```ocaml
let style =
  Components.style
    ~design
    ~fg:Theme.Accent_primary
    ~bg:Theme.Bg_surface
    ~attrs:[ Attr.Bold ]
    ()
```

## Source layout

`Tui` is a compatibility facade. The implementation is split into focused modules under `lib/`:

- Core rendering and input modules live in files such as `style.re`, `surface.re`, `node.re`, `layout.re`, `render.re`, and `renderer.re`.
- Theme tokens and palette helpers live in `theme.re`.
- Component design context and reusable widgets live under `components/`.
- JSX wrapper modules live in `jsx.re` and delegate to the public component and pattern layers.
- Reusable components use one file per component, for example `components/component_panel.re`, `components/component_table.re`, `components/component_callout.re`, and `components/component_meter.re`.
- `components/components_core.re`, `components/components.re`, `patterns.re`, and `presets.re` aggregate the public layers.

Callers should prefer the stable `Tui.Components`, `Tui.Patterns`, and `Tui.Presets` namespaces. The split files keep implementation ownership clear without requiring consumers to learn every internal module.

## Keyboard usage

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
| `agent_workspace_jsx` | JSX-wrapper parity version of `agent_workspace` for the recommended authoring path. | `opam exec -- dune exec examples/agent_workspace_jsx.exe` |
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

## Package release

The publishable opam package is `symphony-orchestrator-tui`. opam does not support npm-style scoped names such as `@symphony-orchestrator/tui`, so the package uses the same words joined with dashes. The installed OCaml module remains `Tui`.

Package metadata lives in `dune-project`, and `symphony-orchestrator-tui.opam` is generated from it.

The GitHub Actions `TUI package` workflow validates pull requests and pushes that touch `apps/tui` or the workflow itself. Release archive publishing runs only for a TUI package version bump on the repository default branch, or for a manual dispatch with `publish_release` enabled, and publishes `dist/symphony-orchestrator-tui-<version>.tar.gz` to a `tui-v<version>` GitHub release.

Before publishing manually, run the package checks from `apps/tui`:

```bash
opam lint symphony-orchestrator-tui.opam
opam install . --deps-only --with-test
opam exec -- dune build @all
opam exec -- dune runtest
```

Install `opam-publish` once if the command is missing:

```bash
opam install opam-publish
```

Because this package lives under `apps/tui`, publish an archive whose root is the TUI package directory. A full repository archive also contains the backend and frontend projects, which is not what opam needs for this package.

Create the package archive from a tag:

```bash
sh scripts/release-archive.sh 0.1.0 tui-v0.1.0
```

Upload the generated `dist/symphony-orchestrator-tui-0.1.0.tar.gz` file to the GitHub release for that tag. Then publish through the standard opam-repository PR flow from `apps/tui`:

```bash
opam publish https://github.com/MatheusBBarni/symphony-orchestrator/releases/download/tui-v0.1.0/symphony-orchestrator-tui-0.1.0.tar.gz .
```
