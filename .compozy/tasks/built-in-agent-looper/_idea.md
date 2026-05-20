# Built-In Agent Looper

## Overview

Build a Runtime-owned **Goal Loop** for Personal Symphony so a Codex operator can give Symphony an explicit goal and let the selected Agent Harness continue working until the goal is satisfied, blocked, or budget-exhausted. V1 should feel narrow: one goal, bounded loop attempts, visible progress, and no extra user nudges for routine continuation. Internally, it should use platform-shaped contracts for future loop recipes, cross-harness support, and richer operations visibility.

## Problem

Personal Symphony already supports **Harness Loop** and **Stage Goal Handoff**, but those are launch-time handoffs. They do not give Symphony ownership over loop state, stop reasons, continuation decisions, progress evidence, or budget visibility.

Operators still have to supervise repeated agent turns manually: inspect output, decide whether the goal is met, nudge the agent, and track cost or drift themselves. This weakens Symphony's value as an orchestration runtime because the system can dispatch agents, but cannot yet own the repeated work loop that makes agent output reliable.

### Market Data

Agent products now compete on delegation, monitoring, and review: Codex runs background tasks in isolated environments, GitHub Copilot cloud agent works through issue/PR flows, Claude `/goal` uses a separate evaluator, and Devin exposes session insights for cost, scope, and repeated-issue patterns. Gartner forecasted task-specific AI agents in 40% of enterprise apps by end of 2026, up from under 5% in 2025.

## Summary / Differentiator

The differentiator is **Workspace Repository-owned loop control**. Instead of relying on provider-specific slash commands or global hooks, Symphony should make goal progress, stop conditions, usage, and evidence part of Runtime State.

## Core Features

| # | Feature | Priority | Description |
|---|---|---|---|
| F1 | Goal Loop Run | Critical | Start a bounded loop for one explicit goal using the selected Agent Harness. |
| F2 | Stop Budgets | Critical | Configure max turns, elapsed time, and usage/cost ceilings for each loop run. |
| F3 | Evidence-Based Stop Reason | Critical | Stop with a visible reason: goal met, blocked, budget exhausted, or evidence missing. |
| F4 | Runtime State Visibility | Critical | Expose active goal, attempts, latest evidence, usage, and next action through Runtime State. |
| F5 | Console/Dashboard Surfacing | High | Show the authoritative loop state in Terminal Console and Web Dashboard. |
| F6 | Harness Adapter Boundary | High | Treat provider loop commands as adapters, not as the source of truth. |
| F7 | Attention Handoff | High | Move ambiguous or blocked loops into a clear operator-attention path without changing delivery authority. |

## Integration with Existing Features

| Integration Point | How |
|---|---|
| Harness Loop | Becomes a provider adapter for Goal Loop execution, not the whole loop model. |
| Stage Goal Handoff | May seed Goal Loop context, but keeps existing non-semantic lifecycle behavior. |
| Runtime State | Becomes the authoritative visibility surface for loop run status. |
| Terminal Console / Web Dashboard | Render Goal Loop status, evidence, usage, and stop reason. |
| Agent Worktree | Remains the execution boundary for file changes and verification evidence. |

## KPIs

| KPI | Target | How to Measure |
|---|---:|---|
| Unnudged completion | >= 70% | Share of looped tasks reaching success or attention without extra user continuation prompts. |
| Stop explanation coverage | >= 90% | Loop runs with explicit stop reason and latest evidence in Runtime State. |
| Budget overrun rate | <= 10% | Loops exceeding configured turn/time/usage budget without actionable attention. |
| Reusable state contract | >= 2 surfaces | Same loop state rendered in Runtime State plus at least one UI surface. |
| Silent lifecycle mutation | 0 | No loop path changes commit, push, merge, PR, or status behavior outside accepted rules. |

## Feature Assessment

| Criteria | Question | Score |
|---|---|---|
| **Impact** | How much more valuable does this make the product? | Must do |
| **Reach** | What % of users would this affect? | Strong |
| **Frequency** | How often would users encounter this value? | Strong |
| **Differentiation** | Does this set us apart or just match competitors? | Strong |
| **Defensibility** | Is this easy to copy or does it compound over time? | Strong |
| **Feasibility** | Can we actually build this? | Maybe |

Leverage type: **Compounding Feature**

## Council Insights

- **Recommended approach:** Build a narrow Goal Loop V1 with platform-shaped internal contracts.
- **Key trade-offs:** Fast learning versus durable runtime semantics; provider loop reuse versus Symphony-owned state; model judgment versus deterministic evidence.
- **Risks identified:** False completion, unbounded token spend, scope creep into delivery behavior, provider lock-in, and weak auditability.
- **Stretch goal (V2+):** Named reusable loop recipes with health detection, cost history, and cross-harness support.

## Out of Scope (V1)

- **Full autonomous delivery authority** — commit, push, merge, PR, and status transitions stay under existing lifecycle rules.
- **Independent completion review** — valuable, but it changes completion semantics and needs a separate ADR.
- **Multi-goal orchestration** — V1 proves one goal loop before coordinating many.
- **Recipe marketplace or broad configuration UI** — defer until the core Runtime contract is validated.
- **Provider-specific global hooks** — Symphony should not depend on hidden global Codex lifecycle behavior.

## Architecture Decision Records

- [ADR-001: Goal Loop Runtime Scope](adrs/adr-001.md) — Accepts a narrow user-facing Goal Loop with platform-shaped Runtime contracts.

## Open Questions

- What final domain term should be accepted in `CONTEXT.md`: **Goal Loop**, **Agent Loop Run**, or another term?
- Should V1 require deterministic verification commands for every goal, or only for goals that claim verifiable completion?
- Should loop budgets live per Stage Agent, per Logical Agent, per Harness, or per explicit run?
- What is the first supported provider target: Codex only, or any Harness with loop capability?

## Research Anchors

- [Codex cloud](https://developers.openai.com/codex/cloud)
- [GitHub Copilot cloud agent](https://docs.github.com/en/copilot/concepts/agents/cloud-agent/about-cloud-agent)
- [Claude `/goal`](https://code.claude.com/docs/en/goal)
- [AI SDK loop control](https://ai-sdk.dev/docs/agents/loop-control)
- [Devin Session Insights](https://docs.devin.ai/product-guides/session-insights)
- [Gartner forecast](https://www.gartner.com/en/newsroom/press-releases/2025-08-26-gartner-predicts-40-percent-of-enterprise-apps-will-feature-task-specific-ai-agents-by-2026-up-from-less-than-5-percent-in-2025)
