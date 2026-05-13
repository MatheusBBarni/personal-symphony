# Terminal Console Elegance Redesign

## Overview

Redesign the default **Terminal Console** so it feels materially more elegant, easier to scan, and better separated by operator moment. The current experience is functionally rich but visually crowded: readiness-blocked startup and active orchestration monitoring compete inside one dense surface, and `Tab` changes focus instead of meaning.

This feature is for solo developers operating Personal Symphony from a **Workspace Repository**, especially heavy daily users who keep the **Terminal Console** open during orchestration runs. The value is faster confidence: users should immediately understand whether Personal Symphony is blocked by **Readiness Gaps** or actively working, and what deserves attention next.

V1 should be a moderate redesign, not a blank-sheet rewrite. It should preserve existing orchestration behavior, keep **Runtime State** as the visible source of truth, and concentrate most changes in the Mosaic presentation layer with only narrow projection support where hierarchy needs clearer structure.

### Summary / Differentiator

Many terminal dashboards optimize for density, but fewer optimize for distinct operator moments. Personal Symphony can differentiate by making the **Terminal Console** feel native to orchestration work: one view optimized for startup and **Readiness Gaps**, one optimized for active monitoring, both grounded in existing **Runtime State** instead of generic terminal chrome.

## Problem

The current **Terminal Console** makes two different jobs compete for space. When Personal Symphony is blocked at startup, the operator wants a crisp answer to a small set of questions: why dispatch is blocked, which **Readiness Gaps** matter, and what remediation to perform next. During an active run, the operator instead wants a scanning surface: what is running, what is retrying, what needs attention, what comes next in the **Ordered Queue**, and whether a **Compozy PRD Run** is progressing cleanly. Today those moments share a single dense layout, which makes the console feel busy rather than intentional.

The UI problem is not only visual styling. The current Mosaic implementation always renders the same six panels and treats `Tab` as focus navigation rather than view switching. That means the user sees everything at once even when only one operational question matters. The result is weak hierarchy, noisy startup states, and detail competing with summary information.

This is especially costly because the **Terminal Console** is the operator’s default surface inside a **Workspace Repository**. When the terminal experience is hard to parse, the user falls back to the **Web Dashboard**, raw runtime files in the **Runtime Home**, or repeated navigation across panels just to understand the current state. That adds friction precisely in the highest-frequency workflow.

A redesign can improve perceived product quality and operator speed without changing runtime semantics. The opportunity is to make the default terminal experience feel legible, calm, and mode-aware while preserving the read-first boundary and existing orchestration behavior.

### Market Data

