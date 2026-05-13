# Terminal Console Elegance Redesign

## Executive Summary

This TechSpec evolves the existing Mosaic-backed **Terminal Console** rather than replacing it. The runtime seam remains unchanged: `main.ml` selects the **Terminal Console** path, `Terminal_console_runtime` owns readiness-versus-orchestrator startup, and `Terminal_console_model` continues to project **Runtime State** for `Terminal_console_mosaic`. The redesign happens at the projection-and-render boundary.

The primary technical decision is to replace the current flat, string-heavy snapshot with an explicit mode-modeled projection: shared chrome plus a top-level body variant for active-run and readiness/startup states. The main trade-off is higher model and test churn in exchange for removing renderer re-parsing, fixed six-panel assumptions, and focus-only navigation that currently blocks a coherent redesign.

## System Architecture

### Component Overview

- **`Terminal_console_runtime`**
  Keeps the current readiness/orchestrator branch selection and latest-state handoff. No new orchestration responsibilities should move here.

- **`Terminal_console_model`**
  Becomes the main redesign surface. It should project **Runtime State** into:
  - shared chrome data
  - explicit top-level mode bodies
  - structured detail records
  - sanitized safe-aid metadata

- **`Terminal_console_mosaic`**
  Stops thinking in fixed panels first. It should render shared chrome plus the selected mode body, with layout variants for wide and compact terminals. UI reducer state stays here.

- **Existing `Runtime_state`**
  Remains the visible source of truth. MVP should derive new structure from existing fields rather than expanding Runtime State schema.

- **Existing tests in `apps/backend/test/test_backend.ml`**
  Continue to protect projection behavior, sanitization, runtime wiring, and user-visible rendering. The redesign should extend them with mode-level coverage rather than replace them wholesale.

### Data Flow

1. `main.ml` prepares runtime state exactly as it does today.
2. `Terminal_console_runtime` chooses readiness-blocked or orchestrator-backed **Terminal Console** mode exactly as it does today.
3. `Runtime_state.t` snapshots continue to flow into the UI runtime through the existing in-process handoff.
4. `Terminal_console_model.of_runtime_state` builds a structured `Terminal_console_snapshot`.
5. `Terminal_console_mosaic` renders:
   - shared chrome
   - the selected top-level mode body
   - compact or wide layout for that mode
6. Key handling updates UI-only state and invokes existing non-mutating safe aids only.

## Implementation Design

### Core Interfaces

```ocaml
type mode_tab = Readiness_tab | Active_run_tab

type chrome = {
  title : string;
  status : status_badge;
  generated_at : string;
  tabs : tab_summary list;
  footer : footer_hint list;
}

type body =
  | Readiness_mode of readiness_mode
  | Active_run_mode of active_run_mode
```

```ocaml
type terminal_console_snapshot = {
  chrome : chrome;
  selected_tab : mode_tab;
  body : body;
  safe_aids : safe_aid list;
  last_error : string option;
}
```

```go
type TerminalConsoleSnapshot struct {
    Chrome      ChromeModel
    SelectedTab string
    Body        ModeBody
    SafeAids    []SafeAid
    LastError   *string
}
```

```ocaml
val of_runtime_state : Runtime_state.t -> terminal_console_snapshot
val render_mode_body : terminal_console_snapshot -> interaction -> rendered_mode
val apply_key : ui_key -> model -> transition
```

### Data Models

#### Shared Chrome Model

The shared chrome model should hold information that every top-level mode needs:

- current high-level status badge
- generated-at timestamp
- top-level tab summaries
- cross-mode alert counts or badges
- contextual footer hints derived from UI state

This replaces the current `summary : string list` approach for global state.

#### Top-Level Mode Models

Use explicit top-level mode bodies rather than always-present buckets:

- **`Readiness_mode`**
  - readiness summary
  - readiness rows
  - selected readiness detail
  - startup-specific support context

- **`Active_run_mode`**
  - active-run summary
  - active rows
  - ordered queue summary/rows
  - optional **Compozy PRD Run** summary
  - selected task detail

#### Structured Detail Records

Replace string-packed detail with structured records:

- active-task detail:
  - issue identifier
  - title
  - state
  - stage-state summary
  - harness identity
  - branch label
  - goal usage
  - context status
  - current error
- readiness detail:
  - requirement
  - remediation
  - blocking scope
  - optional supporting context label

The renderer may format these for display, but it must not recover meaning by splitting strings.

#### UI State

Keep UI reducer state inside `Terminal_console_mosaic`:

