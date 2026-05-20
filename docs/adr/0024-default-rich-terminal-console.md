# Default the Terminal Console to the rich Runtime State surface

## Status

Accepted, amended 2026-05-20

## Date

2026-05-13

## Context

Normal `symphony` runs previously used a mostly static Terminal Console before orchestration owned the
foreground process. The Terminal Console work changed that runtime shape: the Product Repository now
has a richer foreground Terminal Console for normal Workspace Repository operation, while
orchestration runs in the background when readiness allows it.

The default surface still needs to preserve Personal Symphony runtime boundaries. Runtime State
remains the source of visible orchestration truth. Runtime Contract files under the Runtime Home still
own operator configuration. The Web Dashboard remains the browser surface, and its Live Dashboard
Connection remains a Runtime State stream instead of a command channel.

The Terminal Console settings work adds one narrow setup exception to the original read-first contract:
the console may persist its own theme in ignored Runtime Home UI state and may update Runtime Settings
`server.port` for the Web Dashboard. The `w` key also changes from the previous guidance-only behavior
to a loopback local service action that starts or reuses a compatible dashboard for the current
Workspace Repository and Runtime Home.

## Decision

Normal `symphony` runs open the read-first Terminal Console by default. The Terminal Console renders
Runtime State snapshots for active work, retrying work, task attention, Readiness Gaps, Ordered Queue
progress, Compozy PRD Run progress, Agent Worktree details, and Task Branch context.

The Terminal Console implementation uses the local OCaml terminal toolkit package under `apps/tui`.
Its foreground shell presents the Workspace Repository project title and stable primary tabs:
`Queue | Logs | Tasks | Readiness`.

The Terminal Console may provide safe local aids for reading, inspection, and scoped local setup:
refresh the latest in-memory Runtime State snapshot, navigate, filter, open focused Terminal Console settings with `s`, start or reuse the loopback Web Dashboard with `w`, and inspect validated local paths.

The settings surface exposes only Terminal Console theme and Web Dashboard port. Theme persists in
ignored Runtime Home UI state. The Web Dashboard port persists by updating only Runtime Settings
`server.port`. It is not a general Runtime Settings editor and does not edit `server.host`, tracker,
Git, agent, Harness, Sandbox, queue, or lifecycle settings.

The `w` action may start a local loopback HTTP service or reuse a compatible existing dashboard for the
same Workspace Repository and Runtime Home. It must report a conflict for unrelated listeners or
identity mismatches instead of attaching by port alone. Terminal Console V1 dashboard controls are loopback-only; non-loopback Web Dashboard access remains governed by Runtime Settings `server.host`
and the generated local dashboard auth token described in ADR-0025.

These aids must not retry tasks, pause or resume dispatch, update tracker status, merge or push Task
Branches, open pull requests, change any Runtime Contract field other than scoped `server.port`, or
otherwise mutate task lifecycle state.

Readiness-blocked runs render Readiness Gaps in the Terminal Console without starting orchestration.
`symphony --web` keeps Web Dashboard mode separate. The `symphony --once` command keeps
non-interactive terminal output and exits without starting the foreground Terminal Console loop.

## Consequences

- The default local operator experience becomes the Terminal Console Runtime State surface instead of
  static terminal output.
- The MVP improves active-run comprehension without creating a second orchestration control path.
- The Terminal Console can now reduce local setup friction without becoming a general Runtime Settings
  editor or a task lifecycle control surface.
- The Runtime Contract boundary has one documented exception: Terminal Console settings may update
  only Runtime Settings `server.port`.
- The `w` key is local service control, not Live Dashboard Connection command handling.
- Web Dashboard mode stays available for deeper browser inspection and keeps its existing Runtime
  State delivery semantics.
- Package validation must cover the backend executable path because the default `symphony` runtime now
  depends on the richer Terminal Console path.

## References

- `CONTEXT.md`
- `README.md`
- `apps/backend/bin/main.ml`
- `apps/backend/bin/terminal_console_runtime.ml`
- `apps/backend/bin/terminal_console_tui.ml`
- `apps/tui/lib/tui.re`
- `apps/backend/lib/terminal_console_model.ml`
- `docs/adr/0025-dashboard-loopback-and-auth.md`
