# Default the Terminal Console to the rich Runtime State surface

## Status

Accepted

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

## Decision

Normal `symphony` runs open the read-first Terminal Console by default. The Terminal Console renders
Runtime State snapshots for active work, retrying work, task attention, Readiness Gaps, Ordered Queue
progress, Compozy PRD Run progress, Agent Worktree details, and Task Branch context.

The Terminal Console implementation uses the local OCaml terminal toolkit package under `apps/tui`.
Its foreground shell presents the Workspace Repository project title and stable primary tabs:
`Queue | Logs | Tasks | Readiness`.

The Terminal Console may provide safe local aids for reading and inspection: refresh the latest
in-memory Runtime State snapshot, navigate, filter, show Web Dashboard handoff guidance, and inspect
validated local paths. These aids must not retry tasks, pause or resume dispatch, update tracker
status, merge or push Task Branches, open pull requests, change Runtime Contract files, or otherwise
mutate task lifecycle state.

Readiness-blocked runs render Readiness Gaps in the Terminal Console without starting orchestration.
`symphony --web` keeps Web Dashboard mode separate. The `symphony --once` command keeps
non-interactive terminal output and exits without starting the foreground Terminal Console loop.

## Consequences

- The default local operator experience becomes the Terminal Console Runtime State surface instead of
  static terminal output.
- The MVP improves active-run comprehension without creating a second orchestration control path.
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
- `apps/tui/lib/tui.ml`
- `apps/backend/lib/terminal_console_model.ml`
