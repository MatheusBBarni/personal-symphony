---
status: pending
title: Rebuild Terminal Console Projection Around Explicit Mode Models
type: backend
complexity: high
dependencies: []
---

# Task 01: Rebuild Terminal Console Projection Around Explicit Mode Models

## Overview
Replace the current flat, string-heavy `Terminal_console_model` snapshot with explicit top-level mode models and structured detail records. This task creates the new projection contract that every later renderer, interaction, and validation task depends on, while keeping the existing in-process runtime seam and **Runtime State** ownership intact.

<critical>
- ALWAYS READ the PRD and TechSpec before starting
- REFERENCE TECHSPEC for implementation details — do not duplicate here
- FOCUS ON "WHAT" — describe what needs to be accomplished, not how
- MINIMIZE CODE — show code only to illustrate current structure or problem areas
- TESTS REQUIRED — every task MUST include tests in deliverables
</critical>

<requirements>
- MUST replace the flat `Terminal_console_model.t` shape with a structured snapshot built from shared chrome plus explicit top-level mode bodies, as described in the TechSpec "System Architecture" and "Data Models" sections.
- MUST replace string-packed summary and detail fields with structured mode-specific records for active-run and readiness/startup content.
- MUST keep attention and summary context inside the mode models required by MVP rather than introducing a separate shared global attention subsystem.
- MUST keep the existing in-process `Runtime_state -> Terminal_console_model -> Terminal_console_mosaic` seam and MUST NOT require Runtime State schema changes.
- MUST sanitize all untrusted display text at projection time so downstream renderers never need unsanitized fields.
- SHOULD shape the new snapshot so a shared serializable terminal/browser snapshot remains possible later, without implementing that convergence in this task.
</requirements>

## Subtasks
- [ ] 1.1 Define the new projection types for shared chrome, top-level mode bodies, and structured detail records.
- [ ] 1.2 Replace flat mode and summary builders with explicit readiness-mode and active-run-mode projection builders.
- [ ] 1.3 Replace string-packed task and readiness detail content with typed, sanitized records.
- [ ] 1.4 Preserve existing safe-aid descriptors and last-error behavior within the new projection contract.
- [ ] 1.5 Extend projection and sanitization tests to validate the new snapshot shape without changing Runtime State semantics.

## Implementation Details
Modify `apps/backend/lib/terminal_console_model.ml` to become the main redesign boundary described in the TechSpec "Executive Summary", "Core Interfaces", and "Data Models" sections. The goal is to move product meaning into the projection layer so `Terminal_console_mosaic.ml` no longer needs to infer mode semantics from generic buckets or re-parse display strings.

Keep the runtime handoff unchanged. This task should not refactor `Terminal_console_runtime.ml` or `main.ml` beyond any compile-through adjustments required by the new projected type shape.

### Relevant Files
- `apps/backend/lib/terminal_console_model.ml` — Primary projection module that must be restructured around explicit mode bodies and structured detail records.
- `apps/backend/lib/runtime_state.ml` — Source of truth for all projected fields; must remain schema-stable while the projection changes.
- `apps/backend/test/test_backend.ml` — Existing projection, sanitization, and fixture tests that should be evolved to assert mode-level content.
- `apps/backend/bin/terminal_console_mosaic.ml` — Current consumer of the projection; useful for identifying which string-packed fields are currently re-parsed.

### Dependent Files
- `apps/backend/bin/terminal_console_mosaic.ml` — Later tasks will render directly from the new projection shape.
- `apps/backend/test/test_backend.ml` — Mode-level and structured-detail assertions will depend on the new snapshot contract.
- `.compozy/tasks/terminal-console-elegance/_techspec.md` — Defines the explicit mode-model boundary this task must satisfy.

### Related ADRs
- [ADR-004: Redesign the Terminal Console around explicit mode models over the existing in-process seam](../adrs/adr-004.md) — Establishes the new projection boundary while preserving runtime wiring.
- [ADR-005: Replace string-packed Terminal Console summaries with structured mode-specific records](../adrs/adr-005.md) — Requires typed summary and detail records instead of renderer-parsed strings.

## Deliverables
- A new mode-modeled `Terminal_console_model` snapshot contract with shared chrome and explicit top-level mode bodies.
- Structured active-run and readiness/startup detail records derived from existing **Runtime State** fields.
- Preserved sanitization and safe-aid projection behavior under the new model.
- Unit tests with 80%+ coverage for the updated projection **(REQUIRED)**.
- Integration-oriented projection tests using representative Runtime State fixtures **(REQUIRED)**.

## Tests
- Unit tests:
  - [ ] Empty Runtime State projects to an idle or ready-compatible snapshot with shared chrome and no active or readiness detail records.
  - [ ] Running work projects to the active-run mode body with structured task detail fields instead of a packed `detail` string.
  - [ ] Retrying and attention scenarios project into the active-run mode body without losing goal-usage, context-status, or error semantics.
  - [ ] Readiness-blocked state projects to the readiness-mode body with structured requirement and remediation detail.
  - [ ] Ordered Queue and **Compozy PRD Run** fields project into structured active-run summaries without depending on line-oriented summary strings.
  - [ ] Sanitization still strips terminal escape sequences, control characters, and secret values from every structured text field.
- Integration tests:
  - [ ] Existing Runtime State schema and serialization tests continue to pass without requiring Runtime State JSON changes.
  - [ ] Representative fixture snapshots compile through the new projection shape without any renderer involvement.
- Test coverage target: >=80%
- All tests must pass

## Success Criteria
- All tests passing
- Test coverage >=80%
- `Terminal_console_model` exposes explicit mode bodies and structured detail records instead of flat summary/detail strings.
- No Runtime State schema changes or runtime handoff changes are required.
- The new projection is sufficient for downstream renderer work without reintroducing string parsing as a product boundary.
