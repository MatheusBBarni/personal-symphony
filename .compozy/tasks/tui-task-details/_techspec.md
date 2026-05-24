# TUI Task Details TechSpec

## Executive Summary

Implement status-first inspect mode inside the backend Terminal Console by extending the existing Runtime State projection and TUI shell. The chosen approach preserves Ordered Queue presence in `Terminal_console_model.t`, derives visible tabs from that projection, and renders inline inspect details beneath the selected row for every non-Logs selectable tab.

The primary trade-off is adding projection-surface fields to avoid ambiguous Queue visibility. This is slightly broader than a TUI-only patch, but it keeps Runtime State and orchestration unchanged while preserving the distinction between no Ordered Queue and a present empty queue.

## System Architecture

### Component Overview

| Component | Responsibility |
| --- | --- |
| `Runtime_state` | Source data for running, retrying, attention, readiness, queue, Goal Loop, Goal Usage, and Context Status. No schema changes. |
| `Terminal_console_model` | Preserve Queue presence and expose inspect-ready, sanitized row details. |
| `terminal_console_tui` | Own visible tabs, active row state, Enter inspect toggling, inline detail rendering, help/footer copy, and Queue Space compatibility. |
| `test_backend.ml` | Focused coverage for projection, tab behavior, key handling, inline details, and read-only transitions. |

PRD mapping:

- Dynamic Queue visibility maps to `Terminal_console_model` plus TUI visible tabs.
- Status-first inspect mode maps to projection detail helpers plus inline TUI rendering.
- Tasks default surface maps to TUI active-tab clamping/defaulting.
- Read-only behavior maps to key transition tests with no lifecycle safe aids.

## Implementation Design

### Core Interfaces

Shape-only contract for the primary projection dependency; this is not a new Go package:

```go
type TerminalConsoleProjection struct {
	QueuePresent bool
	Queue        []TaskRow
	Active       []TaskRow
	Readiness    []ReadinessRow
	Inspect      InspectDetails
}
```

Reason-facing design:

- Add `queue_present: bool` or an equivalent `queue: option(list(task_row))` to `Terminal_console_model.t`.
- Add inspect detail helpers in `terminal_console_model.re` for task-like rows and readiness rows.
- Replace Queue-only `expanded_queue_id` as the only detail state with an inspect state that can target `Queue`, `Tasks`, `Readiness`, and `Attention`.
- Keep Space Queue expansion intact; Enter toggles inspect mode in normal mode.

### Data Models

- `Runtime_state.t`: unchanged.
- `Terminal_console_model.t`: modified to preserve Queue presence.
- `Terminal_console_model.inspect_details`: new projection-level detail shape for status-first display.
- `terminal_console_tui.interaction`: modified to track active inline inspect target.

### API Endpoints

Not applicable. This is a local Terminal Console rendering and interaction change.

## Impact Analysis

| Component | Impact Type | Description and Risk | Required Action |
| --- | --- | --- | --- |
| `terminal_console_model.re` | Modified | Queue presence and inspect detail projection. Medium risk due to changed projection type. | Add fields/helpers and projection tests. |
| `terminal_console_tui.re` | Modified | Dynamic tabs, Enter inspect, inline rendering, footer/help updates. Medium risk due to key and tab behavior. | Update interaction model and focused TUI tests. |
| `test_backend.ml` | Modified | Existing static tab tests need updates and new inspect coverage. Low risk. | Add cases near existing Terminal Console tests. |
| `Runtime_state.re` | Unchanged | Source data remains stable. | No schema changes. |
| Web Dashboard | Unchanged | PRD excludes Web Dashboard parity. | No action. |

## Testing Approach

### Unit Tests

- Projection preserves `ordered_queue = None` vs `Some { entries = [] }`.
- Visible tab text omits Queue only when Queue is absent.
- Initial active tab becomes Tasks when Queue is absent.
- Enter toggles inline inspect details for Tasks, Queue, Readiness, and Needs attention.
- Logs ignores inspect mode and preserves scroll behavior.
- Space still expands Queue rows.
- Inspect transitions do not emit lifecycle mutation safe aids.

### Integration Tests

- Render tests for active tab content with inline inspect details.
- Keyboard transition tests proving snapshot identity stays unchanged after navigation and inspect toggling.
- Existing Terminal Console fixture render coverage remains valid.

## Development Sequencing

### Build Order

1. Extend `Terminal_console_model.t` with Queue presence and inspect detail helpers - no dependencies.
2. Update projection tests for Queue absence and inspect detail content - depends on step 1.
3. Add dynamic visible tab derivation in `terminal_console_tui.re` - depends on step 1.
4. Add interaction state and Enter toggling for inspect mode - depends on step 3.
5. Render inline status-first details for each non-Logs selectable tab - depends on steps 1 and 4.
6. Update help/footer copy and Queue Space compatibility tests - depends on steps 3-5.
7. Run focused Alcotest coverage and `pnpm backend:build` - depends on steps 1-6.

### Technical Dependencies

- Existing `Runtime_state.t` fields are sufficient.
- No new package, service, or runtime dependency is required.

## Monitoring and Observability

No new runtime monitoring is required. Verification should rely on deterministic Terminal Console render and key-transition tests. Manual preview through `terminal_console_preview` can be used for visual confirmation after implementation.

## Technical Considerations

### Key Decisions

- **Projection-backed Queue presence:** avoids guessing from empty row lists.
- **Enter inspect toggle:** avoids changing existing Queue Space expansion.
- **Inline details:** keeps operators in the active panel and avoids adding modal or split-pane behavior.
- **Shared projection helpers:** centralizes status-first detail ordering without creating a new module.

### Known Risks

- **Dynamic tabs may break assumptions:** update tests that assert static tab order.
- **Inline detail may become noisy:** render only when Enter opens inspect mode.
- **Queue has two detail commands:** distinguish Space expansion from Enter inspect in footer/help.
- **Focused tests may miss broader issues:** run `pnpm backend:build`; escalate to `pnpm test` if implementation touches runtime behavior beyond projection/TUI.

## Architecture Decision Records

- [ADR-001: Preserve Queue Absence and Add Progressive Task Detail](adrs/adr-001.md) — Superseded narrower scope.
- [ADR-002: Adopt Unified Terminal Console Inspect Mode](adrs/adr-002.md) — Accepted unified inspect-mode product direction.
- [ADR-003: Use Status-First Inspect Mode for the PRD](adrs/adr-003.md) — Accepted status-first product approach.
- [ADR-004: Use Projection-Backed Inline Inspect State](adrs/adr-004.md) — Accepted technical model for Queue presence and inline inspect details.
- [ADR-005: Use Enter for Inspect and Keep Space Queue-Compatible](adrs/adr-005.md) — Accepted key behavior.
- [ADR-006: Verify with Focused Alcotest and Backend Build](adrs/adr-006.md) — Accepted verification gate.
