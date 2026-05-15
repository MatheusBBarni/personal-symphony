## Overview

Symphony should continuously admit newly ready work from the selected **Issue Tracker** in a **Workspace Repository** without requiring the operator to stop and restart the process. The operator marks work as ready in the tracker they already use, and Symphony notices that change on a later poll and starts work under the existing orchestration model.

This feature is for self-hosting engineers and small teams who leave Symphony running on a VPS or long-lived machine. It is valuable because it removes restart friction, makes readiness explicit, and preserves the existing **Task Branch**, **Agent Worktree**, stage, and retry semantics. V1 should make background intake real without redesigning the **Ordered Queue**.

### Summary / Differentiator

Most agent tools are either tracker-native SaaS workflows or local-first file watchers. Symphony can differentiate by making GitHub and Compozy feel like the same product capability at the **Runtime Contract** level: one selected tracker, one explicit readiness concept, one persistent orchestrator.

## Problem

Symphony already has a continuous polling loop, but admission into work is still awkward for operators who keep the process running for long periods. In a GitHub-backed **Workspace Repository**, new work becomes visible only through the current GitHub Project status rules, and there is no explicit “this is ready for Symphony now” control. In a Compozy-backed **Local Issue Tracker**, work becomes runnable from task-step state, but there is no dedicated run-level readiness signal for automatic intake. In practice, that means operators either shape tracker state indirectly, rebuild an **Ordered Queue**, or restart and re-run commands more often than they should.

This hurts the exact workflow Symphony is supposed to make reliable: leave the orchestrator running, add or refine work in the selected tracker, and let Symphony continue when something is truly ready. The friction is especially visible for self-hosted usage on a VPS, where “restart the process so it notices the new item” feels like a product failure rather than a normal operator action.

The broader market is moving toward continuous issue-to-agent workflows. GitHub’s current Copilot agent flow treats asynchronous issue work as a first-class pattern, and local-first orchestration tools increasingly market persistent intake, pause/resume, and long-running background operation as standard expectations. GitHub’s Octoverse 2025 also reported large-scale issue and pull-request activity, while DORA’s March 10, 2026 analysis reported broad workplace AI usage and highlighted workflow fragmentation as a practical risk. The opportunity is not to invent background automation from scratch. The opportunity is to make Symphony’s existing persistent runtime behave like a trustworthy intake system.

### Market Data

