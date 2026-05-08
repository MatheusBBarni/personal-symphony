---
status: completed
title: "Resolve Stage Agents Through Logical Agents And Add Migration Readiness Diagnostics"
type: backend
complexity: high
dependencies:
  - task_01
---

# Task 02: Resolve Stage Agents Through Logical Agents And Add Migration Readiness Diagnostics

## Overview
This task changes the selected Harness resolution path from direct stage-level Harness selection to stage -> logical agent -> Harness. It also adds the blocking readiness diagnostics required for legacy harness-shaped `agents.*` and stage-level `harness` settings.

<critical>
- ALWAYS READ the PRD and TechSpec before starting
- REFERENCE TECHSPEC for implementation details — do not duplicate here
- FOCUS ON "WHAT" — describe what needs to be accomplished, not how
- MINIMIZE CODE — show code only to illustrate current structure or problem areas
- TESTS REQUIRED — every task MUST include tests in deliverables
</critical>

<requirements>
- MUST resolve `stageAgents.stages[].agent` to `agents.<name>`.
- MUST resolve `agents.<name>.harness` to `harnesses.<name>`.
- MUST merge agent execution overrides over Harness defaults field-by-field.
- MUST treat `stageAgents.stages[].harness` as legacy input that produces migration diagnostics.
- MUST treat legacy harness-shaped `agents.*` settings as a readiness migration problem.
- MUST keep selected-Harness readiness scoped to Harnesses used by enabled Stage Agents.
</requirements>

## Subtasks
- [x] 2.1 Add a resolved Harness helper that follows stage -> logical agent -> Harness.
- [x] 2.2 Implement field-by-field agent override merging.
- [x] 2.3 Update selected-Harness readiness to use logical agent selection.
- [x] 2.4 Add readiness gaps for stage-level `harness` usage.
- [x] 2.5 Add readiness gaps for legacy harness-shaped `agents.*` entries.
- [x] 2.6 Update existing PI Harness readiness tests to use `harnesses` and logical `agents`.

## Implementation Details
Modify `apps/backend/lib/config.ml` around current `stage_harness_name`, `selected_agent_harness`, `readiness_agent_harnesses`, and readiness gap generation. Reference the TechSpec "System Architecture" and "Technical Considerations" sections for the accepted resolution path.

### Relevant Files
- `apps/backend/lib/config.ml` — owns selected Harness resolution and readiness diagnostics.
- `apps/backend/test/test_backend.ml` — contains existing launch selection, Agent Harness readiness, and PI selected-Harness tests.
- `.compozy/tasks/claude-code-harness-integration/adrs/adr-003.md` — defines the accepted stage -> agent -> Harness rule.

### Dependent Files
- `apps/backend/lib/orchestrator.ml` — dispatch and launch use `Config.selected_agent_harness`.
- `apps/backend/lib/runtime_state.ml` — later tasks need selected Harness identity in running rows.
- `apps/backend/lib/runtime_home.ml` — Bootstrap defaults must avoid legacy stage-level Harness settings.

### Related ADRs
- [ADR-001: First-Class Harness Runtime Settings](adrs/adr-001.md) — Requires readiness errors for ambiguous legacy config.
- [ADR-002: Clarity-First PRD Scope](adrs/adr-002.md) — Chooses blocking migration diagnostics over warnings.
- [ADR-003: Runtime Settings Resolution and Loop Semantics](adrs/adr-003.md) — Defines resolution and override semantics.

## Deliverables
- Stage -> logical agent -> Harness resolution.
- Agent override merge behavior.
- Readiness gaps for legacy `agents.*` Harness definitions and stage-level `harness`.
- Updated backend tests for resolution and migration diagnostics.
- Unit tests with 80%+ coverage **(REQUIRED)**
- Integration tests for selected-Harness readiness **(REQUIRED)**

## Tests
- Unit tests:
  - [x] Stage `agent: "engineer"` resolves through `agents.engineer.harness: "claude"`.
  - [x] Agent `model` overrides Harness `model` while missing timeouts inherit from the Harness.
  - [x] Unknown logical agent produces a readiness gap naming the missing `agents.<name>`.
  - [x] Unknown Harness reference produces a readiness gap naming the missing `harnesses.<name>`.
  - [x] Stage-level `harness` produces a migration readiness gap.
  - [x] Legacy harness-shaped `agents.pi.kind` produces a migration readiness gap.
- Integration tests:
  - [x] Selected PI readiness checks run only when a logical agent selects the PI Harness.
  - [x] Unselected PI and Claude Harness definitions do not block dispatch.
- Test coverage target: >=80%
- All tests must pass

## Success Criteria
- All tests passing
- Test coverage >=80%
- Stages no longer own steady-state Harness selection.
- Legacy ambiguous Runtime Settings are reported before dispatch.
