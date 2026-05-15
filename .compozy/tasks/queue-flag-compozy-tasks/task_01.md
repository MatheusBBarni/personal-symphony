---
status: completed
title: "Add tracker-aware Ordered Queue resolution primitives"
type: backend
complexity: high
dependencies: []

---

# Task 01: Add tracker-aware Ordered Queue resolution primitives

## Overview
Add the queue-resolution primitives that let `--queue` preserve raw operator input while still resolving canonical identifiers after tracker selection. This task establishes the shared normalization boundary the readiness and orchestration tasks will depend on, so it must keep `Ordered_queue.parse` generic and move Compozy meaning behind the selected **Issue Tracker**.

<critical>
- ALWAYS READ the PRD and TechSpec before starting
- REFERENCE TECHSPEC for implementation details — do not duplicate here
- FOCUS ON "WHAT" — describe what needs to be accomplished, not how
- MINIMIZE CODE — show code only to illustrate current structure or problem areas
- TESTS REQUIRED — every task MUST include tests in deliverables
</critical>

<requirements>
- R1 MUST keep `Ordered_queue.parse` tracker-agnostic and allow opaque bare queue tokens without assigning them Compozy meaning at parse time.
- R2 MUST preserve direct parse failures for empty queue entries, issue URLs, and cross-repository references.
- R3 MUST introduce a shared resolved queue representation that maps raw queue identifiers to canonical tracker identifiers after Runtime Settings load.
- R4 MUST extend Compozy tracker normalization so the selected Compozy-backed **Issue Tracker** accepts both bare slugs and legacy canonical `compozy:<slug>` selectors.
- R5 MUST detect duplicate queue entries after canonical tracker normalization, including collisions such as repeated bare Compozy slugs or equivalent canonical forms.
- R6 MUST preserve existing GitHub, minibeads, and canonical Compozy normalization behavior for already supported selector forms.
- R7 MUST keep task-step-like Compozy selectors outside the **Compozy PRD Run** boundary.
</requirements>

## Subtasks
- [x] 1.1 Extend the ordered queue model to preserve raw queue identifiers and expose a resolved queue-entry shape for downstream callers.
- [x] 1.2 Update queue parsing so structurally valid bare tokens survive parse-time validation without becoming Compozy-specific selectors.
- [x] 1.3 Add a shared queue-resolution helper that uses the selected tracker normalization rules to derive canonical identifiers.
- [x] 1.4 Extend Compozy tracker normalization to accept bare slugs and legacy canonical selectors without changing GitHub or minibeads behavior.
- [x] 1.5 Add duplicate-detection coverage based on resolved canonical identifiers rather than raw queue text alone.

## Implementation Details
Reference TechSpec "Implementation Design", especially "Core Interfaces", "Ordered Queue Entry", "Resolved Queue Entry", and "Compozy Normalization Rules". Keep this task focused on raw-versus-canonical queue representation and selected-tracker normalization; readiness messaging and orchestration changes belong to later tasks.

### Relevant Files
- `apps/backend/lib/ordered_queue.ml` — Current queue entry model, parse rules, canonical identifier helpers, and validation path.
- `apps/backend/lib/issue_tracker.ml` — Selected tracker normalization boundary, including current Compozy canonical identifier handling.
- `apps/backend/test/test_backend.ml` — Existing parser, normalization, and Compozy lookup-boundary tests to extend near related cases.

### Dependent Files
- `apps/backend/lib/runtime_readiness.ml` — Later task will consume the shared queue-resolution helper for readiness-owned diagnostics.
- `apps/backend/lib/orchestrator.ml` — Later task will consume resolved queue entries for matching, ordering, and resume-sensitive behavior.
- `apps/backend/bin/main.ml` — Startup wiring will later pass parsed queues through post-settings resolution.

### Related ADRs
- [ADR-001: Compozy Queue Slug Scope](adrs/adr-001.md) — Defines bare Compozy slugs as a `compozy_tasks`-only queue affordance.
- [ADR-003: Tracker-Aware Ordered Queue Resolution](adrs/adr-003.md) — Requires raw queue state plus post-settings canonical resolution.

## Deliverables
- Updated ordered queue primitives that preserve raw queue identifiers and expose resolved canonical identifiers.
- Compozy tracker normalization that accepts bare slugs after tracker selection.
- Duplicate-detection behavior based on resolved canonical identifiers.
- Unit tests with 80%+ coverage **(REQUIRED)**
- Integration tests for selected-tracker normalization and lookup behavior **(REQUIRED)**

## Tests
- Unit tests:
  - [x] `Ordered_queue.parse "example-feature"` succeeds as a structurally valid opaque queue token.
  - [x] `Ordered_queue.parse "owner/repo#20"` still fails with the existing cross-repository reference diagnostic.
  - [x] Compozy normalization resolves `example-feature` to `compozy:example-feature`.
  - [x] Compozy normalization preserves `compozy:example-feature` as the canonical identifier.
  - [x] Resolved duplicate detection reports a collision when two bare Compozy slugs normalize to the same canonical identifier.
  - [x] Task-step-like Compozy selectors such as `compozy:task_01` remain missing at the PRD-run boundary.
- Integration tests:
  - [x] Selected Compozy tracker lookup resolves a bare slug and returns the same issue identity as the legacy canonical selector.
  - [x] Existing canonical Compozy ordered-queue validation tests continue to pass unchanged.
- Test coverage target: >=80%
- All tests must pass

## Success Criteria
- All tests passing
- Test coverage >=80%
- Ordered queue parsing preserves raw bare tokens without becoming tracker-specific.
- Selected-tracker normalization resolves bare Compozy slugs to canonical identifiers without regressing existing selector behavior.
