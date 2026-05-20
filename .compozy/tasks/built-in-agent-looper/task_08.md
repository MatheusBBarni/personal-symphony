---
status: pending
title: "Gate completion on evidence with retry and Human Attention routing"
type: backend
complexity: critical
dependencies:
  - task_06
  - task_07
---

# Task 08: Gate completion on evidence with retry and Human Attention routing

## Overview
This task implements the highest-risk behavior change: Goal Loop-enabled tasks cannot enter existing completion behavior until deterministic evidence passes. Evidence failures retry with missing-evidence guidance until the configured retry limit is exhausted, then move to Human Attention before Stage Commit or status changes.

<critical>
- ALWAYS READ the PRD and TechSpec before starting
- REFERENCE TECHSPEC for implementation details — do not duplicate here
- FOCUS ON "WHAT" — describe what needs to be accomplished, not how
- MINIMIZE CODE — show code only to illustrate current structure or problem areas
- TESTS REQUIRED — every task MUST include tests in deliverables
</critical>

<requirements>
- REQ-01 MUST run evidence evaluation before `mark_completed` proceeds for Goal Loop-enabled stages.
- REQ-02 MUST allow existing completion behavior only after evidence succeeds.
- REQ-03 MUST retry evidence failures with missing-evidence guidance while the configured retry budget remains available.
- REQ-04 MUST move the task to Human Attention after retry exhaustion before Stage Commit/status changes.
- REQ-05 MUST preserve existing behavior for non-Goal Loop tasks.
- REQ-06 MUST persist terminal `goal_met`, `needs_attention`, and `budget_exhausted` states.
</requirements>

## Subtasks
- [ ] 8.1 Add the evidence gate before the existing completion path.
- [ ] 8.2 Route evidence success to existing completion behavior.
- [ ] 8.3 Route evidence failure to retry with guidance when budget remains.
- [ ] 8.4 Route exhausted evidence failures to Human Attention.
- [ ] 8.5 Add regression tests for Stage Commit, status, auto-merge, PR, and non-enabled tasks.

## Implementation Details
Use the TechSpec "Executive Summary" and "Integration Points" sections. This task modifies completion semantics only for Goal Loop-enabled stages and must be reviewed carefully against existing `mark_completed`, `mark_retrying`, and attention paths.

### Relevant Files
- `apps/backend/lib/orchestrator.ml` — owns `reap_children`, `mark_completed`, `mark_retrying`, `mark_blocked`, and Human Attention routing.
- `apps/backend/lib/runtime_state.ml` — exposes terminal Goal Loop outcomes.
- `apps/backend/lib/config.ml` — provides stage config and retry/budget settings.
- `apps/backend/test/test_backend.ml` — existing completion, retry, Goal Usage, and attention tests.

### Dependent Files
- `apps/backend/lib/terminal_console_model.ml` — task_09 renders terminal states produced here.
- `apps/frontend/src/RuntimeStateSnapshot.res` — task_10 renders terminal states produced here.
- `CONTEXT.md` and README — task_11 documents evidence gating behavior.

### Related ADRs
- [ADR-002: Evidence-First Goal Loop Approach](adrs/adr-002.md) — Requires evidence-backed Goal met outcomes.
- [ADR-004: Evidence Command Completion Gate](adrs/adr-004.md) — Defines retry then Human Attention behavior.

## Deliverables
- Evidence-gated completion path for Goal Loop-enabled stages.
- Retry guidance for missing or failed evidence.
- Human Attention routing after retry exhaustion.
- Regression tests for existing completion behavior.
- Unit tests with 80%+ coverage **(REQUIRED)**.
- Integration tests for the full evidence gate lifecycle **(REQUIRED)**.

## Tests
- Unit tests:
  - [ ] Agent exit `0` plus passing evidence records `goal_met` and calls existing completion path.
  - [ ] Agent exit `0` plus failing evidence schedules retry when retry budget remains.
  - [ ] Retry includes missing-evidence guidance for the next attempt.
  - [ ] Evidence failure after retry exhaustion records `needs_attention`.
  - [ ] Non-Goal Loop task exit `0` follows existing completion behavior unchanged.
- Integration tests:
  - [ ] Stage Commit is not attempted before evidence succeeds.
  - [ ] Status transition is not attempted before evidence succeeds.
  - [ ] Auto-merge and PR handoff behavior remains downstream of successful evidence.
  - [ ] Human Attention appears in Runtime State for exhausted evidence failures.
- Test coverage target: >=80%
- All tests must pass

## Success Criteria
- All tests passing
- Test coverage >=80%
- `Goal met` cannot occur without deterministic evidence.
- Evidence failures never silently complete existing delivery behavior.
