---
status: pending
title: Add Readiness Mode And Compact 80x24 Layouts
type: backend
complexity: high
dependencies:
  - task_02
---

# Task 03: Add Readiness Mode And Compact 80x24 Layouts

## Overview
Implement the explicit readiness/startup mode and the compact single-column layouts that preserve the redesign at the existing 80x24 minimum size. This task makes the new mode model complete and ensures the redesigned **Terminal Console** remains usable in smaller terminals without falling back to the old fixed-panel assumptions.

<critical>
- ALWAYS READ the PRD and TechSpec before starting
- REFERENCE TECHSPEC for implementation details — do not duplicate here
- FOCUS ON "WHAT" — describe what needs to be accomplished, not how
- MINIMIZE CODE — show code only to illustrate current structure or problem areas
- TESTS REQUIRED — every task MUST include tests in deliverables
</critical>

<requirements>
- MUST render an explicit readiness/startup mode from the structured projection model rather than treating readiness as just another fixed panel.
- MUST preserve the current runtime behavior where readiness-blocked Terminal Console runs open without starting orchestration.
- MUST support the established 80x24 minimum by rendering each top-level mode in a compact single-column layout when width is constrained.
- MUST keep secondary detail available in compact mode by stacking it beneath primary content rather than suppressing it entirely.
- MUST preserve the resize-required screen only for terminals smaller than the established minimum.
- SHOULD keep wide and compact layouts driven by the same shared chrome and mode data so they do not drift semantically over time.
</requirements>

## Subtasks
- [ ] 3.1 Add explicit readiness/startup mode rendering from the structured projection model.
- [ ] 3.2 Add compact single-column layout helpers shared by active-run and readiness modes.
- [ ] 3.3 Adapt active-run rendering to preserve its hierarchy in compact mode.
- [ ] 3.4 Adapt readiness rendering to preserve remediation-first hierarchy in compact mode.
- [ ] 3.5 Extend minimum-size, compact-layout, and readiness-path render tests.

## Implementation Details
Modify `apps/backend/bin/terminal_console_mosaic.ml` to complete the two-mode rendering model described in the TechSpec "Data Models", "Development Sequencing", and "Known Risks" sections. This task may require small follow-up projection adjustments in `apps/backend/lib/terminal_console_model.ml` only if the new readiness-mode or compact-layout renderers reveal missing structured fields.

Do not widen runtime scope. The readiness-versus-orchestrator branch behavior should continue to live in `apps/backend/bin/terminal_console_runtime.ml` and be validated, not redesigned, in this task.

### Relevant Files
- `apps/backend/bin/terminal_console_mosaic.ml` — Primary renderer for readiness mode and compact layout behavior.
- `apps/backend/lib/terminal_console_model.ml` — Structured readiness and active-run data source for compact and wide layouts.
- `apps/backend/test/test_backend.ml` — Existing readiness panel, minimum-size, and fixture render tests that should evolve to mode-level coverage.
- `apps/backend/bin/terminal_console_runtime.ml` — Confirms readiness-blocked runtime behavior remains unchanged while the renderer evolves.

### Dependent Files
- `apps/backend/bin/terminal_console_mosaic.ml` — Later interaction work depends on the completed two-mode render surface.
- `apps/backend/test/test_backend.ml` — Compact and readiness rendering assertions will expand here.
- `docs/adr/0024-default-rich-terminal-console.md` — May need review later if the implemented runtime semantics differ from the established minimum-size/readiness behavior.

### Related ADRs
- [ADR-001: Scope the Terminal Console elegance redesign as a two-mode presentation refactor](../adrs/adr-001.md) — Establishes startup/readiness and active-run as distinct top-level modes.
- [ADR-004: Redesign the Terminal Console around explicit mode models over the existing in-process seam](../adrs/adr-004.md) — Requires the renderer to treat readiness as a real mode body.
- [ADR-006: Preserve 80x24 support with compact single-column mode rendering](../adrs/adr-006.md) — Defines the minimum-size contract and compact-layout strategy.

## Deliverables
- Readiness/startup mode rendering driven by the structured snapshot.
- Compact single-column layouts for both top-level modes at the established minimum size.
- Preserved detail visibility in compact mode without introducing a larger minimum-size requirement.
- Unit tests with 80%+ coverage for readiness and compact-layout render helpers **(REQUIRED)**.
- Integration-style render and runtime tests for readiness-blocked and compact terminal scenarios **(REQUIRED)**.

## Tests
- Unit tests:
  - [ ] Readiness/startup mode renders structured requirement and remediation detail without using the old panel-first path.
  - [ ] Compact active-run layout preserves primary-versus-secondary ordering in one column.
  - [ ] Compact readiness layout preserves remediation-first hierarchy in one column.
  - [ ] Minimum-size rendering still shows the resize-required screen only below 80x24.
  - [ ] Shared chrome remains semantically consistent between wide and compact layouts.
- Integration tests:
  - [ ] Readiness-blocked runtime path still launches the **Terminal Console** without starting orchestration.
  - [ ] Representative 80x24 fixture states render successfully for both active-run and readiness modes.
- Test coverage target: >=80%
- All tests must pass

## Success Criteria
- All tests passing
- Test coverage >=80%
- The redesigned **Terminal Console** supports explicit readiness and active-run modes at both wide and compact sizes.
- 80x24 remains a supported minimum for the redesigned experience.
- Readiness-blocked behavior stays aligned with existing runtime semantics.
