---
status: pending
title: "Preserve pull request handoff for minibeads tracker runs"
type: backend
complexity: medium
dependencies:
  - task_01
  - task_05
---

# Task 09: Preserve pull request handoff for minibeads tracker runs

## Overview
Audit and update pull request handoff behavior so it remains available when minibeads is the selected Issue Tracker. PR handoff must not require GitHub Issues, GitHub Projects, or tracker token settings, while minibeads task status still updates through the selected tracker.

<critical>
- ALWAYS READ the PRD and TechSpec before starting
- REFERENCE TECHSPEC for implementation details — do not duplicate here
- FOCUS ON "WHAT" — describe what needs to be accomplished, not how
- MINIMIZE CODE — show code only to illustrate current structure or problem areas
- TESTS REQUIRED — every task MUST include tests in deliverables
</critical>

<requirements>
- R1 MUST keep existing PR handoff behavior available for minibeads tracker runs when PR settings are configured.
- R2 MUST not require GitHub Issues, GitHub Projects, or tracker token settings for minibeads PR handoff.
- R3 MUST route task status changes through the selected Issue Tracker.
- R4 MUST preserve non-force push behavior.
- R5 MUST keep existing GitHub PR handoff behavior unchanged.
</requirements>

## Subtasks
- [ ] 9.1 Audit PR handoff paths for `config.tracker.owner` and `config.tracker.repo` assumptions.
- [ ] 9.2 Decouple PR repository context from Issue Tracker fields where minibeads needs it.
- [ ] 9.3 Ensure PR handoff success/failure updates selected tracker status.
- [ ] 9.4 Add minibeads PR handoff tests without GitHub tracker settings.
- [ ] 9.5 Preserve existing PR handoff regression tests.

## Implementation Details
Follow TechSpec "GitHub Remote PR Handoff". Treat GitHub as a possible remote destination separately from GitHub as an Issue Tracker.

### Relevant Files
- `apps/backend/lib/orchestrator.ml` — Batch and task PR handoff behavior, status transitions, and retryable handoff failures.
- `apps/backend/lib/config.ml` — Pull request settings and tracker settings.
- `apps/backend/test/test_backend.ml` — Existing PR handoff tests.

### Dependent Files
- `apps/backend/lib/issue_tracker.ml` — Selected tracker status update path.
- `apps/backend/bin/main.ml` — Runtime config/readiness path for minibeads plus PR settings.
- `README.md` — Later docs should distinguish tracker from PR remote behavior.

### Related ADRs
- [ADR-005: Keep PR handoff independent of tracker kind](adrs/adr-005.md) — Primary decision for this task.
- [ADR-003: Introduce a shared Issue Tracker boundary](adrs/adr-003.md) — Status changes use selected tracker.

## Deliverables
- PR handoff works for minibeads tracker runs when configured.
- PR handoff does not reintroduce GitHub tracker readiness requirements for minibeads.
- Existing GitHub PR handoff behavior remains covered.
- Unit tests with 80%+ coverage **(REQUIRED)**
- Integration tests for minibeads PR handoff **(REQUIRED)**

## Tests
- Unit tests:
  - [ ] minibeads config with PR handoff enabled does not emit GitHub tracker readiness gaps.
  - [ ] PR handoff status update calls selected tracker.
  - [ ] PR handoff failure records retryable handoff state without requiring GitHub Project membership.
- Integration tests:
  - [ ] Existing batch PR handoff tests pass for GitHub tracker runs.
  - [ ] Existing task PR handoff tests pass for GitHub tracker runs.
  - [ ] minibeads PR handoff stub updates minibeads status after review handoff.
- Test coverage target: >=80%
- All tests must pass

## Success Criteria
- All tests passing
- Test coverage >=80%
- minibeads users can keep PR handoff workflows without configuring GitHub as the Issue Tracker.
