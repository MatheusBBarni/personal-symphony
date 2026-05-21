# Agent Workspace Example

Direct-call source: [../agent_workspace.ml](../agent_workspace.ml)

JSX-wrapper source: [../agent_workspace_jsx.re](../agent_workspace_jsx.re)

Run from `apps/tui`:

```bash
opam exec -- dune exec examples/agent_workspace.exe
opam exec -- dune exec examples/agent_workspace_jsx.exe
```

## Purpose

`agent_workspace` shows a message-first interface for agent work. It combines navigation, conversation history, an input composer, and a run-state side panel.

Use `agent_workspace_jsx` when evaluating the recommended `Tui.Jsx` authoring path. Use `agent_workspace` when you want the lower-level direct `Components` and `Patterns` calls for comparison. Both examples render the same screen model through `Tui.Renderer`.

## What It Demonstrates

- `Tui.Jsx.AppShell` for an application frame with status badges and footer commands.
- `Tui.Jsx.Split` for navigator plus workspace layout.
- `Tui.Jsx.SectionTitle` and `Tui.Jsx.NavItem` for sidebar navigation.
- `Tui.Jsx.Message` for transcript entries.
- `Tui.Jsx.ScrollBox` for a scrollable conversation region.
- `Tui.Jsx.Composer` for a bordered input row.
- `Tui.Jsx.Timeline` and `Tui.Jsx.KeyValue` for run-state details.
- Direct `Patterns` and `Components` calls as the parity reference in `agent_workspace.ml`.

## Layout Notes

The example renders at `132x38`. The conversation column flexes while the run-state panel keeps a fixed width. This makes the transcript the primary work area without losing task context.

## When To Use It

Use this example when building chat, review, task-workspace, or command-center interfaces where a transcript is the main interaction surface.
