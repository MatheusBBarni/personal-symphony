---
status: completed
title: "Add Terminal Console Settings Persistence"
type: backend
complexity: medium
dependencies: []

---

# Task 01: Add Terminal Console Settings Persistence

## Overview
This task adds the persistence boundary for the Terminal Console setup values before UI or service behavior depends on them. It creates the local Terminal Console theme state and the scoped Runtime Settings writer for `server.port` without changing Bootstrap defaults.

<critical>
- ALWAYS READ the PRD and TechSpec before starting
- REFERENCE TECHSPEC for implementation details — do not duplicate here
- FOCUS ON "WHAT" — describe what needs to be accomplished, not how
- MINIMIZE CODE — show code only to illustrate current structure or problem areas
- TESTS REQUIRED — every task MUST include tests in deliverables
</critical>

<requirements>
- REQ-01 MUST add a backend ReasonML persistence helper for Terminal Console settings.
- REQ-02 MUST persist Terminal Console theme under ignored Runtime Home state at `.symphony/state/terminal-console/settings.json`.
- REQ-03 MUST default a missing theme state file to `cursor-dark`.
- REQ-04 MUST reject unsupported themes and surface a safe fallback result for the caller.
- REQ-05 MUST update only `server.port` in `.symphony/settings.json` while preserving unrelated known and unknown JSON fields.
- REQ-06 MUST reject empty, nonnumeric, zero, negative, and over-65535 port values before writing any file.
- REQ-07 MUST NOT change Runtime Contract defaults in `apps/backend/lib/runtime_home.ml`.
- REQ-08 MUST keep Terminal Console state under the already ignored Runtime Home `state` directory.
</requirements>

## Subtasks
- [x] 1.1 Review `_prd.md`, `_techspec.md`, ADR-001, ADR-002, and ADR-003.
- [x] 1.2 Add a ReasonML backend settings helper for theme state and scoped dashboard port persistence.
- [x] 1.3 Keep Runtime Home path handling idempotent and avoid overwriting unrelated Runtime Contract content.
- [x] 1.4 Add validation results for supported themes and dashboard port inputs.
- [x] 1.5 Add focused backend tests for theme loading, theme saving, port validation, and JSON preservation.

## Implementation Details
Use the TechSpec "Data Models" and "Development Sequencing" sections for the accepted persistence split. Keep the implementation in backend code and avoid introducing a reusable TUI settings framework or a Runtime Contract default change.

### Relevant Files
- `apps/backend/lib/terminal_console_settings.re` — New ReasonML module for Terminal Console theme state and scoped `server.port` updates.
- `apps/backend/lib/dune` — Library stanza may need to include the new backend module.
- `apps/backend/lib/util.re` — Existing file and directory helpers for Runtime Home state writes.
- `apps/backend/lib/runtime_home.ml` — Existing Runtime Home paths and Bootstrap defaults; read for constraints, do not change defaults.
- `apps/backend/lib/config.ml` — Existing `server.port` parsing behavior and Runtime Settings shape.
- `apps/backend/test/test_backend.ml` — Focused Alcotest coverage for Runtime Home, settings parsing, and JSON preservation.
- `.agents/rules/backend.md` — Backend rule requiring new source modules under `apps/backend/**` to be ReasonML.

### Dependent Files
- `apps/backend/bin/main.ml` — Later tasks will load the persisted port and theme through this helper.
- `apps/backend/bin/terminal_console_runtime.ml` — Later tasks will pass settings callbacks into the Terminal Console runtime.
- `apps/backend/bin/terminal_console_tui.ml` — Later tasks will render and save the settings values.

### Related ADRs
- [ADR-001: Scope the Terminal Console Settings MVP](adrs/adr-001.md) — Defines the narrow settings scope.
- [ADR-002: Select Narrow Setup MVP Product Approach](adrs/adr-002.md) — Selects persistent theme and port for V1.
- [ADR-003: Terminal Console Settings and Dashboard Service Architecture](adrs/adr-003.md) — Selects theme state outside Runtime Contract and port inside Runtime Settings.

## Deliverables
- New Terminal Console settings persistence helper.
- Validated supported-theme and port-input results for callers.
- Scoped Runtime Settings writer that preserves unknown fields.
- Unit tests with 80%+ coverage for the new helper **(REQUIRED)**.
- Integration tests for Runtime Home and Runtime Contract preservation **(REQUIRED)**.

## Tests
- Unit tests:
  - [x] Missing Terminal Console state file returns `cursor-dark` without creating unrelated files.
  - [x] Saved `cursor-dark`, `dark`, `light`, `high-contrast`, and `no-color` themes round-trip.
  - [x] Unsupported theme values fall back safely and report that fallback to the caller.
  - [x] Port validation rejects empty, nonnumeric, `0`, negative, and `65536` inputs.
  - [x] Port validation accepts `1`, `8080`, and `65535`.
- Integration tests:
  - [x] Updating `server.port` preserves unrelated top-level Runtime Settings fields.
  - [x] Updating `server.port` preserves unknown nested fields under `server`.
  - [x] Invalid port input leaves `.symphony/settings.json` byte-for-byte unchanged.
  - [x] Bootstrap idempotency remains unchanged for existing Runtime Contract files.
  - [x] Terminal Console settings state path stays under ignored Runtime Home state.
- Test coverage target: >=80%
- All tests must pass

## Success Criteria
- All tests passing
- Test coverage >=80%
- Theme persistence lives under ignored Runtime Home state.
- Dashboard port persistence updates only `server.port`.
- Runtime Contract defaults are unchanged.
- Focused backend verification for the runtime-home/settings tests and `pnpm backend:build` passes.
