---
status: pending
title: "Implement GitHub exact-match ready-status admission"
type: backend
complexity: medium
dependencies:
  - task_01
---

# Task 02: Implement GitHub exact-match ready-status admission

## Overview
Update the GitHub Tracker so a GitHub Project item becomes newly admissible only when its configured project status exactly matches the Symphony-ready Status. This task must preserve tracker-visible issue discovery needed for ongoing lifecycle behavior while tightening first admission to the exact-match rule selected in the PRD and TechSpec.

<critical>
- ALWAYS READ the PRD and TechSpec before starting
- REFERENCE TECHSPEC for implementation details - do not duplicate here
- FOCUS ON "WHAT" - describe what needs to be accomplished, not how
- MINIMIZE CODE - show code only to illustrate current structure or problem areas
- TESTS REQUIRED - every task MUST include tests in deliverables
</critical>

<requirements>
- R1 MUST require an exact configured Symphony-ready Status match for GitHub first admission.
- R2 MUST preserve tracker-visible issue discovery needed for already admitted, retrying, terminal, or dashboard-visible GitHub issues.
- R3 MUST keep GitHub status-field integration bound to the configured project status field rather than introducing a second GitHub readiness marker.
- R4 MUST return explicit non-eligible reasons for GitHub issues whose project status does not satisfy the ready-status rule.
- R5 MUST include backend test coverage for exact-match admission, non-match exclusion, and preserved visible-issue behavior.
</requirements>

## Subtasks
- [ ] 2.1 Update GitHub tracker admission evaluation to compare project status against the configured Symphony-ready Status.
- [ ] 2.2 Preserve visible issue discovery for ongoing lifecycle consumers while separating first-admission eligibility from general visibility.
- [ ] 2.3 Add explicit admission reasons for GitHub non-ready and ready cases.
- [ ] 2.4 Extend backend tests for exact-match GitHub intake behavior and compatibility with existing tracker state handling.

## Implementation Details
Reference the TechSpec "System Architecture", "Implementation Design", and "Technical Considerations" sections, especially the GitHub exact-match decision and the distinction between tracker visibility and first admission. Keep this task focused on GitHub adapter semantics; queue precedence, idle startup, and Runtime State projections belong to later tasks.

### Relevant Files
- `apps/backend/lib/github_tracker.ml` - GitHub Project status fetch and issue construction path that must implement exact-match admission.
- `apps/backend/lib/issue_tracker.ml` - Shared tracker boundary that exposes the new admission decision to callers.
- `apps/backend/test/test_backend.ml` - Existing GitHub tracker fixtures and integration tests for project-status behavior.

### Dependent Files
- `apps/backend/lib/ordered_queue.ml` - Queue validation and identifier handling will later need the same GitHub-ready semantics.
- `apps/backend/lib/orchestrator.ml` - Later dispatch logic will rely on GitHub admission decisions instead of broader active-state checks for first admission.
- `apps/backend/lib/runtime_readiness.ml` - Later startup and queue validation should use the same GitHub-ready semantics.
- `apps/backend/lib/runtime_state.ml` - Later state projections will expose GitHub admission reasons to operators.

### Related ADRs
- [ADR-002: Use a standard Symphony-ready status convention across trackers](adrs/adr-002.md) - Product requirement for one cross-tracker ready concept.
- [ADR-003: Put Symphony-ready status at the tracker boundary with exact-match first-admission semantics](adrs/adr-003.md) - Requires the GitHub exact-match rule implemented here.

## Deliverables
- GitHub Tracker admission logic that requires an exact configured Symphony-ready Status for first admission.
- Preserved tracker-visible issue discovery for existing lifecycle and dashboard consumers.
- Backend tests covering exact-match ready admission and non-ready exclusion behavior.
- Unit tests with 80%+ coverage **(REQUIRED)**
- Integration tests for GitHub project-status intake behavior **(REQUIRED)**

## Tests
- Unit tests:
  - [ ] A GitHub issue with the configured ready status returns an eligible first-admission decision.
  - [ ] A GitHub issue with another active project status returns a non-eligible decision with a ready-status mismatch reason.
  - [ ] Missing or unknown GitHub project status returns a deterministic non-eligible decision instead of silently dispatching.
- Integration tests:
  - [ ] A GitHub Project item that moves into the configured ready status becomes admissible on a later poll without requiring restart.
  - [ ] Existing GitHub lifecycle visibility tests continue to surface already admitted or terminal issues even when they are not newly admissible.
- Test coverage target: >=80%
- All tests must pass

## Success Criteria
- All tests passing
- Test coverage >=80%
- GitHub first admission is gated by an exact Symphony-ready Status match.
- GitHub tracker visibility needed for lifecycle and state consumers remains intact.
