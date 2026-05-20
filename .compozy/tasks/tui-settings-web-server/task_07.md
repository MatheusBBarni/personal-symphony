---
status: pending
title: "Update Product Docs and Project ADR"
type: docs
complexity: low
dependencies:
  - task_05
  - task_06
---

# Task 07: Update Product Docs and Project ADR

## Overview
This task updates repository-level product language after the settings and dashboard behavior exists. It records the precise Terminal Console boundary change: scoped local setup controls are allowed, but orchestration and task lifecycle state remain protected.

<critical>
- ALWAYS READ the PRD and TechSpec before starting
- REFERENCE TECHSPEC for implementation details — do not duplicate here
- FOCUS ON "WHAT" — describe what needs to be accomplished, not how
- MINIMIZE CODE — show code only to illustrate current structure or problem areas
- TESTS REQUIRED — every task MUST include tests in deliverables
</critical>

<requirements>
- REQ-01 MUST update `CONTEXT.md` using established glossary terms.
- REQ-02 MUST update README Terminal Console and Web Dashboard documentation for `s`, theme, port, and `w` start/reuse behavior.
- REQ-03 MUST add or update a project ADR under `docs/adr/` for the Terminal Console local setup control boundary.
- REQ-04 MUST preserve loopback-only Terminal Console V1 language and existing non-loopback Web Dashboard auth expectations.
- REQ-05 MUST state that settings and `w` do not mutate task lifecycle state.
- REQ-06 MUST keep docs secret-free and avoid token values, webhook URLs, and local `.env` contents.
- REQ-07 MUST update backend docs assertions that currently describe `w` as handoff-only or Terminal Console aids as unable to change any Runtime Contract field.
- REQ-08 MUST update docs example validation assertions in lockstep with backend docs assertions.
- REQ-09 MUST keep product docs using "Terminal Console" instead of "TUI".
</requirements>

## Subtasks
- [ ] 7.1 Review existing Terminal Console and Web Dashboard language in README, CONTEXT, and ADRs.
- [ ] 7.2 Update `CONTEXT.md` to describe scoped Terminal Console setup controls.
- [ ] 7.3 Update README with the settings shortcut, persistent theme, persistent dashboard port, and `w` start/reuse behavior.
- [ ] 7.4 Add or amend a project ADR for the Runtime Contract exception and local service action.
- [ ] 7.5 Update docs assertions in backend tests and run docs checks.

## Implementation Details
Use the TechSpec "Integration Points" and ADR-003 "Consequences" sections. Keep the documentation narrow: V1 is not a general Runtime Settings editor, not a command channel for the Live Dashboard Connection, and not a task lifecycle control surface.

### Relevant Files
- `CONTEXT.md` — Domain source of truth for Runtime Contract, Terminal Console, Web Dashboard, and Live Dashboard Connection terms.
- `README.md` — Operator-facing Terminal Console and Web Dashboard instructions.
- `docs/adr/0024-default-rich-terminal-console.md` — Existing read-first Terminal Console ADR that may need amendment.
- `docs/adr/0025-dashboard-loopback-and-auth.md` — Existing loopback and auth ADR to preserve or cross-reference.
- `docs/adr/` — Location for a new project ADR if amendment is not the clearest path.
- `apps/backend/test/test_backend.ml` — Documentation assertions for Terminal Console semantics and secret-free docs.
- `scripts/validate-docs-examples.js` — Documentation validation assertions that currently require handoff-only wording.

### Dependent Files
- `apps/backend/bin/terminal_console_tui.ml` — Source of final `s` and `w` user-facing labels.
- `apps/backend/lib/dashboard_service.re` — Source of final start/reuse/conflict behavior.
- `apps/backend/lib/terminal_console_settings.re` — Source of final persisted settings behavior.
- `docs/adr/0025-dashboard-loopback-and-auth.md` — Source of non-loopback auth language to preserve.

### Related ADRs
- [ADR-001: Scope the Terminal Console Settings MVP](adrs/adr-001.md) — Product boundary for settings and `w`.
- [ADR-002: Select Narrow Setup MVP Product Approach](adrs/adr-002.md) — Selected V1 product approach.
- [ADR-003: Terminal Console Settings and Dashboard Service Architecture](adrs/adr-003.md) — Architecture and documentation implications.

## Deliverables
- Updated `CONTEXT.md` Terminal Console and Web Dashboard language.
- Updated README instructions for `s` settings and `w` dashboard start/reuse.
- New or amended project ADR under `docs/adr/`.
- Unit/documentation tests with 80%+ coverage for changed assertions **(REQUIRED)**.
- Integration docs validation through the repository docs test command **(REQUIRED)**.

## Tests
- Unit tests:
  - [ ] Docs assertions expect `s` settings behavior in README.
  - [ ] Docs assertions expect `w` start/reuse behavior instead of handoff-only behavior.
  - [ ] Docs assertions stop requiring the old `Web Dashboard handoff command` phrase.
  - [ ] Docs assertions expect Terminal Console theme to persist in ignored Runtime Home state.
  - [ ] Docs assertions expect only `server.port` to be updated through scoped Runtime Settings behavior.
  - [ ] Docs assertions preserve "must not retry tasks, pause or resume dispatch, update tracker status" lifecycle boundary language.
  - [ ] Docs assertions preserve loopback-only Terminal Console V1 behavior.
  - [ ] Docs assertions preserve non-loopback generated dashboard auth token expectations.
  - [ ] Secret-free docs assertions still reject token value markers.
  - [ ] `scripts/validate-docs-examples.js` keeps the product wording guard against `TUI`.
- Integration tests:
  - [ ] `pnpm docs:test` passes when available.
  - [ ] Backend docs assertion tests pass with the amended Terminal Console language.
- Test coverage target: >=80%
- All tests must pass

## Success Criteria
- All tests passing
- Test coverage >=80%
- Product docs match implemented `s` and `w` behavior.
- Terminal Console local setup controls are documented without expanding lifecycle authority.
- Loopback and non-loopback auth boundaries remain clear.
- Backend docs tests and `scripts/validate-docs-examples.js` agree on the same updated Terminal Console wording.