- selected top-level tab
- selection indexes within the current mode
- filter query
- help visibility
- compact vs wide layout state derived from terminal size

Do not move UI reducer state into the projection for MVP.

### API Endpoints

No new endpoints are required.

Existing behavior remains unchanged:

- existing **Web Dashboard** endpoints remain separate
- the **Terminal Console** continues to use the in-process state handoff
- no new shared serializable snapshot is introduced in MVP

The new projection should be shaped so a shared snapshot could be introduced later without a second rewrite, but that convergence is explicitly out of MVP scope.

## Integration Points

No new external integrations are required.

Internal boundaries that must remain stable:

- `main.ml` startup branch selection
- `Terminal_console_runtime` latest-state handoff
- existing safe-aid contract
- existing **Web Dashboard** separation and **Live Dashboard Connection** behavior

## Impact Analysis

| Component | Impact Type | Description and Risk | Required Action |
| --- | --- | --- | --- |
| `apps/backend/lib/terminal_console_model.ml` | modified | Main redesign surface. Risk: projection churn and sanitization regressions. | Replace flat/string-heavy snapshot with explicit mode models and structured detail records. |
| `apps/backend/bin/terminal_console_mosaic.ml` | modified | Main renderer and interaction rewrite. Risk: layout/navigation regressions. | Replace panel-first rendering with shared chrome plus mode-body rendering for wide and compact layouts. |
| `apps/backend/test/test_backend.ml` | modified | Existing tests are broad and valuable. Risk: brittle updates during migration. | Extend projection tests to mode-level assertions and keep essential render/panel coverage during transition. |
| `apps/backend/bin/main.ml` | validated | Existing runtime branch wiring should remain stable. Risk: unnecessary blast radius. | Keep behavior unchanged except for any data needed to instantiate the redesigned snapshot. |
| `apps/backend/bin/terminal_console_runtime.ml` | validated | Existing handoff is the correct seam. Risk: accidental runtime refactor. | Keep runtime handoff unchanged for MVP. |
| `docs/adr/0024-default-rich-terminal-console.md` and `CONTEXT.md` | review-only | Product semantics should stay intact. Risk: accidental contract drift. | Update only if implementation materially changes established runtime semantics or user-visible domain language. |

## Testing Approach

### Unit Tests

Extend the current projection-focused tests in `apps/backend/test/test_backend.ml`:

- mode projection:
  - idle
  - readiness-blocked
  - active-run with running work
  - retrying
  - attention conditions
  - queue presence
  - **Compozy PRD Run** presence
- structured detail projection:
  - active-task detail fields
  - readiness-detail fields
  - cross-mode tab summaries
- sanitization:
  - escape stripping
  - secret redaction
  - structured fields never bypass sanitization

### Integration Tests

Keep existing runtime wiring tests and extend them only where needed:

- readiness path still starts the **Terminal Console** without orchestration
- orchestrator path still sends snapshots through the existing handoff
- safe aids remain non-mutating
- `--web` and `--once` behavior remain unchanged

### Render Tests

Per the chosen testing posture, keep the current panel-level safety net but add mode-level tests:

- selected mode renders the correct primary hierarchy
- compact 80x24 layout renders in a single column
- wide layout renders detail as secondary content
- tab switching changes meaning, not just focus
- footer hints are mode-aware

## Development Sequencing

### Build Order

1. Introduce the new mode-modeled projection types in `terminal_console_model.ml` while keeping current runtime inputs unchanged. No dependencies.
2. Implement projection builders for shared chrome, readiness mode, active-run mode, and structured detail records. Depends on step 1.
3. Migrate projection unit tests from flat `mode` and string assertions to explicit mode/content assertions. Depends on step 2.
4. Introduce new Mosaic render helpers for shared chrome, mode-body rendering, and compact-versus-wide layout. Depends on step 1.
5. Replace fixed six-panel rendering with explicit top-level mode rendering while preserving the current UI reducer boundary. Depends on steps 2 and 4.
6. Update key handling so top-level tab switching is semantic mode switching rather than panel focus cycling. Depends on step 5.
7. Implement compact single-column rendering for 80x24 while keeping wide-mode secondary detail composition. Depends on step 5.
8. Extend render tests with mode-level and compact-layout coverage while retaining essential panel-level regression tests. Depends on steps 5, 6, and 7.
9. Re-run runtime integration coverage to verify readiness/orchestrator handoff, safe-aid behavior, and unchanged `--web`/`--once` semantics. Depends on steps 3 and 8.
10. Review docs and ADR alignment for any runtime-semantics drift and run final backend verification. Depends on steps 1 through 9.

