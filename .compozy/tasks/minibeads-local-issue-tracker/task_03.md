---
status: pending
title: "Add minibeads CLI readiness and diagnostics"
type: backend
complexity: medium
dependencies:
  - task_01
  - task_02
---

# Task 03: Add minibeads CLI readiness and diagnostics

## Overview
Add the minibeads adapter skeleton and readiness diagnostics for the `mb` CLI and local issue store. This task makes local tracker failures actionable before any dispatch logic depends on minibeads issue data.

<critical>
- ALWAYS READ the PRD and TechSpec before starting
- REFERENCE TECHSPEC for implementation details — do not duplicate here
- FOCUS ON "WHAT" — describe what needs to be accomplished, not how
- MINIMIZE CODE — show code only to illustrate current structure or problem areas
- TESTS REQUIRED — every task MUST include tests in deliverables
</critical>

<requirements>
- R1 MUST add a minibeads tracker adapter that is selected by `tracker.kind = "minibeads"`.
- R2 MUST check that the configured `mb` command is available to the Symphony process.
- R3 MUST report missing `.beads` or local issue store state as Readiness Gaps.
- R4 MUST treat `mb` command output and failures as untrusted diagnostics.
- R5 MUST NOT parse full issue data or perform status updates in this task.
</requirements>

## Subtasks
- [ ] 3.1 Add a minibeads adapter module with command runner injection for tests.
- [ ] 3.2 Add readiness checks for missing `mb` command.
- [ ] 3.3 Add readiness checks for missing local issue store.
- [ ] 3.4 Add deterministic diagnostic messages for command failures.
- [ ] 3.5 Add tests using fake command runner behavior.

## Implementation Details
Follow TechSpec "Integration Points: minibeads CLI". Keep the command rooted in the Workspace Repository. Full fetch/lookup/status mapping belongs to task_04.

### Relevant Files
- `apps/backend/lib/minibeads_tracker.ml` — New adapter module for minibeads CLI readiness.
- `apps/backend/lib/issue_tracker.ml` — Selected tracker boundary that will expose readiness gaps.
- `apps/backend/lib/config.ml` — Supplies minibeads command/root settings.
- `apps/backend/lib/util.ml` — Existing utility patterns for filesystem and environment helpers.
- `apps/backend/test/test_backend.ml` — Add fake command runner tests near tracker/config tests.

### Dependent Files
- `apps/backend/lib/runtime_state.ml` — Readiness gap shape is surfaced through Runtime State.
- `apps/backend/bin/main.ml` — Later startup readiness will include selected tracker gaps.
- `README.md` — Later docs will explain readiness remediations.

### Related ADRs
- [ADR-003: Introduce a shared Issue Tracker boundary](adrs/adr-003.md) — minibeads adapter plugs into the boundary.
- [ADR-004: Use the mb CLI as the minibeads integration boundary](adrs/adr-004.md) — CLI is the integration contract.

## Deliverables
- minibeads adapter skeleton wired into Issue Tracker selection.
- Readiness gaps for missing command and local issue store.
- Deterministic sanitized diagnostics for minibeads command failures.
- Unit tests with 80%+ coverage **(REQUIRED)**
- Integration tests for minibeads readiness behavior **(REQUIRED)**

## Tests
- Unit tests:
  - [ ] Missing `mb` command produces `tracker.minibeads.command` readiness gap.
  - [ ] Missing local issue store produces `tracker.minibeads.store` readiness gap.
  - [ ] Nonzero `mb` readiness command output produces a sanitized diagnostic.
  - [ ] Valid fake readiness output produces no minibeads readiness gap.
- Integration tests:
  - [ ] Runtime readiness includes minibeads gaps without GitHub owner/repo/project/token gaps.
- Test coverage target: >=80%
- All tests must pass

## Success Criteria
- All tests passing
- Test coverage >=80%
- minibeads readiness failures are actionable before orchestration dispatch starts.
