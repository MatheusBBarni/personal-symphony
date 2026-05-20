You are the Engineer agent for the Symphony Orchestrator Repository.

You are a senior software engineer specializing in OCaml, ReScript, Rust, React, TypeScript, and JavaScript.

Responsibilities:
- Implement only the scoped issue.
- Use CONTEXT.md terms and follow AGENTS.md.
- Prefer existing module boundaries and tests over new abstractions.
- Preserve Runtime Contract semantics unless the issue explicitly asks to change them.
- Do not touch protected release/package paths unless the issue explicitly authorizes that scope.
- Edit ReScript .res sources only; never commit generated .res.js files.
- Keep examples secret-free and refer only to GITHUB_TOKEN or GH_TOKEN variable names.
- Run focused verification, then broader checks when shared orchestration/config/runtime behavior changes.

Stage Commit is enabled for this stage. Leave the worktree ready for a local commit boundary before review.

---

Stage agent: engineer

# Compozy Task Step

Run: compozy:tui-settings-web-server
PRD directory: tui-settings-web-server
Current task file: task_07.md
Current task title: Update Product Docs and Project ADR

## Current Task (`task_07.md`)

---
status: in_progress
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

## PRD (`_prd.md`)

# Terminal Console Settings and Web Dashboard Start PRD

## Overview

Terminal Console Settings and Web Dashboard Start reduces setup friction for solo local developers operating Symphony from a Workspace Repository.

V1 adds a focused settings menu to the Terminal Console. The user can persist their Terminal Console theme, persist the Web Dashboard port, and press `w` to start or reuse the local loopback Web Dashboard for the current Workspace Repository and Runtime Home. The feature keeps the Terminal Console as the main local operating surface without turning it into a general Runtime Settings editor or a task lifecycle control panel.

## Goals

- Reduce manual setup steps for Terminal Console appearance and Web Dashboard access.
- Let users persist the immediate local operating experience from inside the Terminal Console.
- Make the Web Dashboard reachable from the Terminal Console with one visible, reliable action.
- Preserve the product boundary that Terminal Console setup controls do not mutate task lifecycle state.
- Keep V1 narrow enough to validate user value before expanding local cockpit behavior.

## User Stories

- As a solo local developer, I want to open settings from the Terminal Console so that I can adjust my local operating experience without leaving Symphony.
- As a solo local developer, I want my Terminal Console theme choice to persist so that the console remains comfortable across sessions.
- As a solo local developer, I want to set the Web Dashboard port from the Terminal Console so that I do not need to edit Runtime Settings by hand for a common local setup change.
- As a solo local developer, I want `w` to start or reuse the local Web Dashboard and show the URL so that I can move from terminal monitoring to browser monitoring without remembering a command.
- As a security-conscious operator, I want Terminal Console dashboard controls to stay loopback-only so that local convenience does not accidentally expose Runtime State.

## Core Features

### Critical: Settings Menu

The Terminal Console provides a focused settings surface opened with `s`. The footer and help modal show the settings shortcut wherever it is relevant.

The menu is limited to V1 setup controls: Terminal Console theme and Web Dashboard port. It does not expose task lifecycle controls, tracker configuration, Git policy, agent routing, non-loopback host exposure, or a general Runtime Settings editor.

### Critical: Persistent Theme Selection

The user can choose from a small supported set of Terminal Console themes. The selected theme persists across Terminal Console sessions.

The theme setting affects the Terminal Console product surface. It does not change Web Dashboard styling and does not introduce a broad theme platform for every Symphony surface.

### Critical: Persistent Dashboard Port

The user can edit the Web Dashboard port as a numeric value. The selected port persists across Terminal Console sessions.

The product must reject invalid values before any user-visible side effect. Invalid examples include empty input, nonnumeric input, out-of-range values, and values that cannot be used for the local dashboard.

### Critical: `w` Starts Or Reuses Web Dashboard

Pressing `w` starts or reuses a compatible loopback Web Dashboard for the current Workspace Repository and Runtime Home, then shows the dashboard URL.

If the dashboard is already available and compatible, Symphony reports the existing URL instead of starting another server. If the configured port is occupied by something incompatible, Symphony reports a clear conflict instead of attaching to an unrelated process.

### High: Clear Local Feedback

The Terminal Console shows concise feedback for saved settings, invalid port input, dashboard startup, compatible reuse, unavailable dashboard, and port conflicts.

The feedback must help the user decide the next action without leaving the Terminal Console for routine setup cases.

## User Experience

The user starts Symphony in a Workspace Repository and lands in the Terminal Console. The footer shows `s` for settings and `w` for the Web Dashboard.

When the user presses `s`, a settings menu opens over the console. The user can move between theme and dashboard port fields, change values, save them, or exit without saving. Saved changes are confirmed in the Terminal Console and apply to later sessions.

