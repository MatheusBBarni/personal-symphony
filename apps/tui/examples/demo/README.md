# Demo Example

Source: [../demo.ml](../demo.ml)

Run from `apps/tui`:

```bash
opam exec -- dune exec examples/demo.exe
```

## Purpose

`demo` is the smallest broad tour of the toolkit. It builds a fixed-size component tree and prints a plain terminal snapshot.

## What It Demonstrates

- Opening `Tui` directly for the root helpers such as `box`, `text`, `select`, `progress_bar`, `sparkline`, and `input`.
- Creating a small local `panel` helper from `box` plus `Style.make`.
- Using fixed cell sizes with `Style.Cells`.
- Combining column and row layout through `Style.flex_direction`.
- Rendering with `Renderer.create` and `Renderer.render_to_string`.
- Adding a footer with `Patterns.footer`.

## When To Use It

Use this example when learning the minimum shape of a TUI program:

1. Build a tree of nodes.
2. Give the renderer a width and height.
3. Convert the rendered surface to a string.

It is also a good starting point for snapshot-style tests because the output size is deterministic.
