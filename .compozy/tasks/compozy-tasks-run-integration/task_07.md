---
status: pending
title: "Add sequential task-step orchestration in one worktree"
type: backend
complexity: critical
dependencies:
  - task_04
  - task_06
---

# Task 07: Add sequential task-step orchestration in one worktree

## Overview
Extend orchestration so a Compozy PRD run can execute multiple task-step launches in the same Agent Worktree and Task Branch. Intermediate task-step completion must update task frontmatter and relaunch the next step without triggering final branch integration.

<critical>
- ALWAYS READ the PRD and TechSpec before starting
- REFERENCE TECHSPEC for implementation details — do not duplicate here
- FOCUS ON "WHAT" — describe what needs to be accomplished, not how
- MINIMIZE CODE — show code only to illustrate current structure or problem areas
- TESTS REQUIRED — every task MUST include tests in deliverables
</critical>

<requirements>
- R1 MUST keep all task steps for one PRD run in the same Agent Worktree and Task Branch.
- R2 MUST mark a successful intermediate task step completed in task frontmatter.
- R3 MUST relaunch the next runnable task step in the same worktree and branch.
- R4 MUST defer Stage Commit, Stage Push, Task Branch Integration, and cleanup until PRD-run final completion.
- R5 MUST preserve GitHub issue completion behavior.
- R6 MUST expose current-step progress through Runtime State during relaunches.
</requirements>

## Subtasks
- [ ] 7.1 Identify Compozy PRD-run children separately from normal GitHub issue children.
- [ ] 7.2 Add intermediate task-step completion handling before final completion.
- [ ] 7.3 Reuse the existing Agent Worktree and Task Branch for the next task step.
- [ ] 7.4 Update Runtime State progress between task-step launches.
- [ ] 7.5 Ensure final completion uses existing Stage Commit, Stage Push, and integration behavior.
- [ ] 7.6 Add orchestration tests for same-worktree sequential execution.

## Implementation Details
Reference TechSpec "Git" and "Build Order" steps 7-8. This is the highest-risk task because it touches the completion path in `orchestrator.ml`; keep edits tightly scoped and regression-test existing completion behavior.

### Relevant Files
- `apps/backend/lib/orchestrator.ml` — Dispatch, child completion, retry, workspace preparation, and Task Branch integration.
- `apps/backend/lib/compozy_tasks_tracker.ml` — Selects current/next task step and updates task frontmatter.
- `apps/backend/lib/workspace.ml` — Existing workspace creation behavior for issue identifiers.
- `apps/backend/test/test_backend.ml` — Existing orchestrator completion, worktree reuse, stage commit, and auto-merge tests.

### Dependent Files
- `apps/backend/lib/runtime_state.ml` — Carries Compozy progress updates.
- `apps/backend/lib/config.ml` — Supplies selected tracker kind.
- `apps/backend/bin/main.ml` — Routes Compozy runs into orchestration.

### Related ADRs
- [ADR-002: Treat a Compozy PRD run as the local issue](adrs/adr-002.md) — Requires one worktree per PRD run.
- [ADR-005: Relaunch task steps sequentially in one worktree](adrs/adr-005.md) — Defines sequential relaunch behavior.
- [ADR-003: Add a narrow Compozy tracker path](adrs/adr-003.md) — Allows Compozy-specific orchestration flow.

## Deliverables
- Sequential Compozy task-step orchestration.
- Same worktree and Task Branch across task steps.
- Final completion delayed until PRD-run completion.
- Unit tests with 80%+ coverage **(REQUIRED)**
- Integration tests for multi-step Compozy PRD run **(REQUIRED)**

## Tests
- Unit tests:
  - [ ] Intermediate task-step completion does not call final branch integration.
  - [ ] Next task step uses the same workspace path and Task Branch.
  - [ ] Final task-step completion calls existing final completion behavior.
  - [ ] GitHub issue completion behavior remains unchanged.
- Integration tests:
  - [ ] Two-task Compozy PRD run completes both task files in one Agent Worktree.
  - [ ] Runtime State shows current step changing from `task_01.md` to `task_02.md`.
- Test coverage target: >=80%
- All tests must pass

## Success Criteria
- All tests passing
- Test coverage >=80%
- Compozy PRD runs execute sequential task steps in one worktree.
- Final integration never happens before the PRD run is complete.
