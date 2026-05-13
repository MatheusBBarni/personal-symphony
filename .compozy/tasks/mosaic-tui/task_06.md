---
status: completed
title: "Document Runtime Semantics And Finalize Validation"
type: docs
complexity: medium
dependencies:
  - task_05
---

# Task 06: Document Runtime Semantics And Finalize Validation

## Overview
Update project documentation and architecture records for the default richer Terminal Console behavior after the implementation lands. This task also performs final validation across backend build, tests, and package-sensitive checks required by the Mosaic dependency and default runtime change.

<critical>
- ALWAYS READ the PRD and TechSpec before starting
- REFERENCE TECHSPEC for implementation details — do not duplicate here
- FOCUS ON "WHAT" — describe what needs to be accomplished, not how
- MINIMIZE CODE — show code only to illustrate current structure or problem areas
- TESTS REQUIRED — every task MUST include tests in deliverables
</critical>

<requirements>
- MUST update `CONTEXT.md` if implementation adds or changes domain language or runtime semantics.
- MUST add or update a Product Repository ADR under `docs/adr/` if default Terminal Console runtime semantics change.
- MUST document that the MVP Terminal Console is read-first, default for `symphony`, and limited to safe local aids with no task lifecycle mutation.
- MUST preserve existing terminology: Workspace Repository, Runtime Home, Runtime Contract, Runtime State, Terminal Console, Web Dashboard, Live Dashboard Connection, Readiness Gap, Ordered Queue, Compozy PRD Run, Agent Worktree, and Task Branch.
- MUST NOT document secret values; only variable names such as `GITHUB_TOKEN` and `GH_TOKEN` may appear.
- MUST run final validation commands required by the Product Repository and dependency changes.
</requirements>

## Subtasks
- [x] 6.1 Review implemented behavior against PRD, TechSpec, and task ADRs.
- [x] 6.2 Update `CONTEXT.md` for any confirmed domain or runtime semantic changes.
- [x] 6.3 Add or update a Product Repository ADR under `docs/adr/` if required by the runtime change.
- [x] 6.4 Update README or operator docs for default Terminal Console behavior and safe-aid boundaries.
- [x] 6.5 Add or update documentation assertions if existing tests cover docs examples.
- [x] 6.6 Run final backend, task, and package-sensitive validation.

## Implementation Details
Use this as the final feature integration task after code tasks are complete. Reference the TechSpec "Impact Analysis", "Monitoring and Observability", and "Development Sequencing" sections. Follow the Project Context rule that `CONTEXT.md` is the source of truth for product terminology and that architecture decisions changing runtime semantics need ADR coverage under `docs/adr/`.

Do not change npm package files, `bin/symphony.js`, or packaged-binary behavior unless explicitly approved. If `pnpm prepack` rewrites vendor binaries during validation, treat that as validation output and do not broaden the documentation task without approval.

### Relevant Files
- `CONTEXT.md` — Domain source of truth for Personal Symphony terminology and runtime semantics.
- `README.md` — Operator-facing command and dashboard documentation.
- `docs/adr/` — Product Repository architecture decision records.
- `.compozy/tasks/mosaic-tui/_prd.md` — Business requirements to verify.
- `.compozy/tasks/mosaic-tui/_techspec.md` — Technical design and validation guidance.
- `.compozy/tasks/mosaic-tui/adrs/` — Feature-level decisions that should inform docs.
- `package.json` — Provides validation commands.

### Dependent Files
- `apps/backend/bin/main.ml` — Implemented default Terminal Console runtime behavior to document.
- `apps/backend/bin/terminal_console_mosaic.ml` — Implemented user-facing safe aids and labels to document.
- `apps/backend/lib/terminal_console_model.ml` — Implemented state classifications and terminology to verify.
- `dune-project` and Dune files — Dependency changes that require build/package validation.

### Related ADRs
- [ADR-001: Scope Mosaic Terminal Console as a Runtime State command center](adrs/adr-001.md) — Product scope and Runtime State boundary.
- [ADR-002: Make the read-first Terminal Console with safe local aids the MVP approach](adrs/adr-002.md) — Default-run and no lifecycle mutation scope.
- [ADR-003: Run Mosaic in-process with Orchestrator Runtime State callbacks](adrs/adr-003.md) — Runtime architecture to reflect in Product Repository ADRs if semantics changed.
- [ADR-004: Add Mosaic as the direct Terminal Console dependency](adrs/adr-004.md) — Dependency/build validation context.
- [ADR-005: Use a pure Terminal Console view-model projection](adrs/adr-005.md) — Projection and sanitization boundary.

## Deliverables
- Updated `CONTEXT.md` entries if runtime semantics or domain language changed.
- Product Repository ADR under `docs/adr/` when required by the implementation.
- README/operator docs explaining default rich Terminal Console behavior and MVP safe-aid boundaries.
- Documentation or backend assertions for examples when applicable.
- Unit tests with 80%+ coverage for any documentation-backed helper changes **(REQUIRED)**.
- Integration validation for backend build, backend tests, Compozy task validation, and package-sensitive build path **(REQUIRED)**.

## Tests
- Unit tests:
  - [x] Any changed doc-example assertions verify Terminal Console mode, Web Dashboard mode, and Runtime State terminology.
  - [x] Any helper changed for documentation output keeps secret values redacted and uses only variable names.
- Integration tests:
  - [x] `pnpm backend:build` succeeds after all Mosaic Terminal Console changes.
  - [x] `pnpm test` succeeds with all backend tests.
  - [x] `compozy tasks validate --name mosaic-tui` succeeds.
  - [x] Package-sensitive validation from the TechSpec succeeds or records explicit follow-up if packaging requires separate approval.
  - [x] Documentation text uses established glossary terms and avoids introducing conflicting user-facing `TUI` product language.
- Test coverage target: >=80%
- All tests must pass

## Success Criteria
- All tests passing
- Test coverage >=80%
- Documentation reflects the implemented default Terminal Console runtime behavior.
- Product Repository ADR coverage exists for any runtime semantic change.
- No secrets, generated frontend `.res.js`, or unapproved package artifacts are introduced.
- Compozy task validation passes for `mosaic-tui`.
