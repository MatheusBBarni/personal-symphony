# Agent Workspace Example

Source: [../agent_workspace.ml](../agent_workspace.ml)

Run from `apps/tui`:

```bash
opam exec -- dune exec examples/agent_workspace.exe
```

## Purpose

`agent_workspace` shows a message-first interface for agent work. It combines navigation, conversation history, an input composer, and a run-state side panel.

## What It Demonstrates

- `Patterns.app_shell` for an application frame with status badges and footer commands.
- `Components.split` for navigator plus workspace layout.
- `Patterns.section_title` and `Patterns.nav_item` for sidebar navigation.
- `Patterns.message` for transcript entries.
- `scroll_box` for a scrollable conversation region.
- `Patterns.composer` for a bordered input row.
- `Patterns.timeline` and `Components.key_value` for run-state details.

## Layout Notes

The example renders at `132x38`. The conversation column flexes while the run-state panel keeps a fixed width. This makes the transcript the primary work area without losing task context.

## When To Use It

Use this example when building chat, agent-session, review, task-workspace, or command-center interfaces where a transcript is the main interaction surface.