When the user presses `w`, Symphony checks whether a compatible local Web Dashboard is already available. If yes, the console shows the dashboard URL. If not, Symphony starts the local loopback dashboard and then shows the URL. If startup fails or the port is occupied by an incompatible process, the console reports the reason in plain language.

The experience should feel like a local setup surface, not a new orchestration control surface. Settings and `w` are visible enough to discover, but they do not compete with the console’s primary Runtime State monitoring workflow.

## High-Level Technical Constraints

- The feature must use existing Symphony product language: Workspace Repository, Runtime Home, Runtime Contract, Runtime Settings, Terminal Console, Web Dashboard, and Live Dashboard Connection.
- Terminal Console dashboard controls are loopback-only in V1.
- V1 must preserve the existing non-loopback Web Dashboard auth expectation: non-loopback access remains governed outside Terminal Console settings.
- The feature must not expose or log token values, local `.env` contents, webhook URLs, or secrets.
- The Terminal Console must not mutate task lifecycle state, issue state, queues, stages, Task Branches, or orchestration results.

## Non-Goals (Out of Scope)

- General Runtime Settings editor.
- Editing `server.host` or enabling non-loopback exposure from the Terminal Console.
- Stop, restart, or kill controls for dashboard processes.
- Automatic browser opening.
- Web Dashboard visual redesign.
- Web Dashboard settings UI.
- Task lifecycle actions from the settings menu.
- Tracker, Git, agent, Harness, Sandbox, or queue configuration.
- Reusable settings framework in the TUI toolkit package.
- Remote dashboard sharing or LAN/Tailscale setup flows.

## Phased Rollout Plan

### MVP (Phase 1)

- Add `s` settings access with footer/help visibility.
- Support persistent Terminal Console theme selection.
- Support persistent numeric Web Dashboard port editing.
- Make `w` start or reuse a compatible loopback Web Dashboard and show the URL.
- Show clear feedback for save, invalid input, startup, reuse, and conflict cases.

Success criteria:

- A solo developer can persist theme and dashboard port without editing files manually.
- A solo developer can press `w` and either get a working local dashboard URL or a clear reason why not.
- Terminal Console setup controls do not mutate task lifecycle state.

### Phase 2

- Add richer dashboard status visibility inside the Terminal Console.
- Consider an explicit open-browser action after V1 validates start/reuse behavior.
- Refine settings discoverability based on observed usage.

Success criteria:

- Users can understand dashboard availability at a glance.
- Additional actions remain local-service controls, not orchestration controls.

### Phase 3

- Evaluate whether more local setup controls belong in the Terminal Console.
- Consider a broader local cockpit only if repeated setup needs justify it.
- Revisit whether any reusable settings primitives belong in the TUI toolkit.

Success criteria:

- Expansion decisions are backed by observed setup friction, not generic settings-platform ambition.
- Product boundaries remain clear in documentation and user-facing labels.

## Success Metrics

- Manual setup reduction: reduce direct file edits or remembered dashboard commands for theme and port setup by at least 80%.
- Dashboard start/reuse success: at least 95% of local `w` attempts either produce a dashboard URL or a clear actionable failure within 3 seconds.
- Port validation clarity: 100% of invalid port inputs are rejected before dashboard start/reuse side effects.
- Discoverability: `s` and `w` appear in footer/help in all relevant Terminal Console states.
- Boundary preservation: no task lifecycle state changes occur from settings navigation, settings save, or dashboard start/reuse actions.

## Risks and Mitigations

- Risk: Users assume the settings menu can edit every Runtime Setting.
  Mitigation: Label the surface as focused Terminal Console setup and keep V1 limited to theme and dashboard port.
- Risk: Users expect LAN or Tailscale exposure from the settings menu.
  Mitigation: Make V1 loopback-only and document that non-loopback exposure remains outside Terminal Console settings.
- Risk: `w` starting a local service surprises users who remember handoff-only behavior.
  Mitigation: Update product language and make the action label explicit: start or reuse Web Dashboard.
- Risk: Port conflicts create confusing failures.
  Mitigation: Use plain status messages that distinguish invalid input, incompatible listener, and failed dashboard start.
- Risk: The settings surface becomes a path to orchestration controls.
  Mitigation: Keep task lifecycle actions explicitly out of scope and require separate product decisions for expansion.

## Architecture Decision Records

- [ADR-001: Scope the Terminal Console Settings MVP](adrs/adr-001.md) - Defines V1 as a narrow Terminal Console settings menu plus idempotent Web Dashboard local service control.
- [ADR-002: Select Narrow Setup MVP Product Approach](adrs/adr-002.md) - Selects the setup-friction-focused product approach and records the V1 decisions for persistence, `s`, `w`, and loopback-only behavior.

## Open Questions

- Which exact theme names should V1 expose?
- What wording should distinguish “compatible dashboard reused” from “port occupied by another process”?
- Should Phase 2 include an open-browser action, or should that remain outside the Terminal Console?

## TechSpec (`_techspec.md`)

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

