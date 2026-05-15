---
status: pending
title: Show Sandbox Status In The Web Dashboard
type: frontend
complexity: medium
dependencies:
  - task_04
---

# Task 05: Show Sandbox Status In The Web Dashboard

## Overview
Expose the new sandbox runtime metadata in the Web Dashboard so operators can confirm when work is running under Docker and whether the runtime created, reused, or recreated the repository-scoped container. This task keeps the UI scoped to the approved moderate visibility level and preserves current **Runtime State** snapshot semantics.

<critical>
- ALWAYS READ the PRD and TechSpec before starting
- REFERENCE TECHSPEC for implementation details — do not duplicate here
- FOCUS ON "WHAT" — describe what needs to be accomplished, not how
- MINIMIZE CODE — show code only to illustrate current structure or problem areas
- TESTS REQUIRED — every task MUST include tests in deliverables
</critical>

<requirements>
- The dashboard MUST display approved sandbox metadata for running work using the backend snapshot fields from task 04.
- The UI MUST preserve existing readiness banners and issue card semantics for repositories without sandboxing enabled.
- Sandbox rendering MUST stay concise and must not introduce a full lifecycle history view in V1.
- Any ReScript snapshot-model changes MUST remain compatible with the existing full-snapshot **Live Dashboard Connection** model.
</requirements>

## Subtasks
- [ ] 5.1 Extend the frontend runtime snapshot mapping to read sandbox metadata from backend state.
- [ ] 5.2 Add concise sandbox status rendering to the dashboard for running work.
- [ ] 5.3 Preserve current dashboard behavior for non-sandboxed repositories and readiness-only scenarios.
- [ ] 5.4 Add frontend tests or coverage for sandbox snapshot mapping and rendering.
- [ ] 5.5 Verify the dashboard still builds and passes frontend validation flows.

## Implementation Details
Reference the TechSpec sections "Component Overview", "API Endpoints", and "Monitoring and Observability". The dashboard should consume backend snapshot fields rather than inventing new client-side state.

### Relevant Files
- `/Users/matheusbbarni/projects/symphony-orchestrator/apps/frontend/lib/ocaml/RuntimeStateSnapshot.res` — maps backend runtime-state snapshots into dashboard display data.
- `/Users/matheusbbarni/projects/symphony-orchestrator/apps/frontend/src/Pages/Dashboard.res` — renders issue cards, banners, and runtime summary details.
- `/Users/matheusbbarni/projects/symphony-orchestrator/apps/backend/lib/runtime_state.ml` — source of the sandbox fields consumed by the frontend.

### Dependent Files
- `/Users/matheusbbarni/projects/symphony-orchestrator/apps/backend/test/test_backend.ml` — snapshot contract changes may need corresponding backend assertions kept in sync.
- `/Users/matheusbbarni/projects/symphony-orchestrator/.compozy/tasks/optional-docker-sandbox/task_06.md` — docs should reflect final dashboard-visible sandbox behavior.

### Related ADRs
- [ADR-002: Use Repository-Level Opt-In With Strict Sandbox Readiness](../adrs/adr-002.md) — Requires visible operator trust signals.
- [ADR-004: Attach Sandboxing at the Launch Boundary With Reusable Repository-Scoped Containers](../adrs/adr-004.md) — Limits V1 visibility to enabled/provider/reuse outcome.

## Deliverables
- Frontend snapshot mapping for sandbox metadata.
- Dashboard rendering for moderate sandbox visibility.
- Frontend build/test updates covering sandbox display behavior.
- Unit tests with 80%+ coverage **(REQUIRED)**
- Integration tests for dashboard sandbox visibility **(REQUIRED)**

## Tests
- Unit tests:
  - [ ] Snapshot mapping preserves empty sandbox values for non-sandboxed runs.
  - [ ] Snapshot mapping converts sandbox provider and reuse outcome fields into dashboard display data.
  - [ ] Dashboard rendering shows sandbox status for a running sandboxed issue without affecting other issue states.
- Integration tests:
  - [ ] Frontend build succeeds after sandbox snapshot model changes.
  - [ ] Live runtime snapshots containing sandbox metadata render without breaking readiness banners or issue cards.
  - [ ] Existing non-sandbox dashboard scenarios still render correctly.
- Test coverage target: >=80%
- All tests must pass

## Success Criteria
- All tests passing
- Test coverage >=80%
- Operators can see approved sandbox status in the Web Dashboard for running work.
- Dashboard behavior for non-sandboxed repositories remains unchanged.
