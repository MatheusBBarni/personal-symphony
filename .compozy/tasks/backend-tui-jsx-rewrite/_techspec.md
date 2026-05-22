# Backend TUI JSX Rewrite TechSpec

## Executive Summary

Rewrite `Terminal_console_tui` as a Reason-authored backend shell module that uses literal `Tui.Jsx` tags for existing Terminal Console UI construction. Preserve the current `Terminal_console_tui` module name, public types, public functions, runtime wiring, model transitions, safe-aid behavior, settings behavior, and rendered operator experience.

Primary trade-off: literal JSX and whole-module Reason conversion deliver the strongest maintainability/readability outcome, but create more syntax churn than replacing direct `Components.*` calls with `Tui.Jsx.*.make` inside the existing OCaml file. The mitigation is to keep the module contract stable and make view construction the only semantic rewrite target.

## System Architecture

### Component Overview

- **`Terminal_console_tui`**: Product-specific Terminal Console shell. Owns model state, keyboard transitions, rendered snapshot shaping, theme selection, and final `Tui.Node.t` view construction.
- **`Terminal_console_model`**: Runtime State projection and sanitization layer. It remains unchanged.
- **`Terminal_console_runtime`**: Runtime handoff from orchestration/readiness flow into the UI runtime. It remains unchanged.
- **`Tui.Jsx`**: Reusable TUI Toolkit Package JSX wrapper surface. Backend consumes it for view authoring.
- **`Tui.Renderer`**: Existing renderer that consumes the same `Tui.Node.t` tree. No renderer changes.

Data flow remains:

`Runtime_state.t -> Terminal_console_model.t -> Terminal_console_tui.model -> rendered_snapshot -> Tui.Jsx view -> Tui.Node.t -> Renderer`

## Implementation Design

### Core Interfaces

The public module contract stays stable. This sketch captures the dependency contract task code must preserve:

```go
type TerminalConsoleViewContract interface {
    InitialModel(state RuntimeState) TerminalConsoleModel
    RenderModel(model TerminalConsoleModel) RenderedSnapshot
    View(model TerminalConsoleModel) TuiNode
    ApplyKey(key UIKey, model TerminalConsoleModel) Transition
}
```

Required implementation shape:

- Preserve `Terminal_console_tui` as the module name exposed by `symphony_terminal_console_shell`.
- Replace `apps/backend/bin/terminal_console_tui.ml` with a Reason implementation for the same module slot.
- Keep exported types such as `runtime`, `model`, `transition`, `ui_key`, settings result types, and helper constructors compatible with existing callers.
- Convert view construction helpers to literal JSX tags where they produce `Tui.Node.t`.
- Keep non-view logic equivalent: filtering, selection, log compaction, status labels, settings validation flow, and safe-aid dispatch.

### Data Models

No new persisted data model.

Existing in-memory model types remain conceptually unchanged:

- `runtime`: handoff inputs, safe-aid callback, Web Dashboard handoff, settings, and save callback.
- `model`: projected snapshot, logs, terminal size, settings, interaction state.
- `interaction`: active tab, row selections, filter state, help/settings modal state, log scroll, queue expansion.
- `rendered_snapshot`: heading, status, tabs, subheading, panels, footer.

No Runtime State fields, Runtime Settings fields, Runtime Home files, or safe-aid variants are added.

### API Endpoints

None. This feature changes backend Terminal Console view authoring only. It does not add HTTP routes, CLI flags, Web Dashboard endpoints, or Runtime State APIs.

## Integration Points

No external services.

Internal integration boundaries:

- `apps/backend/bin/main.ml` must continue to refer to `Symphony_terminal_console_shell.Terminal_console_tui`.
- `apps/backend/bin/terminal_console_runtime.ml` must continue to build `Terminal_console_tui.runtime`.
- `apps/backend/bin/terminal_console_preview.ml` must continue to render preview states through the same module.
- `apps/backend/test/test_backend.ml` must continue to exercise the same public helpers and model transitions.
- `apps/tui/lib/jsx.re` may receive narrowly reusable wrappers only if a current Terminal Console view cannot be expressed exactly with the existing JSX surface.

## Impact Analysis

| Component | Impact Type | Description and Risk | Required Action |
| --- | --- | --- | --- |
| `apps/backend/bin/terminal_console_tui.ml` | Replaced/converted | Highest churn. Converts OCaml direct component construction to Reason JSX while preserving behavior. | Rename/replace with Reason implementation preserving module contract. |
| `apps/backend/bin/dune` | Modified if needed | Dune module list may need extension/source syntax adjustment. | Keep module name `terminal_console_tui`. |
| `apps/backend/bin/terminal_console_runtime.ml` | Referenced | Runtime handoff must remain source-compatible. | Use as contract check; avoid behavior changes. |
| `apps/backend/bin/main.ml` | Referenced | CLI/runtime wiring must not change. | Keep `Terminal_console_tui` public names stable. |
| `apps/backend/bin/terminal_console_preview.ml` | Referenced | Provides before/after preview parity evidence. | Run preview before and after implementation. |
| `apps/backend/test/test_backend.ml` | Modified if necessary | Existing tests cover behavior; minor syntax/access updates may be needed. | Preserve coverage and add focused parity assertions only for gaps. |
| `apps/tui/lib/jsx.re` | Optional | Add wrappers only when missing reusable primitives block exact view parity. | Add thin wrappers and TUI tests if touched. |
| `apps/tui/test/test_tui.re` | Optional | Required only if `apps/tui` wrappers change. | Add wrapper parity coverage. |
| TUI docs/examples | Modified | Docs should mention backend dogfooding without presenting this as operator-facing functionality. | Update only after rewrite is complete. |

