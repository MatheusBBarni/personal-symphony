---
status: completed
title: "Wire In-Process Terminal Console Runtime"
type: backend
complexity: high
dependencies:
  - task_02
---

# Task 03: Wire In-Process Terminal Console Runtime

## Overview
Wire the default Terminal Console mode so Mosaic owns the foreground terminal loop while orchestration runs in a background thread. This task changes the runtime shape for normal `symphony` runs while preserving non-interactive `--once`, Web Dashboard `--web`, readiness-blocked behavior, and manual merge behavior.

<critical>
- ALWAYS READ the PRD and TechSpec before starting
- REFERENCE TECHSPEC for implementation details — do not duplicate here
- FOCUS ON "WHAT" — describe what needs to be accomplished, not how
- MINIMIZE CODE — show code only to illustrate current structure or problem areas
- TESTS REQUIRED — every task MUST include tests in deliverables
</critical>

<requirements>
- MUST run the Mosaic Terminal Console in the foreground for default Terminal Console mode.
- MUST run `Orchestrator.run_forever` in a background thread when `Runtime_policy.action` permits orchestration.
- MUST pass Runtime State snapshots from `Orchestrator.make ~notify_state` into a thread-safe in-process state handoff.
- MUST render readiness Runtime State without starting orchestration when Readiness Gaps block dispatch.
- MUST preserve `--once` as validate-and-exit without Mosaic.
- MUST preserve `--web` Web Dashboard behavior and must not start the Web Dashboard server in default Terminal Console mode.
- MUST NOT add task lifecycle mutation controls.
</requirements>

## Subtasks
- [x] 3.1 Add a runtime coordination seam for starting the Terminal Console UI with an initial Runtime State.
- [x] 3.2 Add a synchronized Runtime State handoff from `notify_state` to the UI runtime.
- [x] 3.3 Start orchestration in a background thread only when runtime policy allows dispatch.
- [x] 3.4 Preserve readiness-blocked Terminal Console rendering without orchestrator startup.
- [x] 3.5 Preserve existing `--once`, `--web`, and manual merge branches.
- [x] 3.6 Add focused tests for mode selection, state handoff, and non-mutating behavior.

## Implementation Details
Modify `apps/backend/bin/main.ml` and, if useful, add a small executable-side runtime module. Reference the TechSpec "Data Flow", "Readiness-Blocked Flow", and "Development Sequencing" sections. Use the existing Web Dashboard branch as evidence that `notify_state` can drive another foreground surface, but do not reuse the Live Dashboard Connection for Terminal Console commands.

Avoid timing workarounds. Use explicit synchronization primitives rather than sleeps for state handoff correctness.

### Relevant Files
- `apps/backend/bin/main.ml` — Current Terminal Console, Web Dashboard, readiness, `--once`, and orchestrator startup branching.
- `apps/backend/lib/orchestrator.ml` — Existing `notify_state`, `make`, `get_state`, and `run_forever` behavior.
- `apps/backend/lib/runtime_policy.ml` — Determines readiness-blocked versus run-orchestrator behavior.
- `apps/backend/lib/cli_mode.ml` — Current Terminal Console and Web Dashboard mode selection.
- `apps/backend/test/test_backend.ml` — Existing tests for CLI mode, Runtime Policy, and `notify_state` behavior.

### Dependent Files
- `apps/backend/bin/terminal_console_mosaic.ml` — Foreground UI runtime called by this task.
- `apps/backend/lib/terminal_console_model.ml` — Projection used to render initial and updated states.
- `apps/backend/lib/server.ml` — Must remain unchanged for Web Dashboard state endpoints.

### Related ADRs
- [ADR-001: Scope Mosaic Terminal Console as a Runtime State command center](adrs/adr-001.md) — Requires Runtime State as the visible source of truth.
- [ADR-002: Make the read-first Terminal Console with safe local aids the MVP approach](adrs/adr-002.md) — Keeps MVP non-mutating.
- [ADR-003: Run Mosaic in-process with Orchestrator Runtime State callbacks](adrs/adr-003.md) — Primary runtime decision implemented by this task.

## Deliverables
- Default Terminal Console runtime branch that starts Mosaic in the foreground.
- Background orchestration startup that uses `notify_state` for UI updates.
- Readiness-blocked Terminal Console path that does not start orchestration.
- Preservation of `--once`, `--web`, and manual merge behavior.
- Unit tests with 80%+ coverage for new runtime coordination helpers **(REQUIRED)**.
- Integration tests for default Terminal Console runtime wiring **(REQUIRED)**.

## Tests
- Unit tests:
  - [x] Runtime handoff stores the latest Runtime State snapshot without mutating it.
  - [x] Runtime handoff delivers repeated `notify_state` snapshots in deterministic order or latest-state semantics documented by the implementation.
  - [x] Readiness-blocked branch exposes the readiness Runtime State to the UI runtime and does not start orchestration.
- Integration tests:
  - [x] `--once` invokes existing non-interactive rendering and does not call the Mosaic runtime.
  - [x] `--web` starts existing Web Dashboard behavior and does not call the Mosaic runtime.
  - [x] Default Terminal Console mode starts the UI runtime and wires `notify_state` when runtime policy returns `Run_orchestrator`.
  - [x] Manual merge arguments still run one-shot Manual Task Merge instead of starting Mosaic.
- Test coverage target: >=80%
- All tests must pass

## Success Criteria
- All tests passing
- Test coverage >=80%
- Default `symphony` runtime uses the rich Terminal Console path.
- Web Dashboard and non-interactive CLI paths remain compatible.
- No task lifecycle mutation path is introduced by runtime wiring.
