# Idea: Improve Compozy Task Lifecycle Statuses

## Overview

Compozy-backed Symphony workflows already have run-level lifecycle plumbing, but operators still lack a complete, trustworthy contract for how statuses change across a Compozy PRD Run. The real problem is not missing labels alone. It is ambiguity between Compozy Task Step status, Compozy PRD Run lifecycle state, dispatch state, and Pull Request readiness.

This idea updates the scope so Symphony reliably changes and explains those states for the workflow operator watching an active Compozy PRD Run. V1 should be a complete end-to-end feature across Runtime State, Terminal Console, and Web Dashboard, while preserving the current run-level lifecycle architecture and aggregate Batch Pull Request behavior.

## Problem

Operators need to answer one question quickly: what state is this run in right now, and why? Today the implementation already contains richer lifecycle states than the original idea described, but the product contract is still underspecified. One surface may imply active execution, another may reflect dispatch state, and another may expose PR readiness or attention outcomes. That makes status interpretation feel fragile even when the runtime has partial lifecycle data.

This ambiguity is most visible around transitions rather than steady states. Planner work, reviewer work, retries, non-retryable completion failures, merge attention, skipped steps, and Batch Pull Request handoff all need clear meanings. Without that, operators fall back to task files, logs, and branch inspection to understand what Symphony should already report.

The risk is larger in AI-assisted workflows because operator trust depends on stable, inspectable state. If Symphony shows the wrong status, or a status with unclear meaning, the user cannot tell whether work is progressing, waiting on review, blocked by integration, or finished but not PR-ready.

### Market Data

Workflow automation remains a large and growing market. Mordor Intelligence estimates the market at USD 23.77B in 2025 and USD 40.77B by 2031. Competing workflow tools normalize explicit status models and status automation rather than relying on implied progress.

Developer adoption of AI tools is high, but trust remains weak. Stack Overflow's 2025 survey reports that 84% of respondents use or plan to use AI tools in development, while DORA 2024 reports productivity gains from AI alongside stability and throughput trade-offs. Symphony can differentiate by making agentic workflow state trustworthy, local, and operationally clear.

### Summary / Differentiator

The differentiator is a trustworthy local transition contract for agentic work: clear execution progress, clear lifecycle phase, clear dispatch meaning, and clear PR readiness, all without per-step issue noise or per-step pull requests.

## Core Features

| # | Feature | Priority | Description |
| --- | --- | --- | --- |
| F1 | Status-layer transition contract | Critical | Define and validate the relationship between Compozy Task Step status, Compozy PRD Run lifecycle state, dispatch state, and PR readiness. |
| F2 | Complete lifecycle transition coverage | Critical | Ensure planner, execution, review, retry, failed, skipped, blocked, completed, not-PR-ready, and PR handoff transitions are reliable and visible. |
| F3 | Attention-state clarity | Critical | Make merge attention, protected-path attention, and non-retryable completion failures clearly visible without implying successful completion. |
| F4 | All-surface consistency | High | Keep Runtime State, Terminal Console, and Web Dashboard aligned within one poll cycle for lifecycle and PR-readiness changes. |
| F5 | Backward-compatible task-step progress | High | Preserve current-step selection, step counts, and execution-focused step statuses. |
| F6 | Aggregate Batch Pull Request readiness | High | Preserve one aggregate Batch Pull Request per successful Compozy PRD Run in batch mode, with explicit handoff states and failure semantics. |
| F7 | Operator-facing documentation | Medium | Document status meanings, layer boundaries, and representative examples using existing product terminology. |

## Integration with Existing Features

| Integration Point | How |
| --- | --- |
| Compozy Task Step frontmatter | Remains the source of execution progress only. |
| Compozy lifecycle metadata | Remains the run-level source of lifecycle phase and PR readiness. |
| Compozy-backed Local Issue Tracker | Continues to persist dispatch-facing state while respecting lifecycle ownership. |
| Runtime State / Terminal Console / Web Dashboard | Must present a consistent operator-facing story for the same run. |
| Batch Pull Request flow | Remains aggregate-only and explicitly tied to readiness and handoff outcomes. |

