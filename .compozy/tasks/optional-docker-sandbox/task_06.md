---
status: pending
title: Update Runtime Contract Defaults, Glossary, And Docs
type: docs
complexity: medium
dependencies:
  - task_01
  - task_03
  - task_05
---

# Task 06: Update Runtime Contract Defaults, Glossary, And Docs

## Overview
Update bootstrap defaults, glossary entries, and operator-facing documentation so the final sandbox contract matches implemented behavior. This task should only land after the runtime settings, launch behavior, and user-visible sandbox state have settled, especially because changing `runtime_home.ml` defaults is an ask-first area in this repository.

<critical>
- ALWAYS READ the PRD and TechSpec before starting
- REFERENCE TECHSPEC for implementation details — do not duplicate here
- FOCUS ON "WHAT" — describe what needs to be accomplished, not how
- MINIMIZE CODE — show code only to illustrate current structure or problem areas
- TESTS REQUIRED — every task MUST include tests in deliverables
</critical>

<requirements>
- Bootstrap examples MUST remain secret-free and idempotent.
- Runtime contract docs MUST reflect the final sandbox settings names and user-visible behavior.
- If sandbox introduces stable product terminology, `CONTEXT.md` MUST be updated to preserve glossary consistency.
- Documentation and bootstrap assertions MUST match the implemented Runtime Settings shape and approved V1 visibility model.
</requirements>

## Subtasks
- [ ] 6.1 Update embedded bootstrap `settings.json` examples with the approved sandbox fields.
- [ ] 6.2 Update glossary or domain language in `CONTEXT.md` if sandbox becomes a stable runtime term.
- [ ] 6.3 Update README or ADR references that explain Runtime Settings and runtime behavior.
- [ ] 6.4 Extend docs/bootstrap assertions to cover the new runtime contract examples.
- [ ] 6.5 Verify docs remain secret-free and consistent with implemented behavior.

## Implementation Details
Reference the TechSpec sections "High-Level Technical Constraints", "Impact Analysis", and "Architecture Decision Records". This task must preserve the project’s idempotent bootstrap behavior and glossary discipline.

### Relevant Files
- `/Users/matheusbbarni/projects/symphony-orchestrator/apps/backend/lib/runtime_home.ml` — owns embedded bootstrap defaults and idempotent Runtime Contract creation.
- `/Users/matheusbbarni/projects/symphony-orchestrator/CONTEXT.md` — glossary source of truth for stable product terminology.
- `/Users/matheusbbarni/projects/symphony-orchestrator/README.md` — operator-facing Runtime Settings and runtime behavior documentation.
- `/Users/matheusbbarni/projects/symphony-orchestrator/docs/adr/0021-agent-harness-runtime-settings.md` — existing ADR context for runtime settings evolution.
- `/Users/matheusbbarni/projects/symphony-orchestrator/apps/backend/test/test_backend.ml` — contains bootstrap/docs assertions to extend.

### Dependent Files
- `/Users/matheusbbarni/projects/symphony-orchestrator/apps/backend/lib/config.ml` — docs must match the implemented sandbox settings shape.
- `/Users/matheusbbarni/projects/symphony-orchestrator/apps/frontend/src/Pages/Dashboard.res` — user-visible docs should match final dashboard behavior.

### Related ADRs
- [ADR-001: Scope V1 Sandbox as an Optional Docker Execution Boundary](../adrs/adr-001.md) — Establishes Docker-only V1 scope and runtime contract direction.
- [ADR-002: Use Repository-Level Opt-In With Strict Sandbox Readiness](../adrs/adr-002.md) — Requires no fallback for enabled repositories.
- [ADR-003: Model Sandbox as a Repository-Owned Runtime Settings Block With Startup Readiness Gating](../adrs/adr-003.md) — Defines the `sandbox.enabled` contract.
- [ADR-004: Attach Sandboxing at the Launch Boundary With Reusable Repository-Scoped Containers](../adrs/adr-004.md) — Defines user-visible execution and reuse behavior that docs must match.

## Deliverables
- Updated bootstrap Runtime Contract examples.
- Updated glossary and operator-facing documentation.
- Extended docs/bootstrap assertions covering sandbox examples.
- Unit tests with 80%+ coverage **(REQUIRED)**
- Integration tests for bootstrap/docs consistency **(REQUIRED)**

## Tests
- Unit tests:
  - [ ] Bootstrap example generation includes the approved sandbox settings shape without secrets.
  - [ ] Existing bootstrap idempotency behavior remains unchanged for user-edited files.
  - [ ] Docs assertions validate the sandbox-enabled Runtime Contract examples.
- Integration tests:
  - [ ] Runtime home bootstrap produces the expected sandbox-capable `settings.json` example for a new repository.
  - [ ] README and glossary updates remain consistent with the implemented runtime contract semantics.
  - [ ] Existing docs/runtime-home test suites still pass after sandbox documentation updates.
- Test coverage target: >=80%
- All tests must pass

## Success Criteria
- All tests passing
- Test coverage >=80%
- Runtime Contract examples and docs match the final sandbox implementation.
- Bootstrap remains idempotent and secret-free after sandbox documentation changes.

