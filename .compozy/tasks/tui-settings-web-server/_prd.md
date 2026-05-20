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
