---
status: pending
title: "Refactor Ordered Queue orchestration to use raw state and resolved identifiers"
type: backend
complexity: high
dependencies:
  - task_01
  - task_02
---

# Task 03: Refactor Ordered Queue orchestration to use raw state and resolved identifiers

## Overview
Refactor ordered-queue dispatch, persistence, and resume behavior so Compozy bare-slug queues retain raw identifiers in queue state while orchestration still matches and orders work by canonical issue identity. This task carries the end-to-end runtime behavior for the shortcut and owns the raw-versus-canonical resume semantics defined in the TechSpec.

<critical>
- ALWAYS READ the PRD and TechSpec before starting
- REFERENCE TECHSPEC for implementation details — do not duplicate here
- FOCUS ON "WHAT" — describe what needs to be accomplished, not how
- MINIMIZE CODE — show code only to illustrate current structure or problem areas
- TESTS REQUIRED — every task MUST include tests in deliverables
</critical>

<requirements>
- R1 MUST persist raw bare-slug queue identifiers in **Runtime State** and the ordered queue state file for Compozy shortcut runs.
- R2 MUST use resolved canonical identifiers for queue matching, queue ordering, queue-entry dispatch checks, and issue lookup during orchestration.
- R3 MUST keep the raw queue sequence as the queue resume key so restarting with the same bare-slug queue resumes progress.
- R4 MUST treat a restart with canonical Compozy selectors after a bare-slug queue run as a different queue sequence that resets queue progress.
- R5 MUST preserve existing GitHub, minibeads, and canonical Compozy ordered-queue orchestration behavior.
- R6 MUST emit queue-related diagnostics using operator-facing queue identifiers while preserving canonical issue identity for backend matching.
- R7 MUST add end-to-end orchestration coverage for bare-slug dispatch order and raw-versus-canonical resume behavior.
</requirements>

## Subtasks
- [ ] 3.1 Update ordered queue state projection and persistence to preserve raw queue identifiers for Compozy shortcut runs.
- [ ] 3.2 Refactor orchestrator queue matching and ordering to use resolved canonical identifiers instead of persisted raw queue text.
- [ ] 3.3 Update queue resume matching so the raw queue sequence, not the canonicalized target set, determines resume continuity.
- [ ] 3.4 Preserve operator-facing queue identifiers in queue diagnostics and skipped-entry reporting.
- [ ] 3.5 Add end-to-end orchestration tests for bare-slug dispatch order, raw queue persistence, and restart behavior.

## Implementation Details
Reference TechSpec "System Architecture", "Runtime State", and "Development Sequencing" steps 6 and 9. This task is the runtime slice that joins parsing, readiness, persistence, and dispatch together. Keep documentation wording changes out of scope here; they belong to task 04.

### Relevant Files
- `apps/backend/lib/orchestrator.ml` — Current queue state projection, resume matching, queue ordering, and dispatch admission logic.
- `apps/backend/lib/runtime_state.ml` — Queue JSON shape and queue-entry persistence model.
- `apps/backend/lib/ordered_queue.ml` — Resolved queue-entry helper that orchestrator will consume.
- `apps/backend/test/test_backend.ml` — Existing queue resume, dispatch order, and runtime-state coverage to extend with bare-slug scenarios.

### Dependent Files
- `apps/backend/lib/runtime_readiness.ml` — Must continue to share the same resolution rules and identifier semantics.
- `apps/backend/bin/main.ml` — Startup hands the parsed queue into the refactored orchestrator path.
- `README.md` — Later docs task will explain the raw-input resume nuance created by this behavior.

### Related ADRs
- [ADR-001: Compozy Queue Slug Scope](adrs/adr-001.md) — Preserves canonical downstream issue identity and fail-fast semantics.
- [ADR-003: Tracker-Aware Ordered Queue Resolution](adrs/adr-003.md) — Requires raw queue state plus post-settings canonical resolution.
- [ADR-004: Readiness-First Queue Diagnostics](adrs/adr-004.md) — Requires orchestration to share the same resolution behavior as readiness.

## Deliverables
- Ordered queue runtime behavior that preserves raw bare-slug identifiers in queue state.
- Orchestrator queue matching and ordering based on resolved canonical identifiers.
- Resume behavior that distinguishes raw bare-slug queues from canonical Compozy queues.
- Unit tests with 80%+ coverage **(REQUIRED)**
- Integration tests for ordered queue dispatch and resume behavior **(REQUIRED)**

## Tests
- Unit tests:
  - [ ] `ordered_queue_state_matches` resumes when the persisted raw queue sequence matches the requested bare-slug queue sequence.
  - [ ] `ordered_queue_state_matches` resets when the persisted bare-slug sequence is restarted with canonical `compozy:<slug>` selectors.
  - [ ] Queue ordering uses resolved canonical identifiers even when persisted queue state stores raw bare slugs.
  - [ ] Queue diagnostics continue to show the operator-facing queue identifier for skipped entries.
- Integration tests:
  - [ ] A Compozy bare-slug queue dispatches only the requested PRD runs and in the requested order.
  - [ ] Runtime State exposes raw bare-slug identifiers in `ordered_queue.entries` during a Compozy shortcut run.
  - [ ] Restarting with the same bare-slug queue resumes queue progress from `.symphony/state/ordered_queue.json`.
  - [ ] Restarting with canonical Compozy selectors after a bare-slug run starts a new queue run instead of resuming.
  - [ ] Existing GitHub and minibeads ordered-queue orchestration tests continue to pass unchanged.
- Test coverage target: >=80%
- All tests must pass

## Success Criteria
- All tests passing
- Test coverage >=80%
- Bare Compozy slug queues persist raw identifiers without breaking canonical dispatch matching.
- Queue resume follows the raw input sequence semantics defined in the approved TechSpec.
