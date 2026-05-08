---
status: completed
title: "Add Runtime Settings Schema For Harnesses And Logical Agents"
type: backend
complexity: high
dependencies: []
---

# Task 01: Add Runtime Settings Schema For Harnesses And Logical Agents

## Overview
This task adds the backend Runtime Settings data model for first-class `harnesses` and logical `agents`. It establishes the schema foundation that later resolution, launch, Runtime State, Bootstrap, and docs tasks depend on.

<critical>
- ALWAYS READ the PRD and TechSpec before starting
- REFERENCE TECHSPEC for implementation details — do not duplicate here
- FOCUS ON "WHAT" — describe what needs to be accomplished, not how
- MINIMIZE CODE — show code only to illustrate current structure or problem areas
- TESTS REQUIRED — every task MUST include tests in deliverables
</critical>

<requirements>
- MUST add Harness loop fields for `loop.enabled` and `loop.command`.
- MUST add a logical agent model with `harness` plus optional execution overrides.
- MUST parse top-level `harnesses` as execution backend definitions.
- MUST parse top-level `agents` as logical agent definitions.
- MUST support `codex`, `claude`, and `pi` Harness kinds at the schema level.
- MUST keep legacy top-level `codex` parsing available for follow-up compatibility handling.
</requirements>

## Subtasks
- [x] 1.1 Extend `Config` data models for Harness loop configuration.
- [x] 1.2 Add a logical agent record for settings-level agent definitions.
- [x] 1.3 Parse `harnesses.codex`, `harnesses.claude`, and `harnesses.pi`.
- [x] 1.4 Parse `agents.<name>.harness` and optional per-agent execution overrides.
- [x] 1.5 Add targeted config parsing tests for the new schema.
- [x] 1.6 Preserve existing compilation for callers that still reference current config fields until later tasks migrate them.

## Implementation Details
Modify the Runtime Settings parsing model in `apps/backend/lib/config.ml`. Reference the TechSpec "Data Models" and "Core Interfaces" sections for the intended schema and keep the implementation close to existing JSON parsing helpers.

### Relevant Files
- `apps/backend/lib/config.ml` — owns Runtime Settings types, JSON helpers, legacy Codex parsing, current Agent Harness parsing, and default Harness values.
- `apps/backend/test/test_backend.ml` — contains existing config parsing and Agent Harness tests near the current `agents.*` cases.
- `.compozy/tasks/claude-code-harness-integration/_techspec.md` — defines the schema and merge expectations this task starts.

### Dependent Files
- `apps/backend/lib/orchestrator.ml` — later tasks need resolved Harness loop fields during prompt composition and launch.
- `apps/backend/lib/runtime_home.ml` — later Bootstrap defaults need the new schema.
- `README.md` and `CONTEXT.md` — later docs must describe the new Runtime Contract vocabulary.

### Related ADRs
- [ADR-001: First-Class Harness Runtime Settings](adrs/adr-001.md) — Defines `harnesses`, logical `agents`, and explicit Harness loop configuration.
- [ADR-003: Runtime Settings Resolution and Loop Semantics](adrs/adr-003.md) — Defines the schema relationship between stages, logical agents, and Harnesses.

## Deliverables
- Updated backend config data models for Harnesses and logical agents.
- Parser support for `harnesses` and logical `agents`.
- Focused backend tests covering representative schema examples.
- Unit tests with 80%+ coverage **(REQUIRED)**
- Integration tests for Runtime Settings parsing compatibility **(REQUIRED)**

## Tests
- Unit tests:
  - [x] Parse `harnesses.codex.loop.enabled: true` and `loop.command: "/goal"`.
  - [x] Parse `harnesses.claude.kind: "claude"` with a `stream-json` command.
  - [x] Parse `harnesses.pi.kind: "pi"` with the existing PI command shape.
  - [x] Parse `agents.planner.harness`, `model`, `reasoningEffort`, and timeout overrides.
  - [x] Parse an agent with only `harness` and leave execution overrides absent.
- Integration tests:
  - [x] Loading a representative mixed-Harness `settings.json` succeeds without dispatching work.
  - [x] Loading a legacy top-level `codex` settings fixture still succeeds for compatibility input.
- Test coverage target: >=80%
- All tests must pass

## Success Criteria
- All tests passing
- Test coverage >=80%
- Runtime Settings can represent first-class Harnesses and logical agents.
- No task outside config parsing is required to understand the raw JSON schema.