- GitHub’s `tui` topic page showed 4,496 public repositories in the crawl snapshot, indicating broad sustained interest in terminal-first interfaces. Source: [GitHub topic:tui](https://github.com/topics/tui)
- The Bubble Tea repository page said the framework is used in over 18,000 applications and showed 42.2k stars in the current snapshot. Source: [Bubble Tea](https://github.com/charmbracelet/bubbletea)
- The `k9s` repository page showed 33.6k stars in the current snapshot, and its docs emphasize dense but customizable operational views. Sources: [k9s](https://github.com/derailed/k9s), [Custom Views](https://k9scli.io/topics/columns/)
- `gh-dash` and Textual documentation both reinforce the same pattern set relevant here: explicit view switching, contextual help, and mutually exclusive content panes rather than one overloaded canvas. Sources: [gh-dash global keybindings](https://www.gh-dash.dev/getting-started/keybindings/global/), [gh-dash preview pane](https://www.gh-dash.dev/getting-started/keybindings/preview/), [Textual Footer](https://textual.textualize.io/widgets/footer/), [Textual TabbedContent](https://textual.textualize.io/widgets/tabbed_content/)

### Integration with Existing Features

| Integration Point | How |
| --- | --- |
| **Runtime State** | Remains the single visible source of truth for both top-level Terminal Console modes. |
| Current Mosaic Terminal Console | Rework the presentation and navigation model rather than replacing the runtime path or orchestration handoff. |
| Readiness-blocked startup path | Elevate startup and **Readiness Gaps** into a dedicated top-level mode. |
| Active orchestration path | Preserve active work, retrying work, attention state, **Ordered Queue**, and **Compozy PRD Run** monitoring as the active-run mode. |
| Safe Aids | Keep the existing read-only aid boundary and avoid adding mutating controls. |
| **Web Dashboard** | Preserve it as the deeper inspection fallback rather than chasing parity in V1. |
| **Agent Worktree** and **Task Branch** context | Surface only bounded, sanitized summary detail needed for operator understanding. |

## Core Features

| # | Feature | Priority | Description |
| --- | --- | --- | --- |
| F1 | Two real top-level Terminal Console modes | Critical | Replace focus-only panel cycling with two distinct operator modes: one for startup and **Readiness Gaps**, one for active orchestration monitoring. |
| F2 | Readiness-first startup hierarchy | Critical | Make blocked startup states immediately legible with prominent requirement/remediation structure, calmer spacing, and a clearer next-step emphasis. |
| F3 | Active-run monitoring hierarchy | Critical | Rebuild the active-run view around a strong primary/secondary relationship: active work first, selected detail second, supporting queue and **Compozy PRD Run** context after that. |
| F4 | Curated secondary detail pane | High | Show read-only, sanitized detail for the selected readiness item or active task without forcing the operator into the **Web Dashboard** for routine understanding. |
| F5 | Contextual footer help | High | Replace generic command noise with mode-aware shortcuts that advertise the most relevant keys for the current Terminal Console mode and selection context. |
| F6 | Progressive density and stable summaries | High | Default to compact, high-signal summaries and reveal richer context only when selected or when the terminal is wide enough, instead of rendering every panel with equal visual weight. |
| F7 | Cross-mode status carryover | Medium | Keep urgent summary signals visible even when the user is on the other top-level mode so tabs do not create blind spots. |
| F8 | Trust-preserving detail boundaries | High | Keep all new detail surfaces explicitly read-only, sanitized, ASCII-safe, and bounded to existing **Runtime State** or existing safe inspection flows. |

## KPIs

| KPI | Target | How to Measure |
| --- | --- | --- |
| Time to identify current state | < 10 seconds | In a usability check, ask the operator whether Personal Symphony is blocked, idle, or actively running after opening the Terminal Console. |
| Time to locate the next high-priority item | < 15 seconds | In blocked or active-run scenarios, measure how long it takes to identify the most important **Readiness Gap** or task needing attention. |
| **Web Dashboard** fallback for routine monitoring | Reduce by >= 40% | Compare orchestration sessions that open the **Web Dashboard** for routine understanding before and after the redesign. |
| First-session navigation success | >= 90% | Measure whether users can switch modes, inspect selected detail, and return without outside guidance. |
| Default-console retention during long runs | >= 70% of runs longer than 5 minutes | Track whether the **Terminal Console** remains the primary live monitoring surface during extended orchestration sessions. |

## Feature Assessment

| Criteria | Question | Score |
| --- | --- | --- |
| **Impact** | How much more valuable does this make the product? | Strong |
| **Reach** | What % of users would this affect? | Strong |
| **Frequency** | How often would users encounter this value? | Must do |
| **Differentiation** | Does this set us apart or just match competitors? | Strong |
| **Defensibility** | Is this easy to copy or does it compound over time? | Maybe |
| **Feasibility** | Can we actually build this? | Must do |

Leverage type: Compounding Feature

## Council Insights

- **Recommended approach:** Keep the redesign as a two-mode, read-first **Terminal Console** presentation refactor over existing **Runtime State**, with most changes inside Mosaic and only narrow projection support where the current shape blocks good hierarchy.
- **Key trade-offs:**
  - Two modes improve clarity only if they do not hide urgent cross-cutting state.
  - A richer detail pane improves routine understanding only if it remains curated and explicitly read-only.
  - Keeping the work mostly inside Mosaic reduces risk, but some thin presentation structure is still needed to avoid renderer-only special cases.
- **Risks identified:**
  - The redesign could become prettier fragmentation if the inactive mode becomes a blind spot.
  - A secondary pane could drift into disclosure of secrets, prompt content, or misleading pseudo-controls.
  - Styling-only changes could fail to fix the underlying hierarchy problem and leave the current clutter intact.
- **Stretch goal (V2+):** Expand from elegance and hierarchy into a broader operator cockpit only after V1 proves that tab-separated moments materially improve scanability and reduce routine browser fallback.

## Out of Scope (V1)

- **New mutating controls** — Retry, pause, merge, push, pull request, or any other lifecycle-changing command remains outside the read-first MVP boundary.
- **Runtime semantics changes** — The redesign must not change orchestration behavior, **Runtime Contract** defaults, readiness logic, or dispatch behavior.
- **`--web`, `--once`, and manual-merge behavior changes** — Stable command-mode boundaries remain untouched.
- **Web Dashboard parity** — V1 should reduce routine fallback, not replicate the entire browser surface.
- **Broad runtime data expansion** — The idea should not introduce large new **Runtime State** schema changes just to support presentation.
- **Unbounded diagnostics or secret-rich surfaces** — Full prompts, environment-derived values, `.env` contents, raw logs, and arbitrary file previews are excluded from default detail panes.
- **Packaging or launcher changes** — npm package behavior, binary packaging, and Product Repository release behavior remain outside scope.

## Architecture Decision Records

- [ADR-001: Scope the Terminal Console elegance redesign as a two-mode presentation refactor](./adrs/adr-001.md) — Keep the redesign read-first, mode-aware, and primarily inside Mosaic while preserving global attention visibility.

## Open Questions

- What are the best final user-facing labels for the two top-level Terminal Console modes?
- Which summary signals must remain visible globally when the operator is looking at the other mode?
- Should the redesigned Terminal Console become the default immediately, or launch behind a temporary opt-in gate?
- What is the minimum 80x24 fallback layout for the two-mode design when a full secondary detail pane cannot fit cleanly?
- Which existing detail fields are safe and stable enough to elevate from freeform strings into narrower presentation structures?
