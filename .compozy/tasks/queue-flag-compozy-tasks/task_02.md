---
status: completed
title: "Wire readiness-first queue diagnostics for bare Compozy slugs"
type: backend
complexity: medium
dependencies:
  - task_01

---

# Task 02: Wire readiness-first queue diagnostics for bare Compozy slugs

## Overview
Route bare-slug queue feedback through startup readiness after `.symphony/settings.json` selects the active tracker. This task makes queue mismatch and mixed-style Compozy input visible as **Readiness Gaps** before orchestration begins, while preserving direct parse failures for structurally invalid queue entries.

<critical>
- ALWAYS READ the PRD and TechSpec before starting
- REFERENCE TECHSPEC for implementation details — do not duplicate here
- FOCUS ON "WHAT" — describe what needs to be accomplished, not how
- MINIMIZE CODE — show code only to illustrate current structure or problem areas
- TESTS REQUIRED — every task MUST include tests in deliverables
</critical>

<requirements>
- R1 MUST resolve raw ordered-queue entries only after Runtime Settings load and tracker selection are complete.
- R2 MUST surface bare Compozy slug usage under non-Compozy tracker modes as a guided startup **Readiness Gap**.
- R3 MUST reject mixed bare and canonical Compozy selector styles in the same queue as a readiness-owned validation failure in MVP.
- R4 MUST surface resolved duplicate identifiers and selected-tracker dispatchability failures through the readiness validation path.
- R5 MUST preserve direct parse-time diagnostics for empty entries, issue URLs, and cross-repository references.
- R6 MUST reuse the same queue-resolution logic that later orchestration will consume so readiness and dispatch cannot drift.
</requirements>

## Subtasks
- [ ] 2.1 Update runtime readiness to validate queues through the shared resolved queue-entry helper.
- [ ] 2.2 Add guided remediation for bare Compozy slugs used while the selected tracker kind is not `compozy_tasks`.
- [ ] 2.3 Add readiness validation for mixed bare and canonical Compozy selector styles in one queue.
- [ ] 2.4 Preserve separation between structural parse failures and tracker-aware readiness failures in startup wiring.
- [ ] 2.5 Add readiness-focused test coverage for tracker mismatch, mixed-style Compozy input, and resolved duplicate handling.

## Implementation Details
Reference TechSpec "System Architecture" and "Development Sequencing" steps 4 and 5. Keep this task focused on startup validation and diagnostics. Do not change queue dispatch, queue-state persistence, or resume behavior here.

### Relevant Files
- `apps/backend/lib/runtime_readiness.ml` — Current queue parse-gap and queue-validation composition point for readiness output.
- `apps/backend/bin/main.ml` — Startup path that parses `--queue`, loads Runtime Settings, and builds readiness state.
- `apps/backend/lib/ordered_queue.ml` — Shared queue-resolution and validation helper introduced by task 01.
- `apps/backend/test/test_backend.ml` — Existing ordered-queue validation and startup-readiness tests to extend.

### Dependent Files
- `apps/backend/lib/orchestrator.ml` — Later task will rely on the same resolution rules when dispatch begins.
- `apps/backend/lib/cli_command.ml` — Later docs task will align queue help text with the readiness-owned mismatch behavior.
- `README.md` — Later docs task will explain the same mismatch remediation to operators.

### Related ADRs
- [ADR-001: Compozy Queue Slug Scope](adrs/adr-001.md) — Keeps bare-slug support scoped to the Compozy-backed queue flow.
- [ADR-003: Tracker-Aware Ordered Queue Resolution](adrs/adr-003.md) — Requires post-settings normalization and raw queue preservation.
- [ADR-004: Readiness-First Queue Diagnostics](adrs/adr-004.md) — Places guided mismatch feedback in startup readiness.

## Deliverables
- Readiness validation that resolves queue entries after tracker selection.
- Guided **Readiness Gap** remediation for bare Compozy slugs used under non-Compozy tracker modes.
- Readiness coverage for mixed-style Compozy input and resolved duplicate identifiers.
- Unit tests with 80%+ coverage **(REQUIRED)**
- Integration tests for startup readiness behavior **(REQUIRED)**

## Tests
- Unit tests:
  - [ ] A bare Compozy slug under `tracker.kind = "github"` produces a readiness remediation that mentions the tracker mismatch.
  - [ ] A bare Compozy slug under `tracker.kind = "minibeads"` produces the same class of readiness remediation.
  - [ ] Mixed `example-feature,compozy:example-feature` Compozy queue input produces a readiness validation failure in MVP.
  - [ ] Structural parse failures such as an empty queue entry still appear as parse-stage remediation rather than tracker-mismatch remediation.
  - [ ] Resolved duplicate canonical identifiers are reported through queue readiness validation.
- Integration tests:
  - [ ] `symphony --once --queue example-feature` with a non-Compozy tracker reports a blocking **Readiness Gap** and does not begin orchestration.
  - [ ] Existing canonical Compozy queue readiness validation still passes when `tracker.kind = "compozy_tasks"`.
- Test coverage target: >=80%
- All tests must pass

## Success Criteria
- All tests passing
- Test coverage >=80%
- Bare Compozy slug mismatch is reported through readiness with tracker-aware remediation.
- Structural parse failures and tracker-aware readiness failures remain distinct in startup behavior.