- GitHub’s Octoverse 2025 reported 5.5 million issues closed in July 2025 and 43.2 million pull requests merged per month in 2025. Source: [GitHub Octoverse 2025](https://github.blog/news-insights/octoverse/octoverse-a-new-developer-joins-github-every-second-as-ai-leads-typescript-to-1/)
- DORA’s March 10, 2026 writeup reported that 90% of technology professionals use AI at work and more than 80% believe it increased productivity, while warning about workflow fragmentation. Source: [DORA](https://dora.dev/insights/balancing-ai-tensions/)
- GitHub documents first-class asynchronous issue-to-agent workflows for Copilot and third-party agents. Sources: [Copilot cloud agent](https://docs.github.com/en/copilot/how-tos/use-copilot-agents/cloud-agent/start-copilot-sessions), [third-party agents](https://docs.github.com/en/copilot/concepts/agents/about-third-party-agents)

## Integration with Existing Features

| Integration Point | How |
| --- | --- |
| Selected **Issue Tracker** | Add `ready-for-symphony` as a candidate-admission gate inside tracker-specific discovery. |
| Continuous polling | Reuse the existing poll loop so newly ready work is admitted on a later poll without restart. |
| Startup / idle behavior | Starting with no ready work is a valid healthy idle state and must not be treated as a readiness gap by itself. |
| **Ordered Queue** | Keep it separate; when present, it still filters dispatch and is not auto-built from readiness markers. |
| **Task Branch** / **Agent Worktree** | Preserve current branch, workspace, retry, and completion behavior after first admission. |
| Compozy tracker | Use the first line of `.compozy/tasks/<slug>/_tasks.md` as run-level admission intent only, not as execution truth. |

## Core Features

| # | Feature | Priority | Description |
| --- | --- | --- | --- |
| F1 | Configurable GitHub readiness label | Critical | A GitHub issue becomes newly admissible only when it is otherwise dispatchable under existing GitHub Project status rules and carries the configured readiness label, which defaults to `ready-for-symphony` in `settings.json`. |
| F2 | Explicit Compozy readiness marker | Critical | A **Compozy PRD Run** becomes newly admissible only when it is otherwise runnable under existing task-step and lifecycle rules and the first line of `.compozy/tasks/<slug>/_tasks.md` is `ready-for-symphony`. |
| F3 | Restartless automatic intake | Critical | Symphony notices newly ready work on a later polling cycle and starts it without requiring the operator to restart the running process. |
| F4 | Healthy idle startup | High | When no work is currently marked ready, Symphony remains in valid **Orchestration Idle** state instead of failing readiness. |
| F5 | First-admission-only semantics | High | The readiness marker governs entry into orchestration, but once work is admitted, existing lifecycle, retry, and stage semantics continue to govern the work item. |
| F6 | Queue precedence protection | High | `--queue` remains an explicit higher-precedence filter and is never auto-generated from tracker-driven readiness markers in V1. |
| F7 | Runtime visibility for readiness behavior | Medium | Runtime feedback should make it clear when an item is blocked by missing readiness markers versus blocked by existing tracker or lifecycle state. |

## KPIs

| KPI | Target | How to Measure |
| --- | --- | --- |
| Manual restart avoidance | Reduce restart-required admissions by 95% | Compare operator flows before and after release in dogfood runs and support feedback. |
| Ready-to-dispatch latency | 90% of ready items dispatch within one polling interval when capacity is available | Measure time between marker creation and dispatch start in Runtime State or logs. |
| False-positive admission rate | Fewer than 1 unintended admission per 100 ready-marked items | Audit admitted work against tracker state and operator intent during dogfood runs. |
| Queue misuse avoidance | 0 auto-created **Ordered Queue** entries from readiness markers in V1 | Verify runtime state and queue persistence behavior in integration tests. |
| Compozy marker drift incidents | Fewer than 2 operator-reported confusion cases per release cycle | Track dogfood feedback about `_tasks.md` readiness versus lifecycle/task-step state. |

## Feature Assessment

| Criteria | Question | Score |
| --- | --- | --- |
| **Impact** | How much more valuable does this make the product? | Must do |
| **Reach** | What % of users would this affect? | Strong |
| **Frequency** | How often would users encounter this value? | Must do |
| **Differentiation** | Does this set us apart or just match competitors? | Strong |
| **Defensibility** | Is this easy to copy or does it compound over time? | Maybe |
| **Feasibility** | Can we actually build this? | Must do |

Leverage type: Quick Win

## Council Insights

- **Recommended approach:** Add `ready-for-symphony` inside selected tracker candidate-admission logic and keep orchestration and **Ordered Queue** semantics unchanged in V1.
- **Key trade-offs:** Explicit readiness improves operator control, but it introduces one more marker that can become stale; Compozy gets better run-level intent, but `_tasks.md` must not become a second lifecycle source.
- **Risks identified:** Hidden queue behavior if precedence is vague; restart and stale-marker confusion if first-admission semantics are underspecified; Compozy drift if `_tasks.md` starts expressing progress or completion.
- **Stretch goal (V2+):** Add readiness linting or scoring so Symphony can tell operators whether an issue or **Compozy PRD Run** is well-formed before it is marked ready.

## Out of Scope (V1)

- **Automatic Ordered Queue creation from tracker markers** — This would change queue identity, resume semantics, and operator expectations too early.
- **Multi-tracker intake in one Workspace Repository** — The selected tracker model stays intact and avoids reconciliation complexity.
- **Readiness-based prioritization or scheduling rules** — V1 decides eligibility, not dynamic ordering.
- **Per-step Compozy readiness markers** — The admission unit remains the **Compozy PRD Run**, not individual `task_NN.md` files.
- **Marker-driven cancellation of in-flight work** — Once admitted, existing lifecycle and retry semantics continue to govern the work item.
- **Broad dashboard workflow redesign** — Runtime visibility can improve, but V1 does not require a new operator control plane.

## Architecture Decision Records

- [ADR-001: Add explicit tracker-driven ready-for-symphony admission](./adrs/adr-001.md) — Defines readiness as a tracker-bound first-admission gate and keeps queue semantics separate.

## Open Questions

- How should Runtime State explain stale ready markers that are overridden by active, terminal, or stage-driven lifecycle semantics?
