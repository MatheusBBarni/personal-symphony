# Terminal Console Settings and Web Dashboard Start TechSpec

## Executive Summary

Implement V1 as a narrow backend-owned Terminal Console extension. The Terminal Console gets a product-specific settings modal, `server.port` is persisted to the Runtime Contract, Terminal Console theme is persisted to ignored Runtime Home UI state, and `w` starts or reuses an in-process loopback Web Dashboard service backed by the same Runtime State handoff.

The main trade-off is accepting one tightly scoped Runtime Contract write from the Terminal Console for `server.port` while keeping local theme state outside the Runtime Contract. This preserves existing Web Dashboard port semantics without turning Terminal Console settings into a general Runtime Settings editor.

## System Architecture

### Component Overview

- `Terminal_console_tui`: owns `s` settings modal, key handling, draft values, validation feedback, and user-facing status messages.
- `Terminal_console_runtime`: owns Runtime State handoff and passes callbacks for settings persistence and dashboard start/reuse into the UI runtime.
- `Terminal_console_settings`: new backend Reason module for theme state under `.symphony/state/terminal-console/settings.json` and scoped `server.port` updates in `.symphony/settings.json`.
- `Dashboard_service`: new backend Reason module that probes identity, starts `Server.serve` on a background thread, and returns started/reused/conflict/failure results.
- `Server`: adds dashboard identity response support while keeping existing Runtime State HTTP and Live Dashboard Connection behavior unchanged.

## Implementation Design

### Core Interfaces

Implementation is Reason/OCaml. The Go struct below is a template-required shape for the identity contract other components depend on:

```go
type DashboardIdentity struct {
    WorkspaceRoot string `json:"workspace_root"`
    RuntimeHome   string `json:"runtime_home"`
    Mode          string `json:"mode"`
    AuthRequired  bool   `json:"auth_required"`
}
```

```reason
type dashboard_result =
  | Started(string)
  | Reused(string)
  | Conflict(string)
  | Failed(string);

type settings_save = {
  theme: string,
  port: int,
};
```

### Data Models

- Runtime Contract update: mutate only `server.port` in `.symphony/settings.json`; preserve unrelated known and unknown JSON fields.
- Local UI state file: `.symphony/state/terminal-console/settings.json`.
- Local UI state JSON: `{ "theme": "cursor-dark" }`.
- Supported V1 themes: `cursor-dark` default, `dark`, `light`, `high-contrast`, `no-color`.
- Dashboard identity JSON: workspace root, runtime home, mode, auth requirement, server host, server port.

### API Endpoints

- `GET /api/v1/dashboard/identity`: returns dashboard identity for compatible loopback reuse checks.
- Existing `/api/v1/state`, `/api/v1/refresh`, and `/api/v1/state/live` behavior remains unchanged.
- For non-loopback Web Dashboard mode, identity must follow existing dashboard auth rules or be unavailable; Terminal Console V1 starts only loopback servers.

## Integration Points

- Runtime Contract: `server.port` remains the source of truth for dashboard port.
- Runtime Home state: Terminal Console theme is local ignored state.
- Web Dashboard server: `w` uses the same Runtime State provider as the active Terminal Console.
- Docs/domain language: update `CONTEXT.md`, README, and a project ADR because Terminal Console now has scoped local setup controls.

## Impact Analysis

| Component | Impact Type | Description and Risk | Required Action |
|---|---|---|---|
| `terminal_console_tui.ml` | modified | Adds modal state, `s`, settings save, and `w` result rendering | Extend model/key tests |
| `terminal_console_runtime.ml` | modified | Adds callbacks for settings and dashboard actions | Test callback wiring |
| `main.ml` | modified | Reuses extracted dashboard startup path | Keep CLI `--web` behavior equivalent |
| `Server` | modified | Adds identity endpoint | Test loopback/auth behavior |
| `Config`/settings helper | modified/new | Scoped `server.port` writer | Test validation and field preservation |
| `Runtime_home`/state helper | modified/new | Adds ignored UI state path handling | Test bootstrap idempotency preserved |
| Docs/ADRs | modified | Updates Terminal Console contract language | Run docs checks if touched |

## Testing Approach

### Unit Tests

- Port validation: empty, nonnumeric, zero, negative, over `65535`, valid values.
- Theme loading: missing file defaults to `cursor-dark`; invalid theme falls back with visible feedback.
- Runtime Contract writer preserves unrelated fields and updates only `server.port`.
- Settings modal key flow: open with `s`, edit, save, cancel, render footer/help.

### Integration Tests

- `w` starts a loopback dashboard from readiness-blocked Terminal Console state.
- `w` reuses a compatible identity endpoint for the same Workspace Repository and Runtime Home.
- `w` reports conflict for unrelated listener, mismatched workspace, or mismatched runtime home.
- Existing `--web` startup, auth, Live Dashboard Connection, and Runtime State HTTP tests remain green.
- Non-mutation tests assert settings and `w` do not update tracker status, queue state, Task Branches, or orchestration lifecycle state.

## Development Sequencing

### Build Order

1. Add settings models and persistence helpers for theme state and scoped `server.port` updates - no dependencies.
2. Extract dashboard service startup and identity response support - depends on step 1 for normalized workspace/runtime identity values.
3. Extend Terminal Console runtime callbacks and `terminal_console_tui.ml` modal state - depends on steps 1 and 2.
4. Update README, `CONTEXT.md`, and project ADR language for scoped local setup controls - depends on step 3 behavior.
5. Add focused Alcotest coverage for settings, dashboard start/reuse, identity conflicts, and non-mutation - depends on steps 1 through 4.
6. Run verification: targeted tests first, then `pnpm test`, `pnpm backend:build`, and docs checks if docs changed - depends on step 5.

### Technical Dependencies

- No new external packages.
- No frontend implementation required for V1.
- No Runtime Contract default change required.

## Monitoring and Observability

- Emit secret-free dashboard service events: started, reused, conflict, failed.
- Include `server_host`, `server_port`, `workspace_root`, `runtime_home`, and `auth_required`; never include token values.
- Surface user-facing status messages in the Terminal Console for saved settings, invalid input, started, reused, conflict, and failed.

## Technical Considerations

### Key Decisions

- Persist `server.port` in Runtime Settings; persist theme in ignored Runtime Home state.
- Keep the settings UI product-specific instead of introducing reusable TUI settings abstractions.
- Use an in-process background dashboard service instead of a child `symphony --web` process.
- Require identity-based reuse rather than port-only reuse.

### Known Risks

- JSON formatting churn in `.symphony/settings.json`; mitigate with structured update tests and unknown-field retention.
- Background server thread failures; mitigate by isolating startup and returning explicit failure statuses.
- Identity mismatch confusion; mitigate with distinct messages for compatible reuse, occupied port, and different Workspace Repository.
- Settings scope creep; mitigate by keeping V1 fields hardcoded to theme and `server.port`.

## Architecture Decision Records

- [ADR-001: Scope the Terminal Console Settings MVP](adrs/adr-001.md) - Defines the narrow settings and Web Dashboard local service control scope.
- [ADR-002: Select Narrow Setup MVP Product Approach](adrs/adr-002.md) - Records the setup-friction-focused product approach.
- [ADR-003: Terminal Console Settings and Dashboard Service Architecture](adrs/adr-003.md) - Selects the persistence, settings UI, dashboard service, and identity-reuse architecture.
