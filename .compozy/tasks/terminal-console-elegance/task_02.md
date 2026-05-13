---
status: pending
title: Render Shared Chrome And Active-Run Mode From Structured Snapshot
type: backend
complexity: high
dependencies:
  - task_01
---

# Task 02: Render Shared Chrome And Active-Run Mode From Structured Snapshot

## Overview
Rework the Mosaic renderer so the active-run experience is driven by shared chrome plus the new structured active-run mode body. This task replaces the current fixed six-panel, string-reparsing approach for the core live-monitoring path that the PRD prioritizes most heavily.

<critical>
- ALWAYS READ the PRD and TechSpec before starting
- REFERENCE TECHSPEC for implementation details — do not duplicate here
- FOCUS ON "WHAT" — describe what needs to be accomplished, not how
- MINIMIZE CODE — show code only to illustrate current structure or problem areas
- TESTS REQUIRED — every task MUST include tests in deliverables
</critical>

<requirements>
- MUST render the redesigned active-run experience from the structured `Terminal_console_model` snapshot rather than the current fixed panel buckets.
- MUST introduce shared chrome rendering for title, status, mode labels, generated-at context, and footer hints without rebuilding a global attention subsystem.
- MUST render active-run summary, active work, ordered queue context, optional **Compozy PRD Run** context, and selected task detail from structured records.
- MUST remove renderer dependence on parsing summary lines or splitting packed detail strings to recover product meaning.
- MUST preserve no-color readability and the read-first, non-mutating Terminal Console boundary.
- SHOULD keep the wide-layout composition optimized for heavy daily operators who use the **Terminal Console** as the primary live-monitoring surface.
</requirements>

## Subtasks
- [ ] 2.1 Add shared chrome render helpers that work with the new snapshot contract.
- [ ] 2.2 Replace the current active-run panel assembly with structured active-run mode rendering.
- [ ] 2.3 Render ordered queue, Compozy progress, and selected task detail from typed records rather than parsed text.
- [ ] 2.4 Remove renderer helpers whose only job was to recover semantics from packed summary or detail strings.
- [ ] 2.5 Extend render tests to cover the new active-run hierarchy and no-color output.

## Implementation Details
Modify `apps/backend/bin/terminal_console_mosaic.ml` as described in the TechSpec "System Architecture", "Core Interfaces", and "Technical Considerations" sections. This task should stay inside the existing renderer/UI boundary and should not change `Terminal_console_runtime.ml` startup semantics.

The task is specifically about the active-run path. Readiness/startup mode and the compact 80x24 layout belong to the next task, so do not merge them into this slice unless a shared rendering helper is truly required.

### Relevant Files
- `apps/backend/bin/terminal_console_mosaic.ml` — Primary renderer that currently assumes fixed panels and reparses projection strings.
- `apps/backend/lib/terminal_console_model.ml` — New structured snapshot contract from task 01.
- `apps/backend/test/test_backend.ml` — Existing Mosaic render tests for Active Work, Ordered Queue, Compozy progress, task detail, and no-color labels.
- `apps/backend/bin/terminal_console_runtime.ml` — Useful for confirming that only rendering changes, not runtime handoff responsibilities, are needed here.

### Dependent Files
- `apps/backend/test/test_backend.ml` — Render assertions must evolve to active-run mode expectations.
- `apps/backend/bin/terminal_console_mosaic.ml` — Interaction and compact-layout work in later tasks depends on the new active-run rendering path.
- `.compozy/tasks/terminal-console-elegance/_techspec.md` — Defines the wide-layout active-run rendering strategy this task implements.

### Related ADRs
- [ADR-001: Scope the Terminal Console elegance redesign as a two-mode presentation refactor](../adrs/adr-001.md) — Keeps the redesign read-first and mode-aware.
- [ADR-002: Prioritize active-run elegance as the MVP product approach](../adrs/adr-002.md) — Makes the active-run surface the first-class MVP target.
- [ADR-004: Redesign the Terminal Console around explicit mode models over the existing in-process seam](../adrs/adr-004.md) — Requires the renderer to switch on explicit mode bodies.
- [ADR-005: Replace string-packed Terminal Console summaries with structured mode-specific records](../adrs/adr-005.md) — Eliminates renderer re-parsing of summary and detail strings.

## Deliverables
- Shared chrome rendering for the redesigned **Terminal Console**.
- Structured active-run mode rendering for primary live-monitoring content.
- Renderer logic that no longer depends on packed summary or detail string parsing.
- Unit tests with 80%+ coverage for active-run render helpers and formatting logic **(REQUIRED)**.
- Integration-style render tests for representative active-run fixture states **(REQUIRED)**.

## Tests
- Unit tests:
  - [ ] Shared chrome renders status, generated-at context, and mode labels from the structured snapshot.
  - [ ] Active-run mode renders active work as the primary content area without requiring the old fixed-panel path.
  - [ ] Ordered Queue and **Compozy PRD Run** summaries render from structured records and remain readable without color.
  - [ ] Selected task detail renders from typed detail fields rather than a split `detail` string.
  - [ ] Legacy string-parsing helpers that are no longer needed are removed or no longer drive active-run meaning.
- Integration tests:
  - [ ] Representative running, retrying, attention, queue, and Compozy fixture snapshots render through the new active-run path without crashing.
  - [ ] Existing runtime tests still compile and run with the redesigned renderer surface.
- Test coverage target: >=80%
- All tests must pass

## Success Criteria
- All tests passing
- Test coverage >=80%
- The active-run experience renders from shared chrome plus a structured mode body rather than fixed panels plus parsed text.
- Heavy daily operator workflows map cleanly to the new active-run hierarchy.
- No runtime startup semantics or safe-aid authority boundaries change.
