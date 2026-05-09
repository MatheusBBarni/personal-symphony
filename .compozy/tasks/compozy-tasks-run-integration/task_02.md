---
status: completed
title: "Add Compozy task file parser and frontmatter updater"
type: backend
complexity: medium
dependencies:
  - task_01
---

# Task 02: Add Compozy task file parser and frontmatter updater

## Overview
Create the backend module that reads Compozy task files and updates task-step progress in YAML frontmatter. This provides the file-level foundation for PRD-run discovery and task-step execution.

<critical>
- ALWAYS READ the PRD and TechSpec before starting
- REFERENCE TECHSPEC for implementation details — do not duplicate here
- FOCUS ON "WHAT" — describe what needs to be accomplished, not how
- MINIMIZE CODE — show code only to illustrate current structure or problem areas
- TESTS REQUIRED — every task MUST include tests in deliverables
</critical>

<requirements>
- R1 MUST create a Compozy task file parser for files matching `task_NN.md`.
- R2 MUST sort task files by numeric suffix.
- R3 MUST read required task metadata including `status`, `title`, `type`, `complexity`, and `dependencies`.
- R4 MUST update only frontmatter keys needed for status, retry count, and last error.
- R5 MUST preserve user-authored Markdown body content.
- R6 MUST reject malformed or missing frontmatter with deterministic errors.
- R7 MUST keep file reads and writes scoped to the configured Compozy root.
</requirements>

## Subtasks
- [x] 2.1 Add `apps/backend/lib/compozy_tasks_tracker.ml` with task file parsing types.
- [x] 2.2 Parse valid `task_NN.md` files and ignore non-task metadata files.
- [x] 2.3 Add numeric ordering for task files.
- [x] 2.4 Add frontmatter update helpers for status, retry count, and last error.
- [x] 2.5 Add validation errors for malformed frontmatter and invalid paths.
- [x] 2.6 Add focused parser and updater tests.

## Implementation Details
Follow TechSpec "Task-Step Frontmatter" and "Compozy Artifacts". Avoid duplicating Compozy's whole parser; implement only the frontmatter behavior required by this feature.

### Relevant Files
- `apps/backend/lib/compozy_tasks_tracker.ml` — New module for Compozy task parsing and frontmatter writes.
- `apps/backend/lib/util.ml` — Existing file helpers may be reused for reads and writes.
- `apps/backend/test/test_backend.ml` — Add temporary file fixture tests near local tracker/config tests.

### Dependent Files
- `apps/backend/lib/config.ml` — Supplies the configured Compozy root and retry setting.
- `apps/backend/lib/orchestrator.ml` — Later tasks will call task status update helpers.

### Related ADRs
- [ADR-004: Persist task-step progress in Compozy task files](adrs/adr-004.md) — Defines task frontmatter as authoritative task-step progress.

## Deliverables
- New Compozy task parser and frontmatter updater module.
- Deterministic validation errors for malformed task files.
- Unit tests with 80%+ coverage **(REQUIRED)**
- Integration tests for file update behavior **(REQUIRED)**

## Tests
- Unit tests:
  - [x] `task_01.md`, `task_02.md`, and `task_10.md` sort in numeric order.
  - [x] Non-task files such as `_prd.md` and `notes.md` are ignored.
  - [x] Valid frontmatter parses required metadata fields.
  - [x] Missing frontmatter returns a deterministic parse error.
  - [x] Status and retry updates preserve the Markdown body.
  - [x] Paths outside the configured Compozy root are rejected.
- Integration tests:
  - [x] Temporary Compozy task directory can be parsed and updated across multiple task files.
- Test coverage target: >=80%
- All tests must pass

## Success Criteria
- All tests passing
- Test coverage >=80%
- Parser returns task-step data needed by later PRD-run mapping.
- Frontmatter updates are scoped and preserve task bodies.
