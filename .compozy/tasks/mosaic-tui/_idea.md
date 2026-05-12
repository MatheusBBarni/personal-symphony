# Mosaic Terminal Console Command Center

## Overview

Build a Mosaic-powered **Terminal Console** command center for solo developers running Personal Symphony locally in a **Workspace Repository** during active orchestration runs.

V1 should be a hybrid: read-first, powered by existing **Runtime State**, and augmented with a minimal allowlisted control set for common active-run actions. The goal is faster operations: the operator should understand orchestration state quickly and take safe routine actions without opening the **Web Dashboard** or reading raw Runtime Home files/logs.

This is a Strategic Bet, not a cosmetic terminal refresh. The Terminal Console should become a trustworthy local operations surface while preserving existing Runtime Contract semantics, tracker behavior, Task Branch behavior, cleanup defaults, and package behavior.

## Summary / Differentiator

Most terminal UI frameworks prove that developers like rich terminal workflows, and many AI-agent dashboards are emerging. Symphony can differentiate by making the terminal surface deeply native to its orchestration model: **Runtime State**, **Ordered Queue**, **Compozy PRD Runs**, **Agent Worktrees**, **Task Branches**, **Readiness Gaps**, task execution details, and safe local controls in one keyboard-first view.

## Problem

A solo developer running Symphony locally is already operating from the terminal. During active orchestration, the current Terminal Console gives limited static output, while the Web Dashboard provides the richer live picture. That split forces context switching: terminal for commands and logs, browser for live state, and sometimes Runtime Home files for diagnostics.

This slows down the highest-frequency orchestration moment. The user needs to answer basic questions quickly: What is running? What is retrying? Which task needs attention? What did the current Compozy PRD Run finish? Is a Readiness Gap blocking dispatch? Which Agent Worktree or Task Branch matters right now?

A richer Terminal Console can reduce that operational friction, but V1 must avoid becoming a second orchestrator. The Terminal Console should render Runtime State as truth and expose only safe, explicit controls that preserve existing behavior.

### Market Data

- GitHub `topic:tui` search returned roughly 8,684 repositories, showing broad terminal UI demand.
- Mature TUI frameworks have strong traction: Bubble Tea ~42k stars, Ink ~38k, Textual ~35k, Ratatui ~20k.
- AI/coding-agent dashboard activity is growing: GitHub searches found roughly 179 AI-agent orchestration dashboard repositories and 371 coding-agent dashboard repositories.
- Mosaic is the leading OCaml-native option found in research: `invariant-hq/mosaic`, created in 2025, roughly 76 GitHub stars, `opam` package `mosaic.0.1.0`, TEA runtime, widgets, Matrix terminal rendering/input, and Toffee layout.

## Core Features

| # | Feature | Priority | Description |
| --- | --- | --- | --- |
| F1 | Runtime State overview | Critical | Show running, retrying, token totals, last update time, tracker kind, workspace name, and global last error from Runtime State. |
| F2 | Active work detail | Critical | Show running and retrying tasks with issue metadata, stage states, harness identity, Goal Usage when available, context status, and task errors. |
| F3 | Readiness and attention panel | Critical | Surface Readiness Gaps, Task Needs Attention conditions, and remediation text without blocking the Terminal Console from opening. |
| F4 | Ordered Queue and Compozy PRD Run progress | High | Show queue entry states, current step, completed/failed/skipped counts, and next pending work. |
| F5 | Minimal safe control set | Critical | Provide only allowlisted controls that use existing/shared backend command semantics, such as refresh, navigation/filtering, opening relevant paths or dashboard links, and other reversible safe actions. |
| F6 | Keyboard-first navigation and command palette | High | Let users reach the primary panels and V1 controls within five keystrokes, with visible shortcuts and predictable focus behavior. |
| F7 | Safety guardrails | High | Sanitize untrusted terminal output, redact secret values, confirm destructive or branch-affecting actions, and prevent controls from bypassing Runtime Contract semantics. |
| F8 | Web Dashboard fallback path | Medium | Make it easy to open the Web Dashboard for deeper inspection without duplicating every browser feature in V1. |

## Integration with Existing Features

