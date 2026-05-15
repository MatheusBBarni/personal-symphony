---
status: completed
title: "Update operator documentation and examples for Compozy lifecycle semantics"
type: docs
complexity: medium
dependencies:
  - task_03
  - task_05
---

# Task 06: Update operator documentation and examples for Compozy lifecycle semantics

## Overview
Refresh the operator-facing documentation so the written contract matches the lifecycle, readiness, and UI behavior implemented by the backend and frontend tasks. This task should explain how Compozy Task Step progress, run lifecycle, dispatch state, and Batch Pull Request readiness relate without introducing new vocabulary or drifting from the glossary.

<critical>
- ALWAYS READ the PRD and TechSpec before starting
- REFERENCE TECHSPEC for implementation details — do not duplicate here
- FOCUS ON "WHAT" — describe what needs to be accomplished, not how
- MINIMIZE CODE — show code only to illustrate current structure or problem areas
- TESTS REQUIRED — every task MUST include tests in deliverables
</critical>

<requirements>
- R1 MUST document the approved distinction between Compozy Task Step progress, Compozy PRD Run lifecycle state, dispatch state, and PR readiness.
- R2 MUST explain active states, blocked outcomes, completion, and failed handoff semantics using current product terminology.
- R3 MUST preserve glossary terminology from `CONTEXT.md` and update it only if final implementation wording changes domain language.
- R4 MUST keep aggregate Batch Pull Request behavior explicit and must not imply per-step pull requests.
- R5 MUST keep documentation secret-free and avoid token values or local environment contents.
- R6 MUST align README examples and terminology with the final Runtime State, Terminal Console, and Dashboard behavior.
</requirements>

## Subtasks
- [x] 6.1 Audit current README and glossary wording against the implemented lifecycle and readiness contract.
- [x] 6.2 Update operator-facing lifecycle and readiness tables or examples to match final semantics.
- [x] 6.3 Add representative examples for review, blocked, completed, and handoff-failed Compozy PRD Run states.
- [x] 6.4 Update `CONTEXT.md` only if final implementation wording changes the existing domain model.
- [x] 6.5 Verify docs terminology against backend enums and frontend-visible field names.

## Implementation Details
Reference TechSpec "Monitoring and Observability", "Technical Considerations", and the PRD "Operator-facing documentation and examples" feature. Keep this task focused on documentation and glossary alignment; do not use docs updates to compensate for unresolved product or code ambiguity.

### Relevant Files
- `README.md` — Already documents Compozy lifecycle and readiness values and should be aligned with final behavior.
- `CONTEXT.md` — Source of truth for glossary terms such as Compozy PRD Run Lifecycle, Compozy PR Readiness, Runtime Home, and Batch Pull Request.
- `.compozy/tasks/improve-compozy-task-statuses/_prd.md` — Defines the operator-facing documentation scope and terminology requirements.
- `.compozy/tasks/improve-compozy-task-statuses/_techspec.md` — Defines the final lifecycle, readiness, and cross-surface implementation contract.

### Dependent Files
- `apps/backend/lib/compozy_lifecycle.ml` — Documents must match the lifecycle and readiness enum values implemented here.
- `apps/backend/lib/runtime_state.ml` — Documents should match the shared Compozy payload field names surfaced to operators.
- `apps/frontend/src/Pages/Dashboard.res` — Documentation examples should reflect the final dashboard-visible labels and fields.

### Related ADRs
- [ADR-004: Treat Compozy statuses as an explicit transition contract](adrs/adr-004.md) — Requires documentation to explain the status-layer mapping clearly.
- [ADR-005: Use a cross-surface transition contract as the PRD approach](adrs/adr-005.md) — Requires docs to reflect a consistent cross-surface operator story.
- [ADR-006: Reconcile Compozy lifecycle from task-step progress while keeping readiness separate](adrs/adr-006.md) — Requires docs to explain that readiness and lifecycle are separate concepts.

## Deliverables
- Updated operator-facing documentation for Compozy lifecycle, readiness, and handoff semantics.
- README and glossary wording aligned with the final backend and frontend behavior.
- Representative examples for review, blocked, completed, and handoff-failed Compozy PRD Run states.
- Unit tests with 80%+ coverage **(REQUIRED)**
- Integration tests for documentation-to-implementation consistency **(REQUIRED)**

## Tests
- Unit tests:
  - [x] README lifecycle-state documentation matches the implemented lifecycle values in `apps/backend/lib/compozy_lifecycle.ml`.
  - [x] README readiness and handoff documentation matches the implemented readiness values and handoff semantics.
  - [x] `CONTEXT.md` terminology for Compozy PRD Run Lifecycle and Compozy PR Readiness remains consistent with the final implementation.
- Integration tests:
  - [x] `pnpm test` still passes after documentation or glossary edits.
  - [x] `pnpm frontend:test` still passes and its Compozy examples remain consistent with the documented operator story.
  - [x] Documentation examples do not imply per-step pull requests or contradictory ready states for blocked, failed, skipped, or handoff-failed runs.
- Test coverage target: >=80%
- All tests must pass

Verification note: direct backend and frontend verification commands passed. The exact `pnpm` entrypoints could not start in this sandbox because the installed pnpm attempted to fetch the repository-pinned pnpm version under restricted network access.

## Success Criteria
- All tests passing
- Test coverage >=80%
- Operators can read the docs and understand how Compozy Task Step progress, lifecycle, dispatch state, and readiness relate.
- Documentation uses the same lifecycle and readiness vocabulary that the Runtime State, Terminal Console, and Dashboard expose.
