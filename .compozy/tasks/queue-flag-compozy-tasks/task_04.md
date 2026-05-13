---
status: pending
title: "Update queue shortcut docs and CLI help"
type: docs
complexity: medium
dependencies:
  - task_02
  - task_03
---

# Task 04: Update queue shortcut docs and CLI help

## Overview
Update the user-facing queue contract after the runtime behavior is stable. This task aligns CLI help, README guidance, glossary language, and project ADR coverage with the Compozy-only queue shortcut, the readiness-first mismatch feedback, and the raw-input resume nuance introduced by the runtime changes.

<critical>
- ALWAYS READ the PRD and TechSpec before starting
- REFERENCE TECHSPEC for implementation details — do not duplicate here
- FOCUS ON "WHAT" — describe what needs to be accomplished, not how
- MINIMIZE CODE — show code only to illustrate current structure or problem areas
- TESTS REQUIRED — every task MUST include tests in deliverables
</critical>

<requirements>
- R1 MUST update `--queue` help text to describe the Compozy bare-slug shortcut scope without implying a global selector redesign.
- R2 MUST update README queue examples to show when bare Compozy slugs are accepted and when canonical selector forms still apply.
- R3 MUST document the readiness-first tracker-mismatch behavior for bare Compozy slugs used under non-Compozy tracker modes.
- R4 MUST update `CONTEXT.md` if the final implementation changes glossary-level semantics for **Ordered Queue**, queue identifiers, or queue resume behavior.
- R5 MUST add or update a project ADR under `docs/adr/` if the implemented runtime semantics require repository-level architectural documentation beyond task-local ADRs.
- R6 MUST keep documentation secret-free and aligned with the implemented runtime behavior and test fixtures.
</requirements>

## Subtasks
- [ ] 4.1 Update `apps/backend/lib/cli_command.ml` help text for `--queue`.
- [ ] 4.2 Update README queue examples and Compozy selector guidance for the MVP shortcut.
- [ ] 4.3 Update `CONTEXT.md` if glossary or invariant language needs to reflect raw-input resume semantics.
- [ ] 4.4 Add or update the relevant project ADR under `docs/adr/` for queue runtime semantics if implementation changes warrant it.
- [ ] 4.5 Add or update tests and verification steps that keep docs and help text aligned with runtime behavior.

## Implementation Details
Reference TechSpec "Integration Points", "Monitoring and Observability", and "Known Risks". Complete this task only after tasks 02 and 03 settle the exact readiness message shape and resume behavior. Keep legacy canonical Compozy selector guidance for non-queue selector surfaces unless implementation broadens them separately.

### Relevant Files
- `apps/backend/lib/cli_command.ml` — User-facing `--queue` help text that currently describes generic issue identifiers only.
- `README.md` — User-facing queue and Compozy tracker guidance, including selector-based flow examples.
- `CONTEXT.md` — Domain source of truth for **Ordered Queue** semantics if glossary wording changes.
- `docs/adr/0010-ordered-queue-runtime-state.md` — Existing project ADR about queue runtime-state semantics that may need an update or companion ADR.
- `apps/backend/test/test_backend.ml` — Existing CLI and queue behavior tests that can pin help text or example-aligned behavior.

### Dependent Files
- `apps/backend/lib/runtime_readiness.ml` — Mismatch diagnostics described in docs must match implemented readiness remediation.
- `apps/backend/lib/orchestrator.ml` — Resume semantics and raw queue-state behavior described in docs must match implementation.
- `.compozy/tasks/queue-flag-compozy-tasks/_prd.md` — Product language and boundaries should remain aligned with the final user-facing documentation.

### Related ADRs
- [ADR-001: Compozy Queue Slug Scope](adrs/adr-001.md) — Defines the Compozy-only queue shortcut boundary.
- [ADR-002: Focused Compozy Queue Shortcut](adrs/adr-002.md) — Keeps the documentation story narrow and operator-focused.
- [ADR-004: Readiness-First Queue Diagnostics](adrs/adr-004.md) — Requires user-facing docs to explain readiness-owned mismatch feedback.

## Deliverables
- Updated `--queue` help text that reflects the Compozy shortcut scope.
- Updated README examples and guidance for bare Compozy slugs and mismatch behavior.
- Updated `CONTEXT.md` and project ADR documentation if runtime semantics or glossary wording changed.
- Verification that docs and help text match implemented queue behavior.
- Unit tests with 80%+ coverage **(REQUIRED)**
- Integration tests for documented examples through existing verification **(REQUIRED)**

## Tests
- Unit tests:
  - [ ] `--queue` help text mentions the Compozy bare-slug shortcut scope without removing generic queue support wording.
  - [ ] README examples preserve canonical `compozy:<slug>` guidance for non-queue selector surfaces.
  - [ ] Documentation text does not include secret values and references only environment variable names when applicable.
  - [ ] Project ADR or glossary updates match the implemented raw-input resume semantics if those documents change.
- Integration tests:
  - [ ] Backend queue tests introduced in tasks 02 and 03 still pass after CLI help and documentation changes are aligned.
  - [ ] Documented bare-slug queue examples correspond to passing runtime behavior under `tracker.kind = "compozy_tasks"`.
  - [ ] Documented mismatch examples correspond to a blocking **Readiness Gap** under non-Compozy tracker modes.
- Test coverage target: >=80%
- All tests must pass

## Success Criteria
- All tests passing
- Test coverage >=80%
- User-facing docs and CLI help describe the Compozy queue shortcut accurately and narrowly.
- Repository glossary and ADR documentation, when updated, match the implemented queue runtime semantics.