## KPIs

| KPI | Target | How to Measure |
| --- | --- | --- |
| Transition coverage | 100% of defined lifecycle transitions covered by acceptance tests | Backend acceptance tests for dispatch, retry, failure, blocked, completion, and handoff paths |
| Surface consistency | 100% agreement across Runtime State, Terminal Console, and Web Dashboard within 1 poll cycle | QA scenarios comparing all three operator surfaces |
| Non-ready correctness | 0 runs in failed, skipped, blocked, or handoff-failed states appear PR-ready | Acceptance tests and dogfood checks |
| Operator comprehension | < 2 minutes to answer "what state is this run in and why?" | Timed dogfood walkthroughs |
| Task-step compatibility | 0 regressions in current-step behavior and step counts | Existing Compozy progress tests plus new transition regressions |

## Feature Assessment

| Criteria | Question | Score |
| --- | --- | --- |
| **Impact** | How much more valuable does this make the product? | Must do |
| **Reach** | What % of users would this affect? | Strong |
| **Frequency** | How often would users encounter this value? | Must do |
| **Differentiation** | Does this set us apart or just match competitors? | Maybe |
| **Defensibility** | Is this easy to copy or does it compound over time? | Maybe |
| **Feasibility** | Can we actually build this? | Strong |

Leverage type: Quick Win

## Council Insights

- **Recommended approach:** Keep the existing run-level lifecycle architecture, but redefine V1 around a complete transition contract instead of adding more ad hoc statuses.
- **Key trade-offs:** More explicit semantics improve trust, but they require careful distinction between execution progress, lifecycle phase, dispatch state, and PR readiness.
- **Risks identified:** semantic drift across surfaces, status conflation between lifecycle and dispatch, and scope creep into a configurable workflow platform.
- **Stretch goal (V2+):** lifecycle history, transition timeline, and guided operator repair suggestions.

## Out of Scope (V1)

- **Configurable lifecycle schemas** — V1 should prove one built-in contract before allowing user-defined workflows.
- **Per-step Symphony issues** — Compozy Task Steps remain internal to one Compozy PRD Run.
- **Per-step pull requests** — Batch mode remains aggregate-only.
- **Lifecycle analytics dashboards** — correctness and operator trust come before trend reporting.
- **Guided repair controls** — V1 explains blocked or non-ready states but does not add repair actions.

## Architecture Decision Records

- [ADR-001: Represent Compozy lifecycle at PRD Run level](adrs/adr-001.md) — Lifecycle status belongs to the Compozy PRD Run, while Compozy Task Step statuses remain execution progress; aggregate Batch Pull Requests require successful run completion plus safe final integration.
- [ADR-002: Use full V1 operator trust as the PRD product approach](adrs/adr-002.md) — V1 must expose lifecycle and PR readiness across Runtime State, Terminal Console, and Web Dashboard while deferring analytics and repair automation.
- [ADR-003: Persist dispatch-aware Compozy lifecycle in Runtime Home](adrs/adr-003.md) — Runtime Home lifecycle metadata survives restarts while preserving Compozy Task Step frontmatter as the source of step execution progress.
- [ADR-004: Treat Compozy statuses as an explicit transition contract](adrs/adr-004.md) — V1 must define and validate the mapping between task-step status, run lifecycle state, dispatch state, and PR readiness.

## Open Questions

- Should operator-facing copy keep `in_execution`, or translate it to existing product phrasing such as `running` or `in progress` on some surfaces?
- Should `Human attention` remain purely a dispatch-facing label while lifecycle continues to show `blocked`?
- Should `not_pr_ready` remain a distinct lifecycle state, or be presented mainly as readiness plus reason on some surfaces?
- What is the minimum example set that documentation should show for retry, blocked, review, and handoff-failure transitions?