## Testing Approach

### Unit Tests

Use existing focused Alcotest coverage as the primary behavior contract:

- Terminal Console status labels.
- Projection and sanitization.
- Project title and tabs.
- Cursor design theme and no-color distinctions.
- Tasks, Queue, Logs, Readiness, Attention, Task Detail panels.
- Minimum-size rendering.
- Navigation, filtering, queue expansion, and log scrolling.
- Help and settings modal behavior.
- Safe-aid read-only behavior.
- Runtime handoff and latest-state subscription.

Add targeted tests only where JSX conversion exposes an uncovered parity gap.

### Integration Tests

- Run before/after Terminal Console preview output for representative states.
- Preserve `terminal_console_preview` as the manual parity artifact.
- If `apps/tui` wrappers change, run TUI package wrapper tests and build.

Recommended representative preview states:

- Idle/ready state.
- Running Queue with active task.
- Readiness-blocked state.
- Attention/error state.
- Logs tab with background output.
- Settings modal open.
- Help modal open.
- Minimum terminal size message.

## Development Sequencing

### Build Order

1. Capture current Terminal Console preview output for representative states - no dependencies.
2. Convert `Terminal_console_tui` source to Reason while preserving module name and public signatures - depends on step 1.
3. Convert leaf node helpers (`content_line_nodes`, `log_line_nodes`, `footer_node`, `tab_node`) to literal JSX - depends on step 2.
4. Convert modal/header/root layout helpers to literal JSX - depends on step 3.
5. Convert active panel and scroll-box composition to literal JSX - depends on step 4.
6. Add narrowly reusable `apps/tui` JSX wrappers only if exact parity is blocked - depends on steps 3 through 5.
7. Update focused tests for any public-access syntax changes or uncovered parity gaps - depends on steps 2 through 6.
8. Refresh docs/examples to state backend Terminal Console dogfooding - depends on full JSX coverage from steps 3 through 6.
9. Run verification and compare before/after preview output - depends on steps 1 through 8.

### Technical Dependencies

- Existing `Tui.Jsx` wrappers for text, rich text, box, row, column, panel, scroll box, modal, badge, and related patterns.
- Dune support for Reason source in the backend shell library.
- Existing backend Terminal Console tests and preview executable.

## Monitoring and Observability

No runtime monitoring changes.

Development observability:

- JSX coverage for backend Terminal Console view construction.
- Before/after preview output comparison.
- Existing Alcotest pass/fail signal.
- Optional TUI wrapper parity tests when `apps/tui` changes.

## Technical Considerations

### Key Decisions

- **Literal Reason JSX over `Tui.Jsx.*.make` calls**: maximizes readability and satisfies the requested syntax.
- **Preserve `Terminal_console_tui` module contract**: avoids churn in runtime, preview, main CLI wiring, and tests.
- **No Runtime State or settings changes**: keeps the rewrite authoring-only.
- **Narrow reusable wrapper additions only**: prevents backend-specific behavior from leaking into the TUI Toolkit Package.
- **Backend-first verification**: matches the primary change surface while still requiring TUI checks when package wrappers change.

### Known Risks

- **Reason conversion churn**: mitigate by preserving public names and converting behavior mechanically.
- **Subtle visual drift**: mitigate with preview comparison and existing rendered fixture tests.
- **Modal layering drift**: treat help/settings modal placement and active-panel separation as critical parity cases.
- **Keyboard behavior drift**: preserve `apply_key`, `update`, and safe-aid transition semantics.
- **Wrapper overreach**: add `apps/tui` JSX wrappers only for reusable primitives that already exist as direct component/pattern APIs.

## Architecture Decision Records

- [ADR-001: Adopt Parity-Gated Backend Terminal Console JSX Migration](adrs/adr-001.md) — Superseded council recommendation.
- [ADR-002: Select Complete Backend Terminal Console JSX Rewrite](adrs/adr-002.md) — Accepted complete V1 scope.
- [ADR-003: Select Complete Coverage With Strict Parity PRD Approach](adrs/adr-003.md) — Accepted PRD product approach.
- [ADR-004: Implement Terminal Console View Rewrite As Reason JSX With Preserved Module Contract](adrs/adr-004.md) — Accepted technical approach for literal JSX, preserved module contract, wrapper policy, and parity gates.
