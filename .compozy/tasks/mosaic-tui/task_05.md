---
status: pending
title: "Add Keyboard Navigation And Safe Local Aids"
type: backend
complexity: medium
dependencies:
  - task_04
---

# Task 05: Add Keyboard Navigation And Safe Local Aids

## Overview
Add the interaction layer that makes the Terminal Console keyboard-first while preserving the MVP boundary of no task lifecycle mutation. This task implements UI-only navigation, filtering, help/footer behavior, refresh redraw, Web Dashboard handoff guidance, and validated local inspection aids.

<critical>
- ALWAYS READ the PRD and TechSpec before starting
- REFERENCE TECHSPEC for implementation details — do not duplicate here
- FOCUS ON "WHAT" — describe what needs to be accomplished, not how
- MINIMIZE CODE — show code only to illustrate current structure or problem areas
- TESTS REQUIRED — every task MUST include tests in deliverables
</critical>

<requirements>
- MUST provide keyboard navigation for MVP panels and task detail selection.
- MUST provide discoverable help/footer text for actionable keys in the current context.
- MUST support UI-only filtering/search for visible rows without changing Runtime State.
- MUST implement refresh as a redraw or latest-snapshot consumption action, not as tracker polling or lifecycle mutation.
- MUST implement Web Dashboard handoff as command/URL guidance only; it must not start a Web Dashboard server in MVP.
- MUST validate local path inspection aids and keep them read-only.
- MUST NOT call retry, pause, resume, merge, push, status-update, cleanup, or pull-request lifecycle functions from MVP key handlers.
</requirements>

## Subtasks
- [ ] 5.1 Add UI-only focus and selection state for panels and rows.
- [ ] 5.2 Add keyboard navigation and discoverable contextual footer/help behavior.
- [ ] 5.3 Add filtering/search that changes only UI model state.
- [ ] 5.4 Add refresh redraw/latest-snapshot aid with no tracker polling side effect.
- [ ] 5.5 Add Web Dashboard handoff guidance and validated local path inspection aids.
- [ ] 5.6 Add tests proving key handlers are non-mutating.

## Implementation Details
Modify `apps/backend/bin/terminal_console_mosaic.ml` and any small supporting modules for UI state reducers. Reference the TechSpec "Safe Aid Model", "Terminal Environment", and "Known Risks" sections. Keep lifecycle functions outside this module to make MVP boundaries obvious during review.

Avoid binding terminal-owned interrupt keys such as `Ctrl+C` and ensure the terminal exits cleanly.

### Relevant Files
- `apps/backend/bin/terminal_console_mosaic.ml` — Keyboard handling, help/footer, and safe aids.
- `apps/backend/lib/terminal_console_model.ml` — Safe-aid descriptors and projected rows used by interaction state.
- `apps/backend/bin/main.ml` — Provides current CLI context needed for handoff guidance.
- `apps/backend/lib/orchestrator.ml` — Must not be called for lifecycle mutation from MVP key handlers.
- `apps/backend/test/test_backend.ml` — Focused tests for reducers and safe-aid boundaries.

### Dependent Files
- `apps/backend/bin/terminal_console_mosaic.ml` — Rendering from task 04 depends on interaction state after this task.
- `CONTEXT.md` and `README.md` — May need later docs updates to explain safe-aid boundaries.
- `apps/backend/lib/server.ml` — Must remain unchanged; Web Dashboard handoff does not start server or use command transport.

### Related ADRs
- [ADR-001: Scope Mosaic Terminal Console as a Runtime State command center](adrs/adr-001.md) — Prohibits a parallel orchestration surface.
- [ADR-002: Make the read-first Terminal Console with safe local aids the MVP approach](adrs/adr-002.md) — Defines the safe local aid boundary.
- [ADR-003: Run Mosaic in-process with Orchestrator Runtime State callbacks](adrs/adr-003.md) — Keeps state updates in-process through callbacks.

## Deliverables
- Keyboard-first navigation for MVP panels.
- Contextual footer/help content for supported keys.
- UI-only filtering/search behavior.
- Non-mutating refresh redraw/latest-snapshot aid.
- Web Dashboard handoff guidance and validated local path inspection aids.
- Unit tests with 80%+ coverage for interaction reducers and safe-aid handlers **(REQUIRED)**.
- Integration tests proving MVP key handlers do not mutate task lifecycle state **(REQUIRED)**.

## Tests
- Unit tests:
  - [ ] Pressing navigation keys changes selected panel or row without changing the projected Runtime State snapshot.
  - [ ] Filtering visible rows updates UI-only filter state and leaves Runtime State-derived data unchanged.
  - [ ] Refresh aid uses the latest in-memory snapshot and does not call tracker polling, status update, retry, merge, push, or cleanup functions.
  - [ ] Web Dashboard handoff aid returns command/URL guidance and does not start `Server.serve`.
  - [ ] Invalid local path inspection reports a UI-local status message and does not read or modify outside the allowed Workspace Repository surfaces.
  - [ ] Help/footer content includes `q`, navigation, filter/search, refresh, and handoff keys when those actions are available.
- Integration tests:
  - [ ] Terminal Console runtime with a fake safe-aid handler records only non-mutating safe-aid invocations.
  - [ ] Existing Web Dashboard endpoint tests still pass unchanged after handoff aid work.
- Test coverage target: >=80%
- All tests must pass

## Success Criteria
- All tests passing
- Test coverage >=80%
- Users can navigate and inspect MVP panels without touching task lifecycle state.
- Safe aids complete within the PRD five-keystroke target where applicable.
- No MVP key handler can retry, pause, resume, merge, push, update tracker status, or open pull requests.
