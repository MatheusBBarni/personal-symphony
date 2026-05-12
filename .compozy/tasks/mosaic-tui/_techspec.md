# Mosaic Terminal Console TechSpec

## Executive Summary

The MVP adds a rich default **Terminal Console** by running Mosaic in-process as the foreground UI while `Orchestrator.run_forever` runs in a background thread. The UI consumes immutable **Runtime State** snapshots through the existing `Orchestrator.make ~notify_state` seam and renders a pure Terminal Console view model derived from `Runtime_state.t`.

The primary technical trade-off is accepting a new foreground event loop and Mosaic dependency in exchange for a single-process default `symphony` experience. The design avoids a separate local client/server, avoids task lifecycle mutation, and avoids Runtime State schema changes. It adds a small projection boundary so sanitization, active-state classification, and panel summaries are testable without Mosaic.

## System Architecture

### Component Overview

- **`Terminal_console_model`** — new pure backend module that maps `Runtime_state.t` to a terminal-specific view model. It owns active-state classification, text sanitization, task row construction, safe-aid descriptors, and UI-independent filter/focus state transitions.
- **`Terminal_console_mosaic`** — new executable-side module that owns Mosaic model/update/view wiring. It renders the view model, handles keyboard input, and invokes safe local aid handlers. It must not import orchestration mutation functions.
- **`Terminal_console_runtime`** — small executable-side coordination layer in or near `main.ml`. It starts orchestration in a background thread when dispatch is allowed, passes `notify_state` snapshots into the Mosaic loop, and handles shutdown.
- **Existing `Orchestrator`** — unchanged orchestration owner. It remains the only component that mutates orchestration state during normal runs.
- **Existing `Runtime_state`** — unchanged source of visible orchestration state.
- **Existing `Server` / Web Dashboard** — unchanged. The Terminal Console MVP does not use the **Live Dashboard Connection** as a command channel and does not start the Web Dashboard server by default.

### Data Flow

1. `main.ml` prepares Runtime Home and loads Runtime Settings as it does today.
2. If `--once` is set, the CLI prints non-interactive output and exits without Mosaic.
3. If `--web` is set, existing Web Dashboard behavior remains unchanged.
4. For default Terminal Console mode, `main.ml` creates an initial `Runtime_state.t` through existing readiness/orchestrator paths.
5. When readiness permits orchestration, `main.ml` creates `Orchestrator.make ~notify_state`, starts `Orchestrator.run_forever` in a background thread, and starts the Mosaic loop in the foreground.
6. `notify_state` writes each immutable Runtime State snapshot into a synchronized state cell or queue.
7. Mosaic receives state-change messages, calls `Terminal_console_model.of_runtime_state`, and redraws.
8. Keyboard input changes UI-only model state or invokes safe local aids. MVP key handlers cannot call task lifecycle mutation functions.

### Readiness-Blocked Flow

When `Runtime_policy.action` returns `Serve_readiness_state` for Terminal Console mode, Mosaic renders the readiness state and remediation panels without starting orchestration. This preserves the existing behavior that **Readiness Gaps** block dispatch but do not prevent the Terminal Console from starting.

## Implementation Design

### Core Interfaces

The implementation should keep core display logic pure and Mosaic-independent.

```ocaml
module Terminal_console_model : sig
  type safe_aid = Refresh_view | Show_web_handoff | Show_path of string
  type task_row = { id : string; title : string; state : string; detail : string option }
  type t = {
    generated_at : string;
    mode : string;
    summary : string list;
    active : task_row list;
    readiness : (string * string) list;
    queue : task_row list;
    compozy : string option;
    safe_aids : safe_aid list;
  }

  val of_runtime_state : Runtime_state.t -> t
  val sanitize : string -> string
end
```

The primary dependency contract can be summarized as this language-neutral shape, shown as a Go struct for template compatibility:

```go
type TerminalConsoleSnapshot struct {
    GeneratedAt string
    Mode        string
    Summary     []string
    Active      []TaskRow
    Readiness   []ReadinessGap
    Queue       []TaskRow
    Compozy     *CompozyProgress
    SafeAids    []SafeAid
}
```

Mosaic-specific code should depend on the projected snapshot, not raw `Runtime_state.t`.

