# Backend TUI JSX Rewrite Idea

## Overview

Rewrite all existing backend Terminal Console UI surfaces to use the `Tui.Jsx` syntax from the reusable TUI Toolkit Package. This is for Symphony maintainers who change Terminal Console views, layout, modal flows, and visual states.

V1 is a complete behavior-preserving rewrite, not a pilot. The operator experience must remain unchanged: same shortcuts, states, visual hierarchy, settings behavior, Runtime State semantics, and safe-aid boundaries.

## Problem

The Terminal Console is now a primary Runtime State surface, but its backend view layer is assembled through direct `Tui.Components` calls. That style is explicit and type-safe, but larger screens become visually dense. Maintainers reviewing Terminal Console changes must reconstruct the UI tree from nested function calls instead of reading a component-shaped view.

The repo already has `Tui.Jsx` in the reusable TUI package. Leaving the backend Terminal Console on direct component calls weakens the package story and keeps the most important internal consumer from proving the recommended authoring model.

### Market Data

Reason JSX is library-agnostic and compiles to function calls, so Symphony can use JSX without adopting React runtime semantics: [Reason JSX](https://reasonml.github.io/docs/en/jsx). Ink and OpenTUI show that JSX/component authoring is a common terminal UI expectation: [Ink](https://github.com/vadimdemedes/ink), [OpenTUI](https://opentui.com/docs/getting-started/). GitHub Octoverse 2025 reports TypeScript as GitHub's top language by monthly contributors, reinforcing typed component authoring as a familiar modern default: [GitHub Octoverse](https://github.blog/news-insights/octoverse/octoverse-a-new-developer-joins-github-every-second-as-ai-leads-typescript-to-1/).

## Core Features

| # | Feature | Priority | Description |
| --- | --- | --- | --- |
| F1 | Complete JSX View Rewrite | Critical | Convert all backend Terminal Console UI construction to `Tui.Jsx` while preserving rendered behavior. |
| F2 | Behavior Preservation Contract | Critical | Keep shortcuts, tabs, modals, settings, safe aids, resize handling, logs, and Runtime State display unchanged. |
| F3 | Package Dogfooding | High | Use the existing public TUI JSX API from backend without adding backend-specific semantics to `apps/tui`. |
| F4 | Parity Verification | High | Preserve existing backend Terminal Console tests and add focused parity checks where needed. |
| F5 | Docs And Examples Alignment | High | Update docs/examples to show that the real backend Terminal Console consumes the package JSX API. |

## KPIs

| KPI | Target | How to Measure |
| --- | --- | --- |
| JSX coverage | 100% of existing backend Terminal Console UI surfaces | Review `terminal_console_tui` view construction after migration. |
| Behavioral parity | 100% existing Terminal Console tests pass | Run backend test suite and focused Terminal Console cases. |
| Render parity | 0 intentional visual hierarchy changes | Compare representative preview output before and after. |
| Runtime safety | 0 new Runtime State fields/settings/safe aids | Review diff for runtime contract changes. |
| Maintainability | >= 20% reduction in view-layer nesting or LOC | Compare pre/post view-layer structure. |

## Feature Assessment

| Criteria | Question | Score |
| --- | --- | --- |
| **Impact** | How much more valuable does this make the product? | Strong |
| **Reach** | What % of users would this affect? | Maybe |
| **Frequency** | How often would users encounter this value? | Strong |
| **Differentiation** | Does this set us apart or just match competitors? | Strong |
| **Defensibility** | Is this easy to copy or does it compound over time? | Maybe |
| **Feasibility** | Can we actually build this? | Strong |

Leverage type: Quick Win.

## Council Insights

- **Recommended approach:** Council preferred a parity-gated staged migration, but user direction selects complete V1 rewrite.
- **Key trade-offs:** Full convergence avoids long-lived dual idioms but increases parity and review burden.
- **Risks identified:** behavior drift, visual drift, modal/focus regressions, package boundary leakage.
- **Stretch goal (V2+):** Make JSX the default authoring model for future Terminal Console and TUI package surfaces.

## Out of Scope (V1)

- **Operator UX redesign** - V1 changes authoring syntax, not behavior or layout intent.
- **New Runtime State semantics** - the rewrite must not alter backend runtime contracts.
- **New Terminal Console settings** - settings behavior stays scoped to current theme and Web Dashboard port behavior.
- **New safe-aid actions** - local aids remain read-only and non-mutating.
- **React runtime compatibility** - this uses Reason/TUI JSX semantics over `Tui.Node.t`.

## Architecture Decision Records

- [ADR-001: Adopt Parity-Gated Backend Terminal Console JSX Migration](adrs/adr-001.md) - Superseded council recommendation.
- [ADR-002: Select Complete Backend Terminal Console JSX Rewrite](adrs/adr-002.md) - Accepted complete V1 scope.

## Open Questions

- Which preview states should be captured as the before/after parity baseline?
- Should docs frame backend Terminal Console JSX usage as the recommended internal pattern immediately?
- What exact metric should count as "view-layer nesting" for the maintainability KPI?
