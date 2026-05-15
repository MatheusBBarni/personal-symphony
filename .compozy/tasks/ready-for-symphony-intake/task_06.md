---
status: pending
title: "Update docs and ADR-aligned runtime semantics"
type: docs
complexity: medium
dependencies:
  - task_04
  - task_05
---

# Task 06: Update docs and ADR-aligned runtime semantics

## Overview
Update the Runtime Contract documentation, glossary, and architecture records so they describe the implemented Symphony-ready Status semantics accurately. This task closes the loop between implementation and domain language by documenting idle startup, tracker-owned first admission, Ordered Queue interaction, and the Compozy `_tasks.md` intake boundary.

<critical>
- ALWAYS READ the PRD and TechSpec before starting
- REFERENCE TECHSPEC for implementation details - do not duplicate here
- FOCUS ON "WHAT" - describe what needs to be accomplished, not how
- MINIMIZE CODE - show code only to illustrate current structure or problem areas
- TESTS REQUIRED - every task MUST include tests in deliverables
</critical>

<requirements>
- R1 MUST update README and glossary language to describe the Symphony-ready Status as the tracker-owned first-admission control.
- R2 MUST document that no ready work is valid Orchestration Idle state rather than a readiness failure.
- R3 MUST document that Ordered Queue selection does not bypass the ready-status rule for first admission.
- R4 MUST document `_tasks.md` as the Compozy-ready intake source without redefining Compozy Task Step or Compozy PRD Run Lifecycle truth.
- R5 MUST update or add ADR text wherever runtime semantics changed during implementation.
- R6 MUST include verification that documentation references align with implemented Runtime State and tracker behavior.
</requirements>

## Subtasks
- [ ] 6.1 Update README guidance for tracker-owned ready status, idle startup, and queue precedence.
- [ ] 6.2 Update CONTEXT glossary and invariant sections so the domain language matches the implemented first-admission model.
- [ ] 6.3 Update affected ADRs to reflect final runtime semantics and Compozy intake boundaries.
- [ ] 6.4 Verify documentation examples and terminology against the implemented runtime and state behavior.

## Implementation Details
Reference the TechSpec "High-Level Technical Constraints", "Technical Considerations", and "Architecture Decision Records" sections. Keep this task focused on aligning repo documentation and ADRs to the final implementation, not on introducing new runtime behavior.

### Relevant Files
- `README.md` - User-facing runtime guidance that should explain ready-status intake and idle startup.
- `CONTEXT.md` - Domain glossary and invariants that must remain the source of truth for Symphony terminology.
- `.github/project-tracking.md` - GitHub project-status documentation should stay aligned with the new Symphony-ready Status behavior.
- `docs/adr/0024-compozy-prd-run-lifecycle-semantics.md` - Existing Compozy lifecycle ADR that must stay clear about `_tasks.md` being intake-only.
- `docs/adr/0010-ordered-queue-runtime-state.md` - Ordered Queue ADR that may need wording updates around first-admission eligibility.
- `docs/adr/0002-runtime-contract-in-symphony.md` - Broad Runtime Contract ADR that may need references to the ready-status settings model.
- `.compozy/tasks/ready-for-symphony-intake/adrs/adr-002.md` - Product decision for one Symphony-ready Status convention.
- `.compozy/tasks/ready-for-symphony-intake/adrs/adr-003.md` - Tracker-boundary exact-match first-admission decision.
- `.compozy/tasks/ready-for-symphony-intake/adrs/adr-004.md` - Compozy `_tasks.md` intake-source decision.

### Dependent Files
- `apps/backend/lib/runtime_state.ml` - Documentation should match the operator-facing state fields added in the earlier implementation task.
- `apps/backend/lib/runtime_readiness.ml` - Readiness documentation must reflect the final idle-startup semantics.
- `apps/backend/lib/runtime_home.ml` - Bootstrap examples and default Runtime Contract text must stay aligned with the documented ready-status configuration.
- `apps/backend/lib/compozy_tasks_tracker.ml` - Compozy intake documentation must match the implemented `_tasks.md` parsing behavior.

### Related ADRs
- [ADR-002: Use a standard Symphony-ready status convention across trackers](adrs/adr-002.md) - Product baseline for documented semantics.
- [ADR-003: Put Symphony-ready status at the tracker boundary with exact-match first-admission semantics](adrs/adr-003.md) - Runtime semantics to reflect in docs.
- [ADR-004: Read Compozy Symphony-ready status from _tasks.md while keeping task-step state separate](adrs/adr-004.md) - Compozy intake boundary to preserve in docs.

## Deliverables
- Updated README, CONTEXT glossary, and ADR wording for ready-status intake semantics.
- Documentation that explains idle startup, queue precedence, and Compozy `_tasks.md` intake ownership consistently.
- Verification updates or notes showing documentation matches implemented runtime behavior.
- Unit tests with 80%+ coverage **(REQUIRED)**
- Integration tests for documentation-aligned runtime references **(REQUIRED)**

## Tests
- Unit tests:
  - [ ] Documentation references use the glossary terms Workspace Repository, Runtime Contract, Ordered Queue, Compozy PRD Run, and Symphony-ready Status consistently.
  - [ ] README examples or descriptions do not reintroduce a separate readiness marker or queue override claim.
- Integration tests:
  - [ ] Documentation for idle startup, queue gating, and Compozy `_tasks.md` intake matches the implemented runtime behavior observed in prior tasks.
  - [ ] Updated ADR wording remains consistent with the final code paths and Runtime State projections introduced by the implementation tasks.
- Test coverage target: >=80%
- All tests must pass

## Success Criteria
- All tests passing
- Test coverage >=80%
- Repository documentation consistently describes tracker-owned Symphony-ready first admission and valid idle startup.
- ADRs and glossary text align with the implemented queue, Compozy, and Runtime State semantics.
