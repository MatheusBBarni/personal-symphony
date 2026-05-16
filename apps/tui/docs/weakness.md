# TUI Toolkit Weaknesses

## Scope

This note evaluates the **TUI Toolkit Package** in `apps/tui`. It is about the reusable OCaml toolkit API, not the Personal Symphony **Terminal Console** runtime semantics.

The package is already useful for a first Personal Symphony operator surface: it has a renderer-owned root tree, buffered cell surfaces, Toffee-backed layout, keyboard routing, viewport helpers, panels, tables, status badges, progress bars, log feeds, command bars, and dashboard examples. The primary weakness used to be API boundary clarity; the current remaining weakness is hardening the public surface with an interface file and documented style ownership rules.

## Original Primary Weakness

The first implementation of `Components` mixed three different abstraction levels in one public namespace:

- Reusable primitives: `panel`, `badge`, `tab_bar`, `table`, `key_value`, `row`, `column`, `split`.
- Reusable application patterns: `header`, `app_shell`, `composer`, `log_feed`, `metric_card`, `modal`, `command_bar`.
- Demo- or product-shaped helpers: `wordmark`, `model_status`, `command_block`, `tip`, `hint_bar`.

That made the package easy to demo but harder to treat as a general library. A consumer could not tell which APIs were stable primitives, which were opinionated layout patterns, and which existed to recreate a specific OpenCode-inspired example.

## Cleanup Status

| Issue | Current evidence | Risk |
| --- | --- | --- |
| Theme is injectable at the component layer | `Components.make_design` creates a design context, reusable helpers accept `?design`, and `Theme` now has palette helpers plus `high_contrast_dark`, `named`, and `with_slot`. `Theme.dark` remains only as the default design. | Remaining callers that manually style with `Theme.dark` can still be migrated when they need a shared visual identity. |
| Product copy is no longer in core defaults | `Patterns.app_shell` defaults to `App`. OpenCode-specific copy lives under `Presets.Open_code`. | Preset defaults are still product-shaped by design; generic code should not depend on those presets. |
| Primitive and pattern APIs are separated | `Components` now owns reusable widgets, `Patterns` owns application layouts, and `Presets.Open_code` owns OpenCode-inspired helpers. Component implementations live under `lib/components/` with `Components` as the public aggregator. | The package still has no `.mli`, so the next hardening pass should define the intended public surface explicitly. |
| Styling override behavior is partial | Helpers often preserve only selected fields from an incoming `style` value. | Consumers may pass style fields that silently disappear, producing surprising layouts. |
| Semantic tone is design-driven | `tone` maps through `design.tone_color`, with the dark theme as the default. | Advanced design systems may still need more slots than the current tone set exposes. |
| Examples use explicit presets | OpenCode-inspired examples use `Presets.Open_code` helpers instead of `Components` helpers. | Demo fidelity and stable toolkit design are now separated, but preset naming should remain clearly example-oriented. |

## Better API Shape

The implemented public structure now separates core rendering, reusable widgets, higher-level patterns, and example presets:

```ocaml
Tui
  Core: Style, Color, Theme, Surface, Renderer, Terminal, Viewport, Keymap
  Components: Box, Text, Input, Select, Table, Panel, Badge, Tabs, Progress, Divider, Callout, EmptyState, Toolbar, Meter
  Patterns: AppShell, Header, Footer, Composer, Modal, CommandPalette
  Presets: Open_code
```

This split can continue incrementally. The current cleanup pass keeps `Tui` as the compatibility facade, moves core implementation modules into focused files, and places reusable component implementation files under `lib/components/`. The important part from here is keeping ownership clear:

- Keep primitives stable and boring.
- Move opinionated layout helpers into `Patterns`.
- Move OpenCode-specific or screenshot-specific helpers into a `Presets.Open_code` module.
- Keep Personal Symphony-specific composition outside the generic toolkit unless it is explicitly a `Presets.Symphony` layer.

## Theme Injection

Components now accept a design context instead of calling `Theme.dark` internally:

```ocaml
type design = {
  theme : Theme.t;
  tone_color : Components.tone -> Color.t;
}
```

Implemented migration path:

1. Added a lightweight design context with `Theme.dark` as the default.
2. Threaded `?design` through reusable components, app patterns, and OpenCode-inspired presets.
3. Added palette helpers (`Theme.make`, `of_palette`, `to_palette`, `with_slot`, `named`) and `Theme.high_contrast_dark`.
4. Added `Components.style`, `tone_style`, and `surface_style` so component authors can use design-aware styles without repeating slot lookups.
5. Left a Personal Symphony design preset out of this pass until there is a concrete Terminal Console design need.

This keeps existing examples working while allowing a Workspace Repository operator surface to use a distinct palette later.

## Component Cleanup Priorities

1. Add an interface file.

   The implementation is now split, but an `.mli`/`.rei` is still needed to make the intended public API explicit.

2. Normalize style merging.

   Component helpers should either preserve all compatible fields from `style` or document which fields they own. Silent partial merging is a maintenance trap.

3. Rename and relocate any remaining product-shaped helpers.

   `model_status`, `wordmark`, `tip`, and `hint_bar` should not be presented as generic components unless their labels, copy, and palette are fully caller-owned.

4. Make defaults neutral.

   A generic toolkit default should use labels such as `Model`, `Provider`, `Ready`, or no label at all. Product names belong in examples and presets.

5. Treat `tone` as semantic, not visual.

   `Success`, `Warning`, `Error`, and similar values are good public language. The actual color lookup should come from the active theme or design context.

6. Keep the README honest.

   The README should keep `Components`, `Patterns`, and `Presets` distinct as the package grows.

## Readiness Assessment

The TUI Toolkit Package is ready for internal Personal Symphony prototyping and is closer to a clean, general-purpose OCaml terminal UI library after the architecture cleanup pass.

The next pass should focus on API hardening rather than visual polish: add an interface file, normalize style merging, and decide which pattern helpers are stable enough to commit to.

## Done Criteria For The First Cleanup

- Reusable primitives can be used without OpenCode or Symphony copy appearing by default. Done.
- Components can render with `Theme.dark`, `Theme.light`, or a caller-supplied theme. Done through `Components.make_design` and `?design`.
- Example-specific helpers live outside the core `Components` namespace. Done through `Presets.Open_code`.
- Existing dashboard and OpenCode-inspired examples still render after the move. Covered by `dune runtest` and updated examples.
- Tests cover theme injection, neutral defaults, and at least one migrated example helper. Done in `apps/tui/test/test_tui.re`.
- Reusable component implementations live in separate files under `lib/components/` and aggregate through `Components`. Done with `component_*.re` modules.
- New generic components cover divider, callout, empty state, toolbar, and meter use cases. Done with coverage in `apps/tui/test/test_tui.re`.