```ocaml
module Terminal_console_mosaic : sig
  type runtime = {
    initial_state : Runtime_state.t;
    subscribe : (Runtime_state.t -> unit) -> unit;
    safe_aid : Terminal_console_model.safe_aid -> unit;
  }

  val run : runtime -> unit
end
```

### Data Models

#### Terminal Console View Model

The view model is an in-memory projection only. It is not persisted under Runtime Home and does not change Runtime State JSON.

Required fields:

- `generated_at` — snapshot timestamp from Runtime State rendering or local receipt time.
- `mode` — one of `ready`, `running`, `retrying`, `attention`, `readiness_blocked`, or `idle`.
- `summary` — compact ordered lines for the home view: running count, retrying count, token total, next work, last error summary.
- `active` — task rows derived from `running`, `retrying`, and `issue_errors`.
- `readiness` — requirement/remediation pairs from Runtime State.
- `queue` — Ordered Queue rows with state and skip reason.
- `compozy` — optional Compozy PRD Run summary.
- `safe_aids` — available non-mutating actions for the current UI state.
- UI-only state — selected panel, selected row, filter text, help visibility, and status message. This state lives in the Mosaic model, not Runtime State.

#### Sanitization Model

All repository, tracker, branch, issue, task, and agent-provided text must pass through `Terminal_console_model.sanitize` before rendering. Sanitization must remove or neutralize terminal escape/control sequences while preserving readable text. Secret variable values must not be displayed; only variable names such as `GITHUB_TOKEN` and `GH_TOKEN` may appear.

#### Safe Aid Model

MVP safe aids are non-mutating:

- `Refresh_view` — redraw or consume the latest in-memory snapshot; it must not force a tracker poll or lifecycle transition.
- `Show_web_handoff` — show the command or URL guidance for running `symphony --web --port <port>`; it must not start a Web Dashboard server in MVP.
- `Show_path` — display or open a validated local path for inspection only; it must not modify files or task state.
- `Filter` and navigation actions — update UI-only state only.

### API Endpoints

No new HTTP or WebSocket endpoints are required for MVP.

Existing endpoints remain unchanged:

- `GET /api/v1/state` continues to return Runtime State JSON for diagnostics and Web Dashboard use.
- `/api/v1/state/live` remains the **Live Dashboard Connection** for Web Dashboard Runtime State snapshots.
- `/api/v1/refresh` remains unchanged and is not the Terminal Console MVP refresh mechanism.

The Terminal Console receives state in-process through `notify_state`, not through HTTP.

## Integration Points

### Mosaic / opam / Dune

The backend executable path must add Mosaic as a direct dependency. The implementation must update Dune/opam metadata explicitly and validate the resulting build. Mosaic `0.1.0` requires `dune >= 3.19`, so the dependency task must account for the current `(lang dune 3.14)` declaration.

### Terminal Environment

The UI must work in standard terminals at 80x24 minimum, handle resize, respect `NO_COLOR`, and remain usable without color. It should avoid advanced Unicode that breaks common terminals or multiplexers. `Ctrl+C` and process termination must restore the terminal.

### Web Dashboard Handoff

The Terminal Console MVP does not start the Web Dashboard server. The handoff safe aid presents command/URL guidance derived from existing port settings and current CLI context.

## Impact Analysis