| Integration Point | How |
| --- | --- |
| Runtime State | Use Runtime State snapshots as the single visible state source for the Terminal Console. |
| Current Terminal Console | Replace or augment static output with a Mosaic-rendered active-run surface, without changing product language away from Terminal Console. |
| Web Dashboard | Preserve the Web Dashboard as the richer browser fallback and avoid V1 parity requirements. |
| Live Dashboard Connection | Keep it as a state stream; do not use it as a command channel. |
| Runtime Readiness | Show Readiness Gaps and remediation text while preserving dispatch-blocking behavior. |
| Ordered Queue | Present compact queue progress and skipped/completed states during active runs. |
| Compozy PRD Runs | Show current task step and completed/failed/skipped progress. |
| Agent Worktrees and Task Branches | Show relevant operational status and safe navigation/open actions without changing merge or cleanup semantics. |

## KPIs

| KPI | Target | How to Measure |
| --- | --- | --- |
| Time to understand active orchestration state | < 15 seconds | Usability test: user identifies running, retrying, blocked, and next work from the Terminal Console. |
| Common action completion | <= 5 keystrokes | Count keystrokes for each supported V1 control from the default Terminal Console view. |
| Web Dashboard fallback during active runs | Reduce by >= 60% | Compare active-run sessions where users open the Web Dashboard before and after Terminal Console adoption. |
| Supported control success rate | >= 95% | Track attempted V1 controls and successful completion without invalid state or retryable command failure. |
| Active-run Terminal Console adoption | >= 50% of local active orchestration runs | Measure runs where the Mosaic Terminal Console stays open for active monitoring. |

## Feature Assessment

| Criteria | Question | Score |
| --- | --- | --- |
| **Impact** | How much more valuable does this make the product? | Strong |
| **Reach** | What % of users would this affect? | Strong |
| **Frequency** | How often would users encounter this value? | Strong |
| **Differentiation** | Does this set us apart or just match competitors? | Strong |
| **Defensibility** | Is this easy to copy or does it compound over time? | Maybe |
| **Feasibility** | Can we actually build this? | Maybe |

Leverage type: Strategic Bet

## Council Insights

- **Recommended approach:** Build a read-first Mosaic Terminal Console over shared Runtime State, with a minimal allowlisted control set only where existing/shared backend command semantics preserve current orchestration behavior.
- **Key trade-offs:**
  - Read-only V1 is safer but may not validate faster operations.
  - Broad controls are strategically attractive but risk becoming a second orchestration path.
  - Mosaic is OCaml-native and aligned with the backend, but young enough that the implementation should stay reversible.
- **Risks identified:**
  - Terminal escape injection from issue titles, logs, task names, branch names, or Agent Worktree output.
  - Secret leakage through displayed environment values or logs.
  - Runtime Contract bypass if controls mutate orchestration outside established validation.
  - UI scope creep into Web Dashboard replacement, plugin platform, or command framework.
- **Stretch goal (V2+):** A full local orchestration cockpit with richer task inspection, safe command history, operator preferences, and deeper Web Dashboard/Terminal Console parity after V1 proves active-run speed.

## Out of Scope (V1)

- **Full Web Dashboard replacement** — V1 should optimize active terminal operations, not recreate every browser feature.
- **Broad orchestration command platform** — New runtime semantics, task lifecycle mutations, or command extensibility belong after V1 validation.
- **Runtime Contract default changes** — The feature must not change settings defaults or Bootstrap behavior.
- **Task Branch cleanup or auto-merge default changes** — These are protected product behaviors and not needed for Terminal Console validation.
- **Live Dashboard Connection command channel** — The connection remains a Runtime State stream, not a bidirectional command transport.
- **Tracker model replacement** — GitHub, minibeads, and Compozy Task tracker semantics stay unchanged.
- **Custom layouts, plugins, or themes** — Nice V2+ possibilities, but not required to prove faster active-run operations.
- **npm package or launcher behavior changes** — Packaging and binary behavior stay outside this idea.

## Architecture Decision Records

- [ADR-001: Scope Mosaic Terminal Console as a Runtime State command center](adrs/adr-001.md) — V1 is read-first over Runtime State with only narrow safe controls through explicit command boundaries.

## Open Questions

- Which exact controls qualify as safe and already-supported enough for V1?
- Should the Mosaic Terminal Console initially be opt-in before replacing the existing default Terminal Console rendering?
- What evidence threshold should promote the feature from read-first V1 to broader command-center V2?
- Which terminal environments must be supported for launch?
- What audit/log format should record control attempts and outcomes?
