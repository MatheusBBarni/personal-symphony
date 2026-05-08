---
status: completed
title: "Add Runtime Invocation Override Model And Apply Helper"
type: backend
complexity: medium
dependencies: []
---

# Task 01: Add Runtime Invocation Override Model And Apply Helper

## Overview
This task adds the transient model that represents Runtime Settings Invocation Overrides and the helper that applies those values to a loaded `Config.t`. It establishes the shared effective-config behavior that later CLI and runtime tasks will use without changing Runtime Settings file parsing or writing `.symphony/settings.json`.

<critical>
- ALWAYS READ the PRD and TechSpec before starting
- REFERENCE TECHSPEC for implementation details — do not duplicate here
- FOCUS ON "WHAT" — describe what needs to be accomplished, not how
- MINIMIZE CODE — show code only to illustrate current structure or problem areas
- TESTS REQUIRED — every task MUST include tests in deliverables
</critical>

<requirements>
- MUST define a transient override model for the five issue-66 fields only.
- MUST provide one helper that copies a loaded `Config.t` and replaces only supplied override fields.
- MUST preserve all Runtime Settings values when corresponding overrides are absent.
- MUST resolve `workspace.root` override values with the same path behavior used by Runtime Settings.
- MUST NOT rewrite `.symphony/settings.json` or change Bootstrap defaults.
</requirements>

## Subtasks
- [x] 1.1 Add a transient Runtime Settings Invocation Override model.
- [x] 1.2 Add an apply helper that returns one effective `Config.t`.
- [x] 1.3 Preserve all non-overridden config fields exactly.
- [x] 1.4 Reuse the existing Workspace Repository-relative path behavior for `workspace.root`.
- [x] 1.5 Add focused tests for field replacement, missing overrides, and path resolution.

## Implementation Details
Modify `apps/backend/lib/config.ml` or add a small adjacent backend module if that keeps the helper clearer. Reference the TechSpec "Core Interfaces" and "Data Models" sections for the intended record shape and field mapping. Keep the helper independent from Cmdliner so it can be tested without CLI parsing.

### Relevant Files
- `apps/backend/lib/config.ml` — defines `Config.t`, `polling`, `workspace`, `agent`, `expand_path`, and current Runtime Settings parsing.
- `apps/backend/test/test_backend.ml` — existing config and runtime-home tests live here.
- `apps/backend/lib/dune` — may need updates if the helper is placed in a new module with no extra library dependencies.

### Dependent Files
- `apps/backend/bin/main.ml` — later tasks will call the helper after settings load.
- `apps/backend/test/dune` — later CLI tests may need dependency changes, but this task should avoid unnecessary test stanza churn.

### Related ADRs
- [ADR-001: Narrow Runtime Settings Invocation Overrides](adrs/adr-001.md) — Defines the fixed allowlist and current-process behavior.
- [ADR-003: Post-Load Runtime Override Application](adrs/adr-003.md) — Selects post-load config-copy override application.

## Deliverables
- Transient override model for the five allowed fields.
- Effective config apply helper that copies `Config.t`.
- Unit tests with 80%+ coverage **(REQUIRED)**
- Integration tests for Runtime Settings path behavior **(REQUIRED)**

## Tests
- Unit tests:
  - [ ] Supplying only `polling_interval_ms` changes `config.polling.interval_ms` and preserves all agent/workspace values.
  - [ ] Supplying only `agent_max_concurrent_agents`, `agent_max_turns`, and `agent_max_retry_backoff_ms` changes only those agent fields.
  - [ ] Supplying no overrides returns a config with equivalent field values.
  - [ ] Supplying relative `workspace_root` resolves under the Workspace Repository root.
  - [ ] Supplying absolute and home-relative `workspace_root` values follows existing Runtime Settings behavior.
- Integration tests:
  - [ ] Applying overrides never changes the contents of the input settings file fixture.
- Test coverage target: >=80%
- All tests must pass

## Success Criteria
- All tests passing
- Test coverage >=80%
- Effective config replacement covers all five override fields.
- Runtime Settings parsing remains unchanged for callers that do not use overrides.
