# TUI JSX API Idea

## Overview

Build a public Reason-native JSX authoring kit for `symphony-orchestrator-tui`. The kit should make terminal UI code easier to read, review, copy, and extend by letting users express TUI trees with JSX-style component composition while preserving the existing `Tui.Node.t` renderer and component model.

V1 should serve external Reason/OCaml developers evaluating the standalone TUI package and internal Symphony contributors building Terminal Console surfaces. Internal Symphony examples are the proving ground, but the output should be public-package quality.

## Problem

Current TUI code composes nested lists of `Tui.Components`, `Tui.Patterns`, and node helpers. This is explicit and type-safe, but large screens become visually dense. Contributors reviewing layout changes must mentally reconstruct the tree from nested function calls.

External adoption has a similar problem. Developers familiar with ReasonReact, Ink, or OpenTUI expect component-shaped UI examples. If the first package experience looks unlike familiar component composition, the package has to overcome avoidable friction before users even evaluate rendering, layout, or widgets.

### Market Data

Reason JSX is library-agnostic and compiles to normal function calls, so Symphony can use JSX without adopting React runtime semantics: [Reason JSX](https://reasonml.github.io/docs/en/jsx). ReasonReact demonstrates the typed component/children model users will expect: [ReasonReact JSX](https://reasonml.github.io/reason-react/docs/en/jsx). Ink and OpenTUI validate JSX/component models for terminal apps: [Ink](https://github.com/vadimdemedes/ink), [OpenTUI React bindings](https://opentui.com/docs/bindings/react/). Stack Overflow's 2025 survey reports broad JavaScript/TypeScript/React usage, supporting JSX familiarity as an adoption lever: [survey](https://survey.stackoverflow.co/2025/technology).

## Core Features

| # | Feature | Priority | Description |
| --- | --- | --- | --- |
| F1 | JSX Authoring Surface | Critical | Provide typed JSX-compatible components that render to existing `Tui.Node.t` values. |
| F2 | Public Component Subset | Critical | Cover the first useful subset: text, box/layout, panel, row/column, input/select, badge, table/status data, and app shell primitives. |
| F3 | Internal Proving Screen | High | Recreate one representative existing TUI screen or example using JSX and compare readability against the current call style. |
| F4 | External Examples | High | Add public examples showing basic, dashboard, and agent/workflow UI composition. |
| F5 | Documentation Path | High | Explain when to use JSX vs direct components, with Reason JSX caveats and no React-runtime assumptions. |
| F6 | Equivalence Tests | High | Prove JSX-authored trees preserve rendering behavior for supported primitives. |

## KPIs

| KPI | Target | How to Measure |
| --- | --- | --- |
| Layout readability | Reduce representative screen layout LOC by >= 20% | Compare existing example/screen against JSX version. |
| Rendering parity | 100% snapshot parity for equivalent supported examples | Add focused TUI tests comparing rendered output. |
| First-run adoption | New JSX example runnable in < 5 minutes | Follow README from clean package setup. |
| API containment | 0 JSX-only renderer semantics | Review supported JSX components against existing `Tui.Node.t`/Components behavior. |
| Documentation coverage | >= 3 public examples documented | README and examples index include JSX usage path. |

## Feature Assessment

| Criteria | Question | Score |
| --- | --- | --- |
| **Impact** | How much more valuable does this make the product? | Strong |
| **Reach** | What % of users would this affect? | Strong |
| **Frequency** | How often would users encounter this value? | Strong |
| **Differentiation** | Does this set us apart or just match competitors? | Strong |
| **Defensibility** | Is this easy to copy or does it compound over time? | Maybe |
| **Feasibility** | Can we actually build this? | Strong |

Leverage type: Strategic Bet.

## Council Insights

- **Recommended approach:** Use JSX as an authoring layer over the existing TUI model; do not create a second renderer or runtime.
- **Key trade-offs:** Bigger public scope improves adoption but raises API drift and documentation risks.
- **Risks identified:** Dual idioms, JSX-only semantics, curated-demo bias, and overbuilding V1.
- **Stretch goal (V2+):** Make JSX the recommended authoring path for new Reason TUI screens once V1 proves parity and readability.

## Out of Scope (V1)

- **React runtime compatibility** - V1 uses Reason JSX semantics, not React rendering.
- **Full Terminal Console migration** - one internal proving screen is enough for V1.
- **Every existing component/pattern** - V1 should support a small public subset first.
- **State management framework** - input/focus behavior should reuse existing renderer semantics.
- **Breaking direct component calls** - existing `Tui.Components` and `Tui.Patterns` remain supported.

## Architecture Decision Records

- [ADR-001: Constrain JSX TUI V1 To An Existing Node Authoring Layer](adrs/adr-001.md) - Superseded conservative council recommendation.
- [ADR-002: Adopt Public JSX Kit Scope](adrs/adr-002.md) - Accepted public JSX kit direction.

## Open Questions

- Which exact internal screen should be the proving screen: `demo`, `agent_workspace`, or Terminal Console view?
- Should JSX become the recommended path immediately, or remain experimental until parity/readability gates pass?
- What is the minimum public component subset needed for a credible first release?
