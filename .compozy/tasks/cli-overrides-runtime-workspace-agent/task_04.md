---
status: completed
title: "Wire Effective Config Through Runtime Startup"
type: backend
complexity: medium
dependencies:
  - task_01
  - task_03
---

# Task 04: Wire Effective Config Through Runtime Startup

## Overview
This task passes parsed override values through runtime startup and applies them after Runtime Settings load. It ensures readiness checks, Web Dashboard, Terminal Console, Manual Task Merge, and orchestration all receive the same effective config for the current process.

<critical>
- ALWAYS READ the PRD and TechSpec before starting
- REFERENCE TECHSPEC for implementation details — do not duplicate here
- FOCUS ON "WHAT" — describe what needs to be accomplished, not how
- MINIMIZE CODE — show code only to illustrate current structure or problem areas
- TESTS REQUIRED — every task MUST include tests in deliverables
</critical>

<requirements>
- MUST pass parsed override values through default runtime startup.
- MUST apply overrides after `Runtime_home.require_workspace_root`, Bootstrap, and Runtime Settings load.
- MUST apply overrides before readiness checks, startup reporting, Web Dashboard, Terminal Console, Manual Task Merge, or orchestration use config.
- MUST keep `.symphony/settings.json` byte-for-byte unchanged after startup with overrides.
- MUST preserve existing behavior when no overrides are supplied.
</requirements>

## Subtasks
- [x] 4.1 Add override pass-through to runtime command execution.
- [x] 4.2 Apply task_01's helper immediately after settings load.
- [x] 4.3 Ensure startup reporting and runtime modes use the effective config.
- [x] 4.4 Add settings-preservation coverage for override startup.
- [x] 4.5 Add root-validation-before-override coverage for `--workspace.root`.

## Implementation Details
Modify the runtime startup flow described in the TechSpec "System Architecture" and "Development Sequencing" sections. Keep Workspace Repository root validation before any override application. This task should not add new runtime consumer behavior beyond ensuring existing consumers receive the effective config object.

### Relevant Files
- `apps/backend/bin/main.ml` or extracted CLI runtime module — currently owns `load_runtime_config`, `run_runtime`, and `run`.
- `apps/backend/lib/runtime_home.ml` — owns root validation, Bootstrap paths, and settings path.
- `apps/backend/lib/config.ml` — owns `Config.t` and task_01's apply helper.
- `apps/backend/test/test_backend.ml` — runtime-home and CLI tests belong here.

### Dependent Files
- `apps/backend/lib/server.ml` — Web Dashboard uses config passed through startup.
- `apps/backend/lib/manual_merge.ml` — Manual Task Merge uses the effective `workspace.root`.
- `apps/backend/lib/orchestrator.ml` — orchestration uses effective polling, workspace, concurrency, and retry backoff values.

### Related ADRs
- [ADR-003: Post-Load Runtime Override Application](adrs/adr-003.md) — Requires overrides to apply after settings load by copying the config.
- [ADR-001: Narrow Runtime Settings Invocation Overrides](adrs/adr-001.md) — Requires current-process behavior and no Runtime Contract writes.

## Deliverables
- Runtime startup accepts parsed overrides and applies them after settings load.
- Existing runtime modes receive effective config.
- Unit tests with 80%+ coverage **(REQUIRED)**
- Integration tests for runtime startup and settings preservation **(REQUIRED)**

## Tests
- Unit tests:
  - [x] Runtime startup with no overrides uses the loaded settings values.
  - [x] Runtime startup with multiple overrides produces an effective config containing all supplied values.
  - [x] Startup reporting uses the effective workspace root after `--workspace.root`.
- Integration tests:
  - [x] A `--once` startup with overrides leaves `.symphony/settings.json` byte-for-byte unchanged.
  - [x] Running outside a Workspace Repository with `--workspace.root /tmp/workspaces` still fails root validation.
  - [x] `--web --workspace.root /tmp/symphony-workspaces` passes the effective workspace root into Web Dashboard startup state.
  - [x] `--merge 66 --agent.maxConcurrentAgents 1` accepts the override and still follows Manual Task Merge semantics.
- Test coverage target: >=80%
- All tests must pass

## Success Criteria
- All tests passing
- Test coverage >=80%
- Overrides are applied only after Runtime Settings load.
- All runtime paths receive one effective config object.