### Technical Dependencies

- Existing `Runtime_state` fields remain sufficient for MVP.
- Existing `Terminal_console_runtime` handoff remains stable.
- Existing Mosaic dependency and Dune wiring remain in place from prior work.
- The redesign depends on not introducing a new shared browser-terminal snapshot in this iteration.

## Monitoring and Observability

- Continue to rely on **Runtime State** as the primary observable state source.
- Keep UI-local status messages for:
  - tab changes
  - filter changes
  - refresh
  - handoff guidance
  - invalid or unavailable inspection paths
- Add targeted debug logging only around:
  - projection/render failures
  - state handoff failures
  - terminal cleanup failures
- Avoid logging raw unsanitized detail payloads.
- Keep product success observability focused on:
  - active-run comprehension
  - fallback reduction
  - long-run retention
  - boundary integrity of non-mutating controls

## Technical Considerations

### Key Decisions

- **Decision:** Keep the current in-process runtime seam for MVP.
  - **Rationale:** The existing handoff is already correct and localizes the redesign to the console boundary.
  - **Trade-offs:** Gives up immediate browser-terminal convergence on one shared snapshot.
  - **Alternatives rejected:** shared serializable snapshot now; moving more presentation into runtime.

- **Decision:** Replace the flat projection with explicit top-level mode models.
  - **Rationale:** The current flat snapshot is one of the main reasons the renderer is locked into a six-panel surface.
  - **Trade-offs:** Requires coordinated model, render, and test migration.
  - **Alternatives rejected:** renderer-only layering over the current projection.

- **Decision:** Replace string-packed summaries and details with structured records.
  - **Rationale:** The redesigned hierarchy and curated detail pane need first-class data, not re-parsed text.
  - **Trade-offs:** More type churn and migration work.
  - **Alternatives rejected:** keep strings in place; partial hybrid detail modeling.

- **Decision:** Preserve 80x24 support with a compact single-column layout.
  - **Rationale:** The redesign should not narrow where the **Terminal Console** can be used.
  - **Trade-offs:** More nuanced layout logic and additional render coverage.
  - **Alternatives rejected:** larger minimum size; hiding detail entirely at minimum size.

- **Decision:** Extend the current test suite rather than replacing it.
  - **Rationale:** Existing projection and render tests already cover the right seams.
  - **Trade-offs:** Some temporary duality while panel-era assertions are migrated.
  - **Alternatives rejected:** mostly integration-only coverage; full panel-test removal upfront.

### Known Risks

- **Projection overgrowth**
  The new model could become too broad.
  Mitigation: keep only shared chrome, two top-level mode bodies, and the structured detail needed for MVP.

- **Render migration regressions**
  Replacing panel-first rendering could break existing behavior unexpectedly.
  Mitigation: migrate projection tests first, then renderer tests, while keeping current runtime wiring stable.

- **Compact-layout clutter**
  80x24 rendering may still feel crowded.
  Mitigation: enforce strict per-mode priority and stack secondary detail below primary content in compact mode.

- **Future snapshot divergence**
  A later shared Terminal Console/Web Dashboard snapshot may want different boundaries.
  Mitigation: keep the new projection serializable-friendly without building the shared snapshot now.

## Architecture Decision Records

- [ADR-001: Scope the Terminal Console elegance redesign as a two-mode presentation refactor](./adrs/adr-001.md) — Keep the redesign read-first, mode-aware, and primarily inside the presentation layer.
- [ADR-002: Prioritize active-run elegance as the MVP product approach](./adrs/adr-002.md) — Optimize the MVP for heavy daily operators during live orchestration.
- [ADR-003: Ship the Terminal Console redesign as the default experience](./adrs/adr-003.md) — Treat the redesign as the intended default product surface, not a preview-only path.
- [ADR-004: Redesign the Terminal Console around explicit mode models over the existing in-process seam](./adrs/adr-004.md) — Keep runtime wiring stable while replacing the flat projection with explicit mode bodies.
- [ADR-005: Replace string-packed Terminal Console summaries with structured mode-specific records](./adrs/adr-005.md) — Move summary and detail meaning into typed projection records instead of renderer-parsed strings.
- [ADR-006: Preserve 80x24 support with compact single-column mode rendering](./adrs/adr-006.md) — Keep the current minimum-size contract and adapt each mode to a compact layout.
