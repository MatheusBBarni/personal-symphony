---
status: completed
title: "Support selected-tracker identifiers in Manual Task Merge"
type: backend
complexity: high
dependencies:
  - task_02
  - task_04
  - task_06
---

# Task 07: Support selected-tracker identifiers in Manual Task Merge

## Overview
Update Manual Task Merge to accept selected-tracker identifiers and resolve issues through the shared Issue Tracker. This removes GitHub Project membership as a requirement for minibeads merges while preserving existing clean-worktree and fast-forward-only integration behavior.

<critical>
- ALWAYS READ the PRD and TechSpec before starting
- REFERENCE TECHSPEC for implementation details — do not duplicate here
- FOCUS ON "WHAT" — describe what needs to be accomplished, not how
- MINIMIZE CODE — show code only to illustrate current structure or problem areas
- TESTS REQUIRED — every task MUST include tests in deliverables
</critical>

<requirements>
- R1 MUST accept `20`, `#20`, and `mb-<number>` selectors.
- R2 MUST resolve manual merge targets through the selected Issue Tracker.
- R3 MUST preserve existing Manual Task Merge preflight checks.
- R4 MUST not require GitHub Project membership for minibeads issues.
- R5 MUST update the selected tracker status after successful merge when a review success status exists.
</requirements>

## Subtasks
- [x] 7.1 Update Manual Task Merge selector model to canonical identifiers.
- [x] 7.2 Replace GitHub project issue fetch contract with selected tracker lookup.
- [x] 7.3 Preserve fast-forward, clean-worktree, protected path, and terminal-state preflight behavior.
- [x] 7.4 Route post-merge status updates through selected tracker.
- [x] 7.5 Add minibeads merge tests alongside existing GitHub merge tests.

## Implementation Details
Follow TechSpec "Component Overview" and "Development Sequencing" step 8. Keep Task Branch Integration behavior unchanged.

### Relevant Files
- `apps/backend/lib/manual_merge.ml` — Current numeric selector parsing, GitHub project issue lookup, preflight, and integration.
- `apps/backend/bin/main.ml` — CLI wiring for `--merge` and tracker dependencies.
- `apps/backend/lib/orchestrator.ml` — Task Branch naming, protected path checks, and integration helpers.
- `apps/backend/lib/workspace.ml` — Workspace key sanitization used by issue identifiers.
- `apps/backend/test/test_backend.ml` — Existing Manual Task Merge test cluster.

### Dependent Files
- `apps/backend/lib/issue_tracker.ml` — Provides selected tracker lookup/status update.
- `apps/backend/lib/ordered_queue.ml` — Identifier normalization precedent from task_06.
- `apps/backend/lib/config.ml` — Supplies selected tracker kind and status settings.

### Related ADRs
- [ADR-003: Introduce a shared Issue Tracker boundary](adrs/adr-003.md) — Manual merge resolves through selected tracker.
- [ADR-005: Keep PR handoff independent of tracker kind](adrs/adr-005.md) — Merge/status behavior remains tracker-selected.
- [ADR-006: Constrain V1 local identifiers and dashboard impact](adrs/adr-006.md) — Defines accepted local selector shape.

## Deliverables
- Manual Task Merge accepts minibeads selectors.
- Manual Task Merge no longer requires GitHub Project membership when minibeads is selected.
- Existing GitHub Manual Task Merge behavior remains unchanged.
- Unit tests with 80%+ coverage **(REQUIRED)**
- Integration tests for minibeads Manual Task Merge **(REQUIRED)**

## Tests
- Unit tests:
  - [x] `mb-20` selector normalizes successfully.
  - [x] malformed local selectors are rejected with clear messages.
  - [x] duplicate selectors are rejected by canonical identifier.
  - [x] selected tracker missing issue returns the existing missing-tracker diagnostic shape.
  - [x] minibeads terminal-state validation uses selected tracker semantics.
- Integration tests:
  - [x] Manual Task Merge fast-forwards a minibeads task branch and updates minibeads status through selected tracker.
  - [x] Existing GitHub Manual Task Merge tests still reject absent Project membership for GitHub tracker runs.
- Test coverage target: >=80%
- All tests must pass

## Success Criteria
- All tests passing
- Test coverage >=80%
- Operators can merge completed minibeads task work with `--merge mb-<number>`.