| Component | Impact Type | Description and Risk | Required Action |
| --- | --- | --- | --- |
| `apps/backend/bin/main.ml` | Modified | Terminal Console mode changes from static print + foreground orchestration to Mosaic foreground + background orchestration. Risk: shutdown/thread coordination. | Add Terminal Console runtime branch while preserving `--once` and `--web`. |
| `apps/backend/lib/cli_mode.ml` | Modified or unchanged | Existing modes may remain sufficient; avoid adding product language unless implementation needs a compatibility mode. Risk: unnecessary CLI surface. | Prefer no new mode unless fallback is required. |
| `apps/backend/lib/orchestrator.ml` | Modified minimally or unchanged | Existing `notify_state` seam is sufficient. Risk: adding UI concerns to orchestration. | Do not add Terminal Console-specific logic unless a missing state notification is discovered. |
| `apps/backend/lib/runtime_state.ml` | Unchanged for MVP | Runtime State already carries required display data. Risk: schema creep. | Avoid new fields unless a PRD goal cannot be met from existing state. |
| `apps/backend/lib/server.ml` | Unchanged | Existing Web Dashboard endpoints remain separate. Risk: accidentally using Live Dashboard Connection as command transport. | No MVP endpoint changes. |
| `apps/backend/lib/terminal_console_model.ml` | New | Pure projection and sanitization. Risk: over-modeling. | Add only fields required by MVP panels and safe aids. |
| `apps/backend/bin/terminal_console_mosaic.ml` | New | Mosaic event loop and rendering. Risk: dependency and terminal cleanup. | Keep Mosaic-specific code isolated from orchestration. |
| `dune-project` and Dune files | Modified | Add Mosaic dependency and any required Dune version change. Risk: package/build impact. | Validate backend build, tests, and package build path. |
| `apps/backend/test/test_backend.ml` | Modified | Add focused projection, sanitization, CLI mode wiring, and notification tests near existing Runtime State tests. | Keep additions targeted; do not split the large file unless separately requested. |
| `CONTEXT.md` and `docs/adr/` | Possibly modified during implementation | Runtime semantics may change because default Terminal Console behavior changes. | Update only if implementation adds or changes domain language/runtime semantics. |

## Testing Approach

### Unit Tests

- `Terminal_console_model.of_runtime_state`:
  - empty/idle Runtime State;
  - running work;
  - retrying work;
  - issue errors / attention conditions;
  - Readiness Gaps;
  - Ordered Queue states and skip reasons;
  - Compozy PRD Run progress;
  - Goal Usage and context status summaries.
- `Terminal_console_model.sanitize`:
  - strips ANSI escape sequences;
  - removes control characters except safe whitespace;
  - preserves readable Unicode where supported;
  - never emits secret values from known token fields.
- UI reducer/key handling:
  - navigation changes UI-only state;
  - filter changes UI-only state;
  - refresh does not call tracker polling or lifecycle mutation;
  - Web Dashboard handoff returns guidance only.

### Integration Tests

- Default Terminal Console mode wiring:
  - `--once` does not start Mosaic;
  - `--web` keeps existing Web Dashboard behavior;
  - readiness-blocked Terminal Console renders readiness state without starting orchestration;
  - normal Terminal Console mode passes `notify_state` snapshots to the UI runtime.
- Existing Runtime State endpoint tests remain valid.
- Existing Web Dashboard live-state tests remain valid because no Runtime State schema changes are planned.

### Manual / Smoke Validation

- Run `symphony` in a Workspace Repository with:
  - no Readiness Gaps;
  - Readiness Gaps;
  - Ordered Queue;
  - Compozy-backed Local Issue Tracker;
  - running/retrying tasks.
- Validate terminal restore on quit, `Ctrl+C`, and orchestrator completion.
- Validate rendering at 80x24, 120x40, and a wide terminal.
- Validate `NO_COLOR` behavior and at least one terminal multiplexer.

## Development Sequencing

### Build Order

1. Add `Terminal_console_model` projection and sanitization in the backend library — no new implementation dependencies.
2. Add unit tests for projection and sanitization — depends on step 1.
3. Add Mosaic dependency metadata and a minimal `Terminal_console_mosaic` shell in the backend executable — depends on step 1 so the shell can render a projected snapshot.
4. Wire default Terminal Console mode in `main.ml` to run Mosaic in the foreground and orchestration in a background thread — depends on steps 1 and 3.
5. Add synchronized state handoff from `Orchestrator.make ~notify_state` to the Mosaic loop — depends on step 4.
6. Implement Active Work Home View, Readiness panel, Ordered Queue panel, Compozy panel, and task detail panel — depends on steps 1, 3, and 5.
7. Implement UI-only navigation, filtering, help/footer, refresh redraw, Web Dashboard handoff, and path inspection safe aids — depends on step 6.
8. Add runtime-loop integration tests and smoke fixtures for default mode, readiness-blocked mode, `--once`, and `--web` — depends on steps 4, 5, and 7.
9. Update documentation and domain ADRs if implementation changes runtime semantics or product language — depends on steps 4 and 7.
10. Run final validation: `pnpm backend:build`, `pnpm test`, and package/build checks required by dependency changes — depends on steps 3 through 9.

