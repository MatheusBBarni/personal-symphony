# Terminal Console Settings and Web Dashboard Start

## Overview

Add a minimal **Terminal Console Settings** menu for solo local developers working from a **Workspace Repository**. V1 lets the user select the Terminal Console theme, edit the **Web Dashboard** port as a numeric value, and press `w` to start the Web Dashboard local server if it is not already running. The feature makes the Terminal Console a more complete local setup surface without turning it into a general Runtime Settings platform.

## Problem

Today, the Terminal Console helps users inspect runtime state and shows Web Dashboard handoff guidance, but setup still leaks back into config files and separate CLI invocations. A solo developer who wants to adjust appearance or use a different dashboard port must leave the Terminal Console, edit `.symphony/settings.json` or pass `--port`, and then start the Web Dashboard separately.

That breaks the intended local cockpit workflow. The user is already in the Terminal Console, looking at Symphony's runtime state, but must switch contexts for two common local setup tasks: theme comfort and dashboard launch.

### Market Data

The 2025 Stack Overflow Developer Survey reports Bash/Shell usage by 48.7% of respondents and 84% using or planning to use AI tools, which keeps terminal-native developer workflows relevant. Modern terminal tools also normalize interactive settings: OpenClaw documents TUI settings and shortcuts, Kiro positions its TUI as the default interactive interface, Consoul documents a settings modal, Purplemux exposes terminal theme picking, and RunHQ treats local service/port controls as first-class developer cockpit behavior.

## Summary / Differentiator

Symphony can differentiate by making the Terminal Console the place where a solo developer can configure the immediate local operating experience and bring up the Web Dashboard, while still preserving the boundary that orchestration state is not mutated by UI convenience commands.

## Core Features

| # | Feature | Priority | Description |
| --- | --- | --- | --- |
| F1 | Settings Menu | Critical | Add a focused Terminal Console settings surface for V1 setup controls only. |
| F2 | Theme Selection | Critical | Let the user choose a Terminal Console theme from a small supported set. |
| F3 | Numeric Dashboard Port | Critical | Let the user edit `server.port` with numeric validation before save. |
| F4 | `w` Starts Web Dashboard | Critical | Pressing `w` starts the Web Dashboard local server if not already running, then shows the URL. |
| F5 | Idempotent Server Status | High | If the compatible dashboard server is already running for the current Workspace Repository and Runtime Home, report it instead of starting another. |
| F6 | Explicit Failure Feedback | High | Show clear Terminal Console feedback for invalid ports, port conflicts, and failed starts. |

## Integration with Existing Features

| Integration Point | How |
| --- | --- |
| Terminal Console | Adds settings and local service control to the existing product console surface. |
| Runtime Settings | Reuses existing `server.port`; avoids a second settings store. |
| Web Dashboard | Starts or reuses the local dashboard server and reports its URL. |
| TUI Toolkit Package | Reuses existing theme primitives where practical; does not move product-specific behavior into `apps/tui`. |

## KPIs

| KPI | Target | How to Measure |
| --- | --- | --- |
| Setup friction reduction | Reduce manual config edits for theme/port by 80% | Count setup paths requiring direct file edits before vs after V1. |
| Dashboard start success | 95% of local `w` attempts resolve within 3 seconds | Instrument or test start/reuse outcomes in local runs. |
| Port validation coverage | 100% invalid port inputs rejected before side effects | Unit tests for nonnumeric, empty, out-of-range, and conflicting values. |
| Discoverability | Settings and `w` visible in help/footer in 100% relevant states | Snapshot/render tests for footer and help modal. |
| Regression coverage | 5+ focused backend tests | Tests for settings state, theme selection, port input, `w` behavior, and task-state non-mutation. |

## Feature Assessment

| Criteria | Question | Score |
| --- | --- | --- |
| **Impact** | How much more valuable does this make the product? | Strong |
| **Reach** | What % of users would this affect? | Strong |
| **Frequency** | How often would users encounter this value? | Maybe |
| **Differentiation** | Does this set us apart or just match competitors? | Maybe |
| **Defensibility** | Is this easy to copy or does it compound over time? | Maybe |
| **Feasibility** | Can we actually build this? | Strong |

Leverage type: Quick Win

## Council Insights

- **Recommended approach:** Proceed with the original MVP, but classify `w` as a documented local service control, not an orchestration command.
- **Key trade-offs:** The feature reduces local setup friction, but changes `w` from handoff guidance to a side-effecting local server action.
- **Risks identified:** unsafe server attachment, network exposure, port conflicts, and future settings scope creep. Mitigate with loopback defaults, existing dashboard auth behavior, strict port validation, compatible-server detection, and explicit docs.
- **Stretch goal (V2+):** A broader Terminal Console control center with dashboard status, open-browser action, diagnostics, and additional Runtime Settings.

## Out of Scope (V1)

- **General Runtime Settings editor** - too broad; V1 only covers theme and `server.port`.
- **Remote/non-loopback server configuration** - increases security scope and should remain governed by existing Runtime Settings rules.
- **Task lifecycle actions from settings** - Terminal Console settings must not mutate issue state, queues, stages, or orchestration results.
- **Reusable settings framework in `apps/tui`** - premature until multiple product settings surfaces prove the abstraction.
- **Automatic browser opening** - optional later; V1 starts/reuses the server and reports the URL.

## Architecture Decision Records

- [ADR-001: Scope the Terminal Console Settings MVP](adrs/adr-001.md) - Defines V1 as a narrow Terminal Console settings menu plus idempotent Web Dashboard local service control.

## Open Questions

- Which exact theme names should V1 expose?
- Should the settings menu have a dedicated shortcut, or only be reachable from help/menu navigation?
- Should `w` only show the URL after starting the server, or also offer a later open-browser action?

## Sources

- [Stack Overflow 2025 Developer Survey](https://survey.stackoverflow.co/2025/)
- [OpenClaw TUI docs](https://openclawlab.com/en/docs/web/tui/)
- [Kiro Terminal UI docs](https://kiro.dev/docs/cli/terminal-ui/)
- [Consoul keyboard shortcuts](https://consoul.goatbytes.io/user-guide/tui/keyboard-shortcuts/)
- [Purplemux terminal themes](https://subicura.com/purplemux/docs/terminal-themes/)
- [RunHQ local dev cockpit](https://runhq.dev/)
