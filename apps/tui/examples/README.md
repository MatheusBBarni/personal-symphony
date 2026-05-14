# TUI Examples

These examples show the main ways to use the `tui` package. Commands are meant to run from `apps/tui`.

| Example | Source | README | Run |
| --- | --- | --- | --- |
| `demo` | [demo.ml](demo.ml) | [demo/README.md](demo/README.md) | `opam exec -- dune exec examples/demo.exe` |
| `operations_dashboard` | [operations_dashboard.ml](operations_dashboard.ml) | [operations_dashboard/README.md](operations_dashboard/README.md) | `opam exec -- dune exec examples/operations_dashboard.exe` |
| `agent_workspace` | [agent_workspace.ml](agent_workspace.ml) | [agent_workspace/README.md](agent_workspace/README.md) | `opam exec -- dune exec examples/agent_workspace.exe` |
| `opencode_splash` | [opencode_splash.ml](opencode_splash.ml) | [opencode_splash/README.md](opencode_splash/README.md) | `opam exec -- dune exec examples/opencode_splash.exe` |
| `opencode_session` | [opencode_session.ml](opencode_session.ml) | [opencode_session/README.md](opencode_session/README.md) | `opam exec -- dune exec examples/opencode_session.exe` |

## Choosing An Example

- Start with `demo` when learning the basic component tree and renderer flow.
- Use `operations_dashboard` for dense dashboard layouts with metrics, tables, and logs.
- Use `agent_workspace` for message-first layouts with a navigator, transcript, composer, and side panel.
- Use `opencode_splash` to study responsive full-screen composition and OpenCode-inspired presets.
- Use `opencode_session` to study viewport-driven branching, alternate-screen preview behavior, and a more complete session layout.

## Terminal Behavior

`demo`, `operations_dashboard`, and `agent_workspace` print fixed-size snapshots.

`opencode_splash` and `opencode_session` use the active terminal size, enter the alternate screen when stdin/stdout are interactive, and exit on any key. In non-interactive output they print an ANSI snapshot instead.

For deterministic responsive previews, export `COLUMNS` and `LINES` before running an OpenCode-inspired example:

```bash
COLUMNS=120 LINES=36 opam exec -- dune exec examples/opencode_splash.exe
```

If your shell exports `NO_COLOR`, unset it to see ANSI color:

```bash
env -u NO_COLOR opam exec -- dune exec examples/opencode_session.exe
```