### Technical Dependencies

- Mosaic package availability for the supported OCaml switch.
- Dune version compatibility with Mosaic metadata.
- Existing thread support in backend Dune files.
- Existing `Orchestrator.notify_state` behavior.
- Terminal support for interactive rendering, resize, and cleanup.

## Monitoring and Observability

- Reuse Runtime State as the primary observable state source.
- Emit existing startup/status stderr events outside the full-screen UI when possible without corrupting terminal rendering.
- Surface UI-local status messages for safe aids: refresh, filter changes, handoff guidance, invalid path, and unavailable action.
- Add debug-friendly logs only around Terminal Console startup, shutdown, dependency/runtime failures, and state handoff failures.
- Do not log secret values, full unbounded agent output, or raw terminal escape input.
- MVP success metrics are product measurements rather than backend alerts: active-state comprehension time, Web Dashboard fallback reduction, safe-aid keystrokes, and boundary integrity.

## Technical Considerations

### Key Decisions

- **Decision:** Run Mosaic in-process with background orchestration.
  - **Rationale:** Preserves a single default `symphony` process and reuses `notify_state`.
  - **Trade-off:** Adds thread/event-loop coordination complexity.
  - **Alternatives rejected:** separate terminal client, child process, static console.

- **Decision:** Add Mosaic directly.
  - **Rationale:** Matches the feature intent and keeps the UI in OCaml.
  - **Trade-off:** Requires build metadata and likely Dune version updates.
  - **Alternatives rejected:** defer dependency, Matrix-only, non-OCaml TUI.

- **Decision:** Use a pure view-model projection.
  - **Rationale:** Centralizes sanitization and keeps Mosaic widgets thin.
  - **Trade-off:** Adds a translation layer that must stay aligned with Runtime State.
  - **Alternatives rejected:** render raw Runtime State, reuse frontend JSON shapes, persist UI state.

- **Decision:** Keep safe aids non-mutating in MVP.
  - **Rationale:** Preserves PRD boundary and prevents a parallel orchestration control plane.
  - **Trade-off:** Some command-center expectations move to later phases.
  - **Alternatives rejected:** retry/pause/resume/merge/push/status controls in MVP.

### Known Risks

- **Mosaic dependency and Dune upgrade risk**: Prototype the dependency update early and validate backend/package builds before UI work expands.
- **UI/orchestrator race conditions**: Use immutable snapshots and a small synchronized state handoff. Avoid arbitrary sleeps or polling delays as synchronization workarounds.
- **Terminal cleanup failures**: Wrap Mosaic runtime setup/teardown and test signal/error paths where feasible.
- **Projection drift from Runtime State**: Keep fixture tests near existing Runtime State tests and add cases whenever Runtime State display fields change.
- **Unsafe display content**: Sanitize once at projection boundaries and test malicious issue titles, branch names, task text, and agent messages.
- **Scope creep into lifecycle controls**: Keep lifecycle action functions outside the Mosaic MVP module and make unavailable actions explicit in UI copy.

## Architecture Decision Records

- [ADR-001: Scope Mosaic Terminal Console as a Runtime State command center](adrs/adr-001.md) — V1 is read-first over Runtime State with only narrow safe controls through explicit command boundaries.
- [ADR-002: Make the read-first Terminal Console with safe local aids the MVP approach](adrs/adr-002.md) — The richer Terminal Console is the default experience for `symphony` runs, with no task lifecycle mutation in MVP.
- [ADR-003: Run Mosaic in-process with Orchestrator Runtime State callbacks](adrs/adr-003.md) — Mosaic owns the foreground Terminal Console while orchestration runs in a background thread and sends Runtime State snapshots through `notify_state`.
- [ADR-004: Add Mosaic as the direct Terminal Console dependency](adrs/adr-004.md) — The MVP adopts Mosaic directly and plans the required Dune/opam metadata changes.
- [ADR-005: Use a pure Terminal Console view-model projection](adrs/adr-005.md) — Mosaic views render a sanitized view model derived from Runtime State instead of raw orchestration state.
