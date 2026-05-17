---
description: TUI package rules
globs:
  - "apps/tui/**"
---

# TUI Package Rules

Apply these rules when editing `apps/tui/**`.

- MUST keep reusable TUI library source in ReasonML (`.re`/`.rei`) unless an existing file or tool boundary requires OCaml syntax.
- MUST run `pnpm --filter @symphony-orchestrator/tui test` after changing rendering, layout, component, keymap, viewport, theme, or color behavior.
- MUST run `pnpm --filter @symphony-orchestrator/tui build` after TUI package compile-surface changes.
- SHOULD use `opam exec -- dune build -p symphony-orchestrator-tui -j 1 @install @runtest` when install/package behavior matters.
- MUST extend `apps/tui/test/test_tui.re` for rendering edge cases, component behavior, theme mutation behavior, or regressions in reusable widgets.
- MUST preserve package boundaries: `apps/tui` is the reusable OCaml terminal UI toolkit, while product-specific Terminal Console wiring belongs in `apps/backend`.
- MUST keep timeline pastel colors scoped to actual agent/timeline visualizations; do not use them as global status, navigation, error, or success colors.
- MUST avoid drop-shadow-style depth in terminal components; use explicit borders, spacing, and theme tokens instead.
- SHOULD prefer existing component and theme primitives before adding new rendering abstractions.
